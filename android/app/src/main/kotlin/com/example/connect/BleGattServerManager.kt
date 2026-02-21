package com.example.connect

import android.bluetooth.*
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.nio.charset.Charset
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class BleGattServerManager(private val context: Context, private val channel: MethodChannel) {
    private val serviceUuid = UUID.fromString("b3d9f8a0-6b6f-4d74-9a0c-0f5868e9a1f1")
    private val notifRxUuid = UUID.fromString("b3d9f8a2-6b6f-4d74-9a0c-0f5868e9a1f1")
    private val ackTxUuid = UUID.fromString("b3d9f8a1-6b6f-4d74-9a0c-0f5868e9a1f1")
    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: android.bluetooth.le.AdvertiseCallback? = null
    private val connections = mutableSetOf<BluetoothDevice>()
    private val buffers = ConcurrentHashMap<String, StringBuilder>()
    private val totals = ConcurrentHashMap<String, Int>()
    private val counts = ConcurrentHashMap<String, Int>()

    private fun l(event: String, data: Map<String, Any?> = emptyMap()) {
        val payload = HashMap<String, Any?>()
        payload["source"] = "server"
        payload["event"] = event
        payload["timestamp"] = System.currentTimeMillis()
        for ((k, v) in data) payload[k] = v
        try { channel.invokeMethod("onBleLog", payload) } catch (_: Exception) {}
        android.util.Log.d("BleGattServer", "$event: $data")
    }

    private fun advInfo(settingsInEffect: AdvertiseSettings?): Map<String, Any?> {
        val mode = try { settingsInEffect?.javaClass?.getMethod("getAdvertiseMode")?.invoke(settingsInEffect) } catch (_: Exception) { null }
        val tx = try { settingsInEffect?.javaClass?.getMethod("getTxPowerLevel")?.invoke(settingsInEffect) } catch (_: Exception) { null }
        val connectable = try { settingsInEffect?.javaClass?.getMethod("isConnectable")?.invoke(settingsInEffect) } catch (_: Exception) { null }
        val m = HashMap<String, Any?>()
        m["mode"] = mode
        m["tx"] = tx
        m["connectable"] = connectable
        return m
    }

    fun start() {
        l("start")
        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter
        gattServer = bluetoothManager?.openGattServer(context, callback)
        val supportsAdv = try { bluetoothAdapter?.isMultipleAdvertisementSupported() == true } catch (_: Exception) { null }
        val leExtended = try { bluetoothAdapter?.isLeExtendedAdvertisingSupported() == true } catch (_: Exception) { null }
        val lePeriodic = try { bluetoothAdapter?.isLePeriodicAdvertisingSupported() == true } catch (_: Exception) { null }
        l("adapter_info", mapOf(
            "name" to (bluetoothAdapter?.name ?: ""),
            "address" to (bluetoothAdapter?.address ?: ""),
            "enabled" to (bluetoothAdapter?.isEnabled == true),
            "supportsMultipleAdv" to supportsAdv,
            "leExtendedAdv" to leExtended,
            "lePeriodicAdv" to lePeriodic
        ))
        l("gatt_opened")
        val service = BluetoothGattService(serviceUuid, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val rx = BluetoothGattCharacteristic(
            notifRxUuid,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        val ack = BluetoothGattCharacteristic(
            ackTxUuid,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        service.addCharacteristic(rx)
        service.addCharacteristic(ack)
        gattServer?.addService(service)
        l("service_added", mapOf("uuid" to serviceUuid.toString()))
        advertiser = bluetoothAdapter?.bluetoothLeAdvertiser
        l("advertiser_state", mapOf("isNull" to (advertiser == null)))
        val settings = AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY).setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH).setConnectable(true).build()
        val data = AdvertiseData.Builder().addServiceUuid(ParcelUuid(serviceUuid)).setIncludeDeviceName(false).build()
        advertiseCallback = object : android.bluetooth.le.AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                l("advertise_success", advInfo(settingsInEffect))
            }
            override fun onStartFailure(errorCode: Int) {
                l("advertise_failure", mapOf("code" to errorCode))
            }
        }
        advertiser?.startAdvertising(settings, data, advertiseCallback)
        l("advertising_started")
    }

    fun sendConnectionPing() {
        l("ping_start")
        val adv = advertiser ?: return
        advertiseCallback?.let { adv.stopAdvertising(it) }
        l("advertising_stopped")
        val settings = AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY).setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH).setConnectable(true).build()
        val data = AdvertiseData.Builder()
            .addServiceData(ParcelUuid(serviceUuid), "CONNECT".toByteArray(Charset.forName("UTF-8")))
            .setIncludeDeviceName(false)
            .build()
        advertiseCallback = object : android.bluetooth.le.AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                l("ping_advertise_success", advInfo(settingsInEffect))
            }
            override fun onStartFailure(errorCode: Int) {
                l("ping_advertise_failure", mapOf("code" to errorCode))
                try {
                    val fbData = AdvertiseData.Builder()
                        .addManufacturerData(0xFFFF, "CONNECT".toByteArray(Charset.forName("UTF-8")))
                        .setIncludeDeviceName(false)
                        .build()
                    advertiser?.startAdvertising(settings, fbData, this)
                    l("ping_advertise_fallback_started")
                } catch (_: Exception) {}
            }
        }
        adv.startAdvertising(settings, data, advertiseCallback)
        l("ping_advertising_started")
        Handler(Looper.getMainLooper()).postDelayed({
            advertiseCallback?.let { adv.stopAdvertising(it) }
            l("ping_advertising_stopped")
            val normalSettings = AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY).setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH).setConnectable(true).build()
            val normalData = AdvertiseData.Builder().addServiceUuid(ParcelUuid(serviceUuid)).setIncludeDeviceName(false).build()
            advertiseCallback = object : android.bluetooth.le.AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                    l("advertise_success", advInfo(settingsInEffect))
                }
                override fun onStartFailure(errorCode: Int) {
                    l("advertise_failure", mapOf("code" to errorCode))
                }
            }
            adv.startAdvertising(normalSettings, normalData, advertiseCallback)
            l("advertising_resumed")
        }, 5000)
    }

    fun stop() {
        l("stop")
        advertiseCallback?.let { advertiser?.stopAdvertising(it) }
        l("advertising_stopped")
        advertiseCallback = null
        advertiser = null
        gattServer?.close()
        l("gatt_closed")
        gattServer = null
        connections.clear()
        buffers.clear()
        totals.clear()
        counts.clear()
    }

    private val callback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice?, status: Int, newState: Int) {
            if (device != null) {
                if (newState == BluetoothProfile.STATE_CONNECTED) connections.add(device) else connections.remove(device)
                l("conn_state", mapOf("address" to device.address, "state" to newState, "status" to status))
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice?,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic?,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            if (characteristic?.uuid == notifRxUuid && value != null) {
                l("write", mapOf("uuid" to characteristic.uuid.toString(), "len" to value.size))
                val s = value.toString(Charset.forName("UTF-8"))
                val obj = JSONObject(s)
                val msgId = obj.getString("msgId")
                val seq = obj.getInt("seq")
                val total = obj.getInt("total")
                val data = obj.getString("data")
                l("fragment", mapOf("msgId" to msgId, "seq" to seq, "total" to total, "data_len" to data.length))
                totals[msgId] = total
                val b = buffers.getOrPut(msgId) { StringBuilder() }
                b.append(data)
                counts[msgId] = (counts[msgId] ?: 0) + 1
                if (counts[msgId] == totals[msgId]) {
                    val full = b.toString()
                    l("reassembled", mapOf("msgId" to msgId, "size" to full.length))
                    buffers.remove(msgId)
                    counts.remove(msgId)
                    totals.remove(msgId)
                    val payload = JSONObject(full)
                    val map = HashMap<String, Any?>()
                    for (key in payload.keys()) map[key] = payload.get(key)
                    channel.invokeMethod("onBleNotificationReceived", map)
                    l("delivered", mapOf("msgId" to msgId))
                }
            }
            if (responseNeeded) gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, null)
        }
    }
}