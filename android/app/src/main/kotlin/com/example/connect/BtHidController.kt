package com.example.connect

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothHidDevice
import android.bluetooth.BluetoothHidDeviceAppSdpSettings
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import java.util.concurrent.Executors

/**
 * Registra el teléfono (emisor) como teclado Bluetooth HID y lo conecta al
 * TV box receptor. Al recibir reportes HID de teclado, el OS del TV box genera
 * KeyEvent reales (KEYCODE_DPAD_*) que cualquier app —incluyendo YouTube TV—
 * recibe correctamente, sin necesitar permisos de sistema ni root.
 *
 * Solo disponible en API 28+ (Android 9+). Se usa únicamente para las teclas
 * de D-pad; todo el resto del control remoto sigue por RFCOMM.
 *
 * Flujo de conexión:
 *   initAndConnect(address)
 *     → getProfileProxy(HID_DEVICE)  ← async
 *     → profileListener.onServiceConnected
 *     → registerApp(sdpSettings, callback)  ← async
 *     → hidCallback.onAppStatusChanged(registered=true)
 *     → hid.connect(tvBoxDevice)  ← async
 *     → hidCallback.onConnectionStateChanged(STATE_CONNECTED)
 *     → isConnected == true → sendKeyAsync() funciona
 */
@RequiresApi(Build.VERSION_CODES.P)
class BtHidController(private val context: Context) {

    companion object {
        private const val TAG = "BtHidController"

        /**
         * Descriptor HID de teclado estándar (101 teclas, boot protocol).
         * Formato de reporte (8 bytes):
         *   [modifier, reserved, key1, key2, key3, key4, key5, key6]
         *
         * HID keycodes usados:
         *   0x4F = Arrow Right → KEYCODE_DPAD_RIGHT
         *   0x50 = Arrow Left  → KEYCODE_DPAD_LEFT
         *   0x51 = Arrow Down  → KEYCODE_DPAD_DOWN
         *   0x52 = Arrow Up    → KEYCODE_DPAD_UP
         *   0x28 = Enter       → KEYCODE_ENTER / KEYCODE_DPAD_CENTER
         */
        val KEYBOARD_DESCRIPTOR: ByteArray = intArrayOf(
            0x05, 0x01,        // Usage Page (Generic Desktop Controls)
            0x09, 0x06,        // Usage (Keyboard)
            0xA1, 0x01,        // Collection (Application)
            // Modifier keys (8 bits)
            0x05, 0x07,        // Usage Page (Keyboard/Keypad)
            0x19, 0xE0,        // Usage Minimum (Left Control = 0xE0)
            0x29, 0xE7,        // Usage Maximum (Right GUI   = 0xE7)
            0x15, 0x00,        // Logical Minimum (0)
            0x25, 0x01,        // Logical Maximum (1)
            0x75, 0x01,        // Report Size (1 bit)
            0x95, 0x08,        // Report Count (8)
            0x81, 0x02,        // Input (Data, Variable, Absolute)
            // Reserved byte
            0x75, 0x08,        // Report Size (8 bits)
            0x95, 0x01,        // Report Count (1)
            0x81, 0x01,        // Input (Constant)
            // Key array (6 simultaneous keys)
            0x05, 0x07,        // Usage Page (Keyboard/Keypad)
            0x19, 0x00,        // Usage Minimum (0)
            0x29, 0xFF,        // Usage Maximum (255)
            0x15, 0x00,        // Logical Minimum (0)
            0x26, 0xFF, 0x00,  // Logical Maximum (255) — 2-byte encoding
            0x75, 0x08,        // Report Size (8 bits)
            0x95, 0x06,        // Report Count (6)
            0x81, 0x00,        // Input (Data, Array, Absolute)
            0xC0               // End Collection
        ).map { it.toByte() }.toByteArray()
    }

    enum class HidState { IDLE, REGISTERED, CONNECTING, CONNECTED }

    @Volatile var hidState = HidState.IDLE
        private set

    @Volatile private var hidDevice: BluetoothHidDevice? = null
    @Volatile private var connectedDevice: BluetoothDevice? = null
    @Volatile private var targetAddress: String? = null

    private val sendExecutor = Executors.newSingleThreadExecutor()

    val isConnected: Boolean get() = hidState == HidState.CONNECTED

    // ------------------------------------------------------------------
    // API pública
    // ------------------------------------------------------------------

