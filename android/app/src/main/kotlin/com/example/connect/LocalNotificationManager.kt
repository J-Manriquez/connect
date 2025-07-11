package com.example.connect

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.os.Build
import androidx.core.app.NotificationCompat
import android.util.Log
import android.app.ActivityManager
import io.flutter.embedding.android.FlutterActivity
import android.view.WindowManager
import android.os.Handler
import android.os.Looper
import android.media.AudioManager
import android.provider.Settings

class LocalNotificationManager(private val context: Context) {
    
    // ✅ CONFIGURACIÓN DE SHARED PREFERENCES PARA TIEMPO REAL
    private val sharedPreferences: SharedPreferences = context.getSharedPreferences("flutter.notification_settings", Context.MODE_PRIVATE)
    
    // ✅ SERVICIO DEDICADO PARA SONIDOS
    private val soundService: SoundNotificationService = SoundNotificationService(context)
    
    companion object {
        private const val CHANNEL_ID = "receptor_notifications_channel"
        private const val CHANNEL_NAME = "Notificaciones del Receptor"
        private const val CHANNEL_DESCRIPTION = "Canal para mostrar notificaciones recibidas en el receptor"
        const val NOTIFICATION_ACTION_OPEN = "OPEN_NOTIFICATION"
        const val NOTIFICATION_ACTION_AUTO_OPEN = "AUTO_OPEN_NOTIFICATION"
        const val EXTRA_NOTIFICATION_DATA = "notification_data"
        
        // ✅ CLAVES PARA CONFIGURACIÓN EN TIEMPO REAL
        private const val KEY_SCREEN_WAKE_ENABLED = "flutter.screenWakeEnabled"
        private const val KEY_AUTO_OPEN_ENABLED = "flutter.autoOpenEnabled"
        private const val KEY_SOUND_ENABLED = "flutter.soundEnabled"
        
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
            // ✅ CONFIGURACIÓN SIMPLIFICADA PARA ANDROID 8.0
            if (Build.VERSION.SDK_INT == Build.VERSION_CODES.O) {
                // ANDROID 8.0: Configuración mínima - sonido manejado por separado
                Log.d("LocalNotificationManager", "🔧 Configurando canal simplificado para Android 8.0")
                
                // Recrear canal con configuración mínima
                notificationManager.deleteNotificationChannel(CHANNEL_ID)
                
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH // Suficiente para mostrar notificación
                ).apply {
                    description = CHANNEL_DESCRIPTION
                    
                    // Configuración mínima - el sonido se maneja por separado
                    setSound(null, null) // Sin sonido en el canal
                    enableVibration(false) // Sin vibración en el canal
                    enableLights(false) // Sin luces en el canal
                    lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                    
                    Log.d("LocalNotificationManager", "✅ Canal simplificado configurado para Android 8.0")
                }
                
                notificationManager.createNotificationChannel(channel)
                Log.d("LocalNotificationManager", "✅ Canal simplificado creado para Android 8.0")
            } else {
                // ANDROID 8.1+: Configuración ultra conservadora
                Log.d("LocalNotificationManager", "🔧 Configurando canal para Android 8.1+")
                
                // Recrear canal con configuración sin sonido
                notificationManager.deleteNotificationChannel(CHANNEL_ID)
                
                val importance = NotificationManager.IMPORTANCE_LOW
                
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
                    group = null // Sin grupo
                    
                    Log.d("LocalNotificationManager", "Canal configurado ULTRA conservador - Importance: IMPORTANCE_LOW")
                }
                
