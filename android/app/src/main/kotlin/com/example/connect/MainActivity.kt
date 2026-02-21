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



class MainActivity: FlutterActivity() {
    // CANALES SEPARADOS PARA EMISOR Y RECEPTOR
    private val EMISOR_CHANNEL = "com.example.connect/notifications" // Para NotificationListener (EMISOR)
    private val APP_LIST_CHANNEL = "com.example.connect/app_list"
    private val RECEPTOR_CHANNEL = "com.example.connect/local_notifications" // Para LocalNotificationManager (RECEPTOR)
    private val DEVICE_FINDER_CHANNEL = "com.example.connect/device_finder" // ✅ NUEVO CANAL
    private val SOUND_CHANNEL = "com.example.connect/notification_sound" // ✅ CANAL PARA SONIDOS PERSONALIZADOS
    private val SOUND_EVENTS_CHANNEL = "com.example.connect/sound_events"
    private val BATTERY_CHANNEL = "com.example.connect/battery" // ✅ CANAL PARA OPTIMIZACIÓN DE BATERÍA
    private val BLE_CHANNEL = "com.example.connect/ble"
    private lateinit var emisorChannel: MethodChannel
    private lateinit var appListChannel: MethodChannel
    private lateinit var receptorChannel: MethodChannel
    private lateinit var deviceFinderChannel: MethodChannel // ✅ NUEVO CANAL
    internal lateinit var soundChannel: MethodChannel // ✅ CANAL PARA SONIDOS PERSONALIZADOS
    private lateinit var soundEventsChannel: EventChannel
    private var soundEventsSink: EventChannel.EventSink? = null
    private lateinit var batteryChannel: MethodChannel // ✅ CANAL PARA OPTIMIZACIÓN DE BATERÍA
    private lateinit var bleChannel: MethodChannel
    private lateinit var appListService: AppListService
    private lateinit var localNotificationManager: LocalNotificationManager
    private lateinit var vibrationManager: VibrationManager
    private lateinit var deviceFinderManager: DeviceFinderManager // ✅ NUEVO SERVICIO
    private var bleGattServerManager: BleGattServerManager? = null
    private var bleGattClientManager: BleGattClientManager? = null

    private var btAdapter: BluetoothAdapter? = null
    private var btDiscoveryReceiver: BroadcastReceiver? = null
    private var btDiscoveryRegistered: Boolean = false

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
        
        // ✅ CANAL PARA OPTIMIZACIÓN DE BATERÍA
        batteryChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
        bleChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLE_CHANNEL)
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

        if (handleMediaLaunchIntent(intent)) return
        
        // ✅ MANEJO ESPECÍFICO PARA DEVICE_FINDER_ACTION
        if (intent.action == "DEVICE_FINDER_ACTION") {
            Log.d("MainActivity", "Intent de Device Finder recibido")
            handleNavigationIntent(intent)
            return
        }
        
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
        if (handleMediaLaunchIntent(intent)) return
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
                                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                            )
                        }
                        // Android 7.1 y anteriores - Usar flags tradicionales
                        else -> {
                            Log.d("MainActivity", "Usando flags tradicionales para Android < 8.0")
                            window.addFlags(
                                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                            )
                        }
                    }
                    
                    // ✅ MEJORAR: Manejo específico para segundo plano SOLO si screenWakeEnabled
                    if (fromBackground) {
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
    
}
