package com.example.connect

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.RemoteInput
import android.app.Service
import android.content.ClipData
import android.content.Context
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.media.AudioManager
import android.media.session.MediaController
import android.net.Uri
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Base64
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import android.content.pm.ServiceInfo
import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentChange
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreException
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.QuerySnapshot
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

class NotificationListener : NotificationListenerService() {

    // Usamos un MethodChannel estático para que MainActivity pueda asignarlo
    data class ActiveNotificationEntry(
        val key: String,
        val packageName: String,
        val appName: String,
        val appIcon: String,
        val title: String,
        val text: String,
        val subText: String?,
        val postTime: Long
    )

    companion object {
        var methodChannel: MethodChannel? = null
        var isRunning: Boolean = false
        @Volatile var serviceInstance: NotificationListener? = null
        private val activeNotificationsMap = ConcurrentHashMap<String, ActiveNotificationEntry>()
        private var replyQueueReg: ListenerRegistration? = null
        private val replyExecutor = Executors.newSingleThreadExecutor()
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "notification_listener_channel"
        private const val PREFS_LOCAL_MEDIA_CACHE = "local_media_cache_v1"
        private const val KEY_MEDIA_JSON = "media_json"
        private const val KEY_MEDIA_UPDATED_AT_MS = "updatedAtMs"
        private const val ACTION_ACTIVE_NOTIFICATIONS_CHANGED = "com.example.connect.ACTIVE_NOTIFICATIONS_CHANGED"

        fun getActiveNotificationsSnapshot(): List<ActiveNotificationEntry> {
            return activeNotificationsMap.values
                .toList()
                .sortedByDescending { it.postTime }
        }

        /// True si la notificación con [sbnKey] sigue presente en la barra.
        fun isNotificationActive(sbnKey: String): Boolean {
            val k = sbnKey.trim()
            if (k.isEmpty()) return false
            return activeNotificationsMap.containsKey(k)
        }

        fun cancelNotificationByKey(key: String): Boolean {
            val inst = serviceInstance ?: return false
            return try {
                inst.cancelNotification(key)
                try { activeNotificationsMap.remove(key) } catch (_: Exception) {}
                try { inst.sendBroadcast(Intent(ACTION_ACTIVE_NOTIFICATIONS_CHANGED)) } catch (_: Exception) {}
                true
            } catch (_: Exception) {
                false
            }
        }

        fun cancelAllActiveNotifications(): Int {
            val inst = serviceInstance ?: return 0
            val keys = try { activeNotificationsMap.keys.toList() } catch (_: Exception) { emptyList() }
            var canceled = 0
            for (k in keys) {
                try {
                    inst.cancelNotification(k)
                    canceled++
                } catch (_: Exception) {
                }
                try {
                    activeNotificationsMap.remove(k)
                } catch (_: Exception) {
                }
            }
            return canceled
        }

        fun cancelAllSystemNotifications(): Boolean {
            val inst = serviceInstance ?: return false
            return try {
                inst.cancelAllNotifications()
                try { activeNotificationsMap.clear() } catch (_: Exception) {}
                try { inst.sendBroadcast(Intent(ACTION_ACTIVE_NOTIFICATIONS_CHANGED)) } catch (_: Exception) {}
                true
            } catch (_: Exception) {
                false
            }
        }

        fun forceRebind(ctx: Context): Boolean {
            return try {
                val pm = ctx.packageManager ?: return false
                val cn = ComponentName(ctx, NotificationListener::class.java)
                pm.setComponentEnabledSetting(
                    cn,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
                pm.setComponentEnabledSetting(
                    cn,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                true
            } catch (_: Exception) {
                false
            }
        }

        fun trySendNotificationReply(sbnKey: String, replyText: String): Pair<Boolean, String> {
            val k = sbnKey.trim()
            val t = replyText.trim()
            if (k.isEmpty()) return Pair(false, "sbnKey_vacio")
            if (t.isEmpty()) return Pair(false, "replyText_vacio")

            val inst = serviceInstance ?: return Pair(false, "servicio_no_disponible")
            val list = try { inst.activeNotifications?.toList() ?: emptyList() } catch (_: Exception) { emptyList() }
            val sbn = list.firstOrNull { it.key == k } ?: return Pair(false, "notificacion_no_encontrada")
            val notif = sbn.notification ?: return Pair(false, "notificacion_null")

            val actions = try { notif.actions?.toList() ?: emptyList() } catch (_: Exception) { emptyList() }
            if (actions.isEmpty()) return Pair(false, "sin_acciones")

            for (action in actions) {
                val remoteInputs = try { action.remoteInputs?.toList() ?: emptyList() } catch (_: Exception) { emptyList() }
                if (remoteInputs.isEmpty()) continue

                val fillIn = Intent().apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    clipData = ClipData.newIntent("remoteinput", Intent())
                }

                val results = Bundle()
                for (ri in remoteInputs) {
                    results.putCharSequence(ri.resultKey, t)
                }
                try {
                    RemoteInput.addResultsToIntent(remoteInputs.toTypedArray(), fillIn, results)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        RemoteInput.setResultsSource(fillIn, RemoteInput.SOURCE_FREE_FORM_INPUT)
                    }
                } catch (e: Exception) {
                    return Pair(false, "remoteinput_add_failed")
                }

                return try {
                    action.actionIntent.send(inst, 0, fillIn)
                    Pair(true, "")
                } catch (e: Exception) {
                    Pair(false, "pending_intent_send_failed")
                }
            }

            return Pair(false, "sin_remoteinput")
        }

        fun trySendNotificationReplySmart(
            sbnKey: String,
            replyText: String,
            packageName: String?,
            conversationTitle: String?
        ): Pair<Boolean, String> {
            val first = trySendNotificationReply(sbnKey, replyText)
            if (first.first) return first

            val err = first.second
            val pkg = packageName?.trim().orEmpty()
            val title = conversationTitle?.trim().orEmpty()
            if (pkg.isEmpty() || title.isEmpty()) return first
            if (err != "notificacion_no_encontrada" && err != "sin_remoteinput" && err != "sin_acciones") {
                return first
            }

            fun norm(s: String): String {
                return s.trim().lowercase().replace(Regex("\\s+"), " ")
            }

            val inst = serviceInstance ?: return Pair(false, "servicio_no_disponible")
            val list = try { inst.activeNotifications?.toList() ?: emptyList() } catch (_: Exception) { emptyList() }
            val targetTitle = norm(title)
            if (targetTitle.isEmpty()) return first

            val candidates = list
                .filter { it.packageName == pkg }
                .sortedByDescending { it.postTime }

            for (sbn in candidates) {
                val notif = sbn.notification ?: continue
                val extras = try { notif.extras } catch (_: Exception) { null }
                val rawTitle = try {
                    extras?.getString(Notification.EXTRA_TITLE)
                        ?: extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()
                        ?: ""
                } catch (_: Exception) {
                    ""
                }
                val candTitle = norm(rawTitle)
                val titleMatch = candTitle == targetTitle ||
                        (candTitle.isNotEmpty() && targetTitle.isNotEmpty() &&
                                (candTitle.contains(targetTitle) || targetTitle.contains(candTitle)))
                if (!titleMatch) continue

                val actions = try { notif.actions?.toList() ?: emptyList() } catch (_: Exception) { emptyList() }
                if (actions.isEmpty()) continue
                for (action in actions) {
                    val remoteInputs = try { action.remoteInputs?.toList() ?: emptyList() } catch (_: Exception) { emptyList() }
                    if (remoteInputs.isEmpty()) continue

                    val fillIn = Intent().apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        clipData = ClipData.newIntent("remoteinput", Intent())
                    }

                    val results = Bundle()
                    for (ri in remoteInputs) {
                        results.putCharSequence(ri.resultKey, replyText.trim())
                    }
                    try {
                        RemoteInput.addResultsToIntent(remoteInputs.toTypedArray(), fillIn, results)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            RemoteInput.setResultsSource(fillIn, RemoteInput.SOURCE_FREE_FORM_INPUT)
                        }
                    } catch (_: Exception) {
                        return Pair(false, "remoteinput_add_failed")
                    }

                    return try {
                        action.actionIntent.send(inst, 0, fillIn)
                        Pair(true, "")
                    } catch (_: Exception) {
                        Pair(false, "pending_intent_send_failed")
                    }
                }
            }

