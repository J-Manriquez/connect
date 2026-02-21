package com.example.connect

import android.bluetooth.*
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.ParcelUuid
import org.json.JSONObject
import java.nio.charset.Charset
import java.util.UUID

import io.flutter.plugin.common.MethodChannel

class BleGattClientManager(private val context: Context, private val channel: MethodChannel) {
    private val serviceUuid = UUID.fromString("b3d9f8a0-6b6f-4d74-9a0c-0f5868e9a1f1")
    private val notifRxUuid = UUID.fromString("b3d9f8a2-6b6f-4d74-9a0c-0f5868e9a1f1")
    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var scanner: BluetoothLeScanner? = null
    private var gatt: BluetoothGatt? = null
    private var notifRx: BluetoothGattCharacteristic? = null
    private var restarting: Boolean = false
    private var scanningOnly: Boolean = false
    private val seen: MutableSet<String> = mutableSetOf()
    private var fallbackPosted: Boolean = false
    private var scanMode: Int = 0
    private var toggleHandler: android.os.Handler? = null
    private var togglePosted: Boolean = false
    private val deviceMap: java.util.concurrent.ConcurrentHashMap<String, BluetoothDevice> = java.util.concurrent.ConcurrentHashMap()

    private fun l(event: String, data: Map<String, Any?> = emptyMap()) {
        val payload = HashMap<String, Any?>()
        payload["source"] = "client"
        payload["event"] = event
        payload["timestamp"] = System.currentTimeMillis()
        for ((k, v) in data) payload[k] = v
        try { channel.invokeMethod("onBleLog", payload) } catch (_: Exception) {}
        android.util.Log.d("BleGattClient", "$event: $data")
    }

    fun start() {
        l("start")
        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter
        scanner = bluetoothAdapter?.bluetoothLeScanner
        val filters = listOf(ScanFilter.Builder().setServiceUuid(ParcelUuid(serviceUuid)).build())
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
        scanner?.startScan(filters, settings, scanCallback)
        l("adapter_state", mapOf("enabled" to (bluetoothAdapter?.isEnabled == true), "scannerNull" to (scanner == null)))
        l("scan_started")
    }

    fun stop() {
        l("stop")
        scanner?.stopScan(scanCallback)
        l("scan_stopped")
        scanner = null
        gatt?.close()
        l("gatt_closed")
        gatt = null
        notifRx = null
    }

    fun startScanOnly() {
        l("start_scan_only")
        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter
        scanner = bluetoothAdapter?.bluetoothLeScanner
        scanningOnly = true
        seen.clear()
        l("adapter_state", mapOf("enabled" to (bluetoothAdapter?.isEnabled == true), "scannerNull" to (scanner == null)))
        startSimpleScan()
        scheduleToggle()
    }

    fun stopScanOnly() {
        l("stop_scan_only")
        scanner?.stopScan(scanCallback)
        scanningOnly = false
        seen.clear()
        fallbackPosted = false
        togglePosted = false
        try { toggleHandler?.removeCallbacksAndMessages(null) } catch (_: Exception) {}
        toggleHandler = null
    }

