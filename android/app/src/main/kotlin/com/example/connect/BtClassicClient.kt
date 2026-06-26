package com.example.connect

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothSocket
import android.content.ComponentName
import android.content.Context
import android.content.Intent
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
import android.os.SystemClock
import android.util.Base64
import android.util.Log
import android.view.KeyEvent
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.EOFException
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.roundToInt

object BtClassicClient {
    private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private const val MEDIA_LAUNCH_CHANNEL_ID = "media_launch_channel"
    private var lastMediaLaunchNotifAtMs: Long = 0L

    private var appContext: Context? = null
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val scheduler = ScheduledThreadPoolExecutor(1)

    private var socket: BluetoothSocket? = null
    private var input: DataInputStream? = null
    private var out: DataOutputStream? = null
    private var targetAddress: String? = null
    private var reconnectAttempt: Int = 0
    private val reconnectScheduled = AtomicBoolean(false)
    private val readerRunning = AtomicBoolean(false)
    private var readerThread: Thread? = null

    private var flutterEngine: FlutterEngine? = null
    private var btHiveChannel: MethodChannel? = null
    private var deviceFinderManager: DeviceFinderManager? = null

    fun init(context: Context) {
        appContext = context.applicationContext
        println("[btclassic][client] init")
    }

    fun connect(address: String) {
        val current = targetAddress
        val s = socket
        if (current == address && s != null && s.isConnected) {
            println("[btclassic][client] connect ignored: already_connected address=$address")
            return
        }
        targetAddress = address
        reconnectAttempt = 0
        println("[btclassic][client] connect requested address=$address")
        ioExecutor.execute { connectInternal(address) }
    }

    fun disconnect() {
        targetAddress = null
        reconnectAttempt = 0
        println("[btclassic][client] disconnect requested")
        ioExecutor.execute { closeInternal() }
    }

    fun send(json: String): Boolean {
        val addr = targetAddress ?: run {
            println("[btclassic][client] send rejected: no targetAddress")
            return false
        }
        println("[btclassic][client] send queued bytes=${json.toByteArray(Charsets.UTF_8).size} addr=$addr")
        ioExecutor.execute {
            val ok = trySendInternal(json)
            println("[btclassic][client] send result ok=$ok")
            if (!ok) scheduleReconnect(addr)
        }
        return true
    }

    private fun connectInternal(address: String) {
        closeInternal()
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return
        if (!adapter.isEnabled) return
        try {
            try { adapter.cancelDiscovery() } catch (_: Exception) {}
            val device = adapter.getRemoteDevice(address)
            val s = device.createRfcommSocketToServiceRecord(SPP_UUID)
            s.connect()
            socket = s
            input = DataInputStream(s.inputStream)
            out = DataOutputStream(s.outputStream)
            reconnectAttempt = 0
            reconnectScheduled.set(false)
            Log.d("BtClassicClient", "connected: $address")
            println("[btclassic][client] connected address=$address")
            startReaderThread(address)
            maybeSendFirebaseLink()
        } catch (e: Exception) {
            Log.d("BtClassicClient", "connect_failed: ${e.message ?: ""}")
            println("[btclassic][client] connect_failed address=$address err=${e.message ?: ""}")
            closeInternal()
            scheduleReconnect(address)
        }
    }

    private fun trySendInternal(json: String): Boolean {
        val bytes = json.toByteArray(Charsets.UTF_8)
        val o = out ?: return false
        return try {
            o.writeInt(bytes.size)
            o.write(bytes)
            o.flush()
            true
        } catch (e: Exception) {
            Log.d("BtClassicClient", "send_failed: ${e.message ?: ""}")
            println("[btclassic][client] send_failed err=${e.message ?: ""}")
            closeInternal()
            false
        }
    }

