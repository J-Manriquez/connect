package com.example.connect

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
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
    
    fun vibrateSimple(duration: Long = 500) {
        try {
            Log.d(TAG, "Iniciando vibración simple de ${duration}ms")
            
            if (!hasVibrator()) {
                Log.w(TAG, "El dispositivo no tiene vibrador")
                return
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE)
                vibrator.vibrate(effect)
                Log.d(TAG, "Vibración simple ejecutada con VibrationEffect")
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(duration)
                Log.d(TAG, "Vibración simple ejecutada con método legacy")
            }
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
            
            if (pattern.isEmpty()) {
                Log.w(TAG, "Patrón vacío, usando vibración simple")
                vibrateSimple()
                return
            }
            
            val patternArray = pattern.toLongArray()
            Log.d(TAG, "Patrón convertido: ${patternArray.contentToString()}")
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createWaveform(patternArray, -1)
                vibrator.vibrate(effect)
                Log.d(TAG, "Vibración con patrón ejecutada con VibrationEffect")
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(patternArray, -1)
                Log.d(TAG, "Vibración con patrón ejecutada con método legacy")
            }
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
        
        // Test de vibración simple
        vibrateSimple(200)
        
        // Esperar y hacer test de patrón
        Thread.sleep(500)
        
        // Test de patrón simple
        val testPattern = listOf(0L, 300L, 100L, 300L)
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