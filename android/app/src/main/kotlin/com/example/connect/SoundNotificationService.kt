package com.example.connect

import android.content.Context
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Servicio dedicado para manejar la reproducción de sonidos de notificaciones
 * Especialmente optimizado para Android 8.0 donde las notificaciones tienen restricciones de sonido
 */
class SoundNotificationService(private val context: Context) {
    
    companion object {
        private const val TAG = "SoundNotificationService"
        private const val DEFAULT_VOLUME_THRESHOLD = 0.3f // 30% del volumen máximo
        private const val TARGET_VOLUME_PERCENTAGE = 0.7f // 70% del volumen máximo
    }
    
    private val audioManager: AudioManager by lazy {
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }
    
    /**
     * Reproduce el sonido de notificación usando múltiples estrategias de respaldo
     * @param forceSound Si es true, intenta cambiar configuraciones del sistema para forzar el sonido
     */
    fun playNotificationSound(forceSound: Boolean = true) {
        try {
            Log.d(TAG, "🔊 Iniciando reproducción de sonido de notificación")
            
            // Verificar y preparar el entorno de audio
            if (forceSound) {
                prepareAudioEnvironment()
            }
            
            // Intentar reproducir con diferentes estrategias
            val strategies = listOf(
                ::playWithRingtoneManager,
                ::playWithRingtoneManagerAlarm,
                ::playWithMediaPlayer,
                ::playWithToneGeneratorAlert,
                ::playWithToneGeneratorDTMF,
                ::playWithAudioManagerEffect
            )
            
            for ((index, strategy) in strategies.withIndex()) {
                try {
                    if (strategy()) {
                        Log.d(TAG, "✅ Estrategia ${index + 1} exitosa")
                        return
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "❌ Estrategia ${index + 1} falló: ${e.message}")
                }
            }
            
            // Si todas las estrategias de sonido fallan, usar vibración como respaldo
            playFallbackVibration()
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error crítico en reproducción de sonido", e)
        }
    }
    