                notificationManager.createNotificationChannel(channel)
                Log.d("LocalNotificationManager", "Canal creado - Configuración ultra conservadora")
            }
        }
    }
    
    // ✅ MÉTODO PARA ACTUALIZAR CONFIGURACIÓN EN TIEMPO REAL
    fun updateSettings(screenWakeEnabled: Boolean, autoOpenEnabled: Boolean, soundEnabled: Boolean = true) {
        val editor = sharedPreferences.edit()
        editor.putBoolean(KEY_SCREEN_WAKE_ENABLED, screenWakeEnabled)
        editor.putBoolean(KEY_AUTO_OPEN_ENABLED, autoOpenEnabled)
        editor.putBoolean(KEY_SOUND_ENABLED, soundEnabled)
        editor.apply()
        
        // ✅ RECREAR CANAL PARA ANDROID 8.0 CUANDO CAMBIE LA CONFIGURACIÓN DE SONIDO
        if (Build.VERSION.SDK_INT == Build.VERSION_CODES.O) {
            Log.d("LocalNotificationManager", "Android 8.0: Recreando canal con nueva configuración de sonido")
            createNotificationChannel()
        }
        
        Log.d("LocalNotificationManager", "⚡ CONFIGURACIÓN ACTUALIZADA EN TIEMPO REAL:")
        Log.d("LocalNotificationManager", "   screenWakeEnabled: $screenWakeEnabled")
        Log.d("LocalNotificationManager", "   autoOpenEnabled: $autoOpenEnabled")
        Log.d("LocalNotificationManager", "   soundEnabled: $soundEnabled")
    }
    
    // ✅ MÉTODOS PARA OBTENER CONFIGURACIÓN ACTUAL
    private fun getCurrentScreenWakeEnabled(): Boolean {
        return sharedPreferences.getBoolean(KEY_SCREEN_WAKE_ENABLED, false)
    }
    
    private fun getCurrentAutoOpenEnabled(): Boolean {
        return sharedPreferences.getBoolean(KEY_AUTO_OPEN_ENABLED, false)
    }
    
    private fun getCurrentSoundEnabled(): Boolean {
        return sharedPreferences.getBoolean(KEY_SOUND_ENABLED, true)
    }
    
    // ✅ MÉTODO SIMPLIFICADO USANDO EL SERVICIO DEDICADO DE SONIDO
    private fun playNotificationSoundDirectly() {
        try {
            Log.d("LocalNotificationManager", "🔊 Iniciando reproducción de sonido")
            
            // Intentar reproducir sonido personalizado directamente desde MainActivity
            try {
                Log.d("LocalNotificationManager", "🎵 Intentando reproducir sonido personalizado via MainActivity")
                
                val mainActivity = MainActivity.instance
                if (mainActivity != null) {
                    mainActivity.runOnUiThread {
                        try {
                            // Usar el soundChannel para invocar directamente el método en Flutter
                            mainActivity.soundChannel.invokeMethod("playCustomSound", null)
                            Log.d("LocalNotificationManager", "✅ Comando de sonido personalizado enviado directamente a Flutter")
                        } catch (e: Exception) {
                            Log.e("LocalNotificationManager", "❌ Error al invocar método en Flutter", e)
                        }
                    }
                } else {
                    Log.w("LocalNotificationManager", "⚠️ MainActivity instance no disponible")
                }
                
            } catch (e: Exception) {
                Log.w("LocalNotificationManager", "⚠️ No se pudo enviar comando de sonido personalizado: ${e.message}")
            }
            
            // Solo usar sonido personalizado, sin fallback del sistema
            Log.d("LocalNotificationManager", "✅ Solo sonido personalizado configurado, sin fallback del sistema")
            
        } catch (e: Exception) {
            Log.e("LocalNotificationManager", "❌ Error al reproducir sonido", e)
        }
    }
    
    // ✅ MÉTODO SIMPLIFICADO PARA VERIFICAR ESTADO DEL AUDIO USANDO EL SERVICIO
    private fun checkAudioStateForAndroid8(): String {
        return try {
            soundService.getAudioDiagnostics()
        } catch (e: Exception) {
            "❌ Error al obtener diagnóstico de audio: ${e.message}"
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
        customVibrationPattern: List<Long>?,
        screenWakeEnabled: Boolean,
        autoOpenEnabled: Boolean
    ) {
        try {
            // ✅ VERIFICAR si la notificación fue cancelada previamente
        if (isNotificationCancelled(notificationId)) {
            Log.d("LocalNotificationManager", "Notificación previamente cancelada, no se muestra: $notificationId")
            return
        }
        
        // ✅ USAR CONFIGURACIÓN EN TIEMPO REAL
        val currentScreenWakeEnabled = getCurrentScreenWakeEnabled()
        val currentAutoOpenEnabled = getCurrentAutoOpenEnabled()
        val currentSoundEnabled = getCurrentSoundEnabled()
        
        Log.d("LocalNotificationManager", "=== CONFIGURACIÓN DETALLADA RECIBIDA ===")
        Log.d("LocalNotificationManager", "Title: $title")
        Log.d("LocalNotificationManager", "Body: $body")
        Log.d("LocalNotificationManager", "NotificationId: $notificationId")
        Log.d("LocalNotificationManager", "screenWakeEnabled (parámetro): $screenWakeEnabled")
        Log.d("LocalNotificationManager", "screenWakeEnabled (tiempo real): $currentScreenWakeEnabled")
        Log.d("LocalNotificationManager", "autoOpenEnabled (parámetro): $autoOpenEnabled")
        Log.d("LocalNotificationManager", "autoOpenEnabled (tiempo real): $currentAutoOpenEnabled")
        Log.d("LocalNotificationManager", "soundEnabled (parámetro): $soundEnabled")
        Log.d("LocalNotificationManager", "soundEnabled (tiempo real): $currentSoundEnabled")
        Log.d("LocalNotificationManager", "🔍 VERIFICACIÓN CRÍTICA NATIVA: usando configuración en tiempo real")
        Log.d("LocalNotificationManager", "vibrationEnabled: $vibrationEnabled")
        Log.d("LocalNotificationManager", "Android API Level: ${Build.VERSION.SDK_INT}")
        Log.d("LocalNotificationManager", "=================================================")
            
            // ✅ USAR CONFIGURACIÓN EN TIEMPO REAL PARA SCREEN WAKE
            if (currentScreenWakeEnabled) {
                Log.d("LocalNotificationManager", "screenWakeEnabled (tiempo real): true - Procediendo a activar pantalla")
                wakeUpScreenConservative()
                Log.d("LocalNotificationManager", "Pantalla activada de forma conservadora")
            } else {
                Log.d("LocalNotificationManager", "screenWakeEnabled (tiempo real): false - Pantalla NO será activada")
            }
            
            // ✅ USAR CONFIGURACIÓN EN TIEMPO REAL PARA AUTO-OPEN
            Log.d("LocalNotificationManager", "🔍 EVALUANDO AUTO-OPEN (tiempo real): autoOpenEnabled = $currentAutoOpenEnabled")
            if (currentAutoOpenEnabled) {
                Log.d("LocalNotificationManager", "✅ AUTO-OPEN ACTIVADO (tiempo real): Ejecutando apertura automática")
                // Delay mínimo para auto-open, independiente del wake screen
                val delay = 200L
                Handler(Looper.getMainLooper()).postDelayed({
                    openAppAutomatically(title, body, packageName, appName, notificationId, currentScreenWakeEnabled)
                }, delay)
                Log.d("LocalNotificationManager", "AutoOpen habilitado independientemente (tiempo real)")
            } else {
                Log.d("LocalNotificationManager", "❌ AUTO-OPEN DESACTIVADO (tiempo real): No se ejecutará apertura automática")
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
            
            // ✅ CONFIGURACIÓN ESPECÍFICA PARA ANDROID 8: Usar método anterior que funcionaba
            if (Build.VERSION.SDK_INT == Build.VERSION_CODES.O) {
                // ANDROID 8.0: Usar configuración del archivo previo_funcionando.txt
                Log.d("LocalNotificationManager", "Android 8.0: Usando configuración funcional anterior")
                
                // ✅ DIAGNÓSTICO DE AUDIO PARA ANDROID 8.0
                val audioState = checkAudioStateForAndroid8()
                Log.d("LocalNotificationManager", audioState)
                
                // ✅ FORZAR RECREACIÓN DEL CANAL PARA ANDROID 8.0
                Log.d("LocalNotificationManager", "Android 8.0: Forzando recreación del canal")
                createNotificationChannel()
                
                // ✅ VERIFICAR ESTADO DEL CANAL DESPUÉS DE LA CREACIÓN
                val channel = notificationManager.getNotificationChannel(CHANNEL_ID)
                if (channel != null) {
                    Log.d("LocalNotificationManager", "Android 8.0: Canal verificado - Importance: ${channel.importance}")
                    Log.d("LocalNotificationManager", "Android 8.0: Canal - Sound: ${channel.sound}")
                    Log.d("LocalNotificationManager", "Android 8.0: Canal - CanBypassDnd: ${channel.canBypassDnd()}")
                } else {
                    Log.e("LocalNotificationManager", "Android 8.0: ❌ ERROR - Canal no encontrado después de creación")
                }
                
                notificationBuilder.setPriority(NotificationCompat.PRIORITY_MAX)
                notificationBuilder.setCategory(NotificationCompat.CATEGORY_MESSAGE)
                notificationBuilder.setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                
                // ✅ CONFIGURACIÓN SIMPLIFICADA PARA ANDROID 8.0
                // Sin configuración de sonido en la notificación - se maneja por separado
                notificationBuilder.setSound(null)
                Log.d("LocalNotificationManager", "Android 8.0: Configuración simplificada aplicada, sonido del sistema deshabilitado")
                
                // ✅ REPRODUCIR SONIDO POR SEPARADO SI ESTÁ HABILITADO
                if (currentSoundEnabled) {
                    Log.d("LocalNotificationManager", "🔊 Android 8.0: Iniciando reproducción de sonido directa")
                    
                    // Ejecutar solo una vez para evitar sonidos duplicados
                    playNotificationSoundDirectly()
                    
                    Log.d("LocalNotificationManager", "✅ Android 8.0: Comando de sonido enviado")
                } else {
                    Log.d("LocalNotificationManager", "❌ Android 8.0: Sonido deshabilitado por configuración")
                }
                
                if (vibrationEnabled) {
                    if (customVibrationPattern != null && customVibrationPattern.isNotEmpty()) {
                        val pattern = customVibrationPattern.toLongArray()
                        notificationBuilder.setVibrate(pattern)
                        Log.d("LocalNotificationManager", "Android 8.0: Vibración personalizada aplicada")
                    } else {
                        notificationBuilder.setVibrate(longArrayOf(0, 500, 500, 500))
                        Log.d("LocalNotificationManager", "Android 8.0: Vibración predeterminada habilitada")
                    }
                }
                
                // ✅ MOSTRAR NOTIFICACIÓN PARA ANDROID 8.0
                try {
                    val finalNotification = notificationBuilder.build()
                    notificationManager.notify(uniqueNotificationId, finalNotification)
                    Log.d("LocalNotificationManager", "✅ Android 8.0: Notificación mostrada exitosamente con ID $uniqueNotificationId")
                } catch (e: Exception) {
                    Log.e("LocalNotificationManager", "❌ Android 8.0: Error al mostrar notificación", e)
                }
            } else {
                // ANDROID 8.1+: Configuración ultra conservadora
                if (screenWakeEnabled) {
                    Log.d("LocalNotificationManager", "screenWakeEnabled: true - Usando PRIORITY_DEFAULT (ultra conservador)")
                    notificationBuilder.setPriority(NotificationCompat.PRIORITY_DEFAULT)
                } else {
                    Log.d("LocalNotificationManager", "screenWakeEnabled: false - Configuración ultra restrictiva")
                    notificationBuilder.setPriority(NotificationCompat.PRIORITY_MIN)
                    notificationBuilder.setDefaults(0)
                    notificationBuilder.setLights(0, 0, 0)
                    notificationBuilder.setSound(null)
                    notificationBuilder.setVibrate(null)
                }
                
                // Configuraciones adicionales para evitar activación de pantalla
                notificationBuilder.setOnlyAlertOnce(true)
                notificationBuilder.setLocalOnly(true)
                notificationBuilder.setVisibility(NotificationCompat.VISIBILITY_SECRET)
                
                // ✅ CORREGIDO: Configurar sonido independientemente de screenWakeEnabled para Android 8.1+
                if (currentSoundEnabled) {
                    Log.d("LocalNotificationManager", "🔊 Android 8.1+: Reproduciendo sonido directamente (independiente de screenWake)")
                    
                    // Reproducir SOLO sonido personalizado, sin sonido del sistema
                    playNotificationSoundDirectly()
                    
                    // NO configurar sonido del sistema en la notificación para evitar doble sonido
                    notificationBuilder.setSound(null)
                    Log.d("LocalNotificationManager", "✅ Sonido del sistema deshabilitado, solo sonido personalizado")
                } else {
                    Log.d("LocalNotificationManager", "❌ Android 8.1+: Sonido deshabilitado por configuración")
                    notificationBuilder.setSound(null)
                }
                
                // Configurar vibración solo si screenWakeEnabled está activo
                if (screenWakeEnabled && vibrationEnabled) {
                    if (customVibrationPattern != null && customVibrationPattern.isNotEmpty()) {
                        val pattern = customVibrationPattern.toLongArray()
                        notificationBuilder.setVibrate(pattern)
                        Log.d("LocalNotificationManager", "Vibración personalizada aplicada")
                    } else {
                        notificationBuilder.setVibrate(longArrayOf(0, 500, 500, 500))
                        Log.d("LocalNotificationManager", "Vibración predeterminada habilitada")
                    }
                }
            }
            
            // Mostrar la notificación usando el ID único (solo para Android 8.1+)
            if (Build.VERSION.SDK_INT != Build.VERSION_CODES.O) {
                val finalNotification = notificationBuilder.build()
                notificationManager.notify(uniqueNotificationId, finalNotification)
                Log.d("LocalNotificationManager", "✅ Android 8.1+: Notificación mostrada exitosamente con ID $uniqueNotificationId")
            }
            
            // ✅ LOGGING DETALLADO POST-CREACIÓN
            Log.d("LocalNotificationManager", "=== NOTIFICACIÓN CREADA ===")
            Log.d("LocalNotificationManager", "Notification ID único: $uniqueNotificationId")
            Log.d("LocalNotificationManager", "Android API Level: ${Build.VERSION.SDK_INT}")
            Log.d("LocalNotificationManager", "Screen Wake solicitado: $screenWakeEnabled")
            Log.d("LocalNotificationManager", "Auto Open solicitado: $autoOpenEnabled")
            Log.d("LocalNotificationManager", "Sound Enabled: $currentSoundEnabled")
            Log.d("LocalNotificationManager", "Vibration Enabled: $vibrationEnabled")
            Log.d("LocalNotificationManager", "==============================")
            
        } catch (e: Exception) {
            Log.e("LocalNotificationManager", "Error al mostrar notificación", e)
        }
    }
    
    // ✅ CORREGIDO: Método mejorado para activar pantalla que funciona correctamente
    private fun wakeUpScreenConservative() {
        try {
            Log.d("LocalNotificationManager", "🔥 INICIANDO ACTIVACIÓN DE PANTALLA")
            Log.d("LocalNotificationManager", "Android API Level: ${Build.VERSION.SDK_INT}")
            
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            
            // Verificar si la pantalla ya está encendida
            val isScreenOn = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                powerManager.isInteractive
            } else {
                @Suppress("DEPRECATION")
                powerManager.isScreenOn
            }
            
            Log.d("LocalNotificationManager", "📱 Estado actual de la pantalla: ${if (isScreenOn) "ENCENDIDA" else "APAGADA"}")
            
            if (!isScreenOn) {
                Log.d("LocalNotificationManager", "⚡ PROCEDIENDO A ACTIVAR LA PANTALLA")
                
                when {
                    // Android 8.0 (API 26) - Enfoque híbrido mejorado
                    Build.VERSION.SDK_INT == Build.VERSION_CODES.O -> {
                        Log.d("LocalNotificationManager", "🎯 ANDROID 8.0: Usando enfoque híbrido mejorado")
                        
                        try {
                            // 1. Primero intentar con WakeLock corto
                            val wakeLock = powerManager.newWakeLock(
                                android.os.PowerManager.SCREEN_BRIGHT_WAKE_LOCK or 
                                android.os.PowerManager.ACQUIRE_CAUSES_WAKEUP,
                                "ConnectApp:Android8WakeUp"
                            )
                            
                            wakeLock.acquire(2000) // 2 segundos
                            Log.d("LocalNotificationManager", "✅ WakeLock adquirido para Android 8.0")
                            
                            // 2. Complementar con Intent para asegurar activación
                            Handler(Looper.getMainLooper()).postDelayed({
                                try {
                                    val intent = Intent(context, MainActivity::class.java).apply {
                                        action = "WAKE_SCREEN_ACTION"  // ✅ CORREGIDO: Usar la acción correcta
                                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                                               Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                               Intent.FLAG_ACTIVITY_SINGLE_TOP
                                        putExtra("wakeScreenOnly", true)
                                        putExtra("screenWakeEnabled", true)
                                        putExtra("timestamp", System.currentTimeMillis())
                                    }
                                    
                                    context.startActivity(intent)
                                    Log.d("LocalNotificationManager", "✅ Intent complementario enviado con acción WAKE_SCREEN_ACTION (Android 8.0)")
                                    
                                } catch (e: Exception) {
                                    Log.e("LocalNotificationManager", "Error con Intent complementario", e)
                                }
                            }, 300)
                            
                            // 3. Liberar WakeLock de forma segura
                            Handler(Looper.getMainLooper()).postDelayed({
                                try {
                                    if (wakeLock.isHeld) {
                                        wakeLock.release()
                                        Log.d("LocalNotificationManager", "✅ WakeLock liberado (Android 8.0)")
                                    }
                                } catch (e: Exception) {
                                    Log.e("LocalNotificationManager", "Error al liberar WakeLock", e)
                                }
                            }, 1500)
                            
                        } catch (e: Exception) {
                            Log.e("LocalNotificationManager", "Error con enfoque híbrido Android 8.0", e)
                        }
                    }
                    
                    // Android 8.1+ - Enfoque estándar mejorado
                    else -> {
                        Log.d("LocalNotificationManager", "🎯 ANDROID 8.1+: Usando enfoque estándar mejorado")
                        
                        try {
                            val wakeLock = powerManager.newWakeLock(
                                android.os.PowerManager.SCREEN_BRIGHT_WAKE_LOCK or 
                                android.os.PowerManager.ACQUIRE_CAUSES_WAKEUP,
                                "ConnectApp:StandardWakeUp"
                            )
                            
                            wakeLock.acquire(3000) // 3 segundos para versiones más nuevas
                            Log.d("LocalNotificationManager", "✅ WakeLock estándar adquirido por 3 segundos")
                            
                            // Liberar de forma segura
                            Handler(Looper.getMainLooper()).postDelayed({
                                try {
                                    if (wakeLock.isHeld) {
                                        wakeLock.release()
                                        Log.d("LocalNotificationManager", "✅ WakeLock estándar liberado exitosamente")
                                    }
                                } catch (e: Exception) {
                                    Log.e("LocalNotificationManager", "Error al liberar WakeLock estándar", e)
                                }
                            }, 2500)
                            
                        } catch (e: Exception) {
                            Log.e("LocalNotificationManager", "Error con configuración estándar", e)
                        }
                    }
                }
                
                Log.d("LocalNotificationManager", "🎉 PROCESO DE ACTIVACIÓN DE PANTALLA COMPLETADO")
            } else {
                Log.d("LocalNotificationManager", "✅ La pantalla ya estaba encendida - no se requiere activación")
            }
            
        } catch (e: Exception) {
            Log.e("LocalNotificationManager", "❌ ERROR CRÍTICO al activar la pantalla", e)
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
            Log.d("LocalNotificationManager", "Iniciando apertura automática de app - screenWakeEnabled: $screenWakeEnabled")
            
            // ✅ VERIFICAR: Estado de la aplicación
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val runningTasks = activityManager.getRunningTasks(1)
            val isAppInForeground = runningTasks.isNotEmpty() && 
                runningTasks[0].topActivity?.packageName == context.packageName
            
            val intent = Intent(context, MainActivity::class.java).apply {
                action = NOTIFICATION_ACTION_AUTO_OPEN
                
                // ✅ CONFIGURACIÓN ULTRA CONSERVADORA: Flags según screenWakeEnabled | ESTO ENCIENDE LA PANTALLA EN AUTO OPEN
                // flags = if (isAppInForeground) {
                //     // App en primer plano - flags mínimos
                //     Intent.FLAG_ACTIVITY_SINGLE_TOP or
                //     Intent.FLAG_ACTIVITY_CLEAR_TOP
                // } else {
                    // App en segundo plano - flags según configuración de pantalla
                if (screenWakeEnabled) {
                    // Permitir activación normal cuando screenWake está habilitado
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                } else {
                    // ✅ AUTO-OPEN SILENCIOSO: Flags ultra conservadores
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION // Sin animaciones para ser más silencioso
                }
                // }
                
                putExtra(EXTRA_NOTIFICATION_DATA, notificationId)
                putExtra("title", title)
                putExtra("body", body)
                putExtra("packageName", packageName)
                putExtra("appName", appName)
                putExtra("autoOpen", true)
                putExtra("fromBackground", !isAppInForeground)
                putExtra("timestamp", System.currentTimeMillis()) // ✅ AGREGAR timestamp
                putExtra("screenWakeEnabled", screenWakeEnabled) // ✅ AGREGAR configuración
                
                // ✅ LOGGING DETALLADO DE FLAGS
                Log.d("LocalNotificationManager", "=== AUTO-OPEN INTENT CONFIGURADO ===")
                Log.d("LocalNotificationManager", "App en primer plano: $isAppInForeground")
                Log.d("LocalNotificationManager", "Screen Wake habilitado: $screenWakeEnabled")
                Log.d("LocalNotificationManager", "Intent flags: ${Integer.toHexString(flags)}")
                Log.d("LocalNotificationManager", "Modo: ${if (screenWakeEnabled) "NORMAL" else "SILENCIOSO"}")
                Log.d("LocalNotificationManager", "=========================================")
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