package com.example.connect

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import android.util.Log

class LocalNotificationManager(private val context: Context) {
    
    companion object {
        private const val CHANNEL_ID = "receptor_notifications_channel"
        private const val CHANNEL_NAME = "Notificaciones del Receptor"
        private const val CHANNEL_DESCRIPTION = "Canal para mostrar notificaciones recibidas en el receptor"
        const val NOTIFICATION_ACTION_OPEN = "OPEN_NOTIFICATION"
        const val EXTRA_NOTIFICATION_DATA = "notification_data"
        
        // Usar un ID fijo para que las notificaciones se reemplacen en lugar de acumularse
        private const val FIXED_NOTIFICATION_ID = 1001
    }
    
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    
    init {
        createNotificationChannel()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = CHANNEL_DESCRIPTION
                enableVibration(true)
                enableLights(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            notificationManager.createNotificationChannel(channel)
            Log.d("LocalNotificationManager", "Canal de notificaciones creado")
        }
    }
    
    fun showNotification(
        title: String,
        body: String,
        packageName: String,
        appName: String,
        notificationId: String,
        soundEnabled: Boolean,
        vibrationEnabled: Boolean,
        autoOpenEnabled: Boolean
    ) {
        try {
            // Intent para abrir la aplicación
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = NOTIFICATION_ACTION_OPEN
                putExtra(EXTRA_NOTIFICATION_DATA, notificationId)
                putExtra("title", title)
                putExtra("body", body)
                putExtra("packageName", packageName)
                putExtra("appName", appName)
                putExtra("autoOpen", autoOpenEnabled)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            
            val pendingLaunchIntent = PendingIntent.getActivity(
                context,
                FIXED_NOTIFICATION_ID, // Usar ID fijo en lugar de notificationId.hashCode()
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Construir la notificación
            val notificationBuilder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setContentIntent(pendingLaunchIntent)
                .setAutoCancel(true)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setOnlyAlertOnce(true) // Solo alertar una vez, no en actualizaciones
                .setGroup("receptor_notifications") // Agrupar notificaciones
                .setGroupSummary(false) // No es un resumen de grupo
            
            // Configurar sonido y vibración según las preferencias
            if (soundEnabled) {
                notificationBuilder.setDefaults(NotificationCompat.DEFAULT_SOUND)
            }
            
            if (vibrationEnabled) {
                notificationBuilder.setVibrate(longArrayOf(0, 500, 500, 500))
            }
            
            // Mostrar la notificación usando un ID fijo para que se reemplace
            notificationManager.notify(FIXED_NOTIFICATION_ID, notificationBuilder.build())
            Log.d("LocalNotificationManager", "Notificación mostrada: $title")
            
        } catch (e: Exception) {
            Log.e("LocalNotificationManager", "Error al mostrar notificación", e)
        }
    }
    
    fun cancelNotification(notificationId: String) {
        // Cancelar usando el ID fijo
        notificationManager.cancel(FIXED_NOTIFICATION_ID)
        Log.d("LocalNotificationManager", "Notificación cancelada: $notificationId")
    }
    
    // Nuevo método para cancelar todas las notificaciones del receptor
    fun cancelAllNotifications() {
        notificationManager.cancel(FIXED_NOTIFICATION_ID)
        Log.d("LocalNotificationManager", "Todas las notificaciones del receptor canceladas")
    }
}