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
import android.os.Handler
import android.os.Looper

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
            // ✅ CONFIGURACIÓN ULTRA CONSERVADORA: Evitar activación automática de pantalla
            val importance = NotificationManager.IMPORTANCE_MIN // Ultra conservador para todos
            
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                importance
            ).apply {
                description = CHANNEL_DESCRIPTION
                
                // Configuración ultra conservadora que NO activa pantalla NUNCA
                enableVibration(false) // Sin vibración del canal
                enableLights(false)    // Sin luces del canal
                lockscreenVisibility = NotificationCompat.VISIBILITY_SECRET // Ocultar en pantalla de bloqueo
                setSound(null, null)   // Sin sonido del canal
                setBypassDnd(false)    // No omitir modo no molestar
                setShowBadge(false)    // Sin badge para evitar cualquier activación
                
                // Configuraciones adicionales para Android 8+
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // Evitar cualquier comportamiento que pueda activar la pantalla
                    group = null // Sin grupo
                }
                
                Log.d("LocalNotificationManager", "Canal configurado ULTRA conservador - Importance: IMPORTANCE_MIN")
            }
            
            notificationManager.createNotificationChannel(channel)
            Log.d("LocalNotificationManager", "Canal creado - Configuración ultra conservadora")
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
        screenWakeEnabled: Boolean,
        autoOpenEnabled: Boolean
    ) {
        try {
            // ✅ VERIFICAR si la notificación fue cancelada previamente
        if (isNotificationCancelled(notificationId)) {
            Log.d("LocalNotificationManager", "Notificación previamente cancelada, no se muestra: $notificationId")
            return
        }
        
        Log.d("LocalNotificationManager", "=== CONFIGURACIÓN DETALLADA RECIBIDA ===")
        Log.d("LocalNotificationManager", "Title: $title")
        Log.d("LocalNotificationManager", "Body: $body")
        Log.d("LocalNotificationManager", "NotificationId: $notificationId")
        Log.d("LocalNotificationManager", "screenWakeEnabled: $screenWakeEnabled")
        Log.d("LocalNotificationManager", "autoOpenEnabled: $autoOpenEnabled")
        Log.d("LocalNotificationManager", "soundEnabled: $soundEnabled")
        Log.d("LocalNotificationManager", "vibrationEnabled: $vibrationEnabled")
        Log.d("LocalNotificationManager", "Android API Level: ${Build.VERSION.SDK_INT}")
        Log.d("LocalNotificationManager", "=================================================")
            
            // ✅ TÉRMINO MEDIO PARA ANDROID 8: Activación de pantalla más conservadora
            if (screenWakeEnabled) {
                Log.d("LocalNotificationManager", "screenWakeEnabled: true - Procediendo a activar pantalla")
                wakeUpScreenConservative()
                Log.d("LocalNotificationManager", "Pantalla activada de forma conservadora")
            } else {
                Log.d("LocalNotificationManager", "screenWakeEnabled: false - Pantalla NO será activada")
            }
            
            // ✅ AutoOpen independiente de screenWakeEnabled
            if (autoOpenEnabled) {
                // Delay mínimo para auto-open, independiente del wake screen
                val delay = 200L
                Handler(Looper.getMainLooper()).postDelayed({
                    openAppAutomatically(title, body, packageName, appName, notificationId, screenWakeEnabled)
                }, delay)
                Log.d("LocalNotificationManager", "AutoOpen habilitado independientemente")
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
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setContentIntent(pendingLaunchIntent)
                .setAutoCancel(true)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setDeleteIntent(createDeleteIntent(notificationId))
            
            // ✅ CONFIGURACIÓN ULTRA CONSERVADORA: Evitar activación automática de pantalla
            if (screenWakeEnabled) {
                // Usar PRIORITY_DEFAULT incluso cuando está habilitado para evitar activación automática
                Log.d("LocalNotificationManager", "screenWakeEnabled: true - Usando PRIORITY_DEFAULT (ultra conservador)")
                notificationBuilder.setPriority(NotificationCompat.PRIORITY_DEFAULT)
            } else {
                // Configuración ultra restrictiva cuando screenWakeEnabled es false
                Log.d("LocalNotificationManager", "screenWakeEnabled: false - Configuración ultra restrictiva")
                notificationBuilder.setPriority(NotificationCompat.PRIORITY_MIN)
                notificationBuilder.setDefaults(0) // Sin defaults
                notificationBuilder.setLights(0, 0, 0) // Sin luces
                notificationBuilder.setSound(null) // Sin sonido explícito
                notificationBuilder.setVibrate(null) // Sin vibración explícita
                
                // Configuración adicional para Android 8+
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    notificationBuilder.setChannelId(CHANNEL_ID)
                    Log.d("LocalNotificationManager", "Android 8+: Configuración ultra restrictiva aplicada")
                }
            }
            
            // ✅ CONFIGURACIONES ADICIONALES PARA EVITAR ACTIVACIÓN DE PANTALLA
            notificationBuilder.setOnlyAlertOnce(true) // Solo alertar una vez
            notificationBuilder.setLocalOnly(true) // Solo local, no sincronizar
            notificationBuilder.setVisibility(NotificationCompat.VISIBILITY_SECRET) // Ocultar contenido
            
            // Evitar flags que puedan activar la pantalla
            val currentFlags = notificationBuilder.build().flags
            Log.d("LocalNotificationManager", "Flags actuales antes de limpieza: $currentFlags")
            
            // ✅ CORREGIR: Configurar sonido y vibración según configuración
            if (Build.VERSION.SDK_INT == Build.VERSION_CODES.O && !screenWakeEnabled) {
                // ANDROID 8.0: Solo aplicar restricciones cuando screenWakeEnabled es false
                Log.d("LocalNotificationManager", "Android 8.0: screenWakeEnabled=false - Sin sonido ni vibración")
                notificationBuilder.setSound(null)
                notificationBuilder.setVibrate(null)
                notificationBuilder.setDefaults(0) // Sin ningún default
            } else {
                // Configuración normal para todos los demás casos
                if (soundEnabled) {
                    notificationBuilder.setDefaults(NotificationCompat.DEFAULT_SOUND)
                    Log.d("LocalNotificationManager", "Sonido habilitado para notificación")
                }
                
                if (vibrationEnabled) {
                    notificationBuilder.setVibrate(longArrayOf(0, 500, 500, 500))
                    Log.d("LocalNotificationManager", "Vibración habilitada para notificación")
                }
            }
            
            // Mostrar la notificación usando el ID único
            val finalNotification = notificationBuilder.build()
            notificationManager.notify(uniqueNotificationId, finalNotification)
            
            // ✅ LOGGING DETALLADO POST-CREACIÓN
            Log.d("LocalNotificationManager", "=== NOTIFICACIÓN CREADA ===")
            Log.d("LocalNotificationManager", "Notification ID único: $uniqueNotificationId")
            Log.d("LocalNotificationManager", "Priority: ${finalNotification.priority}")
            Log.d("LocalNotificationManager", "Defaults: ${finalNotification.defaults}")
            Log.d("LocalNotificationManager", "Flags: ${finalNotification.flags}")
            Log.d("LocalNotificationManager", "Channel ID: ${finalNotification.channelId}")
            Log.d("LocalNotificationManager", "Screen Wake solicitado: $screenWakeEnabled")
            Log.d("LocalNotificationManager", "Auto Open solicitado: $autoOpenEnabled")
            Log.d("LocalNotificationManager", "==============================")
            
        } catch (e: Exception) {
            Log.e("LocalNotificationManager", "Error al mostrar notificación", e)
        }
    }
    
    // ✅ TÉRMINO MEDIO: Método conservador que funciona bien en Android 8
    private fun wakeUpScreenConservative() {
        try {
            Log.d("LocalNotificationManager", "Iniciando activación conservadora de pantalla...")
            Log.d("LocalNotificationManager", "Android API Level: ${Build.VERSION.SDK_INT}")
            
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            
            // Verificar si la pantalla ya está encendida
            val isScreenOn = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                powerManager.isInteractive
            } else {
                @Suppress("DEPRECATION")
                powerManager.isScreenOn
            }
            
            Log.d("LocalNotificationManager", "Estado actual de la pantalla: ${if (isScreenOn) "ENCENDIDA" else "APAGADA"}")
            
            if (!isScreenOn) {
                Log.d("LocalNotificationManager", "Procediendo a activar la pantalla de forma conservadora...")
                
                when {
                    // Android 8.0 (API 26) - Enfoque ultra conservador solo con Intent
                    Build.VERSION.SDK_INT == Build.VERSION_CODES.O -> {
                        Log.d("LocalNotificationManager", "Aplicando enfoque ultra conservador para Android 8.0 (solo Intent)")
                        
                        try {
                            // Solo usar Intent para activar MainActivity sin wake locks
                            val intent = Intent(context, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                                       Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                       Intent.FLAG_ACTIVITY_SINGLE_TOP
                                putExtra("wakeScreenOnly", true)
                                putExtra("screenWakeEnabled", true)
                                putExtra("timestamp", System.currentTimeMillis())
                            }
                            
                            context.startActivity(intent)
                            Log.d("LocalNotificationManager", "Intent enviado para activar pantalla (Android 8.0)")
                            
                        } catch (e: Exception) {
                            Log.e("LocalNotificationManager", "Error con enfoque conservador Android 8.0", e)
                        }
                    }
                    
                    // Android 8.1+ - Enfoque estándar ultra conservador
                    else -> {
                        Log.d("LocalNotificationManager", "Aplicando configuración estándar ultra conservadora")
                        
                        try {
                            val wakeLock = powerManager.newWakeLock(
                                android.os.PowerManager.SCREEN_BRIGHT_WAKE_LOCK or 
                                android.os.PowerManager.ACQUIRE_CAUSES_WAKEUP,
                                "ConnectApp:StandardConservativeWakeUp"
                            )
                            
                            wakeLock.acquire(1500) // Solo 1.5 segundos
                            Log.d("LocalNotificationManager", "WakeLock estándar conservador adquirido por 1.5 segundos")
                            
                            // Liberar de forma segura
                            Handler(Looper.getMainLooper()).postDelayed({
                                try {
                                    if (wakeLock.isHeld) {
                                        wakeLock.release()
                                        Log.d("LocalNotificationManager", "WakeLock estándar liberado exitosamente")
                                    }
                                } catch (e: Exception) {
                                    Log.e("LocalNotificationManager", "Error al liberar WakeLock estándar", e)
                                }
                            }, 1000)
                            
                        } catch (e: Exception) {
                            Log.e("LocalNotificationManager", "Error con configuración estándar conservadora", e)
                        }
                    }
                }
                
                Log.d("LocalNotificationManager", "Proceso conservador de activación completado")
            } else {
                Log.d("LocalNotificationManager", "La pantalla ya estaba encendida - no se requiere activación")
            }
            
        } catch (e: Exception) {
            Log.e("LocalNotificationManager", "Error al activar la pantalla de forma conservadora", e)
        }
    }
    
    // ✅ MEJORAR: Método openAppAutomatically más robusto
    private fun openAppAutomatically(
        title: String,
        body: String,
        packageName: String,
        appName: String,
        notificationId: String,
        screenWakeEnabled: Boolean = false
    ) {
        try {
            Log.d("LocalNotificationManager", "Iniciando apertura automática de app")
            
            // ✅ VERIFICAR: Estado de la aplicación
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val runningTasks = activityManager.getRunningTasks(1)
            val isAppInForeground = runningTasks.isNotEmpty() && 
                runningTasks[0].topActivity?.packageName == context.packageName
            
            val intent = Intent(context, MainActivity::class.java).apply {
                action = NOTIFICATION_ACTION_AUTO_OPEN
                
                // ✅ CORREGIR: Flags optimizados según el estado
                flags = if (isAppInForeground) {
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
                } else {
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                }
                
                putExtra(EXTRA_NOTIFICATION_DATA, notificationId)
                putExtra("title", title)
                putExtra("body", body)
                putExtra("packageName", packageName)
                putExtra("appName", appName)
                putExtra("autoOpen", true)
                putExtra("fromBackground", !isAppInForeground)
                putExtra("timestamp", System.currentTimeMillis()) // ✅ AGREGAR timestamp
                putExtra("screenWakeEnabled", screenWakeEnabled) // ✅ AGREGAR configuración
            }
            
            // ✅ MEJORAR: Manejo de errores más robusto
            try {
                context.startActivity(intent)
                Log.d("LocalNotificationManager", "App abierta automáticamente - En primer plano: $isAppInForeground")
            } catch (e: Exception) {
                Log.e("LocalNotificationManager", "Error con startActivity, usando PendingIntent", e)
                
                // ✅ FALLBACK mejorado
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    notificationId.hashCode(),
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                try {
                    pendingIntent.send()
                    Log.d("LocalNotificationManager", "App abierta usando PendingIntent")
                } catch (pendingException: Exception) {
                    Log.e("LocalNotificationManager", "Error con PendingIntent", pendingException)
                }
            }
            
        } catch (e: Exception) {
            Log.e("LocalNotificationManager", "Error general en apertura automática", e)
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
    

}