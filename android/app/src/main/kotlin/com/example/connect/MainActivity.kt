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
import android.view.WindowManager // ✅ Agregar import
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.content.Context
import android.app.ActivityManager



class MainActivity: FlutterActivity() {
    // CANALES SEPARADOS PARA EMISOR Y RECEPTOR
    private val EMISOR_CHANNEL = "com.example.connect/notifications" // Para NotificationListener (EMISOR)
    private val APP_LIST_CHANNEL = "com.example.connect/app_list"
    private val RECEPTOR_CHANNEL = "com.example.connect/local_notifications" // Para LocalNotificationManager (RECEPTOR)
    private val DEVICE_FINDER_CHANNEL = "com.example.connect/device_finder" // ✅ NUEVO CANAL
    private val SOUND_CHANNEL = "com.example.connect/notification_sound" // ✅ CANAL PARA SONIDOS PERSONALIZADOS
    private lateinit var emisorChannel: MethodChannel
    private lateinit var appListChannel: MethodChannel
    private lateinit var receptorChannel: MethodChannel
    private lateinit var deviceFinderChannel: MethodChannel // ✅ NUEVO CANAL
    internal lateinit var soundChannel: MethodChannel // ✅ CANAL PARA SONIDOS PERSONALIZADOS
    private lateinit var appListService: AppListService
    private lateinit var localNotificationManager: LocalNotificationManager
    private lateinit var vibrationManager: VibrationManager
    private lateinit var deviceFinderManager: DeviceFinderManager // ✅ NUEVO SERVICIO