    /**
     * Inicia la conexión HID al TV box en [address]. Si el proxy de perfil ya
     * está disponible y la app está registrada, intenta conectar directamente.
     * De lo contrario inicia el flujo asíncrono completo.
     */
    fun initAndConnect(address: String) {
        targetAddress = address
        val hid = hidDevice
        if (hid != null) {
            if (hidState == HidState.REGISTERED || hidState == HidState.IDLE) {
                connectToTarget(hid)
            }
            return
        }
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: run {
            Log.w(TAG, "No BluetoothAdapter"); return
        }
        adapter.getProfileProxy(context, profileListener, BluetoothProfile.HID_DEVICE)
    }

    fun disconnect() {
        val dev = connectedDevice ?: return
        try { hidDevice?.disconnect(dev) } catch (_: Exception) {}
    }

    /**
     * Envía una pulsación de tecla ([hidKeycode]) de forma asíncrona: primero
     * el reporte de key-down, luego espera 50 ms y envía key-up. Seguro llamar
     * desde el hilo principal.
     */
    fun sendKeyAsync(hidKeycode: Int) {
        if (!isConnected) return
        sendExecutor.execute {
            val hid = hidDevice ?: return@execute
            val dev = connectedDevice ?: return@execute
            if (hidState != HidState.CONNECTED) return@execute
            try {
                val press   = byteArrayOf(0, 0, hidKeycode.toByte(), 0, 0, 0, 0, 0)
                val release = ByteArray(8)
                hid.sendReport(dev, 0, press)
                Thread.sleep(50)
                hid.sendReport(dev, 0, release)
                Log.d(TAG, "sendKey 0x${hidKeycode.toString(16)} ok")
            } catch (e: Exception) {
                Log.w(TAG, "sendReport error: ${e.message}")
            }
        }
    }

    // ------------------------------------------------------------------
    // Internos
    // ------------------------------------------------------------------

    private fun connectToTarget(hid: BluetoothHidDevice) {
        val addr = targetAddress ?: return
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return
        val device = try { adapter.getRemoteDevice(addr) } catch (_: Exception) { return }
        hidState = HidState.CONNECTING
        try {
            hid.connect(device)
            Log.d(TAG, "connect() called to $addr")
        } catch (e: Exception) {
            hidState = HidState.REGISTERED
            Log.w(TAG, "connect() failed: ${e.message}")
        }
    }

    private val profileListener = object : BluetoothProfile.ServiceListener {
        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
            Log.d(TAG, "HID profile proxy ready")
            val hid = proxy as BluetoothHidDevice
            hidDevice = hid
            val sdp = BluetoothHidDeviceAppSdpSettings(
                "Connect Remote",
                "BT HID Keyboard",
                "AndoDevs",
                BluetoothHidDevice.SUBCLASS1_KEYBOARD,
                KEYBOARD_DESCRIPTOR
            )
            try {
                val ok = hid.registerApp(sdp, null, null, sendExecutor, hidCallback)
                Log.d(TAG, "registerApp enqueued ok=$ok")
            } catch (e: Exception) {
                Log.w(TAG, "registerApp error: ${e.message}")
            }
        }
        override fun onServiceDisconnected(profile: Int) {
            Log.d(TAG, "HID profile proxy lost")
            hidDevice = null
            hidState = HidState.IDLE
        }
    }

    private val hidCallback = object : BluetoothHidDevice.Callback() {
        override fun onAppStatusChanged(pluggedDevice: BluetoothDevice?, registered: Boolean) {
            Log.d(TAG, "onAppStatusChanged registered=$registered plugged=${pluggedDevice?.address}")
            if (registered) {
                hidState = HidState.REGISTERED
                hidDevice?.let { connectToTarget(it) }
            } else {
                hidState = HidState.IDLE
            }
        }

        override fun onConnectionStateChanged(device: BluetoothDevice, newState: Int) {
            val stateStr = when (newState) {
                BluetoothProfile.STATE_CONNECTED    -> "CONNECTED"
                BluetoothProfile.STATE_DISCONNECTED -> "DISCONNECTED"
                BluetoothProfile.STATE_CONNECTING   -> "CONNECTING"
                else -> "state=$newState"
            }
            Log.d(TAG, "HID $stateStr addr=${device.address}")
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    connectedDevice = device
                    hidState = HidState.CONNECTED
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    if (connectedDevice?.address == device.address) {
                        connectedDevice = null
                        hidState = HidState.REGISTERED
                    }
                }
            }
        }
    }
}