            return Pair(false, "smart_no_match")
        }

        fun startReplyQueueListener(ctx: Context) {
            if (replyQueueReg != null) return
            val prefs = try {
                ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            } catch (_: Exception) {
                null
            } ?: return

            val deviceId = prefs.getString("flutter.device_id", null)?.trim().orEmpty()
            if (deviceId.isEmpty()) return

            val query = FirebaseFirestore.getInstance()
                .collection("dispositivos")
                .document(deviceId)
                .collection("replyQueue")
                .whereEqualTo("status", "pending")
                .limit(20)

            replyQueueReg = query.addSnapshotListener { snapshots: QuerySnapshot?, error: FirebaseFirestoreException? ->
                if (error != null) return@addSnapshotListener
                if (snapshots == null) return@addSnapshotListener

                for (change in snapshots.documentChanges) {
                    if (change.type != DocumentChange.Type.ADDED && change.type != DocumentChange.Type.MODIFIED) continue
                    val doc = change.document
                    val status = doc.getString("status")?.trim().orEmpty()
                    if (status != "pending") continue

                    val requestId = doc.getString("requestId")?.trim().orEmpty().ifEmpty { doc.id }
                    val sbnKey = doc.getString("sbnKey")?.trim().orEmpty()
                    val replyText = doc.getString("replyText")?.trim().orEmpty()
                    val packageName = doc.getString("packageName")?.trim().orEmpty()
                    val conversationTitle = doc.getString("conversationTitle")?.trim().orEmpty()
                    if (requestId.isEmpty() || sbnKey.isEmpty() || replyText.isEmpty()) {
                        try {
                            doc.reference.update(
                                mapOf(
                                    "status" to "error",
                                    "ok" to false,
                                    "error" to "campos_incompletos",
                                    "doneAt" to Timestamp.now()
                                )
                            )
                        } catch (_: Exception) {
                        }
                        continue
                    }

                    try {
                        doc.reference.update(
                            mapOf(
                                "status" to "processing",
                                "processingAt" to Timestamp.now()
                            )
                        )
                    } catch (_: Exception) {
                    }

                    replyExecutor.execute {
                        val res = trySendNotificationReplySmart(sbnKey, replyText, packageName, conversationTitle)
                        val ok = res.first
                        val err = res.second
                        try {
                            doc.reference.update(
                                mapOf(
                                    "status" to (if (ok) "done" else "error"),
                                    "ok" to ok,
                                    "error" to (if (ok) "" else err),
                                    "processedSbnKey" to sbnKey,
                                    "processedRequestId" to requestId,
                                    "doneAt" to Timestamp.now()
                                )
                            )
                        } catch (_: Exception) {
                        }
                    }
                }
            }
        }

        fun stopReplyQueueListener() {
            try {
                replyQueueReg?.remove()
            } catch (_: Exception) {
            }
            replyQueueReg = null
        }
    }

    private fun buildActiveEntryOrNull(sbn: StatusBarNotification): ActiveNotificationEntry? {
        val packageName = sbn.packageName ?: return null
        val excludedPackages = setOf(
            "android",
            "com.android.systemui",
            "com.android.settings"
        )
        if (excludedPackages.contains(packageName)) return null

        val notification = sbn.notification ?: return null
        if (packageName == "com.example.connect") {
            val chId =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) notification.channelId else null
            if (chId == CHANNEL_ID || sbn.id == NOTIFICATION_ID) return null
        }
        val extras = notification.extras

        val category = notification.category ?: ""
        val hasMediaSession =
            try { extras.containsKey(Notification.EXTRA_MEDIA_SESSION) } catch (_: Exception) { false }
        val template =
            try { extras.getString("android.template") ?: "" } catch (_: Exception) { "" }
        val isMediaNotification = category == Notification.CATEGORY_TRANSPORT ||
                hasMediaSession ||
                template.contains("MediaStyle", ignoreCase = true)
        if (isMediaNotification) return null

        val title = try {
            extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        } catch (_: Exception) {
            ""
        }

        val text = try {
            val direct = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
            if (direct.isNotBlank()) direct else {
                val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
                if (lines != null && lines.isNotEmpty()) {
                    lines.joinToString("\n") { it?.toString().orEmpty() }.trim()
                } else {
                    ""
                }
            }
        } catch (_: Exception) {
            ""
        }

        val subText = try {
            extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
        } catch (_: Exception) {
            null
        }

        var appName = packageName
        var appIcon = ""
        try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            appName = packageManager.getApplicationLabel(appInfo).toString()
            try {
                val drawable = packageManager.getApplicationIcon(appInfo)
                appIcon = drawableToBase64(drawable)
            } catch (_: Exception) {
            }
        } catch (_: Exception) {
        }

        val key = sbn.key ?: return null
        return ActiveNotificationEntry(
            key = key,
            packageName = packageName,
            appName = appName,
            appIcon = appIcon,
            title = title,
            text = text,
            subText = subText,
            postTime = sbn.postTime
        )
    }

    private fun drawableToBase64(drawable: Drawable): String {
        return try {
            val maxSize = 96
            val w = drawable.intrinsicWidth.coerceAtLeast(1).coerceAtMost(maxSize)
            val h = drawable.intrinsicHeight.coerceAtLeast(1).coerceAtMost(maxSize)
            val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 80, out)
            Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
        } catch (_: Exception) {
            ""
        }
    }

    private fun updateActiveCache(sbn: StatusBarNotification) {
        val entry = buildActiveEntryOrNull(sbn) ?: return
        activeNotificationsMap[entry.key] = entry
    }

    private fun removeActiveCache(sbn: StatusBarNotification) {
        val key = sbn.key ?: return
        activeNotificationsMap.remove(key)
    }

    private fun rebuildActiveCacheFromSystem() {
        try {
            val list = try { activeNotifications?.toList() ?: emptyList() } catch (_: Exception) { emptyList() }
            val keys = HashSet<String>()
            for (sbn in list) {
                val k = sbn.key ?: continue
                keys.add(k)
                updateActiveCache(sbn)
            }
            val iterator = activeNotificationsMap.keys.iterator()
            while (iterator.hasNext()) {
                val k = iterator.next()
                if (!keys.contains(k)) iterator.remove()
            }
        } catch (_: Exception) {
        }
    }

    private fun emitActiveNotificationsChangedBroadcast() {
        try {
            sendBroadcast(Intent(ACTION_ACTIVE_NOTIFICATIONS_CHANGED))
        } catch (_: Exception) {
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d("NotificationListener", "Service created")
        // Crear canal de notificación para Android O y superior
        createNotificationChannel()
        // Iniciar el servicio en primer plano inmediatamente
        startForegroundService()
        try {
            BtClassicClient.init(this)
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean("flutter.ble_enabled", true)
            val address = prefs.getString("flutter.ble_peer_address", null)
            if (enabled && !address.isNullOrBlank()) {
                BtClassicClient.connect(address)
            }
        } catch (_: Exception) {
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Servicio de Notificaciones"
            val descriptionText = "Monitorea las notificaciones del sistema"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            Log.d("NotificationListener", "Canal de notificación creado")
        }
    }

    private fun startForegroundService() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Servicio de Notificaciones")
            .setContentText("Monitoreando notificaciones")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        // En Android 12+ (API 31+), debes especificar el tipo de servicio
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        
        Log.d("NotificationListener", "Servicio iniciado en primer plano")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isRunning = true
        serviceInstance = this
        Log.d("NotificationListener", "Servicio de escucha de notificaciones conectado")
        // Notificar a Flutter que el servicio está conectado
        methodChannel?.invokeMethod("serviceConnected", null)
        rebuildActiveCacheFromSystem()
        emitActiveNotificationsChangedBroadcast()
        startReplyQueueListener(applicationContext)
        startMediaMonitoring()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isRunning = false
        serviceInstance = null
        Log.d("NotificationListener", "Servicio de escucha de notificaciones desconectado")
        try {
            requestRebind(ComponentName(this, NotificationListener::class.java))
            Log.d("NotificationListener", "Solicitando rebind del servicio")
        } catch (e: Exception) {
            Log.e("NotificationListener", "Error solicitando rebind", e)
        }
        methodChannel?.invokeMethod("serviceDisconnected", null)
    }

    private var mediaSessionManager: MediaSessionManager? = null
    private var currentMediaController: MediaController? = null
    private var mediaControllerCallback: MediaController.Callback? = null
    private val mediaHandler = Handler(Looper.getMainLooper())
    private var mediaTickRunnable: Runnable? = null
    private var lastStaticSignature: String? = null
    private var lastPositionSecond: Long = -1L
    private var btClientInitialized: Boolean = false
    private var btClientLastAddress: String? = null

    private val activeSessionsListener =
        MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
            updateActiveMediaController(controllers)
        }

    private fun startMediaMonitoring() {
        try {
            val msm = getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
            mediaSessionManager = msm
            if (msm == null) return

            val component = ComponentName(this, NotificationListener::class.java)
            msm.addOnActiveSessionsChangedListener(activeSessionsListener, component)
            val controllers = msm.getActiveSessions(component)
            updateActiveMediaController(controllers)
            ensureBtClientConnectedFromPrefs("startMediaMonitoring")
        } catch (_: Exception) {
        }
    }

    private fun ensureBtClientConnectedFromPrefs(reason: String): Boolean {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean("flutter.ble_enabled", true)
            val address = prefs.getString("flutter.ble_peer_address", null)
            println("[media][bt] ensure_connected reason=$reason enabled=$enabled address=${address ?: ""}")
            if (!enabled || address.isNullOrBlank()) return false

            if (!btClientInitialized) {
                BtClassicClient.init(applicationContext)
                btClientInitialized = true
                println("[media][bt] BtClassicClient.init ok")
            }

            if (btClientLastAddress != address) {
                btClientLastAddress = address
                BtClassicClient.connect(address)
                println("[media][bt] BtClassicClient.connect requested address=$address")
            }

            true
        } catch (e: Exception) {
            println("[media][bt] ensure_connected error=${e.message ?: ""}")
            false
        }
    }

    private fun updateActiveMediaController(controllers: List<MediaController>?) {
        val list = controllers ?: emptyList()
        val best = selectBestController(list)
        if (best?.sessionToken == currentMediaController?.sessionToken) {
            sendMediaState(false)
            return
        }

        try {
            mediaControllerCallback?.let { cb ->
                try { currentMediaController?.unregisterCallback(cb) } catch (_: Exception) {}
            }
        } catch (_: Exception) {
        }

        currentMediaController = best
        mediaControllerCallback = object : MediaController.Callback() {
            override fun onMetadataChanged(metadata: android.media.MediaMetadata?) {
                sendMediaState(true)
            }

            override fun onPlaybackStateChanged(state: android.media.session.PlaybackState?) {
                sendMediaState(true)
            }
        }

        try {
            best?.registerCallback(mediaControllerCallback!!)
        } catch (_: Exception) {
        }

        sendMediaState(true)
    }

    private fun selectBestController(controllers: List<MediaController>): MediaController? {
        if (controllers.isEmpty()) return null
        val playing = controllers.firstOrNull { c ->
            val state = c.playbackState?.state ?: PlaybackState.STATE_NONE
            state == PlaybackState.STATE_PLAYING || state == PlaybackState.STATE_BUFFERING
        }
        if (playing != null) return playing
        val paused = controllers.firstOrNull { c ->
            val state = c.playbackState?.state ?: PlaybackState.STATE_NONE
            state == PlaybackState.STATE_PAUSED
        }
        return paused ?: controllers.first()
    }

    private fun scheduleMediaTick(nextDelayMs: Long) {
        val runnable = mediaTickRunnable ?: Runnable { sendMediaState(false) }.also {
            mediaTickRunnable = it
        }
        mediaHandler.removeCallbacks(runnable)
        mediaHandler.postDelayed(runnable, nextDelayMs)
    }

    private fun saveLocalMediaCache(json: String) {
        try {
            val now = System.currentTimeMillis()
            val prefs = applicationContext.getSharedPreferences(PREFS_LOCAL_MEDIA_CACHE, Context.MODE_PRIVATE)

            val mergedJson = try {
                val obj = JSONObject(json)
                val art = obj.optString("artBase64", "").trim()
                if (art.isBlank()) {
                    val prevJson = prefs.getString(KEY_MEDIA_JSON, null)
                    if (!prevJson.isNullOrBlank()) {
                        val prevObj = JSONObject(prevJson)
                        val prevArt = prevObj.optString("artBase64", "").trim()
                        if (prevArt.isNotBlank()) {
                            obj.put("artBase64", prevArt)
                            val prevMime = prevObj.optString("artMime", "").trim()
                            if (prevMime.isNotBlank() && obj.optString("artMime", "").trim().isBlank()) {
                                obj.put("artMime", prevMime)
                            }
                        }
                    }
                }
                obj.toString()
            } catch (_: Exception) {
                json
            }

            prefs.edit()
                .putString(KEY_MEDIA_JSON, mergedJson)
                .putLong(KEY_MEDIA_UPDATED_AT_MS, now)
                .apply()
        } catch (_: Exception) {
        }
    }

    private fun clearLocalMediaCache() {
        try {
            val prefs = applicationContext.getSharedPreferences(PREFS_LOCAL_MEDIA_CACHE, Context.MODE_PRIVATE)
            prefs.edit()
                .remove(KEY_MEDIA_JSON)
                .putLong(KEY_MEDIA_UPDATED_AT_MS, 0L)
                .apply()
        } catch (_: Exception) {
        }
    }

    private fun encodeArtBase64(metadata: android.media.MediaMetadata?): String? {
        if (metadata == null) return null

        fun computeSampleSize(width: Int, height: Int, maxSide: Int): Int {
            var sample = 1
            while (width / sample > maxSide || height / sample > maxSide) {
                sample *= 2
            }
            return sample.coerceAtLeast(1)
        }

        fun decodeBitmapFromUri(uriString: String, maxSide: Int): Bitmap? {
            val uri = try { Uri.parse(uriString) } catch (_: Exception) { null } ?: return null
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            try {
                contentResolver.openInputStream(uri)?.use { input ->
                    BitmapFactory.decodeStream(input, null, bounds)
                }
            } catch (_: Exception) {
                return null
            }

            val outW = bounds.outWidth
            val outH = bounds.outHeight
            if (outW <= 0 || outH <= 0) return null

            val sample = computeSampleSize(outW, outH, maxSide)
            val opts = BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            return try {
                contentResolver.openInputStream(uri)?.use { input ->
                    BitmapFactory.decodeStream(input, null, opts)
                }
            } catch (_: Exception) {
                null
            }
        }

        val maxSide = 220

        val raw: Bitmap? =
            metadata.getBitmap(android.media.MediaMetadata.METADATA_KEY_ALBUM_ART)
                ?: metadata.getBitmap(android.media.MediaMetadata.METADATA_KEY_ART)
                ?: metadata.getBitmap(android.media.MediaMetadata.METADATA_KEY_DISPLAY_ICON)

        val uriString: String? = if (raw == null) {
            metadata.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM_ART_URI)
                ?: metadata.getString(android.media.MediaMetadata.METADATA_KEY_ART_URI)
                ?: metadata.getString(android.media.MediaMetadata.METADATA_KEY_DISPLAY_ICON_URI)
        } else {
            null
        }

        val fromUri = if (!uriString.isNullOrBlank()) {
            decodeBitmapFromUri(uriString, maxSide)
        } else {
            null
        }

        val bmp = raw ?: fromUri ?: return null

        val width = bmp.width
        val height = bmp.height
        val scaled = if (width > maxSide || height > maxSide) {
            val ratio = if (width >= height) {
                maxSide.toFloat() / width.toFloat()
            } else {
                maxSide.toFloat() / height.toFloat()
            }
            val w = (width * ratio).toInt().coerceAtLeast(1)
            val h = (height * ratio).toInt().coerceAtLeast(1)
            Bitmap.createScaledBitmap(bmp, w, h, true)
        } else {
            bmp
        }

        val tryQualities = listOf(70, 55, 45)
        for (q in tryQualities) {
            val baos = ByteArrayOutputStream()
            try {
                scaled.compress(Bitmap.CompressFormat.JPEG, q, baos)
                val bytes = baos.toByteArray()
                if (bytes.size <= 120_000) {
                    return Base64.encodeToString(bytes, Base64.NO_WRAP)
                }
            } catch (_: Exception) {
            } finally {
                try { baos.close() } catch (_: Exception) {}
            }
        }
        return null
    }

    private fun sendMediaState(force: Boolean) {
        val controller = currentMediaController
        val state = controller?.playbackState
        val metadata = controller?.metadata

        val playbackState = state?.state ?: PlaybackState.STATE_NONE
        val isPlaying = playbackState == PlaybackState.STATE_PLAYING ||
                playbackState == PlaybackState.STATE_BUFFERING

        val actions = state?.actions ?: 0L
        val baseCanPlayPause = (actions and PlaybackState.ACTION_PLAY) != 0L ||
                (actions and PlaybackState.ACTION_PAUSE) != 0L ||
                (actions and PlaybackState.ACTION_PLAY_PAUSE) != 0L
        val baseCanSkipNext = (actions and PlaybackState.ACTION_SKIP_TO_NEXT) != 0L
        val baseCanSkipPrev = (actions and PlaybackState.ACTION_SKIP_TO_PREVIOUS) != 0L
        val canSeek = (actions and PlaybackState.ACTION_SEEK_TO) != 0L

        val title = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_TITLE)
            ?: metadata?.getString(android.media.MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
        val artist = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST)
            ?: metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
        val album = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM)
        val durationMs = metadata?.getLong(android.media.MediaMetadata.METADATA_KEY_DURATION) ?: 0L
        val positionMs = state?.position ?: 0L
        val packageName = controller?.packageName ?: ""

        val isYouTube =
            packageName == "com.google.android.youtube" || packageName == "com.google.android.apps.youtube.music"

        val canPlayPause = baseCanPlayPause || playbackState == PlaybackState.STATE_PLAYING ||
                playbackState == PlaybackState.STATE_BUFFERING ||
                playbackState == PlaybackState.STATE_PAUSED ||
                isYouTube
        val canSkipNext = baseCanSkipNext || isYouTube
        val canSkipPrev = baseCanSkipPrev || isYouTube

        val appName = if (packageName.isNotBlank()) {
            try {
                val appInfo = packageManager.getApplicationInfo(packageName, 0)
                packageManager.getApplicationLabel(appInfo).toString()
            } catch (_: Exception) {
                packageName
            }
        } else {
            ""
        }

        val staticSignature = listOf(
            packageName,
            title ?: "",
            artist ?: "",
            album ?: "",
            durationMs.toString(),
            isPlaying.toString(),
            canPlayPause.toString(),
            canSkipNext.toString(),
            canSkipPrev.toString(),
            canSeek.toString()
        ).joinToString("|")
        val positionSecond = (positionMs / 1000L).coerceAtLeast(0L)

        if (controller == null || packageName.isBlank() || title.isNullOrBlank()) {
            lastStaticSignature = null
            lastPositionSecond = -1L
            clearLocalMediaCache()
            println("[media] skip_send controller_null=${controller == null} pkg='$packageName' title='${title ?: ""}'")
            scheduleMediaTick(4000)
            return
        }

        val sendStatic = force || staticSignature != lastStaticSignature
        val sendPosition = isPlaying && positionSecond != lastPositionSecond

        if (!sendStatic && !sendPosition) {
            scheduleMediaTick(if (isPlaying) 1000 else 4000)
            return
        }

        if (sendStatic) lastStaticSignature = staticSignature
        if (sendPosition) lastPositionSecond = positionSecond

        val artBase64 = if (sendStatic) encodeArtBase64(metadata) else null

        val payload = HashMap<String, Any?>()
        payload["type"] = "media_state"
        payload["time"] = System.currentTimeMillis()
        payload["packageName"] = packageName
        payload["appName"] = appName
        payload["title"] = title
        payload["artist"] = artist ?: ""
        payload["album"] = album ?: ""
        payload["durationMs"] = durationMs
        payload["positionMs"] = positionMs
        payload["isPlaying"] = isPlaying
        payload["canPlayPause"] = canPlayPause
        payload["canSkipNext"] = canSkipNext
        payload["canSkipPrev"] = canSkipPrev
        payload["canSeek"] = canSeek

        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            val level = am?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: -1
            val max = am?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: -1
            if (level >= 0 && max > 0) {
                val pct = ((level.toDouble() / max.toDouble()) * 100.0).toInt().coerceIn(0, 100)
                payload["volumeLevel"] = level
                payload["volumeMax"] = max
                payload["volumePct"] = pct
            }
        } catch (_: Exception) {
        }
        if (!artBase64.isNullOrBlank()) {
            payload["artMime"] = "image/jpeg"
            payload["artBase64"] = artBase64
        }

        try {
            val connectedOk = ensureBtClientConnectedFromPrefs("sendMediaState")
            val json = JSONObject(payload as Map<*, *>).toString()
            saveLocalMediaCache(json)
            println("[media][tx] sendStatic=$sendStatic sendPosition=$sendPosition bytes=${json.toByteArray(Charsets.UTF_8).size} title='${title ?: ""}' app='$appName'")
            if (connectedOk) {
                val accepted = BtClassicClient.send(json)
                println("[media][tx] BtClassicClient.send accepted=$accepted")
            } else {
                println("[media][tx] not_sent: bt_not_configured")
            }
        } catch (_: Exception) {
            println("[media][tx] send_failed")
        }

        scheduleMediaTick(if (isPlaying) 1000 else 4000)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)

        if (sbn == null) return

        updateActiveCache(sbn)
        emitActiveNotificationsChangedBroadcast()
        try {
            val k = sbn.key
            val entry = if (k != null) activeNotificationsMap[k] else null
            if (entry == null) return
            val entryMap =
                mapOf(
                    "key" to entry.key,
                    "packageName" to entry.packageName,
                    "appName" to entry.appName,
                    "appIcon" to entry.appIcon,
                    "title" to entry.title,
                    "text" to entry.text,
                    "subText" to (entry.subText ?: ""),
                    "postTime" to entry.postTime
                )
            MainActivity.instance?.emitActiveNotificationsChanged("posted", k, entryMap)
        } catch (_: Exception) {
        }

        val packageName = sbn.packageName
        val notification = sbn.notification
        val extras = notification.extras

        // Lista de paquetes a excluir para evitar bucles infinitos y notificaciones no deseadas
        val excludedPackages = setOf(
            "android", // Sistema Android
            "com.android.systemui", // UI del sistema
            "com.android.settings" // Configuraciones del sistema
        )

        if (packageName == "com.example.connect") {
            val chId =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) notification.channelId else null
            if (chId == CHANNEL_ID || sbn.id == NOTIFICATION_ID) return
        }

        // Filtrar las notificaciones de paquetes excluidos
        if (excludedPackages.contains(packageName)) {
            Log.d("NotificationListener", "Ignorando notificación de paquete excluido: $packageName")
            return
        }

        val category = notification.category ?: ""
        val hasMediaSession =
            try { extras.containsKey(Notification.EXTRA_MEDIA_SESSION) } catch (_: Exception) { false }
        val template =
            try { extras.getString("android.template") ?: "" } catch (_: Exception) { "" }
        val isMediaNotification = category == Notification.CATEGORY_TRANSPORT ||
                hasMediaSession ||
                template.contains("MediaStyle", ignoreCase = true)
        if (isMediaNotification) {
            Log.d("NotificationListener", "Ignorando notificación multimedia: pkg=$packageName category=$category hasMediaSession=$hasMediaSession")
            return
        }

        val title = extras.getString(Notification.EXTRA_TITLE)
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val time = sbn.postTime // Timestamp de la notificación
        val sbnKey = sbn.key

        // Obtener el nombre de la aplicación
        val appName = try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            packageName // Usar el packageName si no se encuentra el nombre
        }

        val appIcon = try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            val drawable = packageManager.getApplicationIcon(appInfo)
            drawableToBase64(drawable)
        } catch (_: Exception) {
            ""
        }

        val notificationData = mapOf(
            "id" to time.toString(), // Usar el timestamp como ID
            "sbnKey" to (sbnKey ?: ""),
            "packageName" to packageName,
            "appName" to appName,
            "appIcon" to appIcon,
            "title" to title,
            "text" to text,
            "time" to time.toString() // Convertir a String para enviarlo
        )

        Log.d("NotificationListener", "Notificación capturada para EMISOR: $notificationData")

        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean("flutter.ble_enabled", true)
            val address = prefs.getString("flutter.ble_peer_address", null)
            if (enabled && !address.isNullOrBlank()) {
                val enabledPkgs = AppListService(this).getEnabledPackages()
                if (enabledPkgs.isNotEmpty() && enabledPkgs.contains(packageName)) {
                    BtClassicClient.send(JSONObject(notificationData).toString())
                }
            }
        } catch (_: Exception) {
        }

        // SOLO enviar la notificación a Flutter para procesamiento (guardar en Firebase)
        // NO mostrar notificación local aquí - eso es responsabilidad del RECEPTOR
        methodChannel?.invokeMethod("onNotificationReceived", notificationData)
            ?: Log.e("NotificationListener", "MethodChannel es null, no se puede enviar la notificación")
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        if (sbn != null) {
            removeActiveCache(sbn)
            emitActiveNotificationsChangedBroadcast()
            try {
                MainActivity.instance?.emitActiveNotificationsChanged("removed", sbn.key, null)
            } catch (_: Exception) {
            }
        }
        sbn?.let {
            val packageName = it.packageName
            Log.d("NotificationListener", "Notification Removed: Package: $packageName")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        serviceInstance = null
        stopReplyQueueListener()
        try {
            val component = ComponentName(this, NotificationListener::class.java)
            mediaSessionManager?.removeOnActiveSessionsChangedListener(activeSessionsListener)
            mediaSessionManager?.getActiveSessions(component)
        } catch (_: Exception) {
        }
        try {
            mediaTickRunnable?.let { mediaHandler.removeCallbacks(it) }
        } catch (_: Exception) {
        }
        Log.d("NotificationListener", "Service destroyed")
    }
}
