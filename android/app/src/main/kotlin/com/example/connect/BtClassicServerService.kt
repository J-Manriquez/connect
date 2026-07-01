package com.example.connect

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.ComponentName
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import org.json.JSONArray
import org.json.JSONObject
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.EOFException
import java.util.UUID
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.atomic.AtomicBoolean

class BtClassicServerService : Service() {
    companion object {
        const val ACTION_START = "com.example.connect.btclassic.START"
        const val ACTION_STOP = "com.example.connect.btclassic.STOP"
        const val ACTION_SEND_TO_PEERS = "com.example.connect.btclassic.SEND_TO_PEERS"
        const val EXTRA_JSON = "json"

        private const val CHANNEL_ID = "bt_classic_server_channel"
        private const val CHANNEL_NAME = "Bluetooth Classic"
        private const val NOTIF_ID = 41001

        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

        private const val PREFS_NOTIFICATION_SETTINGS = "flutter.notification_settings"
        private const val KEY_SCREEN_WAKE_ENABLED = "flutter.screenWakeEnabled"
        private const val KEY_AUTO_OPEN_ENABLED = "flutter.autoOpenEnabled"
        private const val KEY_SOUND_ENABLED = "flutter.soundEnabled"

        private const val PREFS_FLUTTER = "FlutterSharedPreferences"
        private const val KEY_PRIORITIZE_LOCAL_MEDIA = "flutter.prioritize_local_media"

        private const val PREFS_MEDIA_CACHE = "bt_media_cache_v1"
        private const val KEY_MEDIA_JSON = "media_json"
        private const val KEY_MEDIA_UPDATED_AT_MS = "updatedAtMs"

        private const val PREFS_LOCAL_MEDIA_CACHE = "local_media_cache_v1"
        private const val KEY_LOCAL_MEDIA_JSON = "media_json"
        private const val KEY_LOCAL_MEDIA_UPDATED_AT_MS = "updatedAtMs"

        private const val PREFS_VOLUME_CACHE = "bt_volume_cache_v1"
        private const val KEY_VOLUME_LEVEL = "level"
        private const val KEY_VOLUME_MAX = "max"
        private const val KEY_VOLUME_PCT = "pct"
        private const val KEY_VOLUME_UPDATED_AT_MS = "updatedAtMs"

        @Volatile
        var isServiceRunning: Boolean = false

        @Volatile
        var connectedPeers: Int = 0

        @Volatile
        var lastPeerAddress: String? = null

        @Volatile
        var lastPeerName: String? = null

        @Volatile
        var lastMediaJson: String? = null

        @Volatile
        var lastMediaUpdatedAtMs: Long = 0L

        @Volatile
        private var instance: BtClassicServerService? = null

        fun sendDebugLogToPeers(source: String, message: String) {
            try {
                instance?.sendDebugToPeers(source, message)
            } catch (_: Exception) {
            }
        }
    }

