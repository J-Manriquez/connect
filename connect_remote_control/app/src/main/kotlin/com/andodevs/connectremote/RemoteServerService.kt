package com.andodevs.connectremote

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.EOFException
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Servidor RFCOMM del receptor. Mismo patrón de framing length-prefixed que
 * `BtClassicServerService` en `connect`, pero con UUID propio y sin motor
 * Flutter: este proceso es nativo y liviano.
 */
class RemoteServerService : Service() {

    companion object {
        const val ACTION_START = "com.andodevs.connectremote.START"
        const val ACTION_STOP = "com.andodevs.connectremote.STOP"

        private const val CHANNEL_ID = "remote_control_server_channel"
        private const val NOTIF_ID = 51001

        @Volatile
        var isRunning: Boolean = false

        @Volatile
        var connectedPeerName: String? = null

        // Instancia actual del servicio; permite acceder al controller desde
        // OnboardingActivity para aplicar cambios en caliente (ej. tamaño cursor).
        @Volatile
        var instance: RemoteServerService? = null
    }

    // Expone el controller para cambios en caliente (tamaño cursor, etc.)
    val controller: RemoteInputController? get() = inputController

    private var serverSocket: BluetoothServerSocket? = null
    private val sockets: MutableSet<BluetoothSocket> = CopyOnWriteArraySet()
    private val running = AtomicBoolean(false)
    private var acceptThread: Thread? = null
    private var inputController: RemoteInputController? = null
    // Ejecutor de una sola hebra para serializar TODAS las escrituras al socket
    // y evitar race conditions que corrompen el framing length-prefixed.
    private val sendExecutor = Executors.newSingleThreadExecutor()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        RemoteDebugLogger.init { json -> sendToPeers(json) }
        inputController = RemoteInputController(applicationContext) { json -> sendToPeers(json) }
        // Cargar tamaño de cursor guardado por el usuario en OnboardingActivity
        val cursorSizeDp = OnboardingActivity.loadCursorSizeDp(applicationContext)
        inputController?.cursorOverlay?.cursorSizeDp = cursorSizeDp
        createNotificationChannel()
        RemoteDebugLogger.log("server", "RemoteServerService created cursorSizeDp=$cursorSizeDp")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopSelfSafely()
            else -> startServerIfNeeded()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        RemoteDebugLogger.log("server", "RemoteServerService destroyed")
        instance = null
        stopServer()
        inputController?.stop()
        inputController = null
        RemoteDebugLogger.detach()
        super.onDestroy()
    }

    private fun startServerIfNeeded() {
        if (!running.compareAndSet(false, true)) return
        isRunning = true
        startForeground(NOTIF_ID, buildNotification())
        inputController?.start()

        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null || !adapter.isEnabled) {
            stopSelfSafely()
            return
        }

        try {
            serverSocket = adapter.listenUsingRfcommWithServiceRecord(
                RemoteProtocol.SERVICE_NAME,
                RemoteProtocol.SERVICE_UUID
            )
        } catch (_: Exception) {
            stopSelfSafely()
            return
        }

        acceptThread = Thread {
            while (running.get()) {
                try {
                    val socket = serverSocket?.accept() ?: break
                    // Si ya hay emisores conectados, cerrarlos para que el nuevo
                    // tome el control sin necesidad de reiniciar el receptor.
                    if (sockets.isNotEmpty()) {
                        val old = sockets.toList()
                        sockets.clear()
                        RemoteDebugLogger.log("server", "new emitter replacing ${old.size} existing connection(s)")
                        for (s in old) try { s.close() } catch (_: Exception) {}
                    }
                    sockets.add(socket)
                    connectedPeerName = try { socket.remoteDevice?.name } catch (_: Exception) { null }
                    RemoteDebugLogger.log("server", "peer connected name=$connectedPeerName")
                    sendHello(socket)
                    startReaderThread(socket)
                } catch (_: Exception) {
                    break
                }
            }
            stopSelfSafely()
        }.also { it.start() }
    }

    private fun startReaderThread(socket: BluetoothSocket) {
        Thread {
            try {
                val input = DataInputStream(socket.inputStream)
                while (running.get()) {
                    val len = try { input.readInt() } catch (e: EOFException) { break }
                    if (len <= 0 || len > 1024 * 256) break
                    val data = ByteArray(len)
                    input.readFully(data)
                    val json = String(data, Charsets.UTF_8)
                    try {
                        inputController?.handle(JSONObject(json))
                    } catch (_: Exception) {
                    }
                }
            } catch (_: Exception) {
            } finally {
                try { socket.close() } catch (_: Exception) {}
                sockets.remove(socket)
                if (sockets.isEmpty()) connectedPeerName = null
            }
        }.start()
    }

    private fun sendHello(socket: BluetoothSocket) {
        val obj = JSONObject()
        obj.put("type", "hello")
        obj.put("name", Build.MODEL ?: "Receptor")
        obj.put("version", 1)
        // Enviado desde sendExecutor para no competir con logs concurrentes.
        sendToPeers(obj.toString())
    }

    /**
     * Escribe un mensaje JSON al socket con framing length-prefixed.
     * DEBE llamarse solo desde [sendExecutor] para evitar writes concurrentes.
     */
    private fun writeToSocketUnsafe(socket: BluetoothSocket, json: String): Boolean {
        return try {
            val bytes = json.toByteArray(Charsets.UTF_8)
            val out = DataOutputStream(socket.outputStream)
            out.writeInt(bytes.size)
            out.write(bytes)
            out.flush()
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Envía [json] a todos los peers conectados, serializando las escrituras
     * en [sendExecutor] (una sola hebra) para prevenir interleaving de bytes
     * que corrompe el framing length-prefixed y cierra la conexión del emisor.
     */
    private fun sendToPeers(json: String) {
        if (sockets.isEmpty()) return
        sendExecutor.execute {
            val toRemove = ArrayList<BluetoothSocket>()
            for (s in sockets) {
                if (!writeToSocketUnsafe(s, json)) toRemove.add(s)
            }
            if (toRemove.isNotEmpty()) {
                for (s in toRemove) {
                    sockets.remove(s)
                    try { s.close() } catch (_: Exception) {}
                }
                if (sockets.isEmpty()) connectedPeerName = null
            }
        }
    }

    private fun stopSelfSafely() {
        stopServer()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun stopServer() {
        isRunning = false
        if (!running.compareAndSet(true, false)) return
        try { serverSocket?.close() } catch (_: Exception) {}
        serverSocket = null
        try { acceptThread?.interrupt() } catch (_: Exception) {}
        acceptThread = null
        for (s in sockets) {
            try { s.close() } catch (_: Exception) {}
        }
        sockets.clear()
        connectedPeerName = null
        inputController?.stop()
        sendExecutor.shutdown()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Control remoto",
            NotificationManager.IMPORTANCE_LOW
        )
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentTitle("Receptor de control remoto activo")
            .setContentText("Esperando conexión desde connect")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