    private fun scheduleReconnect(address: String) {
        if (reconnectScheduled.getAndSet(true)) return
        val attempt = reconnectAttempt.coerceAtMost(8)
        val delayMs = (1000L shl attempt).coerceAtMost(30000L)
        reconnectAttempt = (reconnectAttempt + 1).coerceAtMost(50)
        scheduler.schedule({
            reconnectScheduled.set(false)
            ioExecutor.execute {
                if (targetAddress == address) connectInternal(address)
            }
        }, delayMs, TimeUnit.MILLISECONDS)
        Log.d("BtClassicClient", "reconnect_scheduled: $delayMs ms")
    }

    private fun startReaderThread(address: String) {
        readerRunning.set(true)
        readerThread = Thread {
            try {
                val i = input ?: return@Thread
                while (readerRunning.get() && targetAddress == address) {
                    val len = try { i.readInt() } catch (e: EOFException) { break }
                    if (len <= 0 || len > 1024 * 256) break
                    val data = ByteArray(len)
                    i.readFully(data)
                    handleIncomingPayload(String(data, Charsets.UTF_8))
                }
            } catch (_: Exception) {
            } finally {
                ioExecutor.execute {
                    val shouldReconnect = targetAddress == address
                    closeInternal()
                    if (shouldReconnect) scheduleReconnect(address)
                }
            }
        }.also { it.start() }
    }

