package com.example.connect

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class CustomSoundReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == "com.example.connect.PLAY_CUSTOM_SOUND") {
            Log.d("CustomSoundReceiver", "Recibido intent para reproducir sonido personalizado")
            
            try {
                // Obtener la instancia de MainActivity
                 val mainActivity = MainActivity.instance
                 if (mainActivity != null) {
                     // Ejecutar en el hilo principal de UI
                     mainActivity.runOnUiThread {
                         try {
                             // Usar el soundChannel configurado en MainActivity para invocar método en Flutter
                             mainActivity.soundChannel.invokeMethod("playCustomSound", null)
                             Log.d("CustomSoundReceiver", "✅ Comando de sonido personalizado enviado a Flutter")
                         } catch (e: Exception) {
                             Log.e("CustomSoundReceiver", "❌ Error al invocar método en Flutter", e)
                         }
                     }
                 } else {
                     Log.e("CustomSoundReceiver", "❌ MainActivity instance es null")
                 }
            } catch (e: Exception) {
                Log.e("CustomSoundReceiver", "Error al enviar comando de sonido a Flutter", e)
            }
        }
    }
}