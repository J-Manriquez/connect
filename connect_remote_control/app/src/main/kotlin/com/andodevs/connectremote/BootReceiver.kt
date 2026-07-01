package com.andodevs.connectremote

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build

/** Si el usuario activó el receptor previamente, lo vuelve a iniciar tras un reinicio. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        val prefs: SharedPreferences =
            context.getSharedPreferences(MainActivity.PREFS_NAME, Context.MODE_PRIVATE)
        val wasEnabled = prefs.getBoolean(MainActivity.KEY_SERVICE_ENABLED, false)
        if (!wasEnabled) return
        val serviceIntent = Intent(context, RemoteServerService::class.java)
            .setAction(RemoteServerService.ACTION_START)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (_: Exception) {
        }
    }
}
