package com.example.connect

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.ComponentName
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioManager
import android.media.session.MediaController
import android.net.Uri
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Base64
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import android.content.pm.ServiceInfo
import org.json.JSONObject
import java.io.ByteArrayOutputStream

class NotificationListener : NotificationListenerService() {

    // Usamos un MethodChannel estático para que MainActivity pueda asignarlo
    companion object {
        var methodChannel: MethodChannel? = null
        var isRunning: Boolean = false
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "notification_listener_channel"
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
        Log.d("NotificationListener", "Servicio de escucha de notificaciones conectado")
        // Notificar a Flutter que el servicio está conectado
        methodChannel?.invokeMethod("serviceConnected", null)
        startMediaMonitoring()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isRunning = false
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
        val canPlayPause = (actions and PlaybackState.ACTION_PLAY) != 0L ||
                (actions and PlaybackState.ACTION_PAUSE) != 0L ||
                (actions and PlaybackState.ACTION_PLAY_PAUSE) != 0L
        val canSkipNext = (actions and PlaybackState.ACTION_SKIP_TO_NEXT) != 0L
        val canSkipPrev = (actions and PlaybackState.ACTION_SKIP_TO_PREVIOUS) != 0L
        val canSeek = (actions and PlaybackState.ACTION_SEEK_TO) != 0L

        val title = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_TITLE)
            ?: metadata?.getString(android.media.MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
        val artist = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST)
            ?: metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
        val album = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM)
        val durationMs = metadata?.getLong(android.media.MediaMetadata.METADATA_KEY_DURATION) ?: 0L
        val positionMs = state?.position ?: 0L
        val packageName = controller?.packageName ?: ""

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

        val packageName = sbn.packageName
        val notification = sbn.notification
        val extras = notification.extras

        // Lista de paquetes a excluir para evitar bucles infinitos y notificaciones no deseadas
        val excludedPackages = setOf(
            "com.example.connect", // Nuestra propia aplicación
            "android", // Sistema Android
            "com.android.systemui", // UI del sistema
            "com.android.settings" // Configuraciones del sistema
        )

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

        // Obtener el nombre de la aplicación
        val appName = try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            packageName // Usar el packageName si no se encuentra el nombre
        }

        val notificationData = mapOf(
            "id" to time.toString(), // Usar el timestamp como ID
            "packageName" to packageName,
            "appName" to appName,
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
        sbn?.let {
            val packageName = it.packageName
            Log.d("NotificationListener", "Notification Removed: Package: $packageName")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
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
