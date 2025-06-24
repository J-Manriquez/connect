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
    private lateinit var emisorChannel: MethodChannel
    private lateinit var appListChannel: MethodChannel
    private lateinit var receptorChannel: MethodChannel
    private lateinit var deviceFinderChannel: MethodChannel // ✅ NUEVO CANAL
    private lateinit var appListService: AppListService
    private lateinit var localNotificationManager: LocalNotificationManager
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
        deviceFinderManager = DeviceFinderManager(this) // ✅ NUEVO SERVICIO

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
                        val autoOpenEnabled = call.argument<Boolean>("autoOpenEnabled") ?: false
                        
                        localNotificationManager.showNotification(
                            title, body, packageName, appName, notificationId,
                            soundEnabled, vibrationEnabled, autoOpenEnabled
                        )
                        result.success(true)
                        Log.d("MainActivity", "Notificación RECEPTOR mostrada: $title")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error al mostrar notificación RECEPTOR", e)
                        result.error("ERROR", "Error al mostrar notificación: ${e.message}", null)
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
    
    // ✅ Mejorar el método para manejar auto-apertura
    private fun handleAutoOpenNotification(intent: Intent) {
        if (intent?.action == LocalNotificationManager.NOTIFICATION_ACTION_AUTO_OPEN) {
            Log.d("MainActivity", "Configurando flags para mostrar sobre pantalla bloqueada")
            try {
                // ✅ SOLUCIÓN: Configurar flags para encender pantalla y mostrar sobre bloqueo
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    setShowWhenLocked(true)
                    setTurnScreenOn(true)
                } else {
                    window.addFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    )
                }
                
                // ✅ Mantener pantalla encendida temporalmente
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                
                // ✅ CORRECCIÓN: Traer la actividad al frente usando ActivityManager
                // 1. Obtener el servicio ActivityManager del sistema.
                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                // 2. Llamar a moveTaskToFront. 'this.taskId' obtiene el ID de la tarea de esta actividad.
                activityManager.moveTaskToFront(this.taskId, 0)
                
                Log.d("MainActivity", "Flags de ventana configurados exitosamente")
            } catch (e: Exception) {
                Log.e("MainActivity", "Error configurando flags de ventana", e)
            }
        }

        val notificationId = intent.getStringExtra(LocalNotificationManager.EXTRA_NOTIFICATION_DATA)
        val title = intent.getStringExtra("title")
        val body = intent.getStringExtra("body")
        val packageName = intent.getStringExtra("packageName")
        val appName = intent.getStringExtra("appName")
        
        if (notificationId != null) {
            val notificationData = mapOf(
                "notificationId" to notificationId,
                "title" to (title ?: ""),
                "body" to (body ?: ""),
                "packageName" to (packageName ?: ""),
                "appName" to (appName ?: ""),
                "autoOpen" to true,
                "isAutoOpened" to true
            )
            
            // ✅ Usar Handler para asegurar que Flutter esté listo
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    receptorChannel.invokeMethod("onNotificationAutoOpened", notificationData)
                    Log.d("MainActivity", "Notificación RECEPTOR auto-abierta, datos enviados a Flutter")
                } catch (e: Exception) {
                    Log.e("MainActivity", "Error enviando datos a Flutter", e)
                }
            }, 500) // Esperar 500ms para que Flutter esté completamente listo
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
