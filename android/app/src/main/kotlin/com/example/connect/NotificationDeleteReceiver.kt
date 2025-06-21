package com.example.connect

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class NotificationDeleteReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getStringExtra("notification_id")
        if (notificationId != null) {
            // Marcar la notificación como cancelada por el usuario
            Log.d("NotificationDeleteReceiver", "Usuario eliminó notificación: $notificationId")
            
            // ✅ Agregar la notificación al conjunto de canceladas en LocalNotificationManager
            LocalNotificationManager.addToCancelledNotifications(notificationId)
            
            // ✅ Comunicar a Flutter que la notificación fue eliminada
            MainActivity.instance?.notifyNotificationDismissed(notificationId)
        }
    }
}
