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
import android.os.Handler
import android.os.Looper
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

        @Volatile
        private var sharedInstance: DeviceFinderManager? = null

        fun getInstance(context: Context): DeviceFinderManager {
            val appContext = context.applicationContext
            val existing = sharedInstance
            if (existing != null) return existing
            return synchronized(this) {
                val again = sharedInstance
                if (again != null) again else DeviceFinderManager(appContext).also { sharedInstance = it }
            }
        }
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
    
    @Synchronized
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
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                       Intent.FLAG_ACTIVITY_CLEAR_TOP or
                       Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("navigate_to", "/buscar_dispositivo")
                action = "DEVICE_FINDER_ACTION"
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("¡Dispositivo encontrado!")
                .setContentText("Toca para abrir la aplicación")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setFullScreenIntent(pendingIntent, true)
                .setAutoCancel(true)
                .setOngoing(false)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .build()
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID, notification)
            
            Log.d("DeviceFinderManager", "Notificación de pantalla completa mostrada con navegación automática")
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error al mostrar notificación", e)
        }
    }
    
    @Synchronized
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
            // Usar MainActivity.instance para acceder a la actividad
            MainActivity.instance?.let { activity ->
                activity.runOnUiThread {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                        activity.setShowWhenLocked(true)
                        activity.setTurnScreenOn(true)
                        Log.d("DeviceFinderManager", "Usando métodos nuevos para encender pantalla (API 27+)")
                    } else {
                        activity.window.addFlags(
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                        )
                        Log.d("DeviceFinderManager", "Usando flags tradicionales para encender pantalla")
                    }

                    Handler(Looper.getMainLooper()).postDelayed({
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                                activity.setShowWhenLocked(false)
                                activity.setTurnScreenOn(false)
                            }
                            activity.window.clearFlags(
                                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                            )
                        } catch (_: Exception) {
                        }
                    }, 3000)
                }
            } ?: Log.w("DeviceFinderManager", "MainActivity.instance es null, no se puede encender pantalla")
            
            Log.d("DeviceFinderManager", "Pantalla encendida")
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error al encender pantalla", e)
        }
    }
    
    private fun startSound() {
        try {
            if (mediaPlayer?.isPlaying == true) return
            stopSound()

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
            Log.d("DeviceFinderManager", "Intentando iniciar vibración...")
            
            vibrator?.let { vib ->
                // Verificar si el dispositivo tiene vibrador
                if (!vib.hasVibrator()) {
                    Log.w("DeviceFinderManager", "El dispositivo no tiene vibrador")
                    return
                }
                
                Log.d("DeviceFinderManager", "Dispositivo tiene vibrador, iniciando patrón...")
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // Patrón más fuerte: vibrar 1s, pausa 0.3s, repetir
                    val pattern = longArrayOf(0, 1000, 300)
                    val amplitudes = intArrayOf(0, 255, 0) // Amplitud máxima
                    val effect = VibrationEffect.createWaveform(pattern, amplitudes, 0)
                    vib.vibrate(effect)
                    Log.d("DeviceFinderManager", "Vibración iniciada con VibrationEffect (API 26+)")
                } else {
                    @Suppress("DEPRECATION")
                    val pattern = longArrayOf(0, 1000, 300)
                    vib.vibrate(pattern, 0)
                    Log.d("DeviceFinderManager", "Vibración iniciada con método legacy")
                }
            } ?: Log.w("DeviceFinderManager", "Vibrator es null")
            
            Log.d("DeviceFinderManager", "Vibración iniciada exitosamente")
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error al iniciar vibración", e)
        }
    }
    
    private fun stopVibration() {
        try {
            Log.d("DeviceFinderManager", "Intentando detener vibración...")
            
            vibrator?.let { vib ->
                vib.cancel()
                Log.d("DeviceFinderManager", "Vibración cancelada exitosamente")
            } ?: Log.w("DeviceFinderManager", "Vibrator es null al intentar detener")
            
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
    
    // ✅ FUNCIÓN DE PRUEBA PARA VERIFICAR VIBRACIÓN
    fun testVibration() {
        try {
            Log.d("DeviceFinderManager", "=== INICIANDO TEST DE VIBRACIÓN ===")
            
            vibrator?.let { vib ->
                Log.d("DeviceFinderManager", "Vibrator disponible: ${vib.hasVibrator()}")
                
                if (vib.hasVibrator()) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        // Test con VibrationEffect
                        val effect = VibrationEffect.createOneShot(1000, VibrationEffect.DEFAULT_AMPLITUDE)
                        vib.vibrate(effect)
                        Log.d("DeviceFinderManager", "Test de vibración ejecutado con VibrationEffect")
                    } else {
                        // Test con método legacy
                        @Suppress("DEPRECATION")
                        vib.vibrate(1000)
                        Log.d("DeviceFinderManager", "Test de vibración ejecutado con método legacy")
                    }
                } else {
                    Log.w("DeviceFinderManager", "El dispositivo no tiene vibrador")
                }
            } ?: Log.w("DeviceFinderManager", "Vibrator es null")
            
            Log.d("DeviceFinderManager", "=== TEST DE VIBRACIÓN COMPLETADO ===")
        } catch (e: Exception) {
            Log.e("DeviceFinderManager", "Error en test de vibración", e)
        }
    }
}
