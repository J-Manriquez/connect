package com.example.connect

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activity que hospeda el control remoto BT desde la bola flotante
 * (ruta Flutter "/floating_ball_remote_control").
 *
 * Se lanza con FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_SINGLE_TOP desde
 * FloatingBallService, igual que FloatingBallChatsActivity.
 *
 * Necesita registrar el canal "com.example.connect/remote_control" con
 * los mismos handlers que MainActivity, ya que esta Activity tiene su
 * propio FlutterEngine. Usa RemoteControlClient (singleton) para no
 * interferir con la conexión ya establecida.
 */
class FloatingBallRemoteControlActivity : FlutterActivity() {

    private val REMOTE_CONTROL_CHANNEL = "com.example.connect/remote_control"

    // Guardamos los callbacks anteriores de RemoteControlClient para
    // restaurarlos al destruir la Activity (evita que MainActivity pierda
    // sus listeners si estaba activa antes de abrir este overlay).
    private var prevOnMessage: ((String) -> Unit)? = null
    private var prevOnConnectionChanged: ((Boolean) -> Unit)? = null

    private lateinit var remoteControlChannel: MethodChannel

    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode =
        FlutterActivityLaunchConfigs.BackgroundMode.transparent

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun getInitialRoute(): String = "/floating_ball_remote_control"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        RemoteControlClient.init(applicationContext)

        remoteControlChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            REMOTE_CONTROL_CHANNEL
        )

        // Guardar callbacks previos antes de sobreescribirlos
        prevOnMessage = RemoteControlClient.onMessage
        prevOnConnectionChanged = RemoteControlClient.onConnectionChanged

        RemoteControlClient.onMessage = { json ->
            runOnUiThread {
                try {
                    remoteControlChannel.invokeMethod("onRemoteMessage", json)
                } catch (_: Exception) {}
            }
        }
        RemoteControlClient.onConnectionChanged = { connected ->
            runOnUiThread {
                try {
                    remoteControlChannel.invokeMethod("onRemoteConnectionChanged", connected)
                } catch (_: Exception) {}
            }
        }

        // Notificar estado actual inmediatamente (si ya había conexión desde RemoteControlScreen)
        if (RemoteControlClient.isConnected()) {
            runOnUiThread {
                try {
                    remoteControlChannel.invokeMethod("onRemoteConnectionChanged", true)
                } catch (_: Exception) {}
            }
        }

        remoteControlChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getBondedDevices" -> {
                    try {
                        val adapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
                        val bonded = adapter?.bondedDevices?.map { d ->
                            mapOf(
                                "address" to d.address,
                                "name" to (d.name ?: ""),
                                "bondState" to d.bondState
                            )
                        } ?: emptyList()
                        result.success(bonded)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "startDiscovery" -> result.success(true)
                "stopDiscovery" -> result.success(true)
                "connectRemote" -> {
                    try {
                        val address = call.argument<String>("address")
                        if (address != null) {
                            RemoteControlClient.connect(address)
                            // HID: obtener hidController de MainActivity si está disponible
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                MainActivity.instance?.hidController?.initAndConnect(address)
                            }
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "address requerido", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "disconnectRemote" -> {
                    try {
                        RemoteControlClient.disconnect()
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            MainActivity.instance?.hidController?.disconnect()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "hidSendDpad" -> {
                    try {
                        val key = call.argument<String>("key")
                        if (key == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val hid = MainActivity.instance?.hidController
                        if (hid == null || !hid.isConnected) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val hidCode = when (key) {
                            "dpad_up"     -> 0x52
                            "dpad_down"   -> 0x51
                            "dpad_left"   -> 0x50
                            "dpad_right"  -> 0x4F
                            "dpad_center" -> 0x28
                            else -> 0
                        }
                        if (hidCode == 0) { result.success(false); return@setMethodCallHandler }
                        result.success(true)
                        hid.sendKeyAsync(hidCode)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "hidStatus" -> {
                    try {
                        val hid = MainActivity.instance?.hidController
                        result.success(mapOf(
                            "supported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P),
                            "connected" to (hid?.isConnected == true),
                            "state" to (hid?.hidState?.name ?: "UNAVAILABLE")
                        ))
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "isRemoteConnected" -> result.success(RemoteControlClient.isConnected())
                "getConnectedAddress" -> result.success(RemoteControlClient.connectedAddress)
                "sendRemote" -> {
                    try {
                        val args = call.arguments as Map<String, Any?>
                        val json = org.json.JSONObject(args).toString()
                        result.success(RemoteControlClient.send(json))
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
        } catch (_: Exception) {}
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        // Restaurar los callbacks previos para que MainActivity (si estaba activa)
        // recupere sus listeners de RemoteControlClient.
        RemoteControlClient.onMessage = prevOnMessage
        RemoteControlClient.onConnectionChanged = prevOnConnectionChanged
        super.onDestroy()
    }
}
