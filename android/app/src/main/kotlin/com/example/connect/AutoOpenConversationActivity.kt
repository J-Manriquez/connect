package com.example.connect

import android.os.Bundle
import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AutoOpenConversationActivity : FlutterActivity() {
    private val AUTO_OPEN_CHANNEL = "com.example.connect/auto_open"

    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode {
        return FlutterActivityLaunchConfigs.BackgroundMode.opaque
    }

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    override fun getInitialRoute(): String {
        return "/floating_ball_conversation_auto"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTO_OPEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAutoOpenPayload" -> {
                        val notificationId = intent.getStringExtra(LocalNotificationManager.EXTRA_NOTIFICATION_DATA) ?: ""
                        val title = intent.getStringExtra("title") ?: ""
                        val body = intent.getStringExtra("body") ?: ""
                        val packageName = intent.getStringExtra("packageName") ?: ""
                        val appName = intent.getStringExtra("appName") ?: ""
                        val autoOpen = intent.getBooleanExtra("autoOpen", true)
                        val fromBackground = intent.getBooleanExtra("fromBackground", true)
                        val timestamp = intent.getLongExtra("timestamp", System.currentTimeMillis())

                        result.success(
                            mapOf(
                                "notificationId" to notificationId,
                                "title" to title,
                                "body" to body,
                                "packageName" to packageName,
                                "appName" to appName,
                                "autoOpen" to autoOpen,
                                "isAutoOpened" to true,
                                "fromBackground" to fromBackground,
                                "timestamp" to timestamp
                            )
                        )
                    }

                    "close" -> {
                        finish()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.skip_auto_redirect_once", true).apply()
        } catch (_: Exception) {
        }
        super.onCreate(savedInstanceState)
    }
}
