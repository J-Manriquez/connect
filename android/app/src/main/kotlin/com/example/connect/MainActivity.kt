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

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.connect/notifications"
    private lateinit var channel: MethodChannel

    // Puedes mantener esta instancia si la necesitas en otras partes de tu app nativa
    companion object {
        var instance: MainActivity? = null
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        instance = this

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        // Asignar el MethodChannel al servicio tan pronto como se crea
        NotificationListener.methodChannel = channel
        Log.d("MainActivity", "MethodChannel assigned to NotificationListener")

        // Iniciar automáticamente el servicio si el permiso está concedido
        if (isNotificationServiceEnabled()) {
            val serviceIntent = Intent(this, NotificationListener::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
                Log.d("MainActivity", "Iniciando servicio automáticamente al arrancar la app")
            } else {
                startService(serviceIntent)
            }
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startNotificationService" -> {
                    if (!isNotificationServiceEnabled()) {
                        // Si el servicio no está habilitado, abrir la configuración
                        openNotificationListenerSettings()
                        // No podemos confirmar que el servicio se inició, solo que se abrió la configuración
                        result.success(false)
                        Log.d("MainActivity", "Servicio no habilitado, abriendo configuración.")
                    } else {
                        // El servicio está habilitado, intentar iniciarlo explícitamente
                        val serviceIntent = Intent(this, NotificationListener::class.java)
                        // Usar startForegroundService para servicios que deben ejecutarse continuamente
                        // Requiere Android O (API 26) o superior
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                            Log.d("MainActivity", "Llamando a startForegroundService.")
                        } else {
                            startService(serviceIntent)
                            Log.d("MainActivity", "Llamando a startService.")
                        }
                        // El flag isRunning se actualizará en onListenerConnected
                        result.success(true) // Indicar que se envió la intención de inicio
                        Log.d("MainActivity", "Intent para iniciar NotificationListener enviado.")
                    }
                }
                "stopNotificationService" -> {
                    val serviceIntent = Intent(this, NotificationListener::class.java)
                    stopService(serviceIntent)
                    // El flag isRunning se actualizará en onListenerDisconnected o onDestroy
                    result.success(true) // Indicar que se envió la intención de detener
                    Log.d("MainActivity", "Intent para detener NotificationListener enviado.")
                }
                "isServiceRunning" -> {
                    // Devolver el estado actual del flag isRunning del servicio
                    result.success(NotificationListener.isRunning)
                    Log.d("MainActivity", "¿NotificationListener está corriendo? ${NotificationListener.isRunning}")
                }
                "isNotificationServiceEnabled" -> {
                    // Devolver si el permiso de escucha de notificaciones está concedido
                    result.success(isNotificationServiceEnabled())
                    Log.d("MainActivity", "¿Permiso de escucha de notificaciones concedido? ${isNotificationServiceEnabled()}")
                }
                 "openNotificationSettings" -> {
                    // Abrir la pantalla de configuración de escucha de notificaciones
                    openNotificationListenerSettings()
                    result.success(null) // No esperamos un resultado de esta acción
                    Log.d("MainActivity", "Abriendo configuración de escucha de notificaciones.")
                }
                // Se eliminan los manejadores getInstalledApps y updateEnabledApps
                else -> {
                    result.notImplemented()
                    Log.w("MainActivity", "Llamada a método no implementado: ${call.method}")
                }
            }
        }
    }

    // Helper para verificar si el permiso de escucha de notificaciones está concedido
    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        // Verificar si el nombre de nuestro componente de servicio está en la lista de listeners habilitados
        val cn = ComponentName(pkgName, NotificationListener::class.java.name)
        val enabled = flat != null && flat.contains(cn.flattenToString())
        return enabled
    }

    // Helper para abrir la pantalla de configuración de escucha de notificaciones
    private fun openNotificationListenerSettings() {
        try {
            val intent = Intent()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                intent.action = Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS
            } else {
                // Acción para versiones anteriores a Android O
                intent.action = "android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error al abrir configuración de notificaciones", e)
        }
    }

    // Se elimina la función getInstalledApplications
}
