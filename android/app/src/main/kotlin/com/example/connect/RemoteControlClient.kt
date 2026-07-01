package com.example.connect

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.util.Log
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.EOFException
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Cliente RFCOMM del control remoto. Mismo patrón de reconexión y framing
 * length-prefixed que `BtClassicClient`, pero con UUID propio y aislado: solo
 * transporta mensajes hacia el receptor "connect remote control", sin tocar
 * el puente de notificaciones/media existente.
 */
object RemoteControlClient {
    // Debe coincidir EXACTAMENTE con RemoteProtocol.SERVICE_UUID del receptor.
    private val REMOTE_SPP_UUID: UUID = UUID.fromString("d8d76f9c-c583-4a45-91eb-ef72a3704ad5")

    private var appContext: Context? = null
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val scheduler = ScheduledThreadPoolExecutor(1)

    private var socket: BluetoothSocket? = null
    private var input: DataInputStream? = null
    private var out: DataOutputStream? = null
    private var targetAddress: String? = null
    private var reconnectAttempt: Int = 0
    private val reconnectScheduled = AtomicBoolean(false)
    private val readerRunning = AtomicBoolean(false)
    private var readerThread: Thread? = null

    @Volatile
    var onMessage: ((String) -> Unit)? = null

    @Volatile
    var onConnectionChanged: ((Boolean) -> Unit)? = null

    fun init(context: Context) {
        appContext = context.applicationContext
    }

    fun connect(address: String) {
        val current = targetAddress
        val s = socket
        if (current == address && s != null && s.isConnected) return
        targetAddress = address
        reconnectAttempt = 0
        ioExecutor.execute { connectInternal(address) }
    }

    fun disconnect() {
        targetAddress = null
        reconnectAttempt = 0
        ioExecutor.execute { closeInternal() }
    }

    fun isConnected(): Boolean = socket?.isConnected == true

    /** Dirección del dispositivo receptor actualmente conectado (o null si no hay conexión). */
    val connectedAddress: String? get() = if (isConnected()) targetAddress else null

    fun send(json: String): Boolean {
        val addr = targetAddress ?: return false
        ioExecutor.execute {
            val ok = trySendInternal(json)
            if (!ok) scheduleReconnect(addr)
        }
        return true
    }

    private fun connectInternal(address: String) {
        closeInternal()
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return
        if (!adapter.isEnabled) return
        try {
            try { adapter.cancelDiscovery() } catch (_: Exception) {}
            val device = adapter.getRemoteDevice(address)
            val s = device.createRfcommSocketToServiceRecord(REMOTE_SPP_UUID)
            s.connect()
            socket = s
            input = DataInputStream(s.inputStream)
            out = DataOutputStream(s.outputStream)
            reconnectAttempt = 0
            reconnectScheduled.set(false)
            Log.d("RemoteControlClient", "connected: $address")
            onConnectionChanged?.invoke(true)
            startReaderThread(address)
        } catch (e: Exception) {
            Log.d("RemoteControlClient", "connect_failed: ${e.message ?: ""}")
            closeInternal()
            scheduleReconnect(address)
        }
    }

    private fun trySendInternal(json: String): Boolean {
        val bytes = json.toByteArray(Charsets.UTF_8)
        val o = out ?: return false
        return try {
            o.writeInt(bytes.size)
            o.write(bytes)
            o.flush()
            true
        } catch (e: Exception) {
            closeInternal()
            false
        }
    }

    private fun scheduleReconnect(address: String) {
        if (reconnectScheduled.getAndSet(true)) return
        val attempt = reconnectAttempt.coerceAtMost(8)
        val delayMs = (1000L shl attempt).coerceAtMost(30000L)
        reconnectAttempt = (reconnectAttempt + 1).coerceAtMost(50)
        scheduler.schedule({
            reconnectScheduled.set(false)
            ioExecutor.execute {
                if (targetAddress == address) connectInternal(address)
            }
        }, delayMs, TimeUnit.MILLISECONDS)
    }

    private fun startReaderThread(address: String) {
        readerRunning.set(true)
        readerThread = Thread {
            try {
                val i = input ?: return@Thread
                while (readerRunning.get() && targetAddress == address) {
                    val len = try { i.readInt() } catch (e: EOFException) { break }
                    if (len <= 0 || len > 1024 * 256) break
                    val data = ByteArray(len)
                    i.readFully(data)
                    val json = String(data, Charsets.UTF_8)
                    try { onMessage?.invoke(json) } catch (_: Exception) {}
                }
            } catch (_: Exception) {
            } finally {
                ioExecutor.execute {
                    val shouldReconnect = targetAddress == address
                    closeInternal()
                    if (shouldReconnect) scheduleReconnect(address)
                }
            }
        }.also { it.start() }
    }

    private fun closeInternal() {
        readerRunning.set(false)
        try { readerThread?.interrupt() } catch (_: Exception) {}
        readerThread = null
        try { input?.close() } catch (_: Exception) {}
        input = null
        try { out?.close() } catch (_: Exception) {}
        out = null
        val wasConnected = socket?.isConnected == true
        try { socket?.close() } catch (_: Exception) {}
        socket = null
        if (wasConnected) {
            try { onConnectionChanged?.invoke(false) } catch (_: Exception) {}
        }
    }
}