    private fun startSimpleScan() {
        val settings = android.bluetooth.le.ScanSettings.Builder()
            .setScanMode(android.bluetooth.le.ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        try {
            scanner?.startScan(emptyList(), settings, scanCallback)
            scanMode = 0
            l("scan_mode_simple")
        } catch (e: Exception) {
            l("scan_start_error", mapOf("error" to (e.message ?: "")))
        }
    }

    private fun startFilteredScan() {
        val filters = listOf(android.bluetooth.le.ScanFilter.Builder().setServiceUuid(android.os.ParcelUuid(serviceUuid)).build())
        val settings = android.bluetooth.le.ScanSettings.Builder()
            .setScanMode(android.bluetooth.le.ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setMatchMode(android.bluetooth.le.ScanSettings.MATCH_MODE_AGGRESSIVE)
            .setCallbackType(android.bluetooth.le.ScanSettings.CALLBACK_TYPE_ALL_MATCHES)
            .build()
        try {
            scanner?.startScan(filters, settings, scanCallback)
            scanMode = 1
            l("scan_mode_filtered")
        } catch (e: Exception) {
            l("scan_fallback_error", mapOf("error" to (e.message ?: "")))
        }
    }

    private fun scheduleToggle() {
        if (togglePosted) return
        togglePosted = true
        toggleHandler = android.os.Handler(android.os.Looper.getMainLooper())
        toggleHandler?.postDelayed(object : Runnable {
            override fun run() {
                if (!scanningOnly) { togglePosted = false; return }
                if (seen.isEmpty()) {
                    try { scanner?.stopScan(scanCallback) } catch (_: Exception) {}
                    if (scanMode == 0) {
                        startFilteredScan()
                    } else {
                        startSimpleScan()
                    }
                    l("scan_toggle", mapOf("mode" to scanMode))
                    toggleHandler?.postDelayed(this, 5000)
                } else {
                    togglePosted = false
                }
            }
        }, 5000)
    }

    fun connectTo(address: String) {
        try {
            scanningOnly = false
            val device = deviceMap[address] ?: bluetoothAdapter?.getRemoteDevice(address) ?: return
            scanner?.stopScan(scanCallback)
            gatt = device.connectGatt(context, false, gattCallback)
            l("connect_to", mapOf("address" to address, "viaCache" to (deviceMap.containsKey(address))))
        } catch (_: Exception) {}
    }

    fun sendNotification(json: String) {
        l("send_notification_called")
        val c = notifRx ?: return
        val maxChunk = 180
        val total = (json.length + maxChunk - 1) / maxChunk
        val id = try { JSONObject(json).getString("id") } catch (e: Exception) { System.currentTimeMillis().toString() }
        l("prepare_send", mapOf("id" to id, "total" to total, "len" to json.length))
        var seq = 0
        var i = 0
        while (i < json.length) {
            val end = (i + maxChunk).coerceAtMost(json.length)
            val part = json.substring(i, end)
            val frag = JSONObject()
            frag.put("msgId", id)
            frag.put("seq", ++seq)
            frag.put("total", total)
            frag.put("data", part)
            val bytes = frag.toString().toByteArray(Charset.forName("UTF-8"))
            c.value = bytes
            c.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            gatt?.writeCharacteristic(c)
            l("chunk_sent", mapOf("seq" to seq, "size" to bytes.size))
            i = end
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt?, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                g?.discoverServices()
                l("connected")
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                notifRx = null
                g?.close()
                gatt = null
                l("disconnected", mapOf("status" to status))
                if (!restarting) {
                    restarting = true
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        restarting = false
                        start()
                        l("reconnect_attempt")
                    }, 1000)
                }
            }
        }
        override fun onServicesDiscovered(g: BluetoothGatt?, status: Int) {
            val s = g?.getService(serviceUuid)
            val c = s?.getCharacteristic(notifRxUuid)
            notifRx = c
            l("services_discovered", mapOf("hasService" to (s != null), "hasChar" to (c != null)))
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            val d = result?.device ?: return
            if (scanningOnly) {
                val addr = d.address
                if (!seen.contains(addr)) {
                    seen.add(addr)
                    deviceMap[addr] = d
                    val record = result?.scanRecord
                    val sd = record?.getServiceData(ParcelUuid(serviceUuid))
                    val uuids = record?.serviceUuids
                    val msd = record?.manufacturerSpecificData
                    var pingMsd = false
                    if (msd != null) {
                        for (i in 0 until msd.size()) {
                            val bytes = msd.valueAt(i)
                            try { if (String(bytes, Charset.forName("UTF-8")) == "CONNECT") { pingMsd = true; break } } catch (_: Exception) {}
                        }
                    }
                    val compatible = try { uuids?.any { it.uuid == serviceUuid } == true || sd != null } catch (_: Exception) { false }
                    val ping = try { (sd != null && String(sd, Charset.forName("UTF-8")) == "CONNECT") || pingMsd } catch (_: Exception) { pingMsd }
                    val uuidList = try { uuids?.map { it.uuid.toString() } ?: emptyList() } catch (_: Exception) { emptyList() }
                    val msdCount = try { msd?.size() ?: 0 } catch (_: Exception) { 0 }
                    val sdLen = try { sd?.size ?: 0 } catch (_: Exception) { 0 }
                    try {
                        channel.invokeMethod(
                            "onBleScanResult",
                            mapOf(
                                "address" to addr,
                                "name" to (d.name ?: ""),
                                "rssi" to (result?.rssi ?: 0),
                                "ping" to ping,
                                "compatible" to compatible,
                                "uuids" to uuidList,
                                "msdCount" to msdCount,
                                "sdLen" to sdLen
                            )
                        )
                        l(
                            "scan_result",
                            mapOf(
                                "address" to addr,
                                "name" to (d.name ?: ""),
                                "rssi" to (result?.rssi ?: 0),
                                "ping" to ping,
                                "compatible" to compatible,
                                "uuids" to uuidList,
                                "msdCount" to msdCount,
                                "sdLen" to sdLen
                            )
                        )
                    } catch (_: Exception) {}
                }
                return
            }
            scanner?.stopScan(this)
            try {
                channel.invokeMethod("onBlePeerFound", mapOf("address" to d.address))
            } catch (_: Exception) {}
            gatt = d.connectGatt(context, false, gattCallback)
            l("peer_found_connect", mapOf("address" to d.address))
        }
        override fun onBatchScanResults(results: MutableList<ScanResult>?) {
            results?.forEach { r -> onScanResult(ScanSettings.CALLBACK_TYPE_ALL_MATCHES, r) }
            l("batch_results", mapOf("count" to (results?.size ?: 0)))
        }
        override fun onScanFailed(errorCode: Int) {
            l("scan_failed", mapOf("code" to errorCode))
        }
    }
}