package com.example.connect

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.view.WindowManager // ✅ Agregar import
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.content.Context
import android.content.BroadcastReceiver
import android.app.ActivityManager
import android.os.PowerManager
import android.net.Uri
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.location.LocationManager
import android.os.BatteryManager
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.android.RenderMode



class MainActivity: FlutterActivity() {
    // CANALES SEPARADOS PARA EMISOR Y RECEPTOR
    private val EMISOR_CHANNEL = "com.example.connect/notifications" // Para NotificationListener (EMISOR)
    private val APP_LIST_CHANNEL = "com.example.connect/app_list"
    private val RECEPTOR_CHANNEL = "com.example.connect/local_notifications" // Para LocalNotificationManager (RECEPTOR)
    private val DEVICE_FINDER_CHANNEL = "com.example.connect/device_finder" // ✅ NUEVO CANAL
    private val SOUND_CHANNEL = "com.example.connect/notification_sound" // ✅ CANAL PARA SONIDOS PERSONALIZADOS
    private val SOUND_EVENTS_CHANNEL = "com.example.connect/sound_events"
    private val ACTIVE_NOTIFICATIONS_EVENTS_CHANNEL = "com.example.connect/active_notifications_events"
    private val BATTERY_CHANNEL = "com.example.connect/battery" // ✅ CANAL PARA OPTIMIZACIÓN DE BATERÍA
    private val BLE_CHANNEL = "com.example.connect/ble"
    private val FLOATING_BALL_CHANNEL = "com.example.connect/floating_ball"
    private lateinit var emisorChannel: MethodChannel
    private lateinit var appListChannel: MethodChannel
    private lateinit var receptorChannel: MethodChannel
    private lateinit var deviceFinderChannel: MethodChannel // ✅ NUEVO CANAL
    internal lateinit var soundChannel: MethodChannel // ✅ CANAL PARA SONIDOS PERSONALIZADOS
    private lateinit var soundEventsChannel: EventChannel
    private var soundEventsSink: EventChannel.EventSink? = null
    private lateinit var batteryChannel: MethodChannel // ✅ CANAL PARA OPTIMIZACIÓN DE BATERÍA
    private lateinit var bleChannel: MethodChannel
    private lateinit var floatingBallChannel: MethodChannel
    private lateinit var activeNotificationsEventsChannel: EventChannel
    private var activeNotificationsEventsSink: EventChannel.EventSink? = null
    private lateinit var appListService: AppListService
    private lateinit var localNotificationManager: LocalNotificationManager
    private lateinit var vibrationManager: VibrationManager
    private lateinit var deviceFinderManager: DeviceFinderManager // ✅ NUEVO SERVICIO
    private var bleGattServerManager: BleGattServerManager? = null
    private var bleGattClientManager: BleGattClientManager? = null

    private var lastHandledNotificationIntentId: String? = null
    private var lastHandledNotificationIntentAtMs: Long = 0L

    private var btAdapter: BluetoothAdapter? = null
    private var btDiscoveryReceiver: BroadcastReceiver? = null
    private var btDiscoveryRegistered: Boolean = false

    companion object {
        var instance: MainActivity? = null
    }