    private fun handleIncomingPayload(json: String) {
        try {
            val obj = JSONObject(json)
            val type = obj.optString("type", "")
            when (type) {
                "media_command" -> {
                    val command = obj.optString("command", "")
                    val positionMs = try { obj.optLong("positionMs", -1L) } catch (_: Exception) { -1L }
                    val ctx = appContext ?: return
                    handleMediaCommand(ctx, command, positionMs)
                }
                "volume_command" -> {
                    val ctx = appContext ?: return
                    val pct = try { obj.optInt("pct", -1) } catch (_: Exception) { -1 }
                    val level = try { obj.optInt("level", -1) } catch (_: Exception) { -1 }
                    val max = try { obj.optInt("max", -1) } catch (_: Exception) { -1 }
                    handleVolumeCommand(ctx, pct, level, max)
                }
                "volume_request" -> {
                    val ctx = appContext ?: return
                    sendVolumeState(ctx)
                }
                "launch_default_media_app" -> {
                    val ctx = appContext ?: return
                    val pkg = obj.optString("packageName", "").trim()
                    val forcePlay = obj.optBoolean("forcePlay", false)
                    val pauseOthers = obj.optBoolean("pauseOthers", false)
                    handleLaunchDefaultMediaApp(ctx, pkg, forcePlay = forcePlay, pauseOthers = pauseOthers)
                }
                "visualization_update" -> {
                    val deviceId = obj.optString("deviceId", "")
                    val dateId = obj.optString("dateId", "")
                    val notificationId = obj.optString("notificationId", "")
                    val visualizado = obj.optBoolean("visualizado", true)

                    if (deviceId.isBlank() || dateId.isBlank() || notificationId.isBlank()) return

                    ensureFlutterEngine()
                    btHiveChannel?.invokeMethod(
                        "onBtVisualizationUpdate",
                        mapOf(
                            "type" to type,
                            "deviceId" to deviceId,
                            "dateId" to dateId,
                            "notificationId" to notificationId,
                            "visualizado" to visualizado
                        )
                    )
                }
                "device_search" -> {
                    val action = obj.optString("action", "start")
                    val ctx = appContext ?: return
                    deviceFinderManager = DeviceFinderManager.getInstance(ctx)
                    if (action == "stop") {
                        try { deviceFinderManager?.stopDeviceSearch() } catch (_: Exception) {}
                    } else {
                        try { deviceFinderManager?.startDeviceSearch() } catch (_: Exception) {}
                    }
                }
                "debug_log" -> {
                    val source = obj.optString("source", "receptor")
                    val message = obj.optString("message", "")
                    val ts = obj.optLong("timestamp", 0L)
                    println("[btclassic][debug][$source][$ts] $message")
                }
                "firebase_link" -> {
                    // El peer (emisor) nos envía su device_id de Firestore. Si
                    // somos receptor, lo guardamos como dispositivo vinculado.
                    val deviceId = obj.optString("deviceId", "").trim()
                    val ctx = appContext
                    if (ctx != null && deviceId.isNotEmpty()) {
                        val prefs = ctx.getSharedPreferences(
                            "FlutterSharedPreferences", Context.MODE_PRIVATE
                        )
                        // Solo guardamos si NO somos el emisor (no capturamos notificaciones).
                        if (!NotificationListener.isRunning) {
                            prefs.edit().putString("flutter.linked_device_id", deviceId).apply()
                            println("[btclassic][client] firebase_link guardado linked=$deviceId")
                            ensureFlutterEngine()
                            btHiveChannel?.invokeMethod(
                                "onFirebaseLink",
                                mapOf("deviceId" to deviceId)
                            )
                        }
                    }
                }
                "query_notif_active" -> {
                    // El peer pregunta si una notificación sigue en la barra de
                    // ESTE dispositivo. Respondemos con su estado actual.
                    val sbnKey = obj.optString("sbnKey", "").trim()
                    val requestId = obj.optString("requestId", "").trim()
                    val active = try {
                        NotificationListener.isNotificationActive(sbnKey)
                    } catch (_: Exception) { false }
                    val resp = JSONObject()
                    resp.put("type", "notif_active_state")
                    resp.put("sbnKey", sbnKey)
                    resp.put("active", active)
                    resp.put("requestId", requestId)
                    resp.put("timestamp", System.currentTimeMillis())
                    send(resp.toString())
                }
                "notif_active_state" -> {
                    // Respuesta a nuestra consulta. La guardamos en SharedPreferences
                    // (puente fiable entre isletas) para que la UI la lea.
                    val sbnKey = obj.optString("sbnKey", "").trim()
                    val active = obj.optBoolean("active", false)
                    val ts = obj.optLong("timestamp", System.currentTimeMillis())
                    saveNotifActiveStateToPrefs(sbnKey, active, ts)
                }
                "notif_reply" -> {
                    val sbnKey = obj.optString("sbnKey", "").trim()
                    val replyText = obj.optString("replyText", "").trim()
                    val requestId = obj.optString("requestId", "").trim()
                    val packageName = obj.optString("packageName", "").trim()
                    val conversationTitle = obj.optString("conversationTitle", "").trim()
                    val now = System.currentTimeMillis()

                    val res = NotificationListener.trySendNotificationReplySmart(
                        sbnKey,
                        replyText,
                        packageName,
                        conversationTitle
                    )
                    val ok = res.first
                    val err = res.second

                    try {
                        val ack = JSONObject()
                        ack.put("type", "notif_reply_ack")
                        ack.put("requestId", requestId)
                        ack.put("sbnKey", sbnKey)
                        ack.put("ok", ok)
                        ack.put("error", if (ok) "" else err)
                        ack.put("time", now)
                        send(ack.toString())
                    } catch (_: Exception) {
                    }
                }
                else -> return
            }
        } catch (_: Exception) {
        }
    }

