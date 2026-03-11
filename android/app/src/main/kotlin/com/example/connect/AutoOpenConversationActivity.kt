package com.example.connect

import android.os.Bundle
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.location.LocationManager
import android.provider.Settings
import android.bluetooth.BluetoothAdapter
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AutoOpenConversationActivity : FlutterActivity() {
    private val AUTO_OPEN_CHANNEL = "com.example.connect/auto_open"
    private val FLOATING_BALL_CHANNEL = "com.example.connect/floating_ball"
    private val APP_LIST_CHANNEL = "com.example.connect/app_list"
    private lateinit var appListService: AppListService

    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode {
        return FlutterActivityLaunchConfigs.BackgroundMode.transparent
    }

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    override fun getInitialRoute(): String {
        return "/floating_ball_conversation_auto"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        appListService = AppListService(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLOATING_BALL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getFsBarSystemState" -> {
                        try {
                            val wifiEnabled = try {
                                val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                                wifi?.isWifiEnabled == true
                            } catch (_: Exception) {
                                false
                            }
                            val btEnabled = try {
                                BluetoothAdapter.getDefaultAdapter()?.isEnabled == true
                            } catch (_: Exception) {
                                false
                            }
                            val dataEnabled = try {
                                val v = try { Settings.Global.getInt(contentResolver, "mobile_data", 0) } catch (_: Exception) { -1 }
                                if (v == 1) {
                                    true
                                } else if (v == 0) {
                                    false
                                } else {
                                    val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                                    val net = cm?.activeNetwork
                                    val caps = if (net != null) cm.getNetworkCapabilities(net) else null
                                    caps?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true &&
                                        caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                                }
                            } catch (_: Exception) {
                                false
                            }
                            val locationEnabled = try {
                                val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                                lm?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true ||
                                    lm?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true
                            } catch (_: Exception) {
                                false
                            }
                            val batteryPct = try {
                                val i = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                                val level = i?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                                val scale = i?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                                if (level < 0 || scale <= 0) null else {
                                    ((level.toDouble() / scale.toDouble()) * 100.0).toInt().coerceIn(0, 100)
                                }
                            } catch (_: Exception) {
                                null
                            }
                            val showMediaRestore = try {
                                val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                                val useAsReceptor = flutterPrefs.getBoolean("flutter.use_as_receptor", false)
                                if (!useAsReceptor) {
                                    false
                                } else {
                                    fun isMediaFresh(prefsName: String): Boolean {
                                        return try {
                                            val now = System.currentTimeMillis()
                                            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                                            val json = prefs.getString("media_json", null)
                                            val updatedAtMs = prefs.getLong("updatedAtMs", 0L)
                                            !json.isNullOrBlank() && updatedAtMs > 0L && now - updatedAtMs <= 15_000L
                                        } catch (_: Exception) {
                                            false
                                        }
                                    }
                                    isMediaFresh("bt_media_cache_v1") || isMediaFresh("local_media_cache_v1")
                                }
                            } catch (_: Exception) {
                                false
                            }
                            result.success(
                                mapOf(
                                    "wifiEnabled" to wifiEnabled,
                                    "btEnabled" to btEnabled,
                                    "dataEnabled" to dataEnabled,
                                    "locationEnabled" to locationEnabled,
                                    "batteryPct" to batteryPct,
                                    "showMediaRestore" to showMediaRestore
                                )
                            )
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_LIST_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> {
                        try {
                            val apps = appListService.getInstalledApps()
                            result.success(apps)
                        } catch (e: Exception) {
                            result.error("ERROR", "Error al obtener aplicaciones: ${e.message}", null)
                        }
                    }
                    "getEnabledPackages" -> {
                        try {
                            val enabledPackages = appListService.getEnabledPackages()
                            result.success(enabledPackages.toList())
                        } catch (e: Exception) {
                            result.error("ERROR", "Error al obtener paquetes habilitados: ${e.message}", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

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