    private var serverSocket: BluetoothServerSocket? = null
    private val sockets: MutableSet<BluetoothSocket> = CopyOnWriteArraySet()
    private val running = AtomicBoolean(false)
    private var acceptThread: Thread? = null
    private var localNotificationManager: LocalNotificationManager? = null
    private var deviceFinderManager: DeviceFinderManager? = null
    private var flutterEngine: FlutterEngine? = null
    private var btHiveChannel: MethodChannel? = null
    private var appListChannel: MethodChannel? = null
    private var appListService: AppListService? = null
    private var lastMediaDebugAtMs: Long = 0L
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile
    private var lastPeerDisconnectedAtMs: Long = 0L
    private var clearMediaRunnable: Runnable? = null
    @Volatile
    private var btHiveReady: Boolean = false
    @Volatile
    private var pendingMediaState: HashMap<String, Any?>? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        localNotificationManager = LocalNotificationManager(applicationContext)
        deviceFinderManager = DeviceFinderManager.getInstance(applicationContext)
        appListService = AppListService(applicationContext)
        ensureFlutterEngine()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopSelfSafely()
            ACTION_SEND_TO_PEERS -> {
                val json = intent.getStringExtra(EXTRA_JSON)
                if (!json.isNullOrBlank()) {
                    var handled = false
                    try {
                        val obj = JSONObject(json)
                        val type = obj.optString("type", "").trim()
                        if (type == "launch_default_media_app") {
                            var pkg = obj.optString("packageName", "").trim()
                            val forcePlay = obj.optBoolean("forcePlay", false)
                            val pauseOthers = obj.optBoolean("pauseOthers", false)
                            if (pkg.isBlank()) {
                                try {
                                    val prefs = applicationContext.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
                                    val fallback = prefs.getString("flutter.media_default_app_package", null)?.trim().orEmpty()
                                    if (fallback.isNotBlank()) {
                                        pkg = fallback
                                        obj.put("packageName", fallback)
                                    }
                                } catch (_: Exception) {
                                }
                            }
                            val outgoingJson = try { obj.toString() } catch (_: Exception) { json }
                            println("[btclassic][server][media_launch] request pkg='${pkg.take(120)}' forcePlay=$forcePlay pauseOthers=$pauseOthers peers=$connectedPeers")

                            try {
                                val localPaused = performLocalMediaCommand("pause", null)
                                println("[btclassic][server][media_launch] local_pause attempted ok=$localPaused")
                            } catch (t: Throwable) {
                                println("[btclassic][server][media_launch] local_pause exception t=${t::class.java.simpleName} msg=${t.message}")
                            }

                            try {
                                val pausePayload = JSONObject()
                                pausePayload.put("type", "media_command")
                                pausePayload.put("command", "pause")
                                pausePayload.put("time", System.currentTimeMillis())
                                startServerIfNeeded()
                                sendToPeers(pausePayload.toString())
                                println("[btclassic][server][media_launch] sent remote_pause to peers=$connectedPeers")
                            } catch (t: Throwable) {
                                println("[btclassic][server][media_launch] remote_pause exception t=${t::class.java.simpleName} msg=${t.message}")
                            }

                            try {
                                startServerIfNeeded()
                                sendToPeers(outgoingJson)
                                println("[btclassic][server][media_launch] sent launch_default_media_app peers=$connectedPeers")
                            } catch (t: Throwable) {
                                println("[btclassic][server][media_launch] send launch exception t=${t::class.java.simpleName} msg=${t.message}")
                            }
                            handled = true
                        }
                    } catch (t: Throwable) {
                        println("[btclassic][server] ACTION_SEND_TO_PEERS parse exception t=${t::class.java.simpleName} msg=${t.message}")
                    }
                    if (!handled) {
                        val localHandled = tryHandleOutgoingLocalCommand(json)
                        if (!localHandled) {
                            startServerIfNeeded()
                            sendToPeers(json)
                        }
                    }
                }
            }
            else -> startServerIfNeeded()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopServer()
        try { flutterEngine?.destroy() } catch (_: Exception) {}
        flutterEngine = null
        btHiveChannel = null
        appListChannel = null
        appListService = null
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun ensureFlutterEngine() {
        if (flutterEngine != null) return
        try {
            val loader: FlutterLoader = FlutterInjector.instance().flutterLoader()
            if (!loader.initialized()) {
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)
            }

            val engine = FlutterEngine(applicationContext)
            GeneratedPluginRegistrant.registerWith(engine)

            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "btHiveMain")
            )

            btHiveChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.example.connect/bt_hive_bridge")
            appListChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.example.connect/app_list")
            btHiveReady = false
            pendingMediaState = null

            btHiveChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendDebugLog" -> {
                        val source = call.argument<String>("source") ?: "receptor_dart"
                        val message = call.argument<String>("message") ?: ""
                        if (message.isNotBlank()) {
                            if (message == "btHiveMain_ready") {
                                btHiveReady = true
                                val pending = pendingMediaState
                                if (pending != null) {
                                    pendingMediaState = null
                                    try {
                                        mainHandler.post {
                                            try {
                                                btHiveChannel?.invokeMethod("onBtMediaState", pending)
                                                sendDebugToPeers("media_invoke", "flush pending onBtMediaState ok keys=${pending.keys.size}")
                                            } catch (_: Exception) {
                                                sendDebugToPeers("media_invoke", "flush pending onBtMediaState failed")
                                            }
                                        }
                                    } catch (_: Exception) {}
                                }
                                sendDebugToPeers("receptor_engine", "btHiveMain_ready")
                            }
                            sendDebugToPeers(source, message)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

            appListChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> {
                        try {
                            val apps = appListService?.getInstalledApps() ?: emptyList()
                            result.success(apps)
                        } catch (e: Exception) {
                            result.error("ERROR", "Error al obtener aplicaciones: ${e.message}", null)
                        }
                    }
                    "searchAppByPackage" -> {
                        try {
                            val packageName = call.argument<String>("packageName")
                            if (packageName != null) {
                                result.success(appListService?.searchAppByPackage(packageName))
                            } else {
                                result.error("INVALID_ARGS", "Nombre de paquete no proporcionado", null)
                            }
                        } catch (e: Exception) {
                            result.error("ERROR", "Error al buscar aplicación: ${e.message}", null)
                        }
                    }
                    "getEnabledPackages" -> {
                        try {
                            val enabledPackages = appListService?.getEnabledPackages()?.toList() ?: emptyList<String>()
                            result.success(enabledPackages)
                        } catch (e: Exception) {
                            result.error("ERROR", "Error al obtener paquetes habilitados: ${e.message}", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

            flutterEngine = engine
        } catch (_: Exception) {
        }
    }

    private fun startServerIfNeeded() {
        if (!running.compareAndSet(false, true)) return
        isServiceRunning = true

        startForeground(NOTIF_ID, buildForegroundNotification())

        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null || !adapter.isEnabled) {
            stopSelfSafely()
            return
        }

        try {
            serverSocket = adapter.listenUsingRfcommWithServiceRecord("ConnectBridge", SPP_UUID)
        } catch (_: Exception) {
            stopSelfSafely()
            return
        }

        acceptThread = Thread {
            while (running.get()) {
                try {
                    val socket = serverSocket?.accept() ?: break
                    sockets.add(socket)
                    connectedPeers = sockets.size
                    try {
                        lastPeerAddress = socket.remoteDevice?.address
                        lastPeerName = socket.remoteDevice?.name
                    } catch (_: Exception) {
                    }
                    sendDebugToPeers(
                        "receptor_server",
                        "peer_connected addr=${lastPeerAddress ?: ""} name=${lastPeerName ?: ""} peers=$connectedPeers"
                    )
                    sendDebugToPeers(
                        "receptor_server",
                        "engine_ready=${flutterEngine != null} btHiveChannel_ready=${btHiveChannel != null} btHiveReady=$btHiveReady"
                    )
                    startReaderThread(socket)
                    maybeSendFirebaseLink()
                } catch (_: Exception) {
                    break
                }
            }
            stopSelfSafely()
        }.also { it.start() }
    }

    private fun startReaderThread(socket: BluetoothSocket) {
        Thread {
            try {
                val input = DataInputStream(socket.inputStream)
                while (running.get()) {
                    val len = try { input.readInt() } catch (e: EOFException) { break }
                    if (len <= 0 || len > 1024 * 256) break
                    val data = ByteArray(len)
                    input.readFully(data)
                    val json = String(data, Charsets.UTF_8)
                    if (json.contains("\"type\":\"media_state\"")) {
                        println("[btclassic][server] rx media_state bytes=$len")
                    }
                    handleIncomingPayload(json)
                }
            } catch (_: Exception) {
            } finally {
                try { socket.close() } catch (_: Exception) {}
                sockets.remove(socket)
                connectedPeers = sockets.size
                sendDebugToPeers("receptor_server", "peer_disconnected peers=$connectedPeers")
                if (connectedPeers <= 0) {
                    val now = System.currentTimeMillis()
                    lastPeerDisconnectedAtMs = now
                    val r = clearMediaRunnable ?: Runnable {
                        try {
                            val stillDisconnected = connectedPeers <= 0
                            val since = System.currentTimeMillis() - lastPeerDisconnectedAtMs
                            if (stillDisconnected && since >= 20_000L) {
                                clearMediaCache()
                            }
                        } catch (_: Exception) {
                        }
                    }.also { clearMediaRunnable = it }
                    mainHandler.removeCallbacks(r)
                    mainHandler.postDelayed(r, 20_000L)
                }
            }
        }.start()
    }

    private fun clearMediaCache() {
        lastMediaJson = null
        lastMediaUpdatedAtMs = 0L
        try {
            val prefs = applicationContext.getSharedPreferences(PREFS_MEDIA_CACHE, Context.MODE_PRIVATE)
            prefs.edit()
                .remove(KEY_MEDIA_JSON)
                .putLong(KEY_MEDIA_UPDATED_AT_MS, 0L)
                .apply()
        } catch (_: Exception) {
        }
        try { MediaWidgetProviderStyle2.updateAll(applicationContext) } catch (_: Exception) {}
        try { MediaWidgetProviderStyle3.updateAll(applicationContext) } catch (_: Exception) {}
        try { MediaWidgetProviderWide.updateAll(applicationContext) } catch (_: Exception) {}
    }

    /// Si este dispositivo es EMISOR (no receptor), envía su device_id de
    /// Firestore al peer para que se auto-vincule por Firebase.
    private fun maybeSendFirebaseLink() {
        try {
            // Solo el EMISOR (el que captura notificaciones) ofrece su device_id.
            if (!NotificationListener.isRunning) return
            val prefs = applicationContext
                .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val deviceId = prefs.getString("flutter.device_id", null)?.trim() ?: ""
            if (deviceId.isEmpty()) return
            val obj = JSONObject()
            obj.put("type", "firebase_link")
            obj.put("deviceId", deviceId)
            obj.put("timestamp", System.currentTimeMillis())
            sendToPeers(obj.toString())
            println("[btclassic][server] firebase_link enviado deviceId=$deviceId")
        } catch (_: Exception) {}
    }

    private fun sendDebugToPeers(source: String, message: String) {
        if (sockets.isEmpty()) return
        val now = System.currentTimeMillis()
        if (source == "media_state" && now - lastMediaDebugAtMs < 1200L) return
        if (source == "media_state") lastMediaDebugAtMs = now

        val obj = JSONObject()
        obj.put("type", "debug_log")
        obj.put("source", source)
        obj.put("message", message)
        obj.put("timestamp", now)
        sendToPeers(obj.toString())
    }

    private fun saveMediaCache(json: String) {
        val now = System.currentTimeMillis()
        val mergedJson = try {
            val prefs = applicationContext.getSharedPreferences(PREFS_MEDIA_CACHE, Context.MODE_PRIVATE)
            val obj = JSONObject(json)
            val art = obj.optString("artBase64", "").trim()
            if (art.isBlank()) {
                val prevJson = lastMediaJson ?: prefs.getString(KEY_MEDIA_JSON, null)
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

        lastMediaJson = mergedJson
        lastMediaUpdatedAtMs = now
        try {
            val prefs = applicationContext.getSharedPreferences(PREFS_MEDIA_CACHE, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(KEY_MEDIA_JSON, mergedJson)
                .putLong(KEY_MEDIA_UPDATED_AT_MS, now)
                .apply()
        } catch (_: Exception) {
        }
    }

    private fun readFlutterBool(key: String, defaultValue: Boolean): Boolean {
        return try {
            val prefs = applicationContext.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            val v = prefs.all[key]
            when (v) {
                is Boolean -> v
                is String -> v.equals("true", ignoreCase = true)
                is Int -> v != 0
                is Long -> v != 0L
                else -> defaultValue
            }
        } catch (_: Exception) {
            defaultValue
        }
    }

    private fun isRemoteMediaFresh(nowMs: Long): Boolean {
        if (connectedPeers <= 0) return false
        return try {
            val prefs = applicationContext.getSharedPreferences(PREFS_MEDIA_CACHE, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY_MEDIA_JSON, null)
            val updatedAtMs = prefs.getLong(KEY_MEDIA_UPDATED_AT_MS, 0L)
            if (json.isNullOrBlank()) return false
            if (updatedAtMs <= 0L || nowMs - updatedAtMs > 15_000L) return false
            val obj = JSONObject(json)
            obj.optString("title", "").trim().isNotBlank()
        } catch (_: Exception) {
            false
        }
    }

    private fun isLocalMediaFresh(nowMs: Long): Boolean {
        return try {
            val prefs = applicationContext.getSharedPreferences(PREFS_LOCAL_MEDIA_CACHE, Context.MODE_PRIVATE)
            val json = prefs.getString(KEY_LOCAL_MEDIA_JSON, null)
            val updatedAtMs = prefs.getLong(KEY_LOCAL_MEDIA_UPDATED_AT_MS, 0L)
            if (json.isNullOrBlank()) return false
            if (updatedAtMs <= 0L || nowMs - updatedAtMs > 15_000L) return false
            val obj = JSONObject(json)
            obj.optString("title", "").trim().isNotBlank()
        } catch (_: Exception) {
            false
        }
    }

    private fun shouldUseLocalMedia(nowMs: Long): Boolean {
        val prioritizeLocal = readFlutterBool(KEY_PRIORITIZE_LOCAL_MEDIA, false)
        val remoteActive = isRemoteMediaFresh(nowMs)
        val localActive = isLocalMediaFresh(nowMs)
        if (prioritizeLocal) return localActive || !remoteActive
        return !remoteActive && localActive
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

    private fun performLocalMediaCommand(command: String, positionMs: Long?): Boolean {
        return try {
            val msm = getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager ?: return false
            val component = ComponentName(this, NotificationListener::class.java)
            val controllers = try { msm.getActiveSessions(component) } catch (_: Exception) { emptyList() }
            val controller = selectBestController(controllers) ?: return false
            val controls = controller.transportControls
            when (command) {
                "next" -> controls.skipToNext()
                "previous", "prev" -> controls.skipToPrevious()
                "play" -> controls.play()
                "pause" -> controls.pause()
                "toggle" -> {
                    val st = controller.playbackState?.state ?: PlaybackState.STATE_NONE
                    val playing = st == PlaybackState.STATE_PLAYING || st == PlaybackState.STATE_BUFFERING
                    if (playing) controls.pause() else controls.play()
                }
                "seekTo" -> {
                    if (positionMs != null && positionMs >= 0L) controls.seekTo(positionMs)
                }
                else -> return false
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun performLocalVolumeCommand(pct: Int): Boolean {
        return try {
            val audio = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false
            val stream = AudioManager.STREAM_MUSIC
            val max = audio.getStreamMaxVolume(stream)
            if (max <= 0) return false
            val level = ((pct.coerceIn(0, 100) / 100.0) * max.toDouble()).toInt().coerceIn(0, max)
            audio.setStreamVolume(stream, level, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun tryHandleOutgoingLocalCommand(json: String): Boolean {
        val nowMs = System.currentTimeMillis()
        val useLocal = shouldUseLocalMedia(nowMs)
        if (!useLocal) return false
        return try {
            val obj = JSONObject(json)
            val type = obj.optString("type", "")
            if (type == "media_command") {
                val command = obj.optString("command", "").trim()
                val positionMs = try { obj.optLong("positionMs", -1L) } catch (_: Exception) { -1L }
                return performLocalMediaCommand(command, if (positionMs >= 0L) positionMs else null)
            }
            if (type == "volume_command") {
                val pct = try { obj.optInt("pct", -1) } catch (_: Exception) { -1 }
                if (pct !in 0..100) return false
                return performLocalVolumeCommand(pct)
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun handleIncomingPayload(json: String) {
        try {
            val obj = JSONObject(json)
            val type = obj.optString("type", "")
            if (type == "notif_reply_ack") {
                return
            }
            if (type == "sensor_data") {
                val hr = obj.optInt("hr", -1)
                val steps = obj.optInt("steps", -1)
                val wrist = obj.optString("wrist", "")
                val zona = obj.optString("zona", "")
                val kcal = obj.optDouble("kcal", -1.0)
                val distM = obj.optInt("dist_m", -1)
                val ts = System.currentTimeMillis()
                fun emitSensor(msg: String) {
                    val sink = MainActivity.instance?.sensorDebugEventSink ?: return
                    val m = mapOf("source" to "bt_sensor_rx", "message" to msg, "timestamp" to ts)
                    sink.success(m)
                }
                mainHandler.post {
                    if (hr >= 0) emitSensor("HR:$hr")
                    if (zona.isNotEmpty()) emitSensor("HR_ZONA:$zona")
                    if (steps >= 0) emitSensor("STEPS:$steps")
                    if (distM >= 0) emitSensor("DIST:$distM")
                    if (kcal >= 0) emitSensor("KCAL:$kcal")
                    if (wrist.isNotEmpty()) emitSensor("WRIST:$wrist")
                }
                return
            }
            if (type == "device_search") {
                val action = obj.optString("action", "start")
                if (action == "stop") {
                    try { deviceFinderManager?.stopDeviceSearch() } catch (_: Exception) {}
                } else {
                    try { deviceFinderManager?.startDeviceSearch() } catch (_: Exception) {}
                }
                return
            }
            if (type == "media_state") {
                try {
                    val title = obj.optString("title", "")
                    val appName = obj.optString("appName", "")
                    val pkg = obj.optString("packageName", "")
                    val pos = try { obj.optLong("positionMs", -1L) } catch (_: Exception) { -1L }
                    val dur = try { obj.optLong("durationMs", -1L) } catch (_: Exception) { -1L }
                    val artLen = obj.optString("artBase64", "").length
                    if (title.isBlank() || pkg.isBlank() || pos < 0L || dur < 0L) {
                        sendDebugToPeers("media_state", "invalid payload title='$title' pkg='$pkg' app='$appName' posMs=$pos durMs=$dur")
                        return
                    }
                    saveMediaCache(json)
                    try { MediaWidgetProviderStyle2.updateAll(applicationContext) } catch (_: Exception) {}
                    try { MediaWidgetProviderStyle3.updateAll(applicationContext) } catch (_: Exception) {}
                    try { MediaWidgetProviderWide.updateAll(applicationContext) } catch (_: Exception) {}
                    println("[btclassic][server][media] rx title='$title' pkg='$pkg' posMs=$pos durMs=$dur artLen=$artLen")
                    sendDebugToPeers("media_state", "rx title='$title' pkg='$pkg' posMs=$pos durMs=$dur artLen=$artLen")
                    ensureFlutterEngine()
                    val payload = HashMap<String, Any?>()
                    val keys = obj.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        val value = obj.opt(key)
                        if (value == JSONObject.NULL) {
                            payload[key] = null
                            continue
                        }
                        payload[key] = when (value) {
                            is JSONObject -> value.toString()
                            is JSONArray -> value.toString()
                            else -> value
                        }
                    }
                    val channel = btHiveChannel
                    if (channel == null) {
                        sendDebugToPeers("media_invoke", "btHiveChannel=null keys=${payload.keys.size}")
                        return
                    }
                    if (!btHiveReady) {
                        pendingMediaState = payload
                        sendDebugToPeers("media_invoke", "btHiveReady=false queued keys=${payload.keys.size}")
                        return
                    }
                    sendDebugToPeers("media_invoke", "post invoke onBtMediaState keys=${payload.keys.size}")
                    try {
                        mainHandler.post {
                            try {
                                channel.invokeMethod("onBtMediaState", payload)
                                sendDebugToPeers("media_invoke", "invoke onBtMediaState ok keys=${payload.keys.size}")
                            } catch (_: Exception) {
                                println("[btclassic][server][media] error processing media_state")
                                sendDebugToPeers("media_invoke", "invoke onBtMediaState failed")
                            }
                        }
                    } catch (_: Exception) {
                        sendDebugToPeers("media_invoke", "post_failed")
                    }
                } catch (_: Exception) {
                    println("[btclassic][server][media] error processing media_state")
                    sendDebugToPeers("media_state", "error processing media_state")
                }
                return
            }
            if (type == "volume_state") {
                try {
                    val level = try { obj.optInt("level", -1) } catch (_: Exception) { -1 }
                    val max = try { obj.optInt("max", -1) } catch (_: Exception) { -1 }
                    val pct = try { obj.optInt("pct", -1) } catch (_: Exception) { -1 }
                    if (level < 0 || max <= 0 || pct !in 0..100) {
                        sendDebugToPeers("volume_state", "invalid payload level=$level max=$max pct=$pct")
                        return
                    }
                    val now = System.currentTimeMillis()
                    try {
                        val prefs = applicationContext.getSharedPreferences(PREFS_VOLUME_CACHE, Context.MODE_PRIVATE)
                        prefs.edit()
                            .putInt(KEY_VOLUME_LEVEL, level)
                            .putInt(KEY_VOLUME_MAX, max)
                            .putInt(KEY_VOLUME_PCT, pct)
                            .putLong(KEY_VOLUME_UPDATED_AT_MS, now)
                            .apply()
                    } catch (_: Exception) {
                    }
                    try { MediaWidgetProviderStyle2.updateAll(applicationContext) } catch (_: Exception) {}
                    try { MediaWidgetProviderStyle3.updateAll(applicationContext) } catch (_: Exception) {}
                    try { MediaWidgetProviderWide.updateAll(applicationContext) } catch (_: Exception) {}

                    ensureFlutterEngine()
                    val payload = hashMapOf<String, Any?>(
                        "type" to "volume_state",
                        "time" to now,
                        "level" to level,
                        "max" to max,
                        "pct" to pct
                    )
                    val channel = btHiveChannel
                    if (channel == null) {
                        sendDebugToPeers("volume_invoke", "btHiveChannel=null")
                        return
                    }
                    if (!btHiveReady) {
                        sendDebugToPeers("volume_invoke", "btHiveReady=false drop")
                        return
                    }
                    try {
                        mainHandler.post {
                            try {
                                channel.invokeMethod("onBtVolumeState", payload)
                                sendDebugToPeers("volume_invoke", "invoke onBtVolumeState ok")
                            } catch (_: Exception) {
                                sendDebugToPeers("volume_invoke", "invoke onBtVolumeState failed")
                            }
                        }
                    } catch (_: Exception) {
                        sendDebugToPeers("volume_invoke", "post_failed")
                    }
                } catch (_: Exception) {
                    sendDebugToPeers("volume_state", "error processing volume_state")
                }
                return
            }
            if (type == "default_media_app_status") {
                try {
                    val pkg = obj.optString("packageName", "").trim()
                    val installed = obj.optBoolean("installed", true)
                    if (pkg.isNotBlank()) {
                        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        prefs.edit()
                            .putString("flutter.media_default_app_installed_pkg", pkg)
                            .putBoolean("flutter.media_default_app_installed", installed)
                            .apply()
                        try { MediaWidgetProviderStyle2.updateAll(applicationContext) } catch (_: Exception) {}
                        try { MediaWidgetProviderStyle3.updateAll(applicationContext) } catch (_: Exception) {}
                        try { MediaWidgetProviderWide.updateAll(applicationContext) } catch (_: Exception) {}
                    }
                } catch (_: Exception) {
                }
                return
            }
            if (type == "debug_log") {
                val source = obj.optString("source", "peer")
                val message = obj.optString("message", "")
                val ts = try { obj.optLong("timestamp", 0L) } catch (_: Exception) { 0L }
                println("[btclassic][server][peer_debug][$source][$ts] $message")
                return
            }
            if (type == "firebase_link") {
                // El emisor nos envía su device_id (= código de Firestore). Si
                // somos receptor, lo guardamos como dispositivo vinculado y
                // avisamos a Dart para actualizar el estado en Firebase.
                val deviceId = obj.optString("deviceId", "").trim()
                val prefs = applicationContext
                    .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                // Solo guardamos si NO somos el emisor (no capturamos notificaciones).
                if (!NotificationListener.isRunning && deviceId.isNotEmpty()) {
                    prefs.edit().putString("flutter.linked_device_id", deviceId).apply()
                    println("[btclassic][server] firebase_link guardado linked=$deviceId")
                    ensureFlutterEngine()
                    val channel = btHiveChannel
                    if (channel != null && btHiveReady) {
                        try {
                            mainHandler.post {
                                try {
                                    channel.invokeMethod(
                                        "onFirebaseLink",
                                        hashMapOf<String, Any?>("deviceId" to deviceId)
                                    )
                                } catch (_: Exception) {}
                            }
                        } catch (_: Exception) {}
                    }
                }
                return
            }
            if (type == "query_notif_active") {
                // El peer pregunta si una notificación sigue en la barra de ESTE
                // dispositivo. Respondemos con su estado actual.
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
                sendToPeers(resp.toString())
                return
            }
            if (type == "notif_active_state") {
                // Respuesta a nuestra consulta. La guardamos en SharedPreferences
                // (puente fiable entre isletas) para que la UI Flutter la lea.
                val sbnKey = obj.optString("sbnKey", "").trim()
                val active = obj.optBoolean("active", false)
                val ts = try { obj.optLong("timestamp", System.currentTimeMillis()) } catch (_: Exception) { System.currentTimeMillis() }
                if (sbnKey.isNotBlank()) {
                    try {
                        val resp = JSONObject()
                        resp.put("sbnKey", sbnKey)
                        resp.put("active", active)
                        resp.put("timestamp", ts)
                        applicationContext
                            .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            .edit()
                            .putString("flutter.bt_notif_active_last", resp.toString())
                            .apply()
                    } catch (_: Exception) {}
                }
                return
            }
            val title = obj.optString("title", "Nueva notificación")
            val text = obj.optString("text", "")
            val packageName = obj.optString("packageName", "")
            val appName = obj.optString("appName", "Desconocida")
            val notificationId = obj.optString("id", System.currentTimeMillis().toString())
            val sbnKey = obj.optString("sbnKey", obj.optString("key", "")).trim()
            val timeMs = try { obj.optLong("time", System.currentTimeMillis()) } catch (_: Exception) { System.currentTimeMillis() }

            val app = if (packageName.isNotEmpty()) {
                try { appListService?.searchAppByPackage(packageName) } catch (_: Exception) { null }
            } else null
            val iconBase64 =
                (app?.get("icon") as? String)
                    ?: obj.optString("appIcon", obj.optString("icon", ""))

            val prefs = applicationContext.getSharedPreferences(PREFS_NOTIFICATION_SETTINGS, Context.MODE_PRIVATE)
            val screenWakeEnabled = prefs.getBoolean(KEY_SCREEN_WAKE_ENABLED, false)
            val autoOpenEnabled = prefs.getBoolean(KEY_AUTO_OPEN_ENABLED, false)
            val soundEnabled = prefs.getBoolean(KEY_SOUND_ENABLED, true)

            val trimmedText = text.trim()
            val effectiveText =
                if (trimmedText.equals("null", ignoreCase = true) ||
                    trimmedText.equals("undefined", ignoreCase = true)) {
                    ""
                } else {
                    trimmedText
                }
            if (effectiveText.isBlank()) {
                sendDebugToPeers(
                    "notif_rx",
                    "drop_blank_text id='$notificationId' pkg='$packageName' title='${title.take(50)}'"
                )
                return
            }

            if (isNewMessagesSummary(title) || isNewMessagesSummary(text)) {
                sendDebugToPeers(
                    "notif_rx",
                    "drop_summary id='$notificationId' pkg='$packageName' title='${title.take(50)}' text='${effectiveText.take(50)}'"
                )
                return
            }

            val signatureSource =
                (packageName.trim() + "|" + title.trim() + "|" + effectiveText.trim()).lowercase()
            val signatureId = fnv1a32Hex(signatureSource)
            val stableLocalId = notificationId

            sendDebugToPeers(
                "notif_rx",
                "rx_ok id='$notificationId' localId='$stableLocalId' sbnKey='${sbnKey.take(60)}' sig='$signatureId' pkg='$packageName' autoOpen=$autoOpenEnabled wake=$screenWakeEnabled"
            )

            try {
                ensureFlutterEngine()
                val payload = HashMap<String, Any?>()
                val keys = obj.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val value = obj.opt(key)
                    payload[key] = when (value) {
                        is JSONObject -> value.toString()
                        is JSONArray -> value.toString()
                        else -> value
                    }
                }
                payload["id"] = notificationId
                payload["title"] = title
                payload["text"] = text
                payload["packageName"] = packageName
                payload["appName"] = appName
                payload["time"] = timeMs
                payload["icon"] = iconBase64
                payload["appIcon"] = iconBase64
                payload["signatureId"] = signatureId

                val channel = btHiveChannel
                if (channel != null) {
                    mainHandler.post {
                        try {
                            channel.invokeMethod("onBtNotification", payload)
                            sendDebugToPeers("notif_invoke", "invoke onBtNotification ok stableId='$stableLocalId'")
                        } catch (_: Exception) {
                            sendDebugToPeers("notif_invoke", "invoke onBtNotification failed stableId='$stableLocalId'")
                        }
                    }
                } else {
                    sendDebugToPeers("notif_invoke", "btHiveChannel=null stableId='$stableLocalId'")
                }
            } catch (_: Exception) {
                sendDebugToPeers("notif_invoke", "exception building onBtNotification stableId='$stableLocalId'")
            }

            sendDebugToPeers(
                "notif_show",
                "showNotification start stableId='$stableLocalId' autoOpen=$autoOpenEnabled wake=$screenWakeEnabled sound=$soundEnabled"
            )
            println(
                "[btclassic][notif_show] call localNotificationManager.showNotification stableId='$stableLocalId' pkg='$packageName' autoOpen=$autoOpenEnabled wake=$screenWakeEnabled sound=$soundEnabled"
            )
            try {
                localNotificationManager?.showNotification(
                    title = title,
                    body = effectiveText,
                    packageName = packageName,
                    appName = appName,
                    appIcon = iconBase64,
                    notificationId = stableLocalId,
                    soundEnabled = soundEnabled,
                    vibrationEnabled = true,
                    customVibrationPattern = null,
                    screenWakeEnabled = screenWakeEnabled,
                    autoOpenEnabled = autoOpenEnabled
                )
                println("[btclassic][notif_show] localNotificationManager.showNotification ok stableId='$stableLocalId'")
            } catch (t: Throwable) {
                println("[btclassic][notif_show] localNotificationManager.showNotification FAILED stableId='$stableLocalId' t=${t::class.java.simpleName} msg=${t.message}")
                try {
                    sendDebugToPeers(
                        "notif_show",
                        "showNotification FAILED stableId='$stableLocalId' err='${t::class.java.simpleName}:${t.message ?: ""}'"
                    )
                } catch (_: Exception) {
                }
            }
            sendDebugToPeers("notif_show", "showNotification end stableId='$stableLocalId'")
        } catch (t: Throwable) {
            println("[btclassic][notif_rx] handleIncomingNotification FAILED t=${t::class.java.simpleName} msg=${t.message}")
            try {
                sendDebugToPeers("notif_rx", "exception err='${t::class.java.simpleName}:${t.message ?: ""}'")
            } catch (_: Exception) {
            }
        }
    }

    private fun fnv1a32Hex(input: String): String {
        val bytes = input.toByteArray(Charsets.UTF_8)
        var hash = 0x811c9dc5L
        for (b in bytes) {
            hash = hash xor (b.toLong() and 0xffL)
            hash = (hash * 0x01000193L) and 0xffffffffL
        }
        return java.lang.Long.toHexString(hash).padStart(8, '0')
    }

    private fun sendToPeers(json: String) {
        if (sockets.isEmpty()) return
        val bytes = json.toByteArray(Charsets.UTF_8)
        Thread {
            val toRemove = ArrayList<BluetoothSocket>()
            for (s in sockets) {
                try {
                    val out = DataOutputStream(s.outputStream)
                    out.writeInt(bytes.size)
                    out.write(bytes)
                    out.flush()
                } catch (_: Exception) {
                    toRemove.add(s)
                    try { s.close() } catch (_: Exception) {}
                }
            }
            if (toRemove.isNotEmpty()) {
                for (s in toRemove) sockets.remove(s)
                connectedPeers = sockets.size
            }
        }.start()
    }

    private fun isNewMessagesSummary(raw: String?): Boolean {
        val value = raw?.trim().orEmpty()
        if (value.isEmpty()) return false
        val prefs = try {
            applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        } catch (_: Exception) {
            null
        }
        val filterSummaries = try {
            prefs?.getBoolean("flutter.filter_whatsapp_message_summaries", true) ?: true
        } catch (_: Exception) {
            true
        }
        val filterChecking = try {
            prefs?.getBoolean("flutter.filter_whatsapp_checking_new_messages", true) ?: true
        } catch (_: Exception) {
            true
        }
        if (!filterSummaries && !filterChecking) return false
        val s = value.lowercase()
            .replace(Regex("[áàäâ]"), "a")
            .replace(Regex("[éèëê]"), "e")
            .replace(Regex("[íìïî]"), "i")
            .replace(Regex("[óòöô]"), "o")
            .replace(Regex("[úùüû]"), "u")
            .replace(Regex("[ñ]"), "n")
            .replace(Regex("[^a-z0-9\\s]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()

        if (filterSummaries) {
            val es = Regex("^\\d+\\s+mensajes?\\s+nuevos?\$")
            val esChats = Regex("^\\d+\\s+mensajes?\\s+de\\s+\\d+\\s+chats?\$")
            val esEnChats = Regex("^\\d+\\s+mensajes?\\s+en\\s+\\d+\\s+chats?\$")
            val en = Regex("^\\d+\\s+new\\s+messages?\$")
            val enChats = Regex("^\\d+\\s+messages?\\s+from\\s+\\d+\\s+chats?\$")
            val enInChats = Regex("^\\d+\\s+messages?\\s+in\\s+\\d+\\s+chats?\$")
            if (es.matches(s) ||
                esChats.matches(s) ||
                esEnChats.matches(s) ||
                en.matches(s) ||
                enChats.matches(s) ||
                enInChats.matches(s)
            ) {
                return true
            }
        }
        if (filterChecking) {
            val checkingEs = Regex("^comprobando\\s+si\\s+hay\\s+mensajes\\s+nuevos\$")
            val checkingEn = Regex("^checking\\s+for\\s+new\\s+messages\$")
            return checkingEs.matches(s) || checkingEn.matches(s)
        }
        return false
    }

    private fun stopSelfSafely() {
        stopServer()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun stopServer() {
        isServiceRunning = false
        if (!running.compareAndSet(true, false)) return
        try { serverSocket?.close() } catch (_: Exception) {}
        serverSocket = null
        try { acceptThread?.interrupt() } catch (_: Exception) {}
        acceptThread = null
        for (s in sockets) {
            try { s.close() } catch (_: Exception) {}
        }
        sockets.clear()
        connectedPeers = 0
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW)
        nm.createNotificationChannel(channel)
    }

    private fun buildForegroundNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentTitle("Conexión Bluetooth activa")
            .setContentText("Escuchando notificaciones entrantes")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
