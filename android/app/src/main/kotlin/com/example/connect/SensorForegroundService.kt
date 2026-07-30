package com.example.connect

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class SensorForegroundService : Service() {

    companion object {
        const val ACTION_START = "com.example.connect.sensors.START"
        const val ACTION_STOP  = "com.example.connect.sensors.STOP"

        private const val CHANNEL_ID   = "sensor_fg_channel"
        private const val CHANNEL_NAME = "Sensores corporales"
        private const val NOTIF_ID     = 42001

        @Volatile var isRunning: Boolean = false
        @Volatile var instance: SensorForegroundService? = null

        // Sinks alimentados por MainActivity desde el engine principal
        @Volatile var hrSink: EventChannel.EventSink? = null
        @Volatile var stepsSink: EventChannel.EventSink? = null
        @Volatile var debugSink: EventChannel.EventSink? = null

        // MethodChannel para enviar rotaryDelta hacia Flutter (seteado por MainActivity)
        @Volatile var rotaryChannel: MethodChannel? = null
    }

    // ── Sensor manager ───────────────────────────────────────────────────────
    private lateinit var sensorManager: SensorManager
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── HR ───────────────────────────────────────────────────────────────────
    private var hrSensor: Sensor? = null
    private var lastBpm: Int = 0

    // ── Pedómetro software (acelerómetro) ────────────────────────────────────
    private var accelSensor: Sensor? = null
    private var wasAboveThreshold = false
    private var lastStepMs = 0L
    private var stepsToday = 0
    private var lastResetDay = -1
    private val STEP_THRESHOLD = 2.0f          // m/s² sobre gravedad eliminada
    private val MIN_STEP_INTERVAL_MS = 400L    // ms mínimos entre pasos
    private val AMPLITUDE_MIN = 1.5f           // m/s² amplitud mínima pico-valle
    private val SMOOTHING_WINDOW = 5           // muestras para media móvil
    private val ANTI_BOUNCE_WINDOW_MS = 3000L  // ventana anti-rebote
    private val ANTI_BOUNCE_MAX_STEPS = 6      // máx pasos en la ventana

    private var gravityEst = 9.8f
    private val linearBuffer = FloatArray(5) { 0f }
    private var linearIdx = 0
    private var lastLinearPeak = 0f
    private var lastLinearValley = Float.MAX_VALUE
    private var antiBounceCount = 0
    private var antiBounceWindowStart = 0L

    // ── Rotary encoder ────────────────────────────────────────────────────────
    private val SENSOR_TYPE_ROTARY_ENCODER = 36
    private var rotarySensor: Sensor? = null

    // ─────────────────────────────────────────────────────────────────────────
    // Ciclo de vida
    // ─────────────────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        instance = this
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        log("foreground_svc", "onCreate")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                startForegroundWithNotification()
                registerSensors()
                isRunning = true
                log("foreground_svc", "iniciado notif_id=$NOTIF_ID")
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        unregisterSensors()
        isRunning = false
        instance = null
        log("foreground_svc", "detenido")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ─────────────────────────────────────────────────────────────────────────
    // Registro de sensores
    // ─────────────────────────────────────────────────────────────────────────

    private fun registerSensors() {
        // HR
        hrSensor = sensorManager.getDefaultSensor(Sensor.TYPE_HEART_RATE)
        hrSensor?.let {
            sensorManager.registerListener(hrListener, it, SensorManager.SENSOR_DELAY_NORMAL)
            log("hr_monitor", "sensor registrado: ${it.name}")
        } ?: log("hr_monitor", "sensor HR no disponible")

        // Acelerómetro (pedómetro)
        accelSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        accelSensor?.let {
            sensorManager.registerListener(accelListener, it, SensorManager.SENSOR_DELAY_GAME)
            log("step_counter", "acelerómetro registrado: ${it.name}")
        } ?: log("step_counter", "acelerómetro no disponible")

    }

    fun registerRotary() {
        val rotary = sensorManager.getDefaultSensor(SENSOR_TYPE_ROTARY_ENCODER)
        if (rotary != null) {
            sensorManager.registerListener(rotaryListener, rotary, SensorManager.SENSOR_DELAY_UI)
            log("rotary", "corona registrada: ${rotary.name}")
        } else {
            log("rotary", "sensor de corona no disponible (type=36)")
        }
    }

    fun unregisterRotary() {
        try { sensorManager.unregisterListener(rotaryListener) } catch (_: Throwable) {}
        log("rotary", "corona desregistrada")
    }

    private fun unregisterSensors() {
        try { sensorManager.unregisterListener(hrListener) } catch (_: Throwable) {}
        try { sensorManager.unregisterListener(accelListener) } catch (_: Throwable) {}
        try { sensorManager.unregisterListener(rotaryListener) } catch (_: Throwable) {}
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Listeners de sensores
    // ─────────────────────────────────────────────────────────────────────────

    private val hrListener = object : SensorEventListener {
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        override fun onSensorChanged(event: SensorEvent) {
            val bpm = event.values[0].toInt()
            val confidence = if (event.values.size > 1) event.values[1].toInt() else 2
            if (confidence < 2) {
                log("hr_monitor", "lectura descartada confidence=$confidence")
                return
            }
            lastBpm = bpm
            val data = mapOf("bpm" to bpm, "confidence" to confidence, "timestamp" to System.currentTimeMillis())
            mainHandler.post { hrSink?.success(data) }
            log("hr_monitor", "BPM=$bpm confidence=$confidence")
            sendSensorDataToBt(hr = bpm)
        }
    }

    private val accelListener = object : SensorEventListener {
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        override fun onSensorChanged(event: SensorEvent) {
            val x = event.values[0]; val y = event.values[1]; val z = event.values[2]
            val raw = Math.sqrt((x * x + y * y + z * z).toDouble()).toFloat()

            // Eliminar gravedad con filtro paso-alto
            gravityEst = 0.8f * gravityEst + 0.2f * raw
            val linear = raw - gravityEst

            // Suavizar con media móvil
            linearBuffer[linearIdx % SMOOTHING_WINDOW] = linear
            linearIdx++
            val smooth = linearBuffer.average().toFloat()

            val nowMs = System.currentTimeMillis()
            checkDayReset(nowMs)

            // Rastrear amplitud pico-valle del ciclo actual
            if (smooth > lastLinearPeak) lastLinearPeak = smooth
            if (smooth < lastLinearValley) lastLinearValley = smooth
            val amplitude = lastLinearPeak - lastLinearValley

            val isAbove = smooth > STEP_THRESHOLD
            if (isAbove && !wasAboveThreshold
                && (nowMs - lastStepMs) > MIN_STEP_INTERVAL_MS
                && amplitude >= AMPLITUDE_MIN) {

                // Anti-rebote de frecuencia: > 6 pasos en 3 s = vibración, descartar
                if (nowMs - antiBounceWindowStart > ANTI_BOUNCE_WINDOW_MS) {
                    antiBounceWindowStart = nowMs
                    antiBounceCount = 0
                }
                antiBounceCount++
                if (antiBounceCount <= ANTI_BOUNCE_MAX_STEPS) {
                    stepsToday++
                    lastStepMs = nowMs
                    val dist = (stepsToday * 0.415 * getUserHeight() / 100.0).toInt()
                    val payload = mapOf("steps" to stepsToday, "distancia_m" to dist, "timestamp" to nowMs)
                    mainHandler.post { stepsSink?.success(payload) }
                    log("step_counter", "paso=$stepsToday smooth=${"%.2f".format(smooth)} ampl=${"%.2f".format(amplitude)} dist=${dist}m")
                    if (stepsToday % 100 == 0) sendSensorDataToBt(steps = stepsToday, distM = dist)
                } else {
                    log("step_counter", "anti-rebote: descartando paso ($antiBounceCount en 3s)")
                }
                lastLinearPeak = 0f
                lastLinearValley = Float.MAX_VALUE
            }
            wasAboveThreshold = isAbove
        }
    }

    private val rotaryListener = object : SensorEventListener {
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        override fun onSensorChanged(event: SensorEvent) {
            val delta = event.values[0]
            mainHandler.post {
                rotaryChannel?.invokeMethod("rotaryDelta", delta.toDouble())
            }
            log("rotary", "delta=${"%.3f".format(delta)}rad")
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private fun checkDayReset(nowMs: Long) {
        val cal = Calendar.getInstance()
        cal.timeInMillis = nowMs
        val day = cal.get(Calendar.DAY_OF_YEAR)
        if (lastResetDay != day) {
            lastResetDay = day
            stepsToday = 0
            log("step_counter", "reset diario día=$day")
        }
    }

    private fun getUserHeight(): Double {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getFloat("flutter.bodyProfile_height_cm", 170f).toDouble()
        } catch (_: Throwable) { 170.0 }
    }

    // Envía un paquete JSON estructurado al emisor via BtClassicServerService
    private fun sendSensorDataToBt(
        hr: Int = -1, steps: Int = -1, distM: Int = -1,
        zona: String = "", kcal: Double = -1.0
    ) {
        try {
            val json = org.json.JSONObject().apply {
                put("type", "sensor_data")
                if (hr >= 0) put("hr", hr)
                if (steps >= 0) put("steps", steps)
                if (distM >= 0) put("dist_m", distM)
                if (zona.isNotEmpty()) put("zona", zona)
                if (kcal >= 0) put("kcal", kcal)
            }
            val intent = Intent(this, BtClassicServerService::class.java).apply {
                action = BtClassicServerService.ACTION_SEND_TO_PEERS
                putExtra(BtClassicServerService.EXTRA_JSON, json.toString())
            }
            startService(intent)
        } catch (_: Throwable) {}
    }

    fun log(source: String, message: String) {
        val tag = "[sensor][$source]"
        println("$tag $message")
        val payload = mapOf(
            "source" to source,
            "message" to message,
            "timestamp" to System.currentTimeMillis()
        )
        mainHandler.post { debugSink?.success(payload) }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Notificación persistente (obligatoria para ForegroundService en Android O+)
    // ─────────────────────────────────────────────────────────────────────────

    private fun startForegroundWithNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW).apply {
                description = "Monitoreo de sensores corporales"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Connect — Sensores")
            .setContentText("Monitoreando sensores corporales")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
        startForeground(NOTIF_ID, notification)
    }
}