    private fun handleLaunchDefaultMediaApp(
        ctx: Context,
        pkgFromPayload: String,
        forcePlay: Boolean,
        pauseOthers: Boolean
    ) {
        println("[btclassic][client][media_launch] rx pkgFromPayload='${pkgFromPayload.take(120)}' forcePlay=$forcePlay pauseOthers=$pauseOthers")
        val pkg = if (pkgFromPayload.isNotBlank()) {
            pkgFromPayload
        } else {
            try {
                val prefs = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.getString("flutter.media_default_app_package", null)?.trim().orEmpty()
            } catch (_: Exception) {
                ""
            }
        }
        if (pkg.isBlank()) {
            println("[btclassic][client][media_launch] abort pkg is blank (no selection)")
            return
        }
        println("[btclassic][client][media_launch] resolved pkg='${pkg.take(160)}'")

        val pm = try { ctx.packageManager } catch (_: Exception) { null } ?: return
        val installed = try {
            pm.getApplicationInfo(pkg, 0)
            true
        } catch (_: Exception) {
            false
        }
        println("[btclassic][client][media_launch] installed=$installed pkg='${pkg.take(160)}'")
        val appLabel = if (installed) {
            try {
                val appInfo = pm.getApplicationInfo(pkg, 0)
                pm.getApplicationLabel(appInfo).toString()
            } catch (_: Exception) {
                pkg
            }
        } else {
            pkg
        }

        if (pauseOthers) {
            println("[btclassic][client][media_launch] pauseOthers=true attempting pause current sessions")
            try {
                val msm = ctx.getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
                if (msm != null) {
                    val component = ComponentName(ctx, NotificationListener::class.java)
                    val controllers = try { msm.getActiveSessions(component) } catch (_: Exception) { emptyList<MediaController>() }
                    val playing = controllers.firstOrNull { c ->
                        val st = c.playbackState?.state ?: PlaybackState.STATE_NONE
                        st == PlaybackState.STATE_PLAYING || st == PlaybackState.STATE_BUFFERING
                    }
                    try { playing?.transportControls?.pause() } catch (_: Exception) {}
                }
            } catch (_: Exception) {
            }
            try { dispatchMediaKey(ctx, KeyEvent.KEYCODE_MEDIA_PAUSE) } catch (_: Exception) {}
        }

        var launchAttempted = false
        var launchSucceeded = false
        if (installed) {
            val launch = try { pm.getLaunchIntentForPackage(pkg) } catch (_: Exception) { null }
            if (launch != null) {
                try {
                    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    ctx.startActivity(launch)
                    launchAttempted = true
                    launchSucceeded = true
                    println("[btclassic][client][media_launch] startActivity(getLaunchIntentForPackage) OK pkg='${pkg.take(160)}'")
                } catch (_: Exception) {
                    launchAttempted = true
                    println("[btclassic][client][media_launch] startActivity(getLaunchIntentForPackage) FAILED pkg='${pkg.take(160)}'")
                }
            }
        }

        if (installed && (!launchSucceeded || forcePlay)) {
            try {
                val openIntent = Intent(ctx, MainActivity::class.java).apply {
                    action = "MEDIA_LAUNCH_ACTION"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("packageName", pkg)
                }
                val pi = PendingIntent.getActivity(
                    ctx,
                    pkg.hashCode(),
                    openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
                )
                pi.send()
                launchAttempted = true
                launchSucceeded = true
                println("[btclassic][client][media_launch] PendingIntent MEDIA_LAUNCH_ACTION sent pkg='${pkg.take(160)}'")
            } catch (_: Exception) {
                println("[btclassic][client][media_launch] PendingIntent MEDIA_LAUNCH_ACTION FAILED pkg='${pkg.take(160)}'")
            }
        }

        val shouldShowLaunchNotif = (!installed) || forcePlay || (!launchSucceeded && launchAttempted)
        if (shouldShowLaunchNotif) {
            val now = System.currentTimeMillis()
            if (now - lastMediaLaunchNotifAtMs > 1500L) {
                lastMediaLaunchNotifAtMs = now
                try {
                    showMediaLaunchNotification(ctx, pkg, appLabel)
                } catch (_: Exception) {
                }
            }
        }

        try {
            val status = JSONObject()
            status.put("type", "default_media_app_status")
            status.put("packageName", pkg)
            status.put("installed", installed)
            status.put("time", System.currentTimeMillis())
            send(status.toString())
        } catch (_: Exception) {
        }

        if (forcePlay) {
            val main = Handler(Looper.getMainLooper())
            fun tryPlayWithSession(attempt: Int) {
                try {
                    val msm = ctx.getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
                    if (msm != null) {
                        val component = ComponentName(ctx, NotificationListener::class.java)
                        val controllers =
                            try { msm.getActiveSessions(component) } catch (_: Exception) { emptyList<MediaController>() }
                        val target = controllers.firstOrNull { it.packageName == pkg }
                        if (target != null) {
                            val st = target.playbackState?.state ?: PlaybackState.STATE_NONE
                            val playing = st == PlaybackState.STATE_PLAYING || st == PlaybackState.STATE_BUFFERING
                            println("[btclassic][client][media_launch] tryPlayWithSession attempt=$attempt found controller playing=$playing pkg='${pkg.take(120)}'")
                            if (!playing) {
                                try { target.transportControls.play() } catch (_: Exception) {}
                            }
                            return
                        }
                        println("[btclassic][client][media_launch] tryPlayWithSession attempt=$attempt controller not found yet pkg='${pkg.take(120)}' controllers=${controllers.size}")
                    } else {
                        println("[btclassic][client][media_launch] tryPlayWithSession attempt=$attempt msm=null pkg='${pkg.take(120)}'")
                    }
                } catch (t: Throwable) {
                    println("[btclassic][client][media_launch] tryPlayWithSession attempt=$attempt exception t=${t::class.java.simpleName} msg=${t.message}")
                }
                if (attempt < 6) {
                    main.postDelayed({ tryPlayWithSession(attempt + 1) }, 250L)
                }
            }

            main.postDelayed({
                try {
                    println("[btclassic][client][media_launch] forcePlay dispatchMediaKey PLAY pkg='${pkg.take(160)}'")
                    dispatchMediaKey(ctx, KeyEvent.KEYCODE_MEDIA_PLAY)
                } catch (_: Exception) {
                    println("[btclassic][client][media_launch] forcePlay dispatchMediaKey PLAY FAILED pkg='${pkg.take(160)}'")
                }
            }, 650L)
            main.postDelayed({
                tryPlayWithSession(0)
            }, 800L)
            main.postDelayed({
                try { sendMediaStateSnapshot(ctx) } catch (_: Exception) {}
                try { sendVolumeState(ctx) } catch (_: Exception) {}
            }, 1100L)
        }
    }