    /**
     * Prepara el entorno de audio para maximizar las posibilidades de reproducción
     */
    private fun prepareAudioEnvironment() {
        try {
            Log.d(TAG, "🔧 Preparando entorno de audio")
            
            // Verificar permisos
            val hasModifyAudioSettings = try {
                context.checkSelfPermission(android.Manifest.permission.MODIFY_AUDIO_SETTINGS) == 
                    android.content.pm.PackageManager.PERMISSION_GRANTED
            } catch (e: Exception) {
                false
            }
            
            Log.d(TAG, "🔐 Permiso MODIFY_AUDIO_SETTINGS: $hasModifyAudioSettings")
            
            // Obtener estado actual
            val ringerMode = audioManager.ringerMode
            val streamVolume = audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_NOTIFICATION)
            
            Log.d(TAG, "📊 Estado actual: RingerMode=$ringerMode, Volume=$streamVolume/$maxVolume")
            
            // Intentar cambiar a modo normal si está en silencioso
            if (ringerMode == AudioManager.RINGER_MODE_SILENT && hasModifyAudioSettings) {
                try {
                    audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
                    Log.d(TAG, "✅ Modo ringer cambiado a NORMAL")
                } catch (e: Exception) {
                    Log.w(TAG, "❌ No se pudo cambiar el modo ringer: ${e.message}")
                }
            }
            
            // Aumentar volumen si está muy bajo
            if (streamVolume < maxVolume * DEFAULT_VOLUME_THRESHOLD && hasModifyAudioSettings) {
                try {
                    val targetVolume = (maxVolume * TARGET_VOLUME_PERCENTAGE).toInt()
                    audioManager.setStreamVolume(AudioManager.STREAM_NOTIFICATION, targetVolume, 0)
                    Log.d(TAG, "✅ Volumen aumentado a $targetVolume/$maxVolume")
                } catch (e: Exception) {
                    Log.w(TAG, "❌ No se pudo ajustar volumen: ${e.message}")
                }
            }
            
        } catch (e: Exception) {
            Log.w(TAG, "❌ Error preparando entorno de audio: ${e.message}")
        }
    }
    
    /**
     * Estrategia 1: RingtoneManager con sonido de notificación
     */
    private fun playWithRingtoneManager(): Boolean {
        return try {
            val notificationUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(context, notificationUri)
            
            if (ringtone != null) {
                ringtone.play()
                Log.d(TAG, "✅ RingtoneManager (TYPE_NOTIFICATION) iniciado")
                
                // Detener después de 2 segundos
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        if (ringtone.isPlaying) ringtone.stop()
                    } catch (e: Exception) { /* Ignorar */ }
                }, 2000)
                
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.w(TAG, "RingtoneManager falló: ${e.message}")
            false
        }
    }
    
    /**
     * Estrategia 2: RingtoneManager con sonido de alarma (más agresivo)
     */
    private fun playWithRingtoneManagerAlarm(): Boolean {
        return try {
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            val ringtone = RingtoneManager.getRingtone(context, alarmUri)
            
            if (ringtone != null) {
                ringtone.play()
                Log.d(TAG, "✅ RingtoneManager (TYPE_ALARM) iniciado")
                
                // Detener después de 1.5 segundos (más corto para alarma)
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        if (ringtone.isPlaying) ringtone.stop()
                    } catch (e: Exception) { /* Ignorar */ }
                }, 1500)
                
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.w(TAG, "RingtoneManager (ALARM) falló: ${e.message}")
            false
        }
    }
    
    /**
     * Estrategia 3: MediaPlayer con atributos de audio optimizados
     */
    private fun playWithMediaPlayer(): Boolean {
        return try {
            val mediaPlayer = MediaPlayer()
            val notificationUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            
            mediaPlayer.setDataSource(context, notificationUri)
            mediaPlayer.setAudioAttributes(
                android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setFlags(android.media.AudioAttributes.FLAG_AUDIBILITY_ENFORCED)
                    .build()
            )
            
            mediaPlayer.prepare()
            mediaPlayer.start()
            Log.d(TAG, "✅ MediaPlayer iniciado")
            
            // Limpiar recursos después de 2 segundos
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    if (mediaPlayer.isPlaying) {
                        mediaPlayer.stop()
                    }
                    mediaPlayer.release()
                } catch (e: Exception) { /* Ignorar */ }
            }, 2000)
            
            true
        } catch (e: Exception) {
            Log.w(TAG, "MediaPlayer falló: ${e.message}")
            false
        }
    }
    
    /**
     * Estrategia 4: ToneGenerator con tono de alerta
     */
    private fun playWithToneGeneratorAlert(): Boolean {
        return try {
            val toneGenerator = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
            toneGenerator.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 1000)
            Log.d(TAG, "✅ ToneGenerator (ALERT) iniciado")
            
            // Liberar recursos después de 1.5 segundos
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    toneGenerator.release()
                } catch (e: Exception) { /* Ignorar */ }
            }, 1500)
            
            true
        } catch (e: Exception) {
            Log.w(TAG, "ToneGenerator (ALERT) falló: ${e.message}")
            false
        }
    }
    
    /**
     * Estrategia 5: ToneGenerator con tono DTMF
     */
    private fun playWithToneGeneratorDTMF(): Boolean {
        return try {
            val toneGenerator = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
            toneGenerator.startTone(ToneGenerator.TONE_DTMF_1, 500)
            Log.d(TAG, "✅ ToneGenerator (DTMF) iniciado")
            
            // Liberar recursos después de 1 segundo
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    toneGenerator.release()
                } catch (e: Exception) { /* Ignorar */ }
            }, 1000)
            
            true
        } catch (e: Exception) {
            Log.w(TAG, "ToneGenerator (DTMF) falló: ${e.message}")
            false
        }
    }
    
    /**
     * Estrategia 6: AudioManager.playSoundEffect
     */
    private fun playWithAudioManagerEffect(): Boolean {
        return try {
            audioManager.playSoundEffect(AudioManager.FX_KEYPRESS_STANDARD, 1.0f)
            Log.d(TAG, "✅ AudioManager.playSoundEffect ejecutado")
            true
        } catch (e: Exception) {
            Log.w(TAG, "AudioManager.playSoundEffect falló: ${e.message}")
            false
        }
    }
    
    /**
     * Vibración de respaldo cuando todas las estrategias de sonido fallan
     */
    private fun playFallbackVibration() {
        try {
            val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
            if (vibrator.hasVibrator()) {
                vibrator.vibrate(longArrayOf(0, 100, 100, 100), -1)
                Log.d(TAG, "✅ Vibración de respaldo ejecutada (todas las estrategias de sonido fallaron)")
            }
        } catch (e: Exception) {
            Log.w(TAG, "❌ Vibración de respaldo falló: ${e.message}")
        }
    }
    
    /**
     * Obtiene información de diagnóstico del estado de audio
     */
    fun getAudioDiagnostics(): String {
        return try {
            val ringerMode = audioManager.ringerMode
            val streamVolume = audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_NOTIFICATION)
            
            val diagnostics = StringBuilder()
            diagnostics.append("🔊 DIAGNÓSTICO DE AUDIO:\n")
            diagnostics.append("   Ringer Mode: ${when(ringerMode) {
                AudioManager.RINGER_MODE_NORMAL -> "NORMAL (sonido habilitado)"
                AudioManager.RINGER_MODE_VIBRATE -> "VIBRATE (solo vibración)"
                AudioManager.RINGER_MODE_SILENT -> "SILENT (silencioso)"
                else -> "UNKNOWN ($ringerMode)"
            }}\n")
            diagnostics.append("   Volumen Notificaciones: $streamVolume/$maxVolume\n")
            
            // Verificar Do Not Disturb en Android 6.0+
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                val currentInterruptionFilter = notificationManager.currentInterruptionFilter
                diagnostics.append("   Do Not Disturb: ${when(currentInterruptionFilter) {
                    android.app.NotificationManager.INTERRUPTION_FILTER_ALL -> "DESACTIVADO (permite todo)"
                    android.app.NotificationManager.INTERRUPTION_FILTER_PRIORITY -> "SOLO PRIORIDAD"
                    android.app.NotificationManager.INTERRUPTION_FILTER_NONE -> "TOTAL (bloquea todo)"
                    android.app.NotificationManager.INTERRUPTION_FILTER_ALARMS -> "SOLO ALARMAS"
                    else -> "UNKNOWN ($currentInterruptionFilter)"
                }}\n")
            }
            
            diagnostics.toString()
        } catch (e: Exception) {
            "❌ Error al obtener diagnóstico de audio: ${e.message}"
        }
    }
}