package com.example.connect

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Build
import androidx.core.app.NotificationCompat
import android.util.Log
import android.app.ActivityManager
import io.flutter.embedding.android.FlutterActivity
import android.view.WindowManager

class LocalNotificationManager(private val context: Context) {
    
    companion object {
        private const val CHANNEL_ID = "receptor_notifications_channel"
        private const val CHANNEL_NAME = "Notificaciones del Receptor"
        private const val CHANNEL_DESCRIPTION = "Canal para mostrar notificaciones recibidas en el receptor"
        const val NOTIFICATION_ACTION_OPEN = "OPEN_NOTIFICATION"
        const val NOTIFICATION_ACTION_AUTO_OPEN = "AUTO_OPEN_NOTIFICATION"
        const val EXTRA_NOTIFICATION_DATA = "notification_data"
        
        // ✅ Hacer el conjunto público para acceso desde NotificationDeleteReceiver
        private val cancelledNotifications = mutableSetOf<String>()
        
        // ✅ Método público para agregar notificaciones canceladas
        fun addToCancelledNotifications(notificationId: String) {
            cancelledNotifications.add(notificationId)
            Log.d("LocalNotificationManager", "Notificación agregada a canceladas: $notificationId")
        }
        
        // ✅ Método público para verificar si una notificación está cancelada
        fun isNotificationCancelled(notificationId: String): Boolean {
            return cancelledNotifications.contains(notificationId)
        }
        
        // ✅ Método público para limpiar notificaciones canceladas
        fun clearCancelledNotifications() {
            cancelledNotifications.clear()
            Log.d("LocalNotificationManager", "Lista de notificaciones canceladas limpiada")
        }
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
        // ✅ NUEVOS PARÁMETROS SEPARADOS
        screenWakeEnabled: Boolean,
        autoOpenEnabled: Boolean
    ) {
        try {
            // Verificar si esta notificación fue cancelada por el usuario
            if (cancelledNotifications.contains(notificationId)) {
                Log.d("LocalNotificationManager", "Notificación previamente cancelada, no se muestra: $notificationId")
                return
            }
            
            // ✅ MANEJAR ACTIVACIÓN DE PANTALLA SEPARADAMENTE
            if (screenWakeEnabled) {
                wakeUpScreen()
                
                // ✅ SOLO ABRIR APP SI AUTO-OPEN TAMBIÉN ESTÁ HABILITADO
                if (autoOpenEnabled) {
                    openAppAutomatically(title, body, packageName, appName, notificationId)
                }
            }
            
            // Intent para abrir la aplicación (cuando se toca la notificación)
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
            
            // Usar el hash del notificationId para generar un ID único
            val uniqueNotificationId = notificationId.hashCode()
            
            val pendingLaunchIntent = PendingIntent.getActivity(
                context,
                uniqueNotificationId,
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
                .setDeleteIntent(createDeleteIntent(notificationId))
            
            // Configurar sonido y vibración según las preferencias
            if (soundEnabled) {
                notificationBuilder.setDefaults(NotificationCompat.DEFAULT_SOUND)
            }
            
            if (vibrationEnabled) {
                notificationBuilder.setVibrate(longArrayOf(0, 500, 500, 500))
            }
            
            // Mostrar la notificación usando el ID único
            notificationManager.notify(uniqueNotificationId, notificationBuilder.build())
            Log.d("LocalNotificationManager", "Notificación mostrada: $title (ID: $uniqueNotificationId)")
            
        } catch (e: Exception) {
            Log.e("LocalNotificationManager", "Error al mostrar notificación", e)
        }
    }
    
    // ✅ Nuevo método para abrir la app automáticamente
    private fun openAppAutomatically(
        title: String,
        body: String,
        packageName: String,
        appName: String,
        notificationId: String 
    ) {
        try {
            Log.d("LocalNotificationManager", "Intentando abrir app automáticamente")
            
            // ✅ SOLUCIÓN: Verificar si la app está en primer plano
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val runningTasks = activityManager.getRunningTasks(1)
            val isAppInForeground = runningTasks.isNotEmpty() && 
                runningTasks[0].topActivity?.packageName == context.packageName
            
            val intent = Intent(context, MainActivity::class.java).apply {
                action = NOTIFICATION_ACTION_AUTO_OPEN
                
                // ✅ SOLUCIÓN: Flags diferentes según el estado de la app
                flags = if (isAppInForeground) {
                    // Si está en primer plano, solo traer al frente
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
                } else {
                    // Si está en segundo plano, forzar al frente
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION // ✅ Evitar animaciones para apertura más rápida
                }
                
                putExtra(EXTRA_NOTIFICATION_DATA, notificationId)
                putExtra("title", title)
                putExtra("body", body)
                putExtra("packageName", packageName)
                putExtra("appName", appName)
                putExtra("autoOpen", true)
                putExtra("fromBackground", !isAppInForeground) // ✅ Indicar si viene del segundo plano
            }
            
            // ✅ SOLUCIÓN: Usar startActivity con manejo de excepciones
            try {
                context.startActivity(intent)
                Log.d("LocalNotificationManager", "App abierta automáticamente - En primer plano: $isAppInForeground")
            } catch (e: Exception) {
                Log.e("LocalNotificationManager", "Error al abrir con startActivity, intentando con PendingIntent", e)
                
                // ✅ FALLBACK: Si startActivity falla, usar PendingIntent
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    notificationId.hashCode(),
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                try {
                    pendingIntent.send()
                    Log.d("LocalNotificationManager", "App abierta usando PendingIntent como fallback")
                } catch (pendingException: Exception) {
                    Log.e("LocalNotificationManager", "Error con PendingIntent fallback", pendingException)
                }
            }
            
        } catch (e: Exception) {
            Log.e("LocalNotificationManager", "Error general al abrir app automáticamente", e)
        }
    }
    
    private fun createDeleteIntent(notificationId: String): PendingIntent {
        val deleteIntent = Intent(context, NotificationDeleteReceiver::class.java).apply {
            putExtra("notification_id", notificationId)
        }
        return PendingIntent.getBroadcast(
            context,
            notificationId.hashCode(),
            deleteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
    
    fun cancelNotification(notificationId: String) {
        val uniqueNotificationId = notificationId.hashCode()
        notificationManager.cancel(uniqueNotificationId)
        // Marcar como cancelada por el usuario
        cancelledNotifications.add(notificationId)
        Log.d("LocalNotificationManager", "Notificación cancelada: $notificationId")
    }
    
    fun cancelAllNotifications() {
        notificationManager.cancelAll()
        Log.d("LocalNotificationManager", "Todas las notificaciones canceladas")
    }
    
    // Método para limpiar notificaciones canceladas (llamar periódicamente)
    fun clearCancelledNotifications() {
        cancelledNotifications.clear()
    }
    
    // ✅ MÉTODO FALTANTE: Activar la pantalla
    private fun wakeUpScreen() {
        try {
            Log.d("LocalNotificationManager", "Activando pantalla...")
            
            // Obtener el PowerManager para activar la pantalla
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            
            // Verificar si la pantalla ya está encendida
            val isScreenOn = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                powerManager.isInteractive
            } else {
                @Suppress("DEPRECATION")
                powerManager.isScreenOn
            }
            
            if (!isScreenOn) {
                // Crear un WakeLock para activar la pantalla
                val wakeLock = powerManager.newWakeLock(
                    android.os.PowerManager.SCREEN_BRIGHT_WAKE_LOCK or 
                    android.os.PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    android.os.PowerManager.ON_AFTER_RELEASE,
                    "ConnectApp:NotificationWakeUp"
                )
                
                // Activar la pantalla por 3 segundos
                wakeLock.acquire(3000)
                
                // Liberar el WakeLock inmediatamente (la pantalla permanecerá encendida)
                if (wakeLock.isHeld) {
                    wakeLock.release()
                }
                
                Log.d("LocalNotificationManager", "Pantalla activada exitosamente")
            } else {
                Log.d("LocalNotificationManager", "La pantalla ya estaba encendida")
            }
            
        } catch (e: Exception) {
            Log.e("LocalNotificationManager", "Error al activar la pantalla", e)
        }
    }
}