    private fun showMediaLaunchNotification(ctx: Context, pkg: String, appLabel: String) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                MEDIA_LAUNCH_CHANNEL_ID,
                "Apertura de multimedia",
                NotificationManager.IMPORTANCE_HIGH
            )
            nm.createNotificationChannel(channel)
        }

        val openIntent = Intent(ctx, MainActivity::class.java).apply {
            action = "MEDIA_LAUNCH_ACTION"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("packageName", pkg)
        }
        val pi = PendingIntent.getActivity(
            ctx,
            pkg.hashCode(),
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )

        val n = NotificationCompat.Builder(ctx, MEDIA_LAUNCH_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Abrir $appLabel")
            .setContentText("Toca para activar la aplicación multimedia seleccionada")
            .setAutoCancel(true)
            .setContentIntent(pi)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_RECOMMENDATION)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(pi, true)
            .build()

        nm.notify(10021, n)
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
    }

    private fun handleMediaCommand(ctx: Context, command: String, positionMs: Long) {
        try {
            if (command == "request_state") {
                sendMediaStateSnapshot(ctx)
                return
            }
            val msm = ctx.getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager ?: return
            val component = ComponentName(ctx, NotificationListener::class.java)
            val controllers = try { msm.getActiveSessions(component) } catch (_: Exception) { emptyList<MediaController>() }
            val controller = selectControllerForCommand(controllers, command)
            val controllerState = controller?.playbackState
            val actions = controllerState?.actions ?: 0L
            val pkg = controller?.packageName.orEmpty()
            val isYouTube =
                pkg == "com.google.android.youtube" || pkg == "com.google.android.apps.youtube.music"

            val main = Handler(Looper.getMainLooper())
            main.post {
                try {
                    if (controller != null) {
                        val controls = controller.transportControls
                        when (command) {
                            "play" -> controls.play()
                            "pause" -> controls.pause()
                            "toggle" -> {
                                val st = controller.playbackState?.state ?: PlaybackState.STATE_NONE
                                val playing = st == PlaybackState.STATE_PLAYING || st == PlaybackState.STATE_BUFFERING
                                if (playing) controls.pause() else controls.play()
                            }
                            "next" -> controls.skipToNext()
                            "previous" -> controls.skipToPrevious()
                            "seekTo" -> if (positionMs >= 0) controls.seekTo(positionMs)
                        }
                    }

                    val shouldFallbackToMediaKey = when (command) {
                        "play" -> controller == null ||
                                ((actions and PlaybackState.ACTION_PLAY) == 0L &&
                                        (actions and PlaybackState.ACTION_PLAY_PAUSE) == 0L)
                        "pause" -> controller == null ||
                                ((actions and PlaybackState.ACTION_PAUSE) == 0L &&
                                        (actions and PlaybackState.ACTION_PLAY_PAUSE) == 0L)
                        "toggle" -> controller == null || (actions and PlaybackState.ACTION_PLAY_PAUSE) == 0L
                        "next" -> controller == null || (actions and PlaybackState.ACTION_SKIP_TO_NEXT) == 0L
                        "previous" -> controller == null || (actions and PlaybackState.ACTION_SKIP_TO_PREVIOUS) == 0L
                        else -> false
                    }
                    if (shouldFallbackToMediaKey) {
                        val key = when (command) {
                            "play" -> KeyEvent.KEYCODE_MEDIA_PLAY
                            "pause" -> KeyEvent.KEYCODE_MEDIA_PAUSE
                            "toggle" -> {
                                val st = controller?.playbackState?.state ?: PlaybackState.STATE_NONE
                                val playing = st == PlaybackState.STATE_PLAYING || st == PlaybackState.STATE_BUFFERING
                                if (playing) KeyEvent.KEYCODE_MEDIA_PAUSE else KeyEvent.KEYCODE_MEDIA_PLAY
                            }
                            "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
                            "previous" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
                            else -> null
                        }
                        if (key != null) dispatchMediaKey(ctx, key)
                    }
                } catch (_: Exception) {
                }
            }

            val delayMs = if (command == "seekTo") 700L else 450L
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    sendMediaStateSnapshot(ctx)
                } catch (_: Exception) {
                }
            }, delayMs)
        } catch (_: Exception) {
        }
    }

    private fun selectControllerForCommand(
        controllers: List<MediaController>,
        command: String
    ): MediaController? {
        if (controllers.isEmpty()) return null
        val playing = controllers.filter { c ->
            val st = c.playbackState?.state ?: PlaybackState.STATE_NONE
            st == PlaybackState.STATE_PLAYING || st == PlaybackState.STATE_BUFFERING
        }
        val paused = controllers.filter { c ->
            val st = c.playbackState?.state ?: PlaybackState.STATE_NONE
            st == PlaybackState.STATE_PAUSED
        }
        val rest = controllers.filter { c ->
            val st = c.playbackState?.state ?: PlaybackState.STATE_NONE
            st != PlaybackState.STATE_PLAYING &&
                st != PlaybackState.STATE_BUFFERING &&
                st != PlaybackState.STATE_PAUSED
        }

        fun isActive(c: MediaController): Boolean {
            val st = c.playbackState?.state ?: PlaybackState.STATE_NONE
            return st == PlaybackState.STATE_PLAYING ||
                    st == PlaybackState.STATE_BUFFERING ||
                    st == PlaybackState.STATE_PAUSED
        }

        fun supports(c: MediaController): Boolean {
            val st = c.playbackState?.state ?: PlaybackState.STATE_NONE
            val actions = c.playbackState?.actions ?: 0L
            val pkg = try { c.packageName.orEmpty() } catch (_: Exception) { "" }
            val isYouTube =
                pkg == "com.google.android.youtube" || pkg == "com.google.android.apps.youtube.music"
            return when (command) {
                "play", "pause", "toggle" -> {
                    if (isYouTube && isActive(c)) return true
                    if (isActive(c) && st != PlaybackState.STATE_NONE) return true
                    (actions and PlaybackState.ACTION_PLAY) != 0L ||
                        (actions and PlaybackState.ACTION_PAUSE) != 0L ||
                        (actions and PlaybackState.ACTION_PLAY_PAUSE) != 0L
                }
                "seekTo" -> (actions and PlaybackState.ACTION_SEEK_TO) != 0L
                "next" -> if (isYouTube && isActive(c)) true else (actions and PlaybackState.ACTION_SKIP_TO_NEXT) != 0L
                "previous" -> if (isYouTube && isActive(c)) true else (actions and PlaybackState.ACTION_SKIP_TO_PREVIOUS) != 0L
                else -> true
            }
        }

        val prioritized = when (command) {
            "toggle", "play", "pause" -> {
                val activeOrdered = (playing + paused + rest)
                if (activeOrdered.any(::isActive)) activeOrdered.filter(::isActive) + activeOrdered.filter { !isActive(it) }
                else activeOrdered
            }
            else -> {
                val activeOrdered = (playing + paused + rest)
                if (activeOrdered.any(::isActive)) activeOrdered.filter(::isActive) + activeOrdered.filter { !isActive(it) }
                else activeOrdered
            }
        }

        val supporting = prioritized.firstOrNull(::supports)
        return supporting ?: selectBestController(prioritized)
    }

    private fun dispatchMediaKey(ctx: Context, keyCode: Int) {
        try {
            val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            val now = SystemClock.uptimeMillis()
            am.dispatchMediaKeyEvent(KeyEvent(now, now, KeyEvent.ACTION_DOWN, keyCode, 0))
            am.dispatchMediaKeyEvent(KeyEvent(now, now, KeyEvent.ACTION_UP, keyCode, 0))
        } catch (_: Exception) {
        }
    }

    private fun handleVolumeCommand(ctx: Context, pct: Int, level: Int, max: Int) {
        try {
            val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            val streamMax = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            if (streamMax <= 0) return

            val target = when {
                pct in 0..100 -> ((pct.toDouble() / 100.0) * streamMax.toDouble()).roundToInt()
                level >= 0 && max > 0 -> ((level.toDouble() / max.toDouble()) * streamMax.toDouble()).roundToInt()
                else -> return
            }.coerceIn(0, streamMax)

            am.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
            sendVolumeState(ctx)
            Handler(Looper.getMainLooper()).postDelayed({
                try { sendMediaStateSnapshot(ctx) } catch (_: Exception) {}
            }, 250L)
        } catch (_: Exception) {
        }
    }

    private fun sendVolumeState(ctx: Context) {
        try {
            val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            val level = am.getStreamVolume(AudioManager.STREAM_MUSIC)
            val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            if (max <= 0 || level < 0) return
            val pct = ((level.toDouble() / max.toDouble()) * 100.0).toInt().coerceIn(0, 100)

            val payload = HashMap<String, Any?>()
            payload["type"] = "volume_state"
            payload["time"] = System.currentTimeMillis()
            payload["level"] = level
            payload["max"] = max
            payload["pct"] = pct

            send(JSONObject(payload as Map<*, *>).toString())
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
            val ctx = appContext ?: return null
            val uri = try { Uri.parse(uriString) } catch (_: Exception) { null } ?: return null
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            try {
                ctx.contentResolver.openInputStream(uri)?.use { input ->
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
                ctx.contentResolver.openInputStream(uri)?.use { input ->
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

    private fun sendMediaStateSnapshot(ctx: Context) {
        val msm = ctx.getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager ?: return
        val component = ComponentName(ctx, NotificationListener::class.java)
        val controllers = try { msm.getActiveSessions(component) } catch (_: Exception) { emptyList<MediaController>() }
        val controller = selectBestController(controllers) ?: return

        val state = controller.playbackState
        val metadata = controller.metadata

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
        val packageName = controller.packageName ?: ""

        if (packageName.isBlank() || title.isNullOrBlank()) return

        val isYouTube =
            packageName == "com.google.android.youtube" || packageName == "com.google.android.apps.youtube.music"

        val canPlayPause = baseCanPlayPause || playbackState == PlaybackState.STATE_PLAYING ||
                playbackState == PlaybackState.STATE_BUFFERING ||
                playbackState == PlaybackState.STATE_PAUSED ||
                isYouTube
        val canSkipNext = baseCanSkipNext || isYouTube
        val canSkipPrev = baseCanSkipPrev || isYouTube

        val appName = try {
            val appInfo = ctx.packageManager.getApplicationInfo(packageName, 0)
            ctx.packageManager.getApplicationLabel(appInfo).toString()
        } catch (_: Exception) {
            packageName
        }

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
            val am = ctx.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
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

        val artBase64 = encodeArtBase64(metadata)
        if (!artBase64.isNullOrBlank()) {
            payload["artMime"] = "image/jpeg"
            payload["artBase64"] = artBase64
        }

        try {
            send(JSONObject(payload as Map<*, *>).toString())
        } catch (_: Exception) {
        }
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

    /// Guarda en SharedPreferences ("FlutterSharedPreferences") la última
    /// respuesta de estado de notificación, para que la UI Flutter la lea
    /// (puente fiable entre isletas, a diferencia de Hive).
    private fun saveNotifActiveStateToPrefs(sbnKey: String, active: Boolean, ts: Long) {
        val ctx = appContext ?: return
        if (sbnKey.isBlank()) return
        try {
            val json = JSONObject()
            json.put("sbnKey", sbnKey)
            json.put("active", active)
            json.put("timestamp", ts)
            ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putString("flutter.bt_notif_active_last", json.toString())
                .apply()
        } catch (_: Exception) {}
    }

    /// Si este dispositivo es EMISOR (no receptor), envía su device_id de
    /// Firestore al peer para que se auto-vincule por Firebase.
    private fun maybeSendFirebaseLink() {
        try {
            val ctx = appContext ?: return
            // Solo el EMISOR (el que captura notificaciones) ofrece su device_id.
            if (!NotificationListener.isRunning) return
            val prefs = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val deviceId = prefs.getString("flutter.device_id", null)?.trim() ?: ""
            if (deviceId.isEmpty()) return
            val obj = JSONObject()
            obj.put("type", "firebase_link")
            obj.put("deviceId", deviceId)
            obj.put("timestamp", System.currentTimeMillis())
            send(obj.toString())
            println("[btclassic][client] firebase_link enviado deviceId=$deviceId")
        } catch (_: Exception) {}
    }

    private fun ensureFlutterEngine() {
        if (flutterEngine != null) return
        val ctx = appContext ?: return
        try {
            val loader: FlutterLoader = FlutterInjector.instance().flutterLoader()
            if (!loader.initialized()) {
                loader.startInitialization(ctx)
                loader.ensureInitializationComplete(ctx, null)
            }

            val engine = FlutterEngine(ctx)
            GeneratedPluginRegistrant.registerWith(engine)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "btHiveMain")
            )
            btHiveChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.example.connect/bt_hive_bridge")
            flutterEngine = engine

            // Handler para llamadas Dart → Kotlin en el mismo canal.
            btHiveChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendDebugLog" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        println("[btHive][${args["source"]}] ${args["message"]}")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        } catch (_: Exception) {
        }
    }

    private fun closeInternal() {
        readerRunning.set(false)
        try { readerThread?.interrupt() } catch (_: Exception) {}
        readerThread = null
        try { input?.close() } catch (_: Exception) {}
        input = null
        try { out?.close() } catch (_: Exception) {}
        out = null
        try { socket?.close() } catch (_: Exception) {}
        socket = null
    }
}
