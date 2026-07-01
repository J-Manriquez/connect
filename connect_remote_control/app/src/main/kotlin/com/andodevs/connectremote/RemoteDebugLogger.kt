package com.andodevs.connectremote

import android.util.Log
import org.json.JSONObject

/**
 * Logger de depuración que reenvía mensajes al emisor (connect) por el mismo
 * socket RFCOMM. Permite leer trazas del receptor sin tener que conectar un
 * cable USB al TV-box.
 *
 * Uso:
 *   RemoteDebugLogger.log("mi_tag", "evento key=value")
 *
 * El emisor recibe {"type":"debug_log","source":"mi_tag","message":"...","timestamp":...}
 * en su RemoteControlService.debugLogStream.
 */
object RemoteDebugLogger {

    private const val TAG = "RemoteDebug"

    @Volatile
    private var sendFn: ((String) -> Unit)? = null

    /** Inicializa el logger con la función de envío del servidor RFCOMM. */
    fun init(send: (String) -> Unit) {
        sendFn = send
        log("logger", "RemoteDebugLogger initialized")
    }

    fun detach() {
        sendFn = null
    }

    fun log(source: String, message: String) {
        Log.d(TAG, "[$source] $message")
        val fn = sendFn ?: return
        try {
            val obj = JSONObject()
            obj.put("type", "debug_log")
            obj.put("source", source)
            obj.put("message", message)
            obj.put("timestamp", System.currentTimeMillis())
            fn(obj.toString())
        } catch (_: Exception) {
            // Nunca bloquear por un fallo de log.
        }
    }
}
