package com.andodevs.connectremote

import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject

/**
 * Recibe los mensajes ya parseados del socket RFCOMM y los traduce a
 * gestos/overlay (modo cursor) o navegación por foco (modo D-pad).
 *
 * @param sendToPeer permite responder al emisor (p. ej. la lista de apps
 * instaladas) por el mismo socket que entregó el mensaje entrante.
 */
class RemoteInputController(
    private val context: Context,
    private val sendToPeer: (String) -> Unit = {}
) {

    // Expuesto para aplicar cambios en caliente desde OnboardingActivity
    val cursorOverlay = CursorOverlayView(context)

    // Auto-ocultar el cursor tras inactividad del touchpad y volver a
    // mostrarlo en cuanto llega actividad nueva.
    private val cursorIdleHandler = Handler(Looper.getMainLooper())
    private val cursorIdleRunnable = Runnable {
        if (mode == RemoteProtocol.MODE_CURSOR) cursorOverlay.hide()
    }

    private fun notifyCursorActivity() {
        if (mode != RemoteProtocol.MODE_CURSOR) return
        if (!cursorOverlay.isVisible()) cursorOverlay.show()
        cursorIdleHandler.removeCallbacks(cursorIdleRunnable)
        cursorIdleHandler.postDelayed(cursorIdleRunnable, CURSOR_IDLE_TIMEOUT_MS)
    }

    @Volatile
    var mode: String = if (isTelevision(context)) RemoteProtocol.MODE_DPAD else RemoteProtocol.MODE_CURSOR
        private set

    @Volatile
    var sensitivity: Float = 1.0f

    @Volatile
    var naturalScroll: Boolean = true

    fun start() {
        val isTV = isTelevision(context)
        RemoteDebugLogger.log("controller", "start isTV=$isTV mode=$mode svc=${RemoteAccessibilityService.instance != null}")
        if (mode == RemoteProtocol.MODE_CURSOR) {
            cursorOverlay.show()
        }
    }

    fun stop() {
        RemoteDebugLogger.log("controller", "stop")
        cursorIdleHandler.removeCallbacks(cursorIdleRunnable)
        cursorOverlay.hide()
    }

    fun handle(json: JSONObject) {
        val type = json.optString("type", "")
        RemoteDebugLogger.log("handle", "type=$type mode=$mode svc=${RemoteAccessibilityService.instance != null} overlay=${cursorOverlay.isVisible()}")
        when (type) {
            "remote_input" -> handleRemoteInput(json)
            "text" -> handleText(json)
            "set_text" -> handleSetText(json)
            "key" -> handleKey(json)
            "config" -> handleConfig(json)
            "apps_list_request" -> handleAppsListRequest()
            "launch_app" -> handleLaunchApp(json)
            else -> {}
        }
    }

    private fun handleAppsListRequest() {
        val apps = try {
            AppsListService.getLaunchableApps(context)
        } catch (_: Exception) {
            emptyList()
        }
        val arr = JSONArray()
        for (app in apps) {
            val obj = JSONObject()
            obj.put("packageName", app.packageName)
            obj.put("label", app.label)
            arr.put(obj)
        }
        val payload = JSONObject()
        payload.put("type", "apps_list")
        payload.put("apps", arr)
        sendToPeer(payload.toString())
    }

    private fun handleLaunchApp(json: JSONObject) {
        val pkg = json.optString("packageName", "").trim()
        if (pkg.isEmpty()) return
        AppsListService.launch(context, pkg)
    }

    private fun setMode(newMode: String) {
        if (newMode != RemoteProtocol.MODE_CURSOR && newMode != RemoteProtocol.MODE_DPAD) {
            RemoteDebugLogger.log("controller", "setMode invalid=$newMode")
            return
        }
        RemoteDebugLogger.log("controller", "setMode $mode -> $newMode svc=${RemoteAccessibilityService.instance != null}")
        if (mode == newMode) return
        mode = newMode
        cursorIdleHandler.removeCallbacks(cursorIdleRunnable)
        if (newMode == RemoteProtocol.MODE_CURSOR) {
            cursorOverlay.show()
        } else {
            cursorOverlay.hide()
        }
    }

    private fun handleConfig(json: JSONObject) {
        if (json.has("mode")) setMode(json.optString("mode", mode))
        if (json.has("sensitivity")) sensitivity = json.optDouble("sensitivity", sensitivity.toDouble()).toFloat()
        if (json.has("naturalScroll")) naturalScroll = json.optBoolean("naturalScroll", naturalScroll)
        RemoteDebugLogger.log("config", "mode=$mode sensitivity=$sensitivity")
    }

    private fun handleRemoteInput(json: JSONObject) {
        // No se filtra por mode: el emisor controla qué tipo de mensajes envía.
        // El cursor siempre rastrea posición; la overlay es opcional.
        val service = RemoteAccessibilityService.instance
        val action = json.optString("action", "")
        RemoteDebugLogger.log("input", "remote_input action=$action mode=$mode svc=${service != null} curX=${cursorOverlay.x} curY=${cursorOverlay.y}")
        notifyCursorActivity()
        when (action) {
            "move" -> {
                val dx = (json.optDouble("dx", 0.0) * sensitivity).toFloat()
                val dy = (json.optDouble("dy", 0.0) * sensitivity).toFloat()
                cursorOverlay.moveBy(dx, dy)
            }
            "tap" -> {
                val longPress = json.optString("button", "") == "right"
                service?.tap(cursorOverlay.x, cursorOverlay.y, longPress)
                    ?: RemoteDebugLogger.log("input", "tap: accessibility service null")
            }
            "double_tap" -> service?.doubleTap(cursorOverlay.x, cursorOverlay.y)
                ?: RemoteDebugLogger.log("input", "double_tap: accessibility service null")
            "scroll" -> {
                val dx = (json.optDouble("dx", 0.0) * (if (naturalScroll) 1 else -1)).toFloat()
                val dy = (json.optDouble("dy", 0.0) * (if (naturalScroll) 1 else -1)).toFloat()
                service?.scroll(cursorOverlay.x, cursorOverlay.y, dx, dy)
            }
            "down" -> service?.dragDown(cursorOverlay.x, cursorOverlay.y)
            "up" -> service?.dragUp(cursorOverlay.x, cursorOverlay.y)
            else -> {}
        }
    }

    private fun handleText(json: JSONObject) {
        val value = json.optString("value", "")
        if (value.isEmpty()) return
        RemoteAccessibilityService.instance?.insertText(value)
    }

    /**
     * Recibe el texto COMPLETO acumulado desde el teclado en tiempo real del
     * emisor y lo establece directamente con ACTION_SET_TEXT. Esto evita el
     * bug de Android 8+ donde node.text devuelve el hint en campos vacíos,
     * y elimina race conditions al tipear rápido.
     */
    private fun handleSetText(json: JSONObject) {
        val value = json.optString("value", "")
        RemoteAccessibilityService.instance?.setFullText(value)
    }

    private fun handleKey(json: JSONObject) {
        val key = json.optString("key", "")
        RemoteDebugLogger.log("key", "key=$key mode=$mode svc=${RemoteAccessibilityService.instance != null}")
        val service = RemoteAccessibilityService.instance ?: run {
            RemoteDebugLogger.log("key", "accessibility service null, key dropped")
            return
        }
        when (key) {
            "backspace" -> service.backspace()
            "enter" -> service.pressEnter()
            "space" -> service.insertText(" ")
            "back" -> service.performBack()
            "home" -> service.performHome()
            "recents" -> service.performRecents()
            "volume_up" -> service.adjustVolume(up = true)
            "volume_down" -> service.adjustVolume(up = false)
            "dpad_up", "dpad_down", "dpad_left", "dpad_right" -> service.performDpad(key)
            "dpad_center" -> {
                if (mode == RemoteProtocol.MODE_CURSOR) {
                    service.tap(cursorOverlay.x, cursorOverlay.y)
                } else {
                    service.performDpad(key)
                }
            }
            else -> {}
        }
    }

    companion object {
        const val CURSOR_IDLE_TIMEOUT_MS = 2000L

        fun isTelevision(context: Context): Boolean {
            return try {
                context.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
                    context.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEVISION)
            } catch (_: Exception) {
                false
            }
        }
    }
}
