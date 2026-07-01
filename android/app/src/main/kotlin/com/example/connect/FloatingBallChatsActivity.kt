package com.example.connect

import android.os.Bundle
import android.os.Build
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

/**
 * Activity que hospeda el menú de chats de la bola flotante
 * (ruta Flutter "/floating_ball_chats"). Se lanza desde el botón "Chats" del
 * menú de la bola (FloatingBallService) tanto en versión pantalla completa
 * como popup.
 *
 * Usa un FlutterEngine PROPIO (igual que AutoOpenConversationActivity), así que
 * debe registrar los canales que usa esta pantalla y, sobre todo, la pantalla
 * de conversación a la que navega: el canal BLE con sus 5 métodos (sin él,
 * BleService falla en silencio y se rompen logs BT, el indicador de
 * notificación activa y el mute del STT), el canal app_list (getInstalledApps)
 * y el canal floating_ball (getFsBarSystemState).
 */
class FloatingBallChatsActivity : FlutterActivity() {
    private val FLOATING_BALL_CHANNEL = "com.example.connect/floating_ball"
    private val APP_LIST_CHANNEL = "com.example.connect/app_list"
    private val BLE_CHANNEL = "com.example.connect/ble"
    private lateinit var appListService: AppListService

    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode {
        return FlutterActivityLaunchConfigs.BackgroundMode.transparent
    }

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    override fun getInitialRoute(): String {
        return "/floating_ball_chats"
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
                    "cancelChatNotifications" -> {
                        // Cancela la notificación agrupada (clave pkg|title) del
                        // chat en la barra del dispositivo, si existe. Mismo
                        // cálculo de numericId que LocalNotificationManager /
                        // AutoOpenConversationActivity.
                        try {
                            val pkg = (call.argument<String>("packageName") ?: "").trim()
                            val title = (call.argument<String>("title") ?: "").trim()
                            val groupKey = ("$pkg|$title").lowercase()
                            val numericId = (groupKey.hashCode() and 0x7FFFFFFF)
                            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                            nm?.cancel(numericId)
                            result.success(true)
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

        // Canal BLE con los métodos que usan esta pantalla y, sobre todo, la
        // pantalla de conversación a la que navega (BleService, STT, indicador
        // de notificación activa).
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
                            val i = Intent(this, BtClassicServerService::class.java)
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
