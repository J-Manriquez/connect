package com.example.connect

import android.content.Context
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class FloatingBallCalculatorActivity : FlutterActivity() {
    private val BLE_CHANNEL = "com.example.connect/ble"

    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode {
        return FlutterActivityLaunchConfigs.BackgroundMode.transparent
    }

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    override fun getInitialRoute(): String {
        return "/floating_ball_calculator"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBtServerStatus" -> {
                        try {
                            result.success(
                                mapOf(
                                    "running" to BtClassicServerService.isServiceRunning,
                                    "connectedCount" to BtClassicServerService.connectedPeers,
                                    "lastPeerAddress" to BtClassicServerService.lastPeerAddress,
                                    "lastPeerName" to BtClassicServerService.lastPeerName,
                                    "lastMediaUpdatedAtMs" to BtClassicServerService.lastMediaUpdatedAtMs
                                )
                            )
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "sendBtServerMessage" -> {
                        try {
                            val args = call.arguments as Map<String, Any?>
                            val json = org.json.JSONObject(args).toString()
                            val i = android.content.Intent(this, BtClassicServerService::class.java)
                                .setAction(BtClassicServerService.ACTION_SEND_TO_PEERS)
                                .putExtra(BtClassicServerService.EXTRA_JSON, json)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i) else startService(i)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "sendNotification" -> {
                        try {
                            val args = call.arguments as Map<String, Any?>
                            val json = org.json.JSONObject(args).toString()
                            BtClassicClient.init(this)
                            BtClassicClient.send(json)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "sendDebugLogToPeers" -> {
                        try {
                            val source = call.argument<String>("source") ?: "receptor"
                            val message = call.argument<String>("message") ?: ""
                            BtClassicServerService.sendDebugLogToPeers(source, message)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    "sttSetMuted" -> {
                        try {
                            val muted = call.argument<Boolean>("muted") ?: false
                            val audio = getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
                            if (audio != null) {
                                val direction = if (muted) android.media.AudioManager.ADJUST_MUTE
                                    else android.media.AudioManager.ADJUST_UNMUTE
                                for (stream in intArrayOf(
                                    android.media.AudioManager.STREAM_MUSIC,
                                    android.media.AudioManager.STREAM_NOTIFICATION,
                                )) {
                                    try { audio.adjustStreamVolume(stream, direction, 0) } catch (_: Exception) {}
                                }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
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
