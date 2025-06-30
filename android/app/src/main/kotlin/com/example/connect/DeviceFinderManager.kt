package com.example.connect

import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.WindowManager
import android.app.Activity
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Timer
import java.util.TimerTask

class DeviceFinderManager(private val context: Context) {
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var isSearching = false
    private var searchTimer: Timer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    
    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "device_finder_channel"
        private const val NOTIFICATION_ID = 9999
    }
    
    init {
        // Inicializar vibrador
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        
        // Crear canal de notificación
        createNotificationChannel()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // ✅ CORREGIR: Usar IMPORTANCE_HIGH para Device Finder (debe funcionar siempre)
            val importance = NotificationManager.IMPORTANCE_HIGH
            
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Búsqueda de Dispositivo",
                importance
            ).apply {
                description = "Notificaciones para la búsqueda de dispositivos"
                
                // Configuración estándar para Device Finder (debe activar pantalla siempre)
                enableVibration(true)
                enableLights(true)
                setSound(null, null) // Sin sonido del canal (se maneja por separado)
                
                Log.d("DeviceFinderManager", "Canal configurado con IMPORTANCE_HIGH")
            }
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            Log.d("DeviceFinderManager", "Canal creado - Importancia: HIGH")
        }
    }
    
    fun startDeviceSearch() {
        if (isSearching) return
        
        try {
            isSearching = true
            
            // Adquirir wake lock
            acquireWakeLock()
            
            // Mostrar notificación de pantalla completa
            showFullScreenNotification()
            
            // Encender pantalla
            turnOnScreen()
            
            // Iniciar sonido
            startSound()
            
            // Iniciar vibración
            startVibration()
            
            Log.d("DeviceFinderManager", "Búsqueda de dispositivo iniciada")
            
            // Auto-detener después de 30 segundos
            searchTimer = Timer()
            searchTimer?.schedule(object : TimerTask() {
                override fun run() {
                    stopDeviceSearch()
                }
            }, 30000) // 30 segundos
            
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error al iniciar búsqueda", e)
            isSearching = false
        }
    }
    
    private fun acquireWakeLock() {
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or 
                PowerManager.ACQUIRE_CAUSES_WAKEUP or 
                PowerManager.ON_AFTER_RELEASE,
                "DeviceFinder:WakeLock"
            )
            wakeLock?.acquire(35000) // 35 segundos
            Log.d("DeviceFinderManager", "Wake lock adquirido")
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error al adquirir wake lock", e)
        }
    }
    
    private fun showFullScreenNotification() {
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("navigate_to", "/buscar_dispositivo")
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("¡Dispositivo encontrado!")
                .setContentText("Toca para abrir la aplicación")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setFullScreenIntent(pendingIntent, true)
                .setAutoCancel(true)
                .setOngoing(true)
                .build()
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, notification)
            
            Log.d("DeviceFinderManager", "Notificación de pantalla completa mostrada")
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error al mostrar notificación", e)
        }
    }
    
    fun stopDeviceSearch() {
        if (!isSearching) return
        
        try {
            // Detener sonido
            stopSound()
            
            // Detener vibración
            stopVibration()
            
            // Liberar wake lock
            releaseWakeLock()
            
            // Cancelar notificación
            cancelNotification()
            
            // Cancelar timer
            searchTimer?.cancel()
            searchTimer = null
            
            isSearching = false
            Log.d("DeviceFinderManager", "Búsqueda de dispositivo detenida")
            
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error al detener búsqueda", e)
        }
    }
    
    private fun turnOnScreen() {
        try {
            if (context is Activity) {
                context.runOnUiThread {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                        context.setShowWhenLocked(true)
                        context.setTurnScreenOn(true)
                    } else {
                        context.window.addFlags(
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                        )
                    }
                }
            }
            Log.d("DeviceFinderManager", "Pantalla encendida")
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error al encender pantalla", e)
        }
    }
    
    private fun startSound() {
        try {
            // Usar el tono de alarma predeterminado o el de llamada
            val alarmUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            
            mediaPlayer = MediaPlayer().apply {
                setDataSource(context, alarmUri)
                setAudioStreamType(AudioManager.STREAM_ALARM)
                isLooping = true
                setVolume(1.0f, 1.0f) // Volumen máximo
                prepare()
                start()
            }
            
            Log.d("DeviceFinderManager", "Sonido iniciado")
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error al iniciar sonido", e)
        }
    }
    
    private fun stopSound() {
        try {
            mediaPlayer?.apply {
                if (isPlaying) {
                    stop()
                }
                release()
            }
            mediaPlayer = null
            Log.d("DeviceFinderManager", "Sonido detenido")
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error al detener sonido", e)
        }
    }
    
    private fun startVibration() {
        try {
            vibrator?.let { vib ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // Patrón más fuerte: vibrar 1s, pausa 0.3s, repetir
                    val pattern = longArrayOf(0, 1000, 300)
                    val amplitudes = intArrayOf(0, 255, 0) // Amplitud máxima
                    val effect = VibrationEffect.createWaveform(pattern, amplitudes, 0)
                    vib.vibrate(effect)
                } else {
                    @Suppress("DEPRECATION")
                    val pattern = longArrayOf(0, 1000, 300)
                    vib.vibrate(pattern, 0)
                }
            }
            Log.d("DeviceFinderManager", "Vibración iniciada")
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error al iniciar vibración", e)
        }
    }
    
    private fun stopVibration() {
        try {
            vibrator?.cancel()
            Log.d("DeviceFinderManager", "Vibración detenida")
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error al detener vibración", e)
        }
    }
    
    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
            wakeLock = null
            Log.d("DeviceFinderManager", "Wake lock liberado")
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error al liberar wake lock", e)
        }
    }
    
    private fun cancelNotification() {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(NOTIFICATION_ID)
            Log.d("DeviceFinderManager", "Notificación cancelada")
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error al cancelar notificación", e)
        }
    }
    
    fun isSearching(): Boolean = isSearching
}