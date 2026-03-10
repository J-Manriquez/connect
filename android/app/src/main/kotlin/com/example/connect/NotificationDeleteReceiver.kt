package com.example.connect

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class NotificationDeleteReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getStringExtra("notification_id")
        if (notificationId != null) {
            if (LocalNotificationManager.consumeProgrammaticCancel(notificationId)) {
                Log.d("NotificationDeleteReceiver", "Cancelada por app: $notificationId")
                return
            }

            Log.d("NotificationDeleteReceiver", "Usuario eliminó notificación: $notificationId")
            LocalNotificationManager.addToCancelledNotifications(notificationId)
            MainActivity.instance?.notifyNotificationDismissed(notificationId)
        }
    }
}
