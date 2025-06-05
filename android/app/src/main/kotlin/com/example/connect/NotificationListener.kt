package com.example.connect

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import android.content.pm.ServiceInfo

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
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isRunning = false
        Log.d("NotificationListener", "Servicio de escucha de notificaciones desconectado")
        // Notificar a Flutter que el servicio está desconectado
        methodChannel?.invokeMethod("serviceDisconnected", null)
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
        Log.d("NotificationListener", "Service destroyed")
    }
}