    private fun isAutoOpenForegroundBlockActive(intent: Intent?): Boolean {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val untilMs = prefs.getLong("flutter.auto_open_block_until_ms", 0L)
            val nowMs = System.currentTimeMillis()
            if (untilMs <= nowMs) return false

            val action = intent?.action ?: ""
            if (action == LocalNotificationManager.NOTIFICATION_ACTION_OPEN) return false
            if (action == "DEVICE_FINDER_ACTION") return false
            if (intent?.hasExtra("navigate_to") == true) return false

            val wakeOnly = try { intent?.getBooleanExtra("wakeScreenOnly", false) == true } catch (_: Exception) { false }
            if (wakeOnly) return true

            if (action.isBlank() || action == Intent.ACTION_MAIN || action == "WAKE_SCREEN_ACTION") return true

            return true
        } catch (_: Exception) {
            return false
        }
    }

    private fun applyAutoOpenForegroundBlockIfNeeded(stage: String, intent: Intent?): Boolean {
        if (!isAutoOpenForegroundBlockActive(intent)) return false
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val untilMs = prefs.getLong("flutter.auto_open_block_until_ms", 0L)
            val nowMs = System.currentTimeMillis()
            val action = intent?.action ?: ""
            val msg = "blocked $stage action='$action' nowMs=$nowMs untilMs=$untilMs moveToBack+finish"
            try {
                android.util.Log.d("MainActivity", "[main_guard] $msg")
            } catch (_: Exception) {
            }
            try {
                println("[main_guard] $msg")
            } catch (_: Exception) {
            }
            try {
                sendBtDebug("main_guard", msg)
            } catch (_: Exception) {
            }
        } catch (_: Exception) {
        }
        try {
            moveTaskToBack(true)
        } catch (_: Exception) {
        }
        try {
            finishAndRemoveTask()
        } catch (_: Exception) {
        }
        try {
            finish()
        } catch (_: Exception) {
        }
        return true
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (applyAutoOpenForegroundBlockIfNeeded("onCreate", intent)) return
    }

    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode {
        return FlutterActivityLaunchConfigs.BackgroundMode.transparent
    }

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    fun emitActiveNotificationsChanged(
        reason: String,
        key: String?,
        entry: Map<String, Any?>?
    ) {
        try {
            activeNotificationsEventsSink?.success(
                mapOf(
                    "reason" to reason,
                    "key" to (key ?: ""),
                    "entry" to entry,
                    "ts" to System.currentTimeMillis()
                )
            )
        } catch (_: Exception) {
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        instance = this
        
        // Inicializar servicios
        appListService = AppListService(this)
        localNotificationManager = LocalNotificationManager(this)
        vibrationManager = VibrationManager(this)
        deviceFinderManager = DeviceFinderManager.getInstance(this) // ✅ INICIALIZAR SERVICIO

        // Canal para EMISOR (NotificationListener)
        emisorChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EMISOR_CHANNEL)
        NotificationListener.methodChannel = emisorChannel
        Log.d("MainActivity", "Canal EMISOR asignado a NotificationListener")
        
        // Canal para lista de aplicaciones
        appListChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_LIST_CHANNEL)
        
        // CANAL PARA RECEPTOR (LocalNotificationManager)
        receptorChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECEPTOR_CHANNEL)
        
        // ✅ CANAL PARA BÚSQUEDA DE DISPOSITIVOS
        deviceFinderChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_FINDER_CHANNEL)
        
        // ✅ CANAL PARA SONIDOS PERSONALIZADOS
        soundChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOUND_CHANNEL)
        soundEventsChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, SOUND_EVENTS_CHANNEL)
        soundEventsChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                soundEventsSink = events
            }
            override fun onCancel(arguments: Any?) {
                soundEventsSink = null
            }
        })

        activeNotificationsEventsChannel =
            EventChannel(flutterEngine.dartExecutor.binaryMessenger, ACTIVE_NOTIFICATIONS_EVENTS_CHANNEL)
        activeNotificationsEventsChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                activeNotificationsEventsSink = events
            }

            override fun onCancel(arguments: Any?) {
                activeNotificationsEventsSink = null
            }
        })
        
        // ✅ CANAL PARA OPTIMIZACIÓN DE BATERÍA
        batteryChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
        bleChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLE_CHANNEL)
        floatingBallChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLOATING_BALL_CHANNEL)
        btAdapter = BluetoothAdapter.getDefaultAdapter()
        
        // Iniciar automáticamente el servicio si el permiso está concedido
        if (isNotificationServiceEnabled()) {
            val serviceIntent = Intent(this, NotificationListener::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
                Log.d("MainActivity", "Iniciando servicio EMISOR automáticamente")
            } else {
                startService(serviceIntent)
            }
        }

        // CONFIGURAR MANEJADOR PARA CANAL EMISOR (NotificationListener)
        emisorChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startNotificationService" -> {
                    if (!isNotificationServiceEnabled()) {
                        openNotificationListenerSettings()
                        result.success(false)
                        Log.d("MainActivity", "Servicio EMISOR no habilitado, abriendo configuración.")
                    } else {
                        try {
                            if (!NotificationListener.isRunning) {
                                NotificationListener.forceRebind(applicationContext)
                            }
                        } catch (_: Exception) {
                        }
                        val serviceIntent = Intent(this, NotificationListener::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                        Log.d("MainActivity", "Servicio EMISOR iniciado.")
                    }
                }
                "stopNotificationService" -> {
                    val serviceIntent = Intent(this, NotificationListener::class.java)
                    stopService(serviceIntent)
                    result.success(true)
                    Log.d("MainActivity", "Servicio EMISOR detenido.")
                }
                "isServiceRunning" -> {
                    result.success(NotificationListener.isRunning)
                    Log.d("MainActivity", "Estado servicio EMISOR: ${NotificationListener.isRunning}")
                }
                "isNotificationServiceEnabled" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "openNotificationSettings" -> {
                    openNotificationListenerSettings()
                    result.success(null)
                }
                "rebindNotificationListener" -> {
                    try {
                        if (!isNotificationServiceEnabled()) {
                            openNotificationListenerSettings()
                            result.success(false)
                        } else {
                            val ok = NotificationListener.forceRebind(applicationContext)
                            result.success(ok)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Error al rebind de notificaciones: ${e.message}", null)
                    }
                }
                "getActiveNotifications" -> {
                    try {
                        val list = NotificationListener.getActiveNotificationsSnapshot().map { e ->
                            mapOf(
                                "key" to e.key,
                                "packageName" to e.packageName,
                                "appName" to e.appName,
                                "appIcon" to e.appIcon,
                                "title" to e.title,
                                "text" to e.text,
                                "subText" to e.subText,
                                "postTime" to e.postTime
                            )
                        }
                        result.success(list)
                    } catch (e: Exception) {
                        result.error("ERROR", "Error al obtener notificaciones activas: ${e.message}", null)
                    }
                }
                "cancelActiveNotification" -> {
                    try {
                        val key = call.argument<String>("key")?.trim().orEmpty()
                        val ok = if (key.isNotBlank()) {
                            NotificationListener.cancelNotificationByKey(key)
                        } else {
                            false
                        }
                        result.success(ok)
                    } catch (e: Exception) {
                        result.error("ERROR", "Error al cancelar notificación: ${e.message}", null)
                    }
                }
                "cancelAllActiveNotifications" -> {
                    try {
                        val canceled = NotificationListener.cancelAllActiveNotifications()
                        result.success(canceled)
                    } catch (e: Exception) {
                        result.error("ERROR", "Error al cancelar todas las notificaciones: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // En la sección donde se configura el manejador para el canal de lista de aplicaciones
        appListChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    try {
                        val apps = appListService.getInstalledApps()
                        result.success(apps)
                        Log.d("MainActivity", "Obtenidas ${apps.size} aplicaciones instaladas")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al obtener aplicaciones instaladas", e)
                        result.error("ERROR", "Error al obtener aplicaciones: ${e.message}", null)
                    }
                }
                "loadAppsFromSystem" -> {
                    try {
                        val apps = appListService.loadAppsFromSystem()
                        result.success(apps)
                        Log.d("MainActivity", "Forzada carga de ${apps.size} aplicaciones desde el sistema")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al obtener aplicaciones desde el sistema", e)
                        result.error("ERROR", "Error al obtener aplicaciones: ${e.message}", null)
                    }
                }
                "searchAppByPackage" -> {
                    try {
                        val packageName = call.argument<String>("packageName")
                        
                        if (packageName != null) {
                            val app = appListService.searchAppByPackage(packageName)
                            if (app != null) {
                                result.success(app)
                                Log.d("MainActivity", "Aplicación encontrada: $packageName")
                            } else {
                                result.success(null) // Devolver null si no se encuentra
                                Log.d("MainActivity", "Aplicación no encontrada: $packageName")
                            }
                        } else {
                            result.error("INVALID_ARGS", "Nombre de paquete no proporcionado", null)
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al buscar aplicación", e)
                        result.error("ERROR", "Error al buscar aplicación: ${e.message}", null)
                    }
                }
                "getLastUpdateDate" -> {
                    try {
                        val date = appListService.getLastUpdateDate()
                        result.success(date)
                        Log.d("MainActivity", "Fecha de última actualización: $date")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al obtener fecha de actualización", e)
                        result.error("ERROR", "Error al obtener fecha: ${e.message}", null)
                    }
                }
                "updateAppState" -> {
                    try {
                        val packageName = call.argument<String>("packageName")
                        val isEnabled = call.argument<Boolean>("isEnabled")
                        
                        if (packageName != null && isEnabled != null) {
                            appListService.updateAppState(packageName, isEnabled)
                            result.success(true)
                            Log.d("MainActivity", "Estado de la aplicación $packageName actualizado a $isEnabled")
                        } else {
                            result.error("INVALID_ARGS", "Argumentos inválidos", null)
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al actualizar estado de la aplicación", e)
                        result.error("ERROR", "Error al actualizar estado: ${e.message}", null)
                    }
                }
                "getEnabledPackages" -> {
                    try {
                        val enabledPackages = appListService.getEnabledPackages()
                        result.success(enabledPackages.toList())
                        Log.d("MainActivity", "Obtenidos ${enabledPackages.size} paquetes habilitados")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al obtener paquetes habilitados", e)
                        result.error("ERROR", "Error al obtener paquetes habilitados: ${e.message}", null)
                    }
                }
                "getAllowedSystemPackages" -> {
                    try {
                        result.success(AppListService.ALLOWED_SYSTEM_PACKAGES)
                        Log.d("MainActivity", "Enviados ${AppListService.ALLOWED_SYSTEM_PACKAGES.size} paquetes del sistema permitidos")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al obtener paquetes del sistema permitidos", e)
                        result.error("ERROR", "Error al obtener paquetes permitidos: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // CONFIGURAR MANEJADOR PARA CANAL RECEPTOR (LocalNotificationManager)
        // En el manejador del canal RECEPTOR
        receptorChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    try {
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        val packageName = call.argument<String>("packageName") ?: ""
                        val appName = call.argument<String>("appName") ?: ""
                        val appIcon = call.argument<String>("appIcon") ?: ""
                        val notificationId = call.argument<String>("notificationId") ?: ""
                        val soundEnabled = call.argument<Boolean>("soundEnabled") ?: true
                        val vibrationEnabled = call.argument<Boolean>("vibrationEnabled") ?: true
                        val customVibrationPattern = try {
                            val raw = call.argument<List<Any>>("customVibrationPattern")
                            raw?.mapNotNull { (it as? Number)?.toLong() }?.takeIf { it.isNotEmpty() }
                        } catch (_: Exception) {
                            null
                        }
                        // ✅ OBTENER LOS NUEVOS PARÁMETROS SEPARADOS
                        val screenWakeEnabled = call.argument<Boolean>("screenWakeEnabled") ?: false
                        val autoOpenEnabled = call.argument<Boolean>("autoOpenEnabled") ?: false
                        
                        // ✅ ACTUALIZAR CONFIGURACIÓN EN TIEMPO REAL
                        localNotificationManager.updateSettings(screenWakeEnabled, autoOpenEnabled, soundEnabled)
                        
                        localNotificationManager.showNotification(
                            title, body, packageName, appName, appIcon, notificationId,
                            soundEnabled, vibrationEnabled, customVibrationPattern, screenWakeEnabled, autoOpenEnabled
                        )
                        result.success(true)
                        Log.d("MainActivity", "Notificación RECEPTOR mostrada: $title")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al mostrar notificación RECEPTOR", e)
                        result.error("ERROR", "Error al mostrar notificación: ${e.message}", null)
                    }
                }
                "updateNotificationSettings" -> {
                    try {
                        val screenWakeEnabledArg = call.argument<Boolean>("screenWakeEnabled")
                        val autoOpenEnabledArg = call.argument<Boolean>("autoOpenEnabled")
                        val soundEnabledArg = call.argument<Boolean>("soundEnabled")

                        val filterWhatsappMessageSummariesArg =
                            call.argument<Boolean>("filterWhatsappMessageSummaries")
                        val filterWhatsappCheckingNewMessagesArg =
                            call.argument<Boolean>("filterWhatsappCheckingNewMessages")

                        if (screenWakeEnabledArg != null ||
                            autoOpenEnabledArg != null ||
                            soundEnabledArg != null
                        ) {
                            val settingsPrefs = applicationContext.getSharedPreferences(
                                "flutter.notification_settings",
                                Context.MODE_PRIVATE
                            )
                            val currentScreenWakeEnabled =
                                settingsPrefs.getBoolean("flutter.screenWakeEnabled", false)
                            val currentAutoOpenEnabled =
                                settingsPrefs.getBoolean("flutter.autoOpenEnabled", false)
                            val currentSoundEnabled =
                                settingsPrefs.getBoolean("flutter.soundEnabled", true)

                            val screenWakeEnabled = screenWakeEnabledArg ?: currentScreenWakeEnabled
                            val autoOpenEnabled = autoOpenEnabledArg ?: currentAutoOpenEnabled
                            val soundEnabled = soundEnabledArg ?: currentSoundEnabled

                            localNotificationManager.updateSettings(
                                screenWakeEnabled = screenWakeEnabled,
                                autoOpenEnabled = autoOpenEnabled,
                                soundEnabled = soundEnabled
                            )
                        }

                        if (filterWhatsappMessageSummariesArg != null ||
                            filterWhatsappCheckingNewMessagesArg != null
                        ) {
                            val prefs = applicationContext.getSharedPreferences(
                                "FlutterSharedPreferences",
                                Context.MODE_PRIVATE
                            )
                            val editor = prefs.edit()
                            if (filterWhatsappMessageSummariesArg != null) {
                                editor.putBoolean(
                                    "flutter.filter_whatsapp_message_summaries",
                                    filterWhatsappMessageSummariesArg
                                )
                            }
                            if (filterWhatsappCheckingNewMessagesArg != null) {
                                editor.putBoolean(
                                    "flutter.filter_whatsapp_checking_new_messages",
                                    filterWhatsappCheckingNewMessagesArg
                                )
                            }
                            editor.apply()
                        }

                        result.success(true)
                        Log.d("MainActivity", "Configuración de notificaciones actualizada")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al actualizar configuración", e)
                        result.error("ERROR", "Error al actualizar configuración: ${e.message}", null)
                    }
                }
                "cancelNotification" -> {
                    try {
                        val notificationId = call.argument<String>("notificationId") ?: ""
                        localNotificationManager.cancelNotification(notificationId)
                        result.success(true)
                        Log.d("MainActivity", "Notificación RECEPTOR cancelada: $notificationId")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al cancelar notificación RECEPTOR", e)
                        result.error("ERROR", "Error al cancelar notificación: ${e.message}", null)
                    }
                }
                "syncCancelledNotifications" -> {
                    try {
                        val cancelledIds = call.argument<List<String>>("cancelledIds") ?: emptyList()
                        
                        // Limpiar la lista actual y agregar las IDs desde Flutter
                        LocalNotificationManager.clearCancelledNotifications()
                        cancelledIds.forEach { id ->
                            LocalNotificationManager.addToCancelledNotifications(id)
                        }
                        
                        result.success(true)
                        Log.d("MainActivity", "Sincronizadas ${cancelledIds.size} notificaciones canceladas desde Flutter")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al sincronizar notificaciones canceladas", e)
                        result.error("ERROR", "Error al sincronizar: ${e.message}", null)
                    }
                }
                "testVibration" -> {
                    try {
                        vibrationManager.testVibration()
                        result.success(true)
                        Log.d("MainActivity", "Test de vibración ejecutado")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error en test de vibración", e)
                        result.error("ERROR", "Error en test de vibración: ${e.message}", null)
                    }
                }
                "vibrateSimple" -> {
                    try {
                        val duration = call.argument<Long>("duration") ?: 500L
                        vibrationManager.vibrateSimple(duration)
                        result.success(true)
                        Log.d("MainActivity", "Vibración simple ejecutada: ${duration}ms")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error en vibración simple", e)
                        result.error("ERROR", "Error en vibración simple: ${e.message}", null)
                    }
                }
                "vibratePattern" -> {
                    try {
                        val pattern = call.argument<List<Long>>("pattern") ?: emptyList()
                        vibrationManager.vibratePattern(pattern)
                        result.success(true)
                        Log.d("MainActivity", "Vibración con patrón ejecutada: $pattern")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error en vibración con patrón", e)
                        result.error("ERROR", "Error en vibración con patrón: ${e.message}", null)
                    }
                }
                "hasVibrator" -> {
                    try {
                        val hasVibrator = vibrationManager.hasVibrator()
                        result.success(hasVibrator)
                        Log.d("MainActivity", "Consulta de vibrador: $hasVibrator")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al consultar vibrador", e)
                        result.error("ERROR", "Error al consultar vibrador: ${e.message}", null)
                    }
                }
                "playNotificationSound" -> {
                    try {
                        val soundService = SoundNotificationService(this@MainActivity)
                        soundService.playNotificationSound(forceSound = true)
                        result.success(true)
                        Log.d("MainActivity", "Sonido de notificación reproducido desde Flutter")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al reproducir sonido de notificación", e)
                        result.error("ERROR", "Error al reproducir sonido: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // ✅ CONFIGURAR MANEJADOR PARA CANAL DE BÚSQUEDA DE DISPOSITIVOS
        deviceFinderChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startDeviceSearch" -> {
                    try {
                        deviceFinderManager.startDeviceSearch()
                        result.success(true)
                        Log.d("MainActivity", "Búsqueda de dispositivo iniciada")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al iniciar búsqueda de dispositivo", e)
                        result.error("ERROR", "Error al iniciar búsqueda: ${e.message}", null)
                    }
                }
                "stopDeviceSearch" -> {
                    try {
                        deviceFinderManager.stopDeviceSearch()
                        result.success(true)
                        Log.d("MainActivity", "Búsqueda de dispositivo detenida")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al detener búsqueda de dispositivo", e)
                        result.error("ERROR", "Error al detener búsqueda: ${e.message}", null)
                    }
                }
                "testVibration" -> {
                    try {
                        deviceFinderManager.testVibration()
                        result.success(true)
                        Log.d("MainActivity", "Test de vibración ejecutado")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al ejecutar test de vibración", e)
                        result.error("ERROR", "Error en test de vibración: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // ✅ CONFIGURAR MANEJADOR PARA CANAL DE SONIDOS PERSONALIZADOS
        soundChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "playCustomSound" -> {
                    try {
                        Log.d("MainActivity", "🔊 Método playCustomSound recibido desde CustomSoundReceiver")
                        // Este método será llamado desde CustomSoundReceiver
                        // No necesita hacer nada más, solo confirmar que se recibió
                        result.success(true)
                        Log.d("MainActivity", "✅ Método playCustomSound procesado exitosamente")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "❌ Error al procesar playCustomSound", e)
                        result.error("ERROR", "Error al reproducir sonido: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // ✅ CONFIGURAR MANEJADOR PARA CANAL DE OPTIMIZACIÓN DE BATERÍA
        batteryChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestBatteryOptimizationPermission" -> {
                    try {
                        requestBatteryOptimizationPermission()
                        result.success(true)
                        Log.d("MainActivity", "Solicitud de permisos de optimización de batería iniciada")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al solicitar permisos de optimización de batería", e)
                        result.error("ERROR", "Error al solicitar permisos: ${e.message}", null)
                    }
                }
                "isBatteryOptimizationIgnored" -> {
                    try {
                        val isIgnored = isBatteryOptimizationIgnored()
                        result.success(isIgnored)
                        Log.d("MainActivity", "Estado de optimización de batería: $isIgnored")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al verificar estado de optimización de batería", e)
                        result.error("ERROR", "Error al verificar estado: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        floatingBallChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getFsBarSystemState" -> {
                    try {
                        val wifiEnabled = try {
                            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                            wifi?.isWifiEnabled == true
                        } catch (_: Exception) {
                            false
                        }
                        val btEnabled = try {
                            BluetoothAdapter.getDefaultAdapter()?.isEnabled == true
                        } catch (_: Exception) {
                            false
                        }
                        val dataEnabled = try {
                            val v = try { Settings.Global.getInt(contentResolver, "mobile_data", 0) } catch (_: Exception) { -1 }
                            if (v == 1) {
                                true
                            } else if (v == 0) {
                                false
                            } else {
                            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                            val net = cm?.activeNetwork
                            val caps = if (net != null) cm.getNetworkCapabilities(net) else null
                            caps?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true &&
                                caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                            }
                        } catch (_: Exception) {
                            false
                        }
                        val locationEnabled = try {
                            val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                            lm?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true ||
                                lm?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true
                        } catch (_: Exception) {
                            false
                        }
                        val batteryPct = try {
                            val i = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                            val level = i?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                            val scale = i?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                            if (level < 0 || scale <= 0) null else {
                                ((level.toDouble() / scale.toDouble()) * 100.0).toInt().coerceIn(0, 100)
                            }
                        } catch (_: Exception) {
                            null
                        }
                        val showMediaRestore = try {
                            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            val useAsReceptor = flutterPrefs.getBoolean("flutter.use_as_receptor", false)
                            if (!useAsReceptor) {
                                false
                            } else {
                                fun isMediaFresh(prefsName: String): Boolean {
                                    return try {
                                        val now = System.currentTimeMillis()
                                        val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                                        val json = prefs.getString("media_json", null)
                                        val updatedAtMs = prefs.getLong("updatedAtMs", 0L)
                                        !json.isNullOrBlank() && updatedAtMs > 0L && now - updatedAtMs <= 15_000L
                                    } catch (_: Exception) {
                                        false
                                    }
                                }
                                isMediaFresh("bt_media_cache_v1") || isMediaFresh("local_media_cache_v1")
                            }
                        } catch (_: Exception) {
                            false
                        }
                        result.success(
                            mapOf(
                                "wifiEnabled" to wifiEnabled,
                                "btEnabled" to btEnabled,
                                "dataEnabled" to dataEnabled,
                                "locationEnabled" to locationEnabled,
                                "batteryPct" to batteryPct,
                                "showMediaRestore" to showMediaRestore
                            )
                        )
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "isOverlayPermissionGranted" -> {
                    try {
                        result.success(isOverlayPermissionGranted())
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "openOverlayPermissionSettings" -> {
                    try {
                        openOverlayPermissionSettings()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "isAccessibilityEnabled" -> {
                    try {
                        result.success(isFloatingBallAccessibilityEnabled())
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "openAccessibilitySettings" -> {
                    try {
                        openAccessibilitySettings()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "isBatteryOptimizationIgnored" -> {
                    try {
                        result.success(isBatteryOptimizationIgnored())
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "requestBatteryOptimizationPermission" -> {
                    try {
                        requestBatteryOptimizationPermission()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "enableAndStart" -> {
                    try {
                        setFloatingBallEnabledTrue()
                        startFloatingBallService(FloatingBallService.ACTION_START)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "start" -> {
                    try {
                        startFloatingBallService(FloatingBallService.ACTION_START)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "updateConfig" -> {
                    try {
                        startFloatingBallService(FloatingBallService.ACTION_UPDATE_CONFIG)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "disable" -> {
                    try {
                        setFloatingBallEnabledFalse()
                        stopFloatingBallService()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        bleChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestBlePermissions" -> {
                    try {
                        val adapter = (getSystemService(Context.BLUETOOTH_SERVICE) as android.bluetooth.BluetoothManager).adapter
                        if (adapter != null && !adapter.isEnabled) {
                            startActivity(Intent(android.bluetooth.BluetoothAdapter.ACTION_REQUEST_ENABLE))
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            requestPermissions(arrayOf(
                                android.Manifest.permission.BLUETOOTH_SCAN,
                                android.Manifest.permission.BLUETOOTH_CONNECT,
                                android.Manifest.permission.BLUETOOTH_ADVERTISE
                            ), 1001)
                        } else {
                            requestPermissions(arrayOf(
                                android.Manifest.permission.ACCESS_FINE_LOCATION
                            ), 1002)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "openLocationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "startBtServer" -> {
                    try {
                        val i = Intent(this, BtClassicServerService::class.java).setAction(BtClassicServerService.ACTION_START)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i) else startService(i)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "stopBtServer" -> {
                    try {
                        val i = Intent(this, BtClassicServerService::class.java).setAction(BtClassicServerService.ACTION_STOP)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i) else startService(i)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getBtServerStatus" -> {
                    try {
                        result.success(
                            mapOf(
                                "running" to BtClassicServerService.isServiceRunning,
                                "connectedCount" to BtClassicServerService.connectedPeers,
                                "lastPeerAddress" to BtClassicServerService.lastPeerAddress,
                                "lastPeerName" to BtClassicServerService.lastPeerName,
                                "lastMediaUpdatedAtMs" to BtClassicServerService.lastMediaUpdatedAtMs
                            )
                        )
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getLastBtMediaState" -> {
                    try {
                        val prefs = applicationContext.getSharedPreferences("bt_media_cache_v1", Context.MODE_PRIVATE)
                        val json = prefs.getString("media_json", null)
                        val updatedAtMs = prefs.getLong("updatedAtMs", 0L)
                        result.success(mapOf("json" to json, "updatedAtMs" to updatedAtMs))
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getLastLocalMediaState" -> {
                    try {
                        val prefs = applicationContext.getSharedPreferences("local_media_cache_v1", Context.MODE_PRIVATE)
                        val json = prefs.getString("media_json", null)
                        val updatedAtMs = prefs.getLong("updatedAtMs", 0L)
                        result.success(mapOf("json" to json, "updatedAtMs" to updatedAtMs))
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "sendBtServerMessage" -> {
                    try {
                        val args = call.arguments as Map<String, Any?>
                        val json = org.json.JSONObject(args).toString()
                        val i = Intent(this, BtClassicServerService::class.java)
                            .setAction(BtClassicServerService.ACTION_SEND_TO_PEERS)
                            .putExtra(BtClassicServerService.EXTRA_JSON, json)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i) else startService(i)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getBondedDevices" -> {
                    try {
                        val adapter = btAdapter
                        val bonded = adapter?.bondedDevices?.map { d ->
                            mapOf(
                                "address" to d.address,
                                "name" to (d.name ?: ""),
                                "bondState" to d.bondState
                            )
                        } ?: emptyList()
                        result.success(bonded)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "startBtDiscovery" -> {
                    try {
                        startBtDiscovery()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "stopBtDiscovery" -> {
                    try {
                        stopBtDiscovery()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "makeDiscoverable" -> {
                    try {
                        val seconds = (call.argument<Int>("seconds") ?: 300).coerceIn(60, 3600)
                        val intent = Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE)
                        intent.putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, seconds)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "startGattServer" -> {
                    try {
                        if (bleGattServerManager == null) bleGattServerManager = BleGattServerManager(this, bleChannel)
                        bleGattServerManager?.start()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "stopGattServer" -> {
                    try {
                        bleGattServerManager?.stop()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "sendConnectionPing" -> {
                    try {
                        bleGattServerManager?.sendConnectionPing()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "startGattClient" -> {
                    try {
                        if (bleGattClientManager == null) bleGattClientManager = BleGattClientManager(this, bleChannel)
                        bleGattClientManager?.start()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "stopGattClient" -> {
                    try {
                        bleGattClientManager?.stop()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "startBleScan" -> {
                    try {
                        if (bleGattClientManager == null) bleGattClientManager = BleGattClientManager(this, bleChannel)
                        bleGattClientManager?.startScanOnly()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "stopBleScan" -> {
                    try {
                        bleGattClientManager?.stopScanOnly()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "connectToPeer" -> {
                    try {
                        val address = call.argument<String>("address")
                        if (address != null) {
                            BtClassicClient.init(this)
                            BtClassicClient.connect(address)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "address requerido", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "startBleScan" -> {
                    try {
                        if (bleGattClientManager == null) bleGattClientManager = BleGattClientManager(this, bleChannel)
                        bleGattClientManager?.startScanOnly()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "stopBleScan" -> {
                    try {
                        bleGattClientManager?.stopScanOnly()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "connectToPeer" -> {
                    try {
                        val address = call.argument<String>("address")
                        if (address != null) {
                            BtClassicClient.init(this)
                            BtClassicClient.connect(address)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "address requerido", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "sendNotification" -> {
                    try {
                        val args = call.arguments as Map<String, Any?>
                        val json = org.json.JSONObject(args).toString()
                        BtClassicClient.init(this)
                        BtClassicClient.send(json)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getAdapterInfo" -> {
                    try {
                        val adapter = (getSystemService(Context.BLUETOOTH_SERVICE) as android.bluetooth.BluetoothManager).adapter
                        val name = adapter?.name ?: ""
                        val address = adapter?.address ?: ""
                        result.success(mapOf("name" to name, "address" to address))
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getBleEnv" -> {
                    try {
                        val bm = getSystemService(Context.BLUETOOTH_SERVICE) as android.bluetooth.BluetoothManager
                        val adapter = bm.adapter
                        val enabled = adapter?.isEnabled == true
                        val hasScanPerm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) androidx.core.content.ContextCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_SCAN) == android.content.pm.PackageManager.PERMISSION_GRANTED else true
                        val hasConnectPerm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) androidx.core.content.ContextCompat.checkSelfPermission(this, android.Manifest.permission.BLUETOOTH_CONNECT) == android.content.pm.PackageManager.PERMISSION_GRANTED else true
                        val hasFineLocation = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) androidx.core.content.ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED else true
                        val lm = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
                        val locationEnabled = try { lm.isProviderEnabled(android.location.LocationManager.GPS_PROVIDER) || lm.isProviderEnabled(android.location.LocationManager.NETWORK_PROVIDER) } catch (_: Exception) { false }
                        result.success(mapOf(
                            "enabled" to enabled,
                            "hasScanPerm" to hasScanPerm,
                            "hasConnectPerm" to hasConnectPerm,
                            "hasFineLocation" to hasFineLocation,
                            "locationEnabled" to locationEnabled
                        ))
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "shareLogFile" -> {
                    try {
                        val path = call.argument<String>("path")
                        val mime = call.argument<String>("mime") ?: "text/plain"
                        val pkg = call.argument<String>("package")
                        if (path != null) {
                            val file = java.io.File(path)
                            val uri = androidx.core.content.FileProvider.getUriForFile(this, this.packageName + ".fileprovider", file)
                            val intent = Intent(Intent.ACTION_SEND)
                            intent.type = mime
                            intent.putExtra(Intent.EXTRA_STREAM, uri)
                            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            if (pkg != null && pkg.isNotEmpty()) {
                                try {
                                    packageManager.getPackageInfo(pkg, 0)
                                    intent.`package` = pkg
                                } catch (_: Exception) { /* paquete no disponible */ }
                            }
                            startActivity(Intent.createChooser(intent, "Compartir log"))
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "path requerido", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "updateWidget" -> {
                    try {
                        MediaWidgetProvider.updateAll(applicationContext)
                        MediaWidgetProviderStyle2.updateAll(applicationContext)
                        MediaWidgetProviderStyle3.updateAll(applicationContext)
                        MediaWidgetProviderStyle4.updateAll(applicationContext)
                        MediaWidgetProviderStyle5.updateAll(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean("flutter.floating_ball_enabled", false)
            if (enabled && isOverlayPermissionGranted()) {
                startFloatingBallService(FloatingBallService.ACTION_START)
            }
        } catch (_: Exception) {
        }
        
        // Verificar si se debe navegar a una pantalla específica
        handleNavigationIntent(intent)
    }

    private fun startBtDiscovery() {
        val adapter = btAdapter ?: return
        if (!adapter.isEnabled) return
        if (adapter.isDiscovering) {
            try { adapter.cancelDiscovery() } catch (_: Exception) {}
        }
        if (!btDiscoveryRegistered) {
            btDiscoveryReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    val action = intent?.action ?: return
                    if (action == BluetoothDevice.ACTION_FOUND) {
                        val device: BluetoothDevice? = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        val rssi = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, 0).toInt()
                        if (device != null) {
                            try {
                                bleChannel.invokeMethod(
                                    "onBleScanResult",
                                    mapOf(
                                        "address" to device.address,
                                        "name" to (device.name ?: ""),
                                        "rssi" to rssi,
                                        "ping" to false,
                                        "compatible" to true
                                    )
                                )
                            } catch (_: Exception) {}
                        }
                    }
                }
            }
            val filter = IntentFilter()
            filter.addAction(BluetoothDevice.ACTION_FOUND)
            registerReceiver(btDiscoveryReceiver, filter)
            btDiscoveryRegistered = true
        }
        adapter.startDiscovery()
    }

    private fun stopBtDiscovery() {
        val adapter = btAdapter
        if (adapter != null && adapter.isDiscovering) {
            try { adapter.cancelDiscovery() } catch (_: Exception) {}
        }
        if (btDiscoveryRegistered) {
            try { unregisterReceiver(btDiscoveryReceiver) } catch (_: Exception) {}
            btDiscoveryReceiver = null
            btDiscoveryRegistered = false
        }
    }


    // ✅ Método público para notificar a Flutter sobre notificaciones eliminadas
    fun notifyNotificationDismissed(notificationId: String) {
        try {
            receptorChannel.invokeMethod("onNotificationDismissed", mapOf(
                "notificationId" to notificationId
            ))
            Log.d("MainActivity", "Notificación eliminada comunicada a Flutter: $notificationId")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error al comunicar eliminación de notificación a Flutter", e)
        }
    }
    
    private fun handleNavigationIntent(intent: Intent?) {
        intent?.getStringExtra("navigate_to")?.let { route ->
            Log.d("MainActivity", "Navegación solicitada a: $route")
            
            // Enviar el comando de navegación a Flutter
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    deviceFinderChannel.invokeMethod("navigateToRoute", route)
                    Log.d("MainActivity", "Comando de navegación enviado a Flutter: $route")
                } catch (e: Exception) {
                    Log.e("MainActivity", "Error al navegar a $route", e)
                }
            }, 1000) // Esperar 1 segundo para que Flutter esté listo
        }
    }

    private fun handleMediaLaunchIntent(intent: Intent?): Boolean {
        if (intent?.action != "MEDIA_LAUNCH_ACTION") return false
        val pkg = intent.getStringExtra("packageName")?.trim().orEmpty()
        try {
            if (pkg.isNotBlank()) {
                val launch = packageManager.getLaunchIntentForPackage(pkg)
                if (launch != null) {
                    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(launch)
                }
            }
        } catch (_: Exception) {
        }
        try {
            intent.removeExtra("packageName")
        } catch (_: Exception) {
        }
        return true
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        if (applyAutoOpenForegroundBlockIfNeeded("onNewIntent", intent)) return

        if (handleMediaLaunchIntent(intent)) return
        
        // ✅ MANEJO ESPECÍFICO PARA DEVICE_FINDER_ACTION
        if (intent.action == "DEVICE_FINDER_ACTION") {
            Log.d("MainActivity", "Intent de Device Finder recibido")
            handleNavigationIntent(intent)
            return
        }

        handleNavigationIntent(intent)
        handleNotificationIntent(intent)
    }
    
    override fun onResume() {
        super.onResume()
        if (applyAutoOpenForegroundBlockIfNeeded("onResume", intent)) return
        if (handleMediaLaunchIntent(intent)) return
        handleNotificationIntent(intent)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus) return
        applyAutoOpenForegroundBlockIfNeeded("onWindowFocusChanged", intent)
    }
    
    private fun handleNotificationIntent(intent: Intent?) {
        when (intent?.action) {
            LocalNotificationManager.NOTIFICATION_ACTION_OPEN -> {
                // Manejo normal cuando se toca la notificación
                handleNormalNotificationTap(intent)
                clearNotificationIntent()
            }
            LocalNotificationManager.NOTIFICATION_ACTION_AUTO_OPEN -> {
                // ✅ Manejo especial para auto-apertura
                handleAutoOpenNotification(intent)
                clearNotificationIntent()
            }
        }
    }

    private fun clearNotificationIntent() {
        try {
            setIntent(Intent(this, MainActivity::class.java))
        } catch (_: Exception) {
        }
    }
    
    private fun handleNormalNotificationTap(intent: Intent) {
        val notificationId = intent.getStringExtra(LocalNotificationManager.EXTRA_NOTIFICATION_DATA)
        val title = intent.getStringExtra("title")
        val body = intent.getStringExtra("body")
        val packageName = intent.getStringExtra("packageName")
        val appName = intent.getStringExtra("appName")
        val autoOpen = intent.getBooleanExtra("autoOpen", false)
        
        if (notificationId != null) {
            val nowMs = System.currentTimeMillis()
            if (notificationId == lastHandledNotificationIntentId &&
                (nowMs - lastHandledNotificationIntentAtMs) < 2500L
            ) {
                sendBtDebug(
                    "main_intent",
                    "tap OPEN ignored duplicate id='${notificationId.take(80)}' deltaMs=${nowMs - lastHandledNotificationIntentAtMs}"
                )
                return
            }
            lastHandledNotificationIntentId = notificationId
            lastHandledNotificationIntentAtMs = nowMs
            sendBtDebug(
                "main_intent",
                "tap OPEN id='${notificationId.take(80)}' pkg='${(packageName ?: "").take(80)}' title='${(title ?: "").take(50)}'"
            )
            cancelReceptorNotification(notificationId)
            val notificationData = mapOf(
                "notificationId" to notificationId,
                "title" to (title ?: ""),
                "body" to (body ?: ""),
                "packageName" to (packageName ?: ""),
                "appName" to (appName ?: ""),
                "autoOpen" to autoOpen
            )
            
            try {
                receptorChannel.invokeMethod("onNotificationTapped", notificationData)
                sendBtDebug("main_intent", "flutter invoke onNotificationTapped ok id='${notificationId.take(80)}'")
            } catch (_: Exception) {
                sendBtDebug("main_intent", "flutter invoke onNotificationTapped failed id='${notificationId.take(80)}'")
            }
            Log.d("MainActivity", "Notificación RECEPTOR tocada, enviando datos a Flutter")
        }
    }
    
    // ✅ CORREGIDO: Método handleAutoOpenNotification que respeta configuración
    private fun handleAutoOpenNotification(intent: Intent) {
        val notificationId = intent.getStringExtra(LocalNotificationManager.EXTRA_NOTIFICATION_DATA)
        val title = intent.getStringExtra("title")
        val body = intent.getStringExtra("body")
        val packageName = intent.getStringExtra("packageName")
        val appName = intent.getStringExtra("appName")
        val fromBackground = intent.getBooleanExtra("fromBackground", false)
        val timestamp = intent.getLongExtra("timestamp", 0)
        val screenWakeEnabled = intent.getBooleanExtra("screenWakeEnabled", false)
        
        if (notificationId != null) {
            val nowMs = System.currentTimeMillis()
            if (notificationId == lastHandledNotificationIntentId &&
                (nowMs - lastHandledNotificationIntentAtMs) < 2500L
            ) {
                sendBtDebug(
                    "main_intent",
                    "AUTO_OPEN ignored duplicate id='${notificationId.take(80)}' deltaMs=${nowMs - lastHandledNotificationIntentAtMs}"
                )
                return
            }
            lastHandledNotificationIntentId = notificationId
            lastHandledNotificationIntentAtMs = nowMs
            sendBtDebug(
                "main_intent",
                "AUTO_OPEN id='${notificationId.take(80)}' fromBg=$fromBackground wake=$screenWakeEnabled ts=$timestamp pkg='${(packageName ?: "").take(80)}'"
            )
            if (screenWakeEnabled) {
                try {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
                        setShowWhenLocked(true)
                        setTurnScreenOn(true)
                    } else {
                        @Suppress("DEPRECATION")
                        window.addFlags(
                            android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                                android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                                android.view.WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                        )
                    }
                } catch (_: Exception) {
                }
            }
            val notificationData = mapOf(
                "notificationId" to notificationId,
                "title" to (title ?: ""),
                "body" to (body ?: ""),
                "packageName" to (packageName ?: ""),
                "appName" to (appName ?: ""),
                "autoOpen" to true,
                "isAutoOpened" to true,
                "fromBackground" to fromBackground,
                "timestamp" to timestamp
            )
            try {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("flutter.skip_auto_redirect_once", true).apply()
            } catch (_: Exception) {
            }
            
            val delay = if (fromBackground) 850L else 450L
            
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    receptorChannel.invokeMethod("onNotificationAutoOpened", notificationData)
                    Log.d("MainActivity", "Auto-open enviado a Flutter delay=${delay}ms")
                    sendBtDebug("main_intent", "flutter invoke onNotificationAutoOpened ok id='${notificationId.take(80)}' delayMs=$delay")
                } catch (e: Exception) {
                    Log.e("MainActivity", "Error enviando datos a Flutter", e)
                    sendBtDebug("main_intent", "flutter invoke onNotificationAutoOpened failed id='${notificationId.take(80)}' err='${e.message ?: ""}'")
                }
            }, delay)
        }
    }

    private fun cancelReceptorNotification(notificationId: String) {
        val id = notificationId.trim()
        if (id.isEmpty()) return
        try {
            val numericId = (id.hashCode() and 0x7FFFFFFF)
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
            nm?.cancel(numericId)
            sendBtDebug("main_intent", "cancel statusbar ok id='${id.take(80)}' numericId=$numericId")
        } catch (_: Exception) {
            sendBtDebug("main_intent", "cancel statusbar failed id='${id.take(80)}'")
        }
    }

    private fun sendBtDebug(source: String, message: String) {
        try {
            val obj = org.json.JSONObject()
            obj.put("type", "debug_log")
            obj.put("source", source)
            obj.put("message", message)
            obj.put("timestamp", System.currentTimeMillis())
            val i = Intent(this, BtClassicServerService::class.java)
                .setAction(BtClassicServerService.ACTION_SEND_TO_PEERS)
                .putExtra(BtClassicServerService.EXTRA_JSON, obj.toString())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i) else startService(i)
        } catch (_: Exception) {
        }
    }
    
    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        val cn = ComponentName(pkgName, NotificationListener::class.java.name)
        val enabled = flat != null && flat.contains(cn.flattenToString())
        return enabled
    }

    private fun openNotificationListenerSettings() {
        try {
            val intent = Intent()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                intent.action = Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS
            } else {
                intent.action = "android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error al abrir configuración de notificaciones", e)
        }
    }

    fun notifyAppListUpdated() {
        appListChannel.invokeMethod("onAppListUpdated", null)
    }
    
    // ✅ MÉTODOS PARA OPTIMIZACIÓN DE BATERÍA
    private fun requestBatteryOptimizationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            val packageName = packageName
            
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                    Log.d("MainActivity", "Solicitando permisos de optimización de batería para: $packageName")
                } catch (e: Exception) {
                    Log.e("MainActivity", "Error al solicitar permisos de optimización de batería", e)
                    // Fallback: abrir configuración general de optimización de batería
                    try {
                        val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(fallbackIntent)
                        Log.d("MainActivity", "Abriendo configuración general de optimización de batería")
                    } catch (fallbackException: Exception) {
                        Log.e("MainActivity", "Error al abrir configuración de optimización de batería", fallbackException)
                    }
                }
            } else {
                Log.d("MainActivity", "La aplicación ya está exenta de optimización de batería")
            }
        } else {
            Log.d("MainActivity", "Optimización de batería no disponible en esta versión de Android")
        }
    }
    
    private fun isBatteryOptimizationIgnored(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            val packageName = packageName
            val isIgnored = powerManager.isIgnoringBatteryOptimizations(packageName)
            Log.d("MainActivity", "Estado de optimización de batería para $packageName: $isIgnored")
            isIgnored
        } else {
            Log.d("MainActivity", "Optimización de batería no disponible en esta versión de Android")
            true // En versiones anteriores, consideramos que no hay optimización
        }
    }

    private fun isOverlayPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun openOverlayPermissionSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        }
    }

    private fun openAccessibilitySettings() {
        try {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        } catch (_: Exception) {
        }
    }

    private fun isFloatingBallAccessibilityEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        val cn = ComponentName(packageName, FloatingBallAccessibilityService::class.java.name)
        val id = cn.flattenToString()
        return flat != null && flat.contains(id)
    }

    private fun setFloatingBallEnabledTrue() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.floating_ball_enabled", true).apply()
        } catch (_: Exception) {
        }
    }

    private fun setFloatingBallEnabledFalse() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.floating_ball_enabled", false).apply()
        } catch (_: Exception) {
        }
    }

    private fun startFloatingBallService(action: String) {
        val i = Intent(this, FloatingBallService::class.java).setAction(action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i) else startService(i)
    }

    private fun stopFloatingBallService() {
        try {
            stopService(Intent(this, FloatingBallService::class.java))
        } catch (_: Exception) {
        }
    }
    
}
