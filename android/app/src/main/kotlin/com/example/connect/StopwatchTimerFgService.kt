package com.example.connect

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject

class StopwatchTimerFgService : Service() {

    companion object {
        const val ACTION_START              = "com.example.connect.stopwatch.START"
        const val ACTION_PAUSE              = "com.example.connect.stopwatch.PAUSE"
        const val ACTION_TOGGLE_START_PAUSE = "com.example.connect.stopwatch.TOGGLE_START_PAUSE"
        const val ACTION_RESET              = "com.example.connect.stopwatch.RESET"
        const val ACTION_LAP                = "com.example.connect.stopwatch.LAP"
        const val ACTION_SET_TIMER          = "com.example.connect.stopwatch.SET_TIMER"
        const val ACTION_SET_MODE           = "com.example.connect.stopwatch.SET_MODE"
        const val ACTION_TOGGLE_MODE        = "com.example.connect.stopwatch.TOGGLE_MODE"
        const val ACTION_TIMER_ADD_STEP     = "com.example.connect.stopwatch.TIMER_ADD_STEP"
        const val ACTION_TIMER_SUB_STEP     = "com.example.connect.stopwatch.TIMER_SUB_STEP"
        const val ACTION_STOP_ALARM         = "com.example.connect.stopwatch.STOP_ALARM"
        const val ACTION_TICK_BROADCAST  = "com.example.connect.stopwatch.TICK"
        const val EXTRA_TIMER_DURATION   = "timer_duration_ms"
        const val EXTRA_TIMER_STEP_MS    = "timer_step_ms"
        const val EXTRA_MODE             = "mode"
        const val NOTIF_ID              = 9201
        const val NOTIF_CHANNEL_ID      = "stopwatch_timer_ch"

        const val STATE_IDLE     = "idle"
        const val STATE_RUNNING  = "running"
        const val STATE_PAUSED   = "paused"
        const val STATE_FINISHED = "finished"

        const val MODE_STOPWATCH = "stopwatch"
        const val MODE_TIMER     = "timer"

        // SharedPreferences keys (sin prefijo flutter.; se añade al leer/escribir)
        const val KEY_MODE       = "flutter.stopwatch_mode"
        const val KEY_STATE      = "flutter.stopwatch_state"
        const val KEY_START      = "flutter.stopwatch_start_epoch"
        const val KEY_ACCUM      = "flutter.stopwatch_accumulated"
        const val KEY_LAPS       = "flutter.stopwatch_laps_json"
        const val KEY_TIMER_TGT  = "flutter.stopwatch_timer_target"
        const val KEY_TIMER_REM  = "flutter.stopwatch_timer_remaining"

        // Config keys
        const val KEY_SND_ENABLED  = "flutter.stopwatch_sound_enabled"
        const val KEY_SND_URI      = "flutter.stopwatch_sound_uri"
        const val KEY_VIB_ENABLED  = "flutter.stopwatch_vibration_enabled"
        const val KEY_VIB_PATTERN  = "flutter.stopwatch_vibration_pattern"
        const val KEY_LAP_VIB      = "flutter.stopwatch_lap_vibrate"
        const val KEY_LAP_SND      = "flutter.stopwatch_lap_sound"
        const val KEY_LAP_SND_URI  = "flutter.stopwatch_lap_sound_uri"

        var isRunning = false

        fun readFlutterBool(prefs: SharedPreferences, key: String, default: Boolean): Boolean {
            return try {
                when (val v = prefs.all[key]) {
                    is Boolean -> v
                    is String  -> v.equals("true", ignoreCase = true)
                    is Int     -> v != 0
                    is Long    -> v != 0L
                    else       -> default
                }
            } catch (_: Exception) { default }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var tickRunnable: Runnable? = null
    private var mediaPlayer: MediaPlayer? = null

    private val prefs: SharedPreferences by lazy {
        getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    }

    private val vibrator: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    // ── Propiedades de estado en memoria (espejo de prefs para evitar I/O en cada tick) ──
    private var mode        = MODE_STOPWATCH
    private var state       = STATE_IDLE
    private var startEpoch  = 0L
    private var accumulated = 0L
    private var timerTarget = 0L
    private val laps        = mutableListOf<Long>()   // elapsed en ms de cada vuelta

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotifChannel()
        loadStateFromPrefs()
        println("[SwSvc] onCreate: state=$state mode=$mode")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        println("[SwSvc] ▶ onStartCommand action=${intent?.action ?: "NULL"}")
        startForeground(NOTIF_ID, buildNotification())
        handleAction(intent)
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        stopTick()
        mediaPlayer?.release()
        mediaPlayer = null
        println("[SwSvc] onDestroy")
    }

    // ── Manejo de acciones ─────────────────────────────────────────────────────────────────

    private fun handleAction(intent: Intent?) {
        val action = intent?.action
        println("[SwSvc] handleAction: action=$action  state=$state  mode=$mode")
        when (action) {
            ACTION_START -> { println("[SwSvc] → doStart"); doStart() }
            ACTION_PAUSE -> { println("[SwSvc] → doPause"); doPause() }
            ACTION_TOGGLE_START_PAUSE -> {
                println("[SwSvc] → TOGGLE_START_PAUSE  state=$state → ${if (state == STATE_RUNNING) "pause" else "start"}")
                if (state == STATE_RUNNING) doPause() else doStart()
            }
            ACTION_RESET -> { println("[SwSvc] → doReset"); doReset() }
            ACTION_LAP   -> { println("[SwSvc] → doLap"); doLap() }
            ACTION_TOGGLE_MODE -> {
                val current = prefs.getString(KEY_MODE, MODE_STOPWATCH) ?: MODE_STOPWATCH
                val next = if (current == MODE_STOPWATCH) MODE_TIMER else MODE_STOPWATCH
                println("[SwSvc] → TOGGLE_MODE  $current → $next")
                doSetMode(next)
            }
            ACTION_SET_TIMER -> {
                val ms = intent.getLongExtra(EXTRA_TIMER_DURATION, 0L)
                println("[SwSvc] → SET_TIMER ms=$ms")
                if (ms > 0) doSetTimer(ms)
            }
            ACTION_SET_MODE -> {
                val m = intent.getStringExtra(EXTRA_MODE) ?: MODE_STOPWATCH
                println("[SwSvc] → SET_MODE mode=$m")
                doSetMode(m)
            }
            ACTION_TIMER_ADD_STEP -> {
                val ms = intent.getLongExtra(EXTRA_TIMER_STEP_MS, 5 * 60_000L)
                println("[SwSvc] → TIMER_ADD_STEP ms=$ms")
                doAdjustTimer(ms)
            }
            ACTION_TIMER_SUB_STEP -> {
                val ms = intent.getLongExtra(EXTRA_TIMER_STEP_MS, 5 * 60_000L)
                println("[SwSvc] → TIMER_SUB_STEP ms=$ms")
                doAdjustTimer(-ms)
            }
            ACTION_STOP_ALARM -> { println("[SwSvc] → doStopAlarm"); doStopAlarm() }
            null -> println("[SwSvc] handleAction: intent o action es NULL")
            else -> println("[SwSvc] handleAction: acción desconocida '$action'")
        }
    }

    private fun doStart() {
        if (state == STATE_RUNNING) return
        startEpoch = System.currentTimeMillis()
        if (state == STATE_PAUSED && mode == MODE_TIMER) {
            // retomar desde el tiempo restante guardado
            val rem = prefs.getLong(KEY_TIMER_REM, timerTarget)
            accumulated = 0L
            timerTarget = rem
            prefs.edit().putLong(KEY_TIMER_TGT, timerTarget).apply()
        } else if (state == STATE_IDLE) {
            accumulated = 0L
            if (mode == MODE_TIMER && timerTarget == 0L) timerTarget = 5 * 60_000L
        }
        state = STATE_RUNNING
        saveState()
        startTick()
        updateNotification()
        broadcastTick()
        updateWidgets()
        println("[SwSvc] doStart: mode=$mode timerTarget=$timerTarget accum=$accumulated")
    }

    private fun doPause() {
        if (state != STATE_RUNNING) return
        val now = System.currentTimeMillis()
        if (mode == MODE_STOPWATCH) {
            accumulated += now - startEpoch
        } else {
            val elapsed = now - startEpoch
            val remaining = (timerTarget - elapsed).coerceAtLeast(0L)
            prefs.edit().putLong(KEY_TIMER_REM, remaining).apply()
        }
        state = STATE_PAUSED
        stopTick()
        saveState()
        updateNotification()
        broadcastTick()
        updateWidgets()
        println("[SwSvc] doPause: accum=$accumulated")
    }

    private fun doReset() {
        stopTick()
        accumulated = 0L
        startEpoch  = 0L
        laps.clear()
        state = STATE_IDLE
        prefs.edit()
            .putLong(KEY_TIMER_REM, timerTarget)
            .apply()
        saveState()
        updateNotification()
        broadcastTick()
        updateWidgets()
        println("[SwSvc] doReset")
    }

    private fun doLap() {
        if (state != STATE_RUNNING || mode != MODE_STOPWATCH) return
        val now     = System.currentTimeMillis()
        val elapsed = accumulated + (now - startEpoch)
        laps.add(elapsed)
        saveLaps()
        broadcastTick()
        updateWidgets()
        // Sonido/vibración de vuelta
        if (readFlutterBool(prefs, KEY_LAP_VIB, false)) vibrateShort()
        if (readFlutterBool(prefs, KEY_LAP_SND, false)) playSound(prefs.getString(KEY_LAP_SND_URI, "") ?: "")
        println("[SwSvc] doLap #${laps.size} elapsed=$elapsed")
    }

    private fun doSetTimer(ms: Long) {
        if (state == STATE_RUNNING) doPause()
        timerTarget = ms
        accumulated = 0L
        state       = STATE_IDLE
        prefs.edit()
            .putLong(KEY_TIMER_TGT, ms)
            .putLong(KEY_TIMER_REM, ms)
            .apply()
        saveState()
        broadcastTick()
        updateWidgets()
    }

    private fun doAdjustTimer(deltaMs: Long) {
        if (mode != MODE_TIMER) return
        val elapsed = if (state == STATE_RUNNING) (System.currentTimeMillis() - startEpoch).coerceAtLeast(0L) else 0L
        timerTarget = (timerTarget + deltaMs).coerceAtLeast(elapsed + 10_000L)
        val newRem  = (timerTarget - elapsed).coerceAtLeast(10_000L)
        prefs.edit()
            .putLong(KEY_TIMER_TGT, timerTarget)
            .putLong(KEY_TIMER_REM, newRem)
            .apply()
        broadcastTick()
        updateWidgets()
    }

    private fun doSetMode(newMode: String) {
        if (state == STATE_RUNNING) doPause()
        mode        = newMode
        accumulated = 0L
        startEpoch  = 0L
        laps.clear()
        state = STATE_IDLE
        if (newMode == MODE_TIMER && timerTarget == 0L) timerTarget = 5 * 60_000L
        saveState()
        broadcastTick()
        updateWidgets()
    }

    private fun doStopAlarm() {
        println("[SwSvc] doStopAlarm: deteniendo sonido y vibración")
        try { vibrator.cancel() } catch (_: Exception) { }
        try { mediaPlayer?.stop(); mediaPlayer?.release(); mediaPlayer = null } catch (_: Exception) { }
        // Vuelve al estado idle para que el widget muestre los botones normales
        accumulated = 0L
        startEpoch  = 0L
        laps.clear()
        state = STATE_IDLE
        if (timerTarget == 0L) timerTarget = 5 * 60_000L
        prefs.edit().putLong(KEY_TIMER_REM, timerTarget).apply()
        saveState()
        updateNotification()
        broadcastTick()
        updateWidgets()
        println("[SwSvc] doStopAlarm: alarma detenida, estado → idle")
    }

    private fun doFinish() {
        stopTick()
        state = STATE_FINISHED
        saveState()
        updateNotification()
        broadcastTick()
        updateWidgets()
        if (readFlutterBool(prefs, KEY_VIB_ENABLED, true)) vibrateFinish()
        if (readFlutterBool(prefs, KEY_SND_ENABLED, true))  playSound(prefs.getString(KEY_SND_URI, "") ?: "")
        println("[SwSvc] doFinish: temporizador llegó a cero")
    }

    // ── Tick ──────────────────────────────────────────────────────────────────────────────

    // Contador de ticks para throttle de widget/notificación (cada 1 s = 20 ticks de 50 ms)
    private var tickCount = 0

    private fun startTick() {
        stopTick()
        tickCount = 0
        val r = object : Runnable {
            override fun run() {
                if (state != STATE_RUNNING) return
                if (mode == MODE_STOPWATCH) {
                    val elapsed = accumulated + (System.currentTimeMillis() - startEpoch)
                    prefs.edit().putLong(KEY_ACCUM, elapsed).apply()
                } else {
                    val elapsed   = System.currentTimeMillis() - startEpoch
                    val remaining = (timerTarget - elapsed).coerceAtLeast(0L)
                    prefs.edit().putLong(KEY_TIMER_REM, remaining).apply()
                    if (remaining <= 0L) {
                        doFinish()
                        return
                    }
                }
                broadcastTick()
                // Actualizar widget y notificación cada ~1 segundo para no saturar IPC
                tickCount++
                if (tickCount >= 20) {
                    tickCount = 0
                    updateWidgets()
                    updateNotification()
                }
                handler.postDelayed(this, 50L)
            }
        }
        tickRunnable = r
        handler.post(r)
    }

    private fun stopTick() {
        tickRunnable?.let { handler.removeCallbacks(it) }
        tickRunnable = null
    }

    // ── Persistencia ─────────────────────────────────────────────────────────────────────

    private fun loadStateFromPrefs() {
        mode        = prefs.getString(KEY_MODE,  MODE_STOPWATCH) ?: MODE_STOPWATCH
        state       = prefs.getString(KEY_STATE, STATE_IDLE)     ?: STATE_IDLE
        startEpoch  = prefs.getLong(KEY_START, 0L)
        accumulated = prefs.getLong(KEY_ACCUM, 0L)
        timerTarget = prefs.getLong(KEY_TIMER_TGT, 5 * 60_000L)

        val lapsJson = prefs.getString(KEY_LAPS, "[]") ?: "[]"
        laps.clear()
        try {
            val arr = JSONArray(lapsJson)
            for (i in 0 until arr.length()) laps.add(arr.getJSONObject(i).getLong("elapsed"))
        } catch (_: Exception) { }

        // Si se reinicia el servicio mientras estaba corriendo, recuperar estado correcto
        if (state == STATE_RUNNING) {
            // Continuamos desde donde estaba; el tick se reanudará si se vuelve a llamar doStart
            // En realidad, al reiniciarse el servicio no iniciamos tick automáticamente
            // para evitar desfases. Flutter lo reanudará llamando ACTION_START.
            state = STATE_PAUSED
            saveState()
        }
    }

    private fun saveState() {
        prefs.edit()
            .putString(KEY_MODE,  mode)
            .putString(KEY_STATE, state)
            .putLong(KEY_START, startEpoch)
            .putLong(KEY_ACCUM, accumulated)
            .putLong(KEY_TIMER_TGT, timerTarget)
            .apply()
        saveLaps()
    }

    private fun saveLaps() {
        val arr = JSONArray()
        var prev = 0L
        for ((i, lap) in laps.withIndex()) {
            arr.put(JSONObject().apply {
                put("elapsed", lap)
                put("delta",   lap - prev)
                put("number",  i + 1)
            })
            prev = lap
        }
        prefs.edit().putString(KEY_LAPS, arr.toString()).apply()
    }

    // ── Broadcast ────────────────────────────────────────────────────────────────────────

    private fun broadcastTick() {
        try {
            sendBroadcast(Intent(ACTION_TICK_BROADCAST).setPackage(packageName))
        } catch (_: Exception) { }
    }

    // ── Widget update ─────────────────────────────────────────────────────────────────────

    private fun updateWidgets() {
        println("[SwSvc] updateWidgets: estado=$state mode=$mode")
        try {
            StopwatchWidgetProviderStyle1.updateAll(applicationContext)
            println("[SwSvc] updateWidgets: style1 OK")
        } catch (e: Exception) {
            println("[SwSvc] updateWidgets: style1 ERROR ${e.message}")
        }
        try {
            StopwatchWidgetProviderStyle3.updateAll(applicationContext)
            println("[SwSvc] updateWidgets: style3 OK")
        } catch (e: Exception) {
            println("[SwSvc] updateWidgets: style3 ERROR ${e.message}")
        }
    }

    // ── Notificación ─────────────────────────────────────────────────────────────────────

    private fun createNotifChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                NOTIF_CHANNEL_ID,
                "Cronómetro y Temporizador",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setShowBadge(false)
                description = "Cronómetro y temporizador en segundo plano"
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("navigate_to", "stopwatch_timer")
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val timeText = when {
            mode == MODE_STOPWATCH -> formatElapsed(accumulated)
            mode == MODE_TIMER     -> formatElapsed(prefs.getLong(KEY_TIMER_REM, timerTarget))
            else                   -> "00:00.000"
        }
        val stateText = when (state) {
            STATE_RUNNING  -> if (mode == MODE_STOPWATCH) "Cronómetro corriendo" else "Temporizador corriendo"
            STATE_PAUSED   -> "Pausado"
            STATE_FINISHED -> "Tiempo terminado"
            else           -> if (mode == MODE_STOPWATCH) "Cronómetro listo" else "Temporizador listo"
        }

        val toggleAction = if (state == STATE_RUNNING) {
            val pi = PendingIntent.getService(this, 1,
                Intent(this, StopwatchTimerFgService::class.java).setAction(ACTION_PAUSE),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            NotificationCompat.Action(android.R.drawable.ic_media_pause, "Pausar", pi)
        } else {
            val pi = PendingIntent.getService(this, 1,
                Intent(this, StopwatchTimerFgService::class.java).setAction(ACTION_START),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            NotificationCompat.Action(android.R.drawable.ic_media_play, "Iniciar", pi)
        }

        val resetPi = PendingIntent.getService(this, 2,
            Intent(this, StopwatchTimerFgService::class.java).setAction(ACTION_RESET),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val resetAction = NotificationCompat.Action(android.R.drawable.ic_menu_close_clear_cancel, "Reiniciar", resetPi)

        return NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(timeText)
            .setContentText(stateText)
            .setContentIntent(openIntent)
            .addAction(toggleAction)
            .addAction(resetAction)
            .setOngoing(state == STATE_RUNNING)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification() {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIF_ID, buildNotification())
        } catch (_: Exception) { }
    }

    // ── Sonido y vibración ────────────────────────────────────────────────────────────────

    private fun playSound(uri: String) {
        try {
            mediaPlayer?.release()
            mediaPlayer = null
            val player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            if (uri.isNotEmpty()) {
                player.setDataSource(applicationContext, Uri.parse(uri))
            } else {
                val defaultUri = Settings.System.DEFAULT_ALARM_ALERT_URI
                player.setDataSource(applicationContext, defaultUri)
            }
            player.setOnCompletionListener { it.release(); if (mediaPlayer == it) mediaPlayer = null }
            player.prepareAsync()
            player.setOnPreparedListener { it.start() }
            mediaPlayer = player
        } catch (e: Exception) {
            println("[SwSvc] playSound ERROR: ${e.message}")
        }
    }

    private fun vibrateFinish() {
        try {
            val patternJson = prefs.getString(KEY_VIB_PATTERN, "") ?: ""
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = if (patternJson.isNotEmpty()) {
                    parseVibrationEffect(patternJson)
                } else {
                    VibrationEffect.createWaveform(
                        longArrayOf(0L, 400L, 200L, 400L, 200L, 600L),
                        intArrayOf(0, 255, 0, 200, 0, 255),
                        -1
                    )
                }
                vibrator.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(longArrayOf(0L, 400L, 200L, 400L, 200L, 600L), -1)
            }
        } catch (e: Exception) {
            println("[SwSvc] vibrateFinish ERROR: ${e.message}")
        }
    }

    private fun vibrateShort() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(80L, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(80L)
            }
        } catch (_: Exception) { }
    }

    private fun parseVibrationEffect(json: String): VibrationEffect {
        // Formato simple: {"timings":[0,300,100,300],"amplitudes":[0,255,0,200],"repeat":-1}
        return try {
            val obj = JSONObject(json)
            val timingsArr   = obj.getJSONArray("timings")
            val amplitudesArr = obj.getJSONArray("amplitudes")
            val repeat       = obj.optInt("repeat", -1)
            val timings = LongArray(timingsArr.length()) { timingsArr.getLong(it) }
            val amps    = IntArray(amplitudesArr.length()) { amplitudesArr.getInt(it) }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                VibrationEffect.createWaveform(timings, amps, repeat)
            } else {
                throw Exception("API < O")
            }
        } catch (_: Exception) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                VibrationEffect.createOneShot(600L, VibrationEffect.DEFAULT_AMPLITUDE)
            } else {
                throw Exception("API < O")
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────────────────

    private fun formatElapsed(ms: Long): String {
        val total = ms.coerceAtLeast(0L)
        val h  = total / 3_600_000L
        val m  = (total % 3_600_000L) / 60_000L
        val s  = (total % 60_000L) / 1_000L
        val ms2 = total % 1_000L
        return if (h > 0) "%02d:%02d:%02d.%03d".format(h, m, s, ms2)
               else       "%02d:%02d.%03d".format(m, s, ms2)
    }
}