    companion object {
        var instance: MainActivity? = null
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        instance = this
        
        // Inicializar servicios
        appListService = AppListService(this)
        localNotificationManager = LocalNotificationManager(this)
        vibrationManager = VibrationManager(this)
        deviceFinderManager = DeviceFinderManager(this) // ✅ INICIALIZAR SERVICIO

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
                        val notificationId = call.argument<String>("notificationId") ?: ""
                        val soundEnabled = call.argument<Boolean>("soundEnabled") ?: true
                        val vibrationEnabled = call.argument<Boolean>("vibrationEnabled") ?: true
                        val customVibrationPattern = call.argument<List<Long>>("customVibrationPattern")
                        // ✅ OBTENER LOS NUEVOS PARÁMETROS SEPARADOS
                        val screenWakeEnabled = call.argument<Boolean>("screenWakeEnabled") ?: false
                        val autoOpenEnabled = call.argument<Boolean>("autoOpenEnabled") ?: false
                        
                        // ✅ ACTUALIZAR CONFIGURACIÓN EN TIEMPO REAL
                        localNotificationManager.updateSettings(screenWakeEnabled, autoOpenEnabled, soundEnabled)
                        
                        localNotificationManager.showNotification(
                            title, body, packageName, appName, notificationId,
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
                        val screenWakeEnabled = call.argument<Boolean>("screenWakeEnabled") ?: false
                        val autoOpenEnabled = call.argument<Boolean>("autoOpenEnabled") ?: false
                        val soundEnabled = call.argument<Boolean>("soundEnabled") ?: true
                        
                        // ✅ ACTUALIZAR CONFIGURACIÓN EN TIEMPO REAL SIN MOSTRAR NOTIFICACIÓN
                        localNotificationManager.updateSettings(
                            screenWakeEnabled = screenWakeEnabled,
                            autoOpenEnabled = autoOpenEnabled,
                            soundEnabled = soundEnabled
                        )
                        
                        result.success(true)
                        Log.d("MainActivity", "Configuración de notificaciones actualizada: screenWake=$screenWakeEnabled, autoOpen=$autoOpenEnabled, sound=$soundEnabled")
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
        
        // Verificar si se debe navegar a una pantalla específica
        handleNavigationIntent(intent)
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
            // Enviar el comando de navegación a Flutter
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    deviceFinderChannel.invokeMethod("navigateToRoute", route)
                } catch (e: Exception) {
                    Log.e("MainActivity", "Error al navegar a $route", e)
                }
            }, 1000) // Esperar 1 segundo para que Flutter esté listo
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        
        // ✅ MANEJO ESPECÍFICO PARA ANDROID 8: Intent de activación de pantalla
        if (intent.action == "WAKE_SCREEN_ACTION" && intent.getBooleanExtra("wakeScreenOnly", false)) {
            Log.d("MainActivity", "Intent de activación de pantalla recibido (Android 8.0)")
            
            val screenWakeEnabled = intent.getBooleanExtra("screenWakeEnabled", false)
            if (screenWakeEnabled && Build.VERSION.SDK_INT == Build.VERSION_CODES.O) {
                Log.d("MainActivity", "Aplicando configuración de pantalla para Android 8.0")
                
                // Aplicar configuración específica para Android 8.0
                try {
                    // Usar tanto métodos nuevos como flags tradicionales
                    setShowWhenLocked(true)
                    setTurnScreenOn(true)
                    
                    window.addFlags(
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    )
                    
                    Log.d("MainActivity", "Configuración de pantalla aplicada exitosamente (Android 8.0)")
                    
                    // Limpiar flags después de un tiempo
                    Handler(Looper.getMainLooper()).postDelayed({
                        try {
                            setShowWhenLocked(false)
                            setTurnScreenOn(false)
                            window.clearFlags(
                                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                            )
                            Log.d("MainActivity", "Flags de pantalla limpiados (Android 8.0)")
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Error limpiando flags de pantalla", e)
                        }
                    }, 3000)
                    
                } catch (e: Exception) {
                    Log.e("MainActivity", "Error aplicando configuración de pantalla Android 8.0", e)
                }
            }
            
            // No procesar como notificación normal
            return
        }
        
        handleNotificationIntent(intent)
    }
    
    override fun onResume() {
        super.onResume()
        handleNotificationIntent(intent)
    }
    
    private fun handleNotificationIntent(intent: Intent?) {
        when (intent?.action) {
            LocalNotificationManager.NOTIFICATION_ACTION_OPEN -> {
                // Manejo normal cuando se toca la notificación
                handleNormalNotificationTap(intent)
            }
            LocalNotificationManager.NOTIFICATION_ACTION_AUTO_OPEN -> {
                // ✅ Manejo especial para auto-apertura
                handleAutoOpenNotification(intent)
            }
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
            val notificationData = mapOf(
                "notificationId" to notificationId,
                "title" to (title ?: ""),
                "body" to (body ?: ""),
                "packageName" to (packageName ?: ""),
                "appName" to (appName ?: ""),
                "autoOpen" to autoOpen
            )
            
            receptorChannel.invokeMethod("onNotificationTapped", notificationData)
            Log.d("MainActivity", "Notificación RECEPTOR tocada, enviando datos a Flutter")
        }
    }
    
    // ✅ CORREGIDO: Método handleAutoOpenNotification que respeta configuración
    private fun handleAutoOpenNotification(intent: Intent) {
        if (intent?.action == LocalNotificationManager.NOTIFICATION_ACTION_AUTO_OPEN) {
            Log.d("MainActivity", "Procesando auto-apertura de notificación")
            
            val fromBackground = intent.getBooleanExtra("fromBackground", false)
            val timestamp = intent.getLongExtra("timestamp", 0)
            val screenWakeEnabled = intent.getBooleanExtra("screenWakeEnabled", false)
            
            try {
                // ✅ CONFIGURACIÓN ULTRA CONSERVADORA: Solo configurar flags si screenWakeEnabled está activo
                if (screenWakeEnabled) {
                    Log.d("MainActivity", "Configurando flags de pantalla - screenWakeEnabled: true")
                    Log.d("MainActivity", "Android API Level: ${Build.VERSION.SDK_INT}")
                    
                    when {
                        // Android 8.1+ (API 27+) - Usar métodos nuevos
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1 -> {
                            Log.d("MainActivity", "Usando métodos para Android 8.1+ (API 27+)")
                            setShowWhenLocked(true)
                            setTurnScreenOn(true)
                            
                            // Para Android 10+ agregar flag adicional
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                        }
                        // Android 8.0 (API 26) - Manejo específico
                        Build.VERSION.SDK_INT == Build.VERSION_CODES.O -> {
                            Log.d("MainActivity", "Usando métodos específicos para Android 8.0 (API 26)")
                            // En Android 8.0, usar tanto métodos nuevos como flags por compatibilidad
                            try {
                                setShowWhenLocked(true)
                                setTurnScreenOn(true)
                            } catch (e: Exception) {
                                Log.w("MainActivity", "Error con métodos nuevos en Android 8.0, usando flags: $e")
                            }
                            
                            // También usar flags como respaldo
                            window.addFlags(
                                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                            )
                        }
                        // Android 7.1 y anteriores - Usar flags tradicionales
                        else -> {
                            Log.d("MainActivity", "Usando flags tradicionales para Android < 8.0")
                            window.addFlags(
                                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                            )
                        }
                    }
                    
                    // ✅ MEJORAR: Manejo específico para segundo plano SOLO si screenWakeEnabled
                    if (fromBackground) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        
                        // ✅ CORREGIR: Mover tarea al frente de forma segura
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            try {
                                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                                activityManager.moveTaskToFront(taskId, ActivityManager.MOVE_TASK_WITH_HOME)
                                Log.d("MainActivity", "Tarea movida al frente exitosamente")
                            } catch (e: Exception) {
                                Log.w("MainActivity", "No se pudo mover tarea al frente: $e")
                            }
                        }
                    }
                } else {
                    // ✅ AUTO-OPEN SIN ACTIVAR PANTALLA: Solo navegar sin flags de pantalla
                    Log.d("MainActivity", "screenWakeEnabled: false - Auto-open sin activar pantalla")
                    
                    // Solo mover la tarea al frente SIN activar la pantalla
                    if (fromBackground) {
                        // ✅ NAVEGACIÓN SILENCIOSA: Mover al frente sin activar pantalla
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            try {
                                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                                // Usar flag que NO active la pantalla
                                activityManager.moveTaskToFront(taskId, 0) // Sin flags adicionales
                                Log.d("MainActivity", "Tarea movida al frente SILENCIOSAMENTE (sin activar pantalla)")
                            } catch (e: Exception) {
                                Log.w("MainActivity", "No se pudo mover tarea al frente silenciosamente: $e")
                            }
                        }
                    }
                }
                
                Log.d("MainActivity", "Auto-open procesado - Desde segundo plano: $fromBackground, ScreenWake: $screenWakeEnabled")
            } catch (e: Exception) {
                Log.e("MainActivity", "Error configurando auto-open", e)
            }
        }

        val notificationId = intent.getStringExtra(LocalNotificationManager.EXTRA_NOTIFICATION_DATA)
        val title = intent.getStringExtra("title")
        val body = intent.getStringExtra("body")
        val packageName = intent.getStringExtra("packageName")
        val appName = intent.getStringExtra("appName")
        val fromBackground = intent.getBooleanExtra("fromBackground", false)
        val timestamp = intent.getLongExtra("timestamp", 0)
        
        if (notificationId != null) {
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
            
            // ✅ MEJORAR: Delay adaptativo según el origen
            val delay = if (fromBackground) 1500L else 750L
            
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    receptorChannel.invokeMethod("onNotificationAutoOpened", notificationData)
                    Log.d("MainActivity", "Datos enviados a Flutter - Delay: ${delay}ms")
                } catch (e: Exception) {
                    Log.e("MainActivity", "Error enviando datos a Flutter", e)
                }
            }, delay)
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
    
}
