package com.example.connect

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log

class VibrationManager(private val context: Context) {
    private val TAG = "VibrationManager"
    
    private val vibrator: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }
    
    fun hasVibrator(): Boolean {
        return vibrator.hasVibrator()
    }
    
    private fun isVibrateAllowed(): Boolean {
        try {
            // Verificar configuración global de vibración
            val hapticFeedbackEnabled = Settings.System.getInt(
                context.contentResolver,
                Settings.System.HAPTIC_FEEDBACK_ENABLED,
                1
            ) == 1
            
            // Verificar modo de sonido
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val ringerMode = audioManager.ringerMode
            
            Log.d(TAG, "Haptic feedback enabled: $hapticFeedbackEnabled")
            Log.d(TAG, "Ringer mode: $ringerMode (NORMAL=2, VIBRATE=1, SILENT=0)")
            
            // Permitir vibración en modo normal y vibración
            val ringerAllowsVibration = ringerMode == AudioManager.RINGER_MODE_NORMAL || 
                                      ringerMode == AudioManager.RINGER_MODE_VIBRATE
            
            return hapticFeedbackEnabled && ringerAllowsVibration
        } catch (e: Exception) {
            Log.e(TAG, "Error verificando configuración de vibración: ${e.message}", e)
            return true // Asumir que está permitido si hay error
        }
    }
    
    fun vibrateSimple(duration: Long = 500) {
        try {
            Log.d(TAG, "Iniciando vibración simple de ${duration}ms")
            
            if (!hasVibrator()) {
                Log.w(TAG, "El dispositivo no tiene vibrador")
                return
            }
            
            if (!isVibrateAllowed()) {
                Log.w(TAG, "Vibración bloqueada por configuración del sistema")
                return
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Usar amplitud máxima para vibración más fuerte
                val amplitude = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    255 // Amplitud máxima en Android 10+
                } else {
                    VibrationEffect.DEFAULT_AMPLITUDE // Amplitud por defecto en Android 8-9
                }
                val effect = VibrationEffect.createOneShot(duration, amplitude)
                vibrator.vibrate(effect)
                Log.d(TAG, "Vibración simple ejecutada con VibrationEffect (amplitud: $amplitude)")
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(duration)
                Log.d(TAG, "Vibración simple ejecutada con método legacy")
            }
            
            // Verificar si realmente vibró
            Log.d(TAG, "Comando de vibración enviado al sistema")
        } catch (e: Exception) {
            Log.e(TAG, "Error en vibración simple: ${e.message}", e)
        }
    }
    
    fun vibratePattern(pattern: List<Long>) {
        try {
            Log.d(TAG, "Iniciando vibración con patrón: $pattern")
            
            if (!hasVibrator()) {
                Log.w(TAG, "El dispositivo no tiene vibrador")
                return
            }
            
            if (!isVibrateAllowed()) {
                Log.w(TAG, "Vibración bloqueada por configuración del sistema")
                return
            }
            
            if (pattern.isEmpty()) {
                Log.w(TAG, "Patrón vacío, usando vibración simple")
                vibrateSimple()
                return
            }
            
            val patternArray = pattern.toLongArray()
            Log.d(TAG, "Patrón convertido: ${patternArray.contentToString()}")
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Crear un array de amplitudes para hacer la vibración más fuerte
                // Alternamos entre amplitud máxima (255) para vibración y 0 para pausas
                val amplitudes = IntArray(patternArray.size) { i -> 
                    if (i % 2 == 0) 0 else VibrationEffect.DEFAULT_AMPLITUDE // 0 para delay, amplitud máxima para vibración
                }
                
                // Usar amplitud máxima para todas las vibraciones
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    // En Android 10+ podemos usar amplitud máxima
                    val amplitudesMax = IntArray(patternArray.size) { i -> 
                        if (i % 2 == 0) 0 else 255 // 0 para delay, 255 (máximo) para vibración
                    }
                    val effect = VibrationEffect.createWaveform(patternArray, amplitudesMax, -1)
                    vibrator.vibrate(effect)
                    Log.d(TAG, "Vibración con patrón ejecutada con amplitud máxima")
                } else {
                    // En Android 8-9 usamos la API más simple
                    val effect = VibrationEffect.createWaveform(patternArray, -1)
                    vibrator.vibrate(effect)
                    Log.d(TAG, "Vibración con patrón ejecutada con VibrationEffect estándar")
                }
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(patternArray, -1)
                Log.d(TAG, "Vibración con patrón ejecutada con método legacy")
            }
            
            // Verificar si realmente vibró
            Log.d(TAG, "Comando de vibración con patrón enviado al sistema")
        } catch (e: Exception) {
            Log.e(TAG, "Error en vibración con patrón: ${e.message}", e)
            // Fallback a vibración simple
            Log.d(TAG, "Intentando fallback a vibración simple")
            vibrateSimple()
        }
    }
    
    fun testVibration() {
        Log.d(TAG, "Iniciando test de vibración")
        
        if (!hasVibrator()) {
            Log.w(TAG, "Test fallido: dispositivo sin vibrador")
            return
        }
        
        if (!isVibrateAllowed()) {
            Log.w(TAG, "Test fallido: vibración bloqueada por configuración del sistema")
            return
        }
        
        // Test de vibración simple más fuerte
        Log.d(TAG, "Ejecutando test de vibración simple (500ms)")
        vibrateSimple(500)
        
        // Esperar y hacer test de patrón
        Thread.sleep(1000)
        
        // Test de patrón más perceptible
        Log.d(TAG, "Ejecutando test de patrón de vibración")
        val testPattern = listOf(0L, 500L, 200L, 500L, 200L, 500L)
        vibratePattern(testPattern)
        
        Log.d(TAG, "Test de vibración completado")
    }
    
    fun cancel() {
        try {
            vibrator.cancel()
            Log.d(TAG, "Vibración cancelada")
        } catch (e: Exception) {
            Log.e(TAG, "Error al cancelar vibración: ${e.message}", e)
        }
    }
}