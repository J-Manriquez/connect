package com.example.connect

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.provider.Settings
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_KEEP_APP_ACTIVE = "flutter.keep_app_active"
        private const val KEY_FLOATING_BALL_ENABLED = "flutter.floating_ball_enabled"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "BootReceiver triggered with action: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED -> {
                handleBootCompleted(context)
            }
        }
    }
    
    private fun handleBootCompleted(context: Context) {
        try {
            // Verificar si la preferencia de mantener app activa está habilitada
            val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val keepAppActive = prefs.getBoolean(KEY_KEEP_APP_ACTIVE, false)
            val floatingBallEnabled = prefs.getBoolean(KEY_FLOATING_BALL_ENABLED, false)
            
            Log.d(TAG, "Keep app active preference: $keepAppActive")
            Log.d(TAG, "Floating ball enabled preference: $floatingBallEnabled")
            
            if (keepAppActive) {
                // Iniciar la aplicación automáticamente
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    
                    Log.d(TAG, "Starting application automatically after boot")
                    context.startActivity(launchIntent)
                } else {
                    Log.e(TAG, "Could not get launch intent for package")
                }
            } else {
                Log.d(TAG, "Keep app active is disabled, not starting automatically")
            }

            if (floatingBallEnabled && canDrawOverlays(context)) {
                val i = Intent(context, FloatingBallService::class.java).setAction(FloatingBallService.ACTION_START)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(i)
                } else {
                    context.startService(i)
                }
                Log.d(TAG, "Starting FloatingBallService automatically after boot")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in handleBootCompleted: ${e.message}", e)
        }
    }

    private fun canDrawOverlays(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }
}
