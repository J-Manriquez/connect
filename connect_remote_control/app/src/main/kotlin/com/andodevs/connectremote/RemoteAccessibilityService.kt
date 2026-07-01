package com.andodevs.connectremote

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityService.GestureResultCallback
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.graphics.Path
import android.graphics.Point
import android.graphics.Rect
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Inyecta gestos (tap/scroll/drag) y teclas/navegación que llegan del emisor.
 * Es el único mecanismo viable sin root para simular mouse/teclado en Android.
 */
class RemoteAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: RemoteAccessibilityService? = null

        // GLOBAL_ACTION_DPAD_* añadidos en API 31 (Android 12). Se usan como
        // literales para evitar errores de compilación en minSdk 24.
        private const val GLOBAL_ACTION_DPAD_UP     = 16
        private const val GLOBAL_ACTION_DPAD_DOWN   = 17
        private const val GLOBAL_ACTION_DPAD_LEFT   = 18
        private const val GLOBAL_ACTION_DPAD_RIGHT  = 19
        private const val GLOBAL_ACTION_DPAD_CENTER = 20

        // Keycodes para shell fallback
        private const val KEYCODE_DPAD_UP     = 19
        private const val KEYCODE_DPAD_DOWN   = 20
        private const val KEYCODE_DPAD_LEFT   = 21
        private const val KEYCODE_DPAD_RIGHT  = 22
        private const val KEYCODE_DPAD_CENTER = 23

        fun isReady(): Boolean = instance != null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        RemoteDebugLogger.log("accessibility", "Service connected")
    }

    override fun onDestroy() {
        RemoteDebugLogger.log("accessibility", "Service destroyed")
        if (instance === this) instance = null
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    // ------------------------------------------------------------------
    // Gestos (modo cursor)
    // ------------------------------------------------------------------

    fun tap(x: Float, y: Float, longPress: Boolean = false) {
        RemoteDebugLogger.log("gesture", "tap x=$x y=$y longPress=$longPress")
        val path = Path().apply { moveTo(x, y) }
        val duration = if (longPress) 600L else 60L
        val stroke = GestureDescription.StrokeDescription(path, 0, duration)
        val ok = dispatchGesture(
            GestureDescription.Builder().addStroke(stroke).build(),
            object : GestureResultCallback() {
                override fun onCompleted(g: GestureDescription) {
                    RemoteDebugLogger.log("gesture", "tap completed x=$x y=$y")
                }
                override fun onCancelled(g: GestureDescription) {
                    RemoteDebugLogger.log("gesture", "tap CANCELLED x=$x y=$y")
                }
            },
            null
        )
        if (!ok) RemoteDebugLogger.log("gesture", "tap dispatch=false x=$x y=$y")
    }

    fun doubleTap(x: Float, y: Float) {
        tap(x, y)
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({ tap(x, y) }, 120L)
    }

    fun scroll(x: Float, y: Float, dx: Float, dy: Float) {
        val path = Path().apply {
            moveTo(x, y)
            lineTo(x - dx, y - dy)
        }
        dispatchGesture(
            GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 180L))
                .build(),
            null, null
        )
    }

    private var dragStroke: GestureDescription.StrokeDescription? = null
    private var dragLastX = 0f
    private var dragLastY = 0f

    fun dragDown(x: Float, y: Float) {
        val path = Path().apply { moveTo(x, y) }
        dragLastX = x; dragLastY = y
        val stroke = GestureDescription.StrokeDescription(path, 0, 500L, true)
        dragStroke = stroke
        dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
    }

    fun dragMove(x: Float, y: Float) {
        val prev = dragStroke ?: return
        val path = Path().apply { moveTo(dragLastX, dragLastY); lineTo(x, y) }
        dragLastX = x; dragLastY = y
        val cont = prev.continueStroke(path, 0, 80L, true)
        dragStroke = cont
        dispatchGesture(GestureDescription.Builder().addStroke(cont).build(), null, null)
    }

    fun dragUp(x: Float, y: Float) {
        val prev = dragStroke ?: return
        val path = Path().apply { moveTo(dragLastX, dragLastY); lineTo(x, y) }
        val fin = prev.continueStroke(path, 0, 80L, false)
        dispatchGesture(GestureDescription.Builder().addStroke(fin).build(), null, null)
        dragStroke = null
    }

    // ------------------------------------------------------------------
    // D-pad (modo TV)
    // ------------------------------------------------------------------

    /**
     * Navega en la dirección indicada. Estrategia por API:
     *
     * API 31+: performGlobalAction(GLOBAL_ACTION_DPAD_*) — KeyEvent real,
     *   funciona en cualquier app.
     *
     * API < 31 — tres estrategias en orden:
     *   1. Geometric nav: ACTION_ACCESSIBILITY_FOCUS + ACTION_FOCUS en el nodo
     *      enfocable más cercano en la dirección. Funciona en apps estándar
     *      (launcher, settings, etc.).
     *   2. Scroll action: ACTION_SCROLL_FORWARD / BACKWARD en el contenedor
     *      scrollable (RecyclerView). En apps leanback (YouTube TV), esto
     *      llama internamente a setSelectedPositionSmooth() desplazando la
     *      selección visual. Solo se activa cuando la navegación geométrica
     *      no obtuvo accesibility focus (a11y=false).
     *   3. Shell keyevent: `input keyevent` vía Runtime.exec(). Inconsistente
     *      en Android 9 sin root, pero se registra el exit code.
     */
    fun performDpad(direction: String): Boolean {
        RemoteDebugLogger.log("dpad", "performDpad dir=$direction api=${Build.VERSION.SDK_INT}")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val action = when (direction) {
                "dpad_up"     -> GLOBAL_ACTION_DPAD_UP
                "dpad_down"   -> GLOBAL_ACTION_DPAD_DOWN
                "dpad_left"   -> GLOBAL_ACTION_DPAD_LEFT
                "dpad_right"  -> GLOBAL_ACTION_DPAD_RIGHT
                "dpad_center" -> GLOBAL_ACTION_DPAD_CENTER
                else -> return false
            }
            val ok = performGlobalAction(action)
            RemoteDebugLogger.log("dpad", "globalAction=$action ok=$ok")
            return ok
        }

        // --- API < 31 ---

        if (direction == "dpad_center") {
            val centerOk = performCenter()
            val shellOk = if (!centerOk) injectKeyShell(KEYCODE_DPAD_CENTER) else false
            return centerOk || shellOk
        }

        val keycode = when (direction) {
            "dpad_up"    -> KEYCODE_DPAD_UP
            "dpad_down"  -> KEYCODE_DPAD_DOWN
            "dpad_left"  -> KEYCODE_DPAD_LEFT
            "dpad_right" -> KEYCODE_DPAD_RIGHT
            else -> return false
        }

        // Estrategia 1: navegación geométrica por árbol de accesibilidad
        val (geoOk, a11yMoved) = performGeometricNav(direction)

        // Estrategia 2: scroll sobre contenedor scrollable (YouTube TV / leanback).
        // Solo se activa cuando el nodo candidato no aceptó accessibility focus,
        // para no causar doble-navegación en apps donde la geo nav ya funcionó.
        val scrollOk = if (!a11yMoved) tryScrollAction(direction) else false

        // Estrategia 3: shell (a veces funciona en ciertos TV-boxes)
        val shellOk = injectKeyShell(keycode)

        return geoOk || scrollOk || shellOk
    }

    // ------------------------------------------------------------------
    // Center / click
    // ------------------------------------------------------------------

    /**
     * Intenta hacer click en el elemento enfocado/seleccionado.
     * Orden de prioridad:
     *   1. Nodo con isSelected=true (estado visual de selección en leanback)
     *   2. Nodo con accessibility focus
     *   3. Nodo con input focus
     *   4. Nodo clickable más cercano al centro de la pantalla
     */
    private fun performCenter(): Boolean {
        val root = try { rootInActiveWindow } catch (_: Exception) { null } ?: return false

        val target = findSelectedClickable(root)
            ?: try { root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY) } catch (_: Exception) { null }
            ?: try { root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) } catch (_: Exception) { null }
            ?: findClickableNearCenter(root)

        root.recycle()

        if (target == null) {
            RemoteDebugLogger.log("dpad", "center: no target found")
            return false
        }

        val ok = target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        RemoteDebugLogger.log("dpad", "center: click ok=$ok")
        target.recycle()
        return ok
    }

    /** Busca recursivamente el primer nodo seleccionado y clickable. */
    private fun findSelectedClickable(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (!node.isVisibleToUser) return null
        if (node.isSelected && node.isClickable) return AccessibilityNodeInfo.obtain(node)
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findSelectedClickable(child)
            child.recycle()
            if (result != null) return result
        }
        return null
    }

    /** Devuelve el nodo clickable cuyo centro es más cercano al centro de pantalla. */
    private fun findClickableNearCenter(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        val (sw, sh) = screenSize()
        val cx = sw / 2f
        val cy = sh / 2f

        val candidates = mutableListOf<Pair<AccessibilityNodeInfo, Rect>>()
        collectClickableNodes(root, candidates)

        var best: AccessibilityNodeInfo? = null
        var bestDist = Float.MAX_VALUE

        for ((node, bounds) in candidates) {
            val dx = bounds.exactCenterX() - cx
            val dy = bounds.exactCenterY() - cy
            val dist = dx * dx + dy * dy
            if (dist < bestDist) {
                best?.recycle()
                bestDist = dist
                best = node
            } else {
                node.recycle()
            }
        }
        return best
    }

    private fun collectClickableNodes(
        node: AccessibilityNodeInfo,
        result: MutableList<Pair<AccessibilityNodeInfo, Rect>>
    ) {
        if (!node.isVisibleToUser) return
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        if (node.isClickable && !bounds.isEmpty) {
            result.add(AccessibilityNodeInfo.obtain(node) to Rect(bounds))
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectClickableNodes(child, result)
            child.recycle()
        }
    }

    // ------------------------------------------------------------------
    // Geometric nav
    // ------------------------------------------------------------------

    /**
     * Encuentra el nodo enfocable más cercano en [direction] al nodo
     * actualmente enfocado, usando distancia geométrica en pantalla.
     *
     * Scoring: score = distancia_primaria + 2 × desplazamiento_lateral
     * (igual que Android AOSP FocusFinder para D-pad).
     *
     * @return Pair(anyOk, a11yMoved) donde anyOk = cualquier acción tuvo efecto,
     *         a11yMoved = ACTION_ACCESSIBILITY_FOCUS fue aceptado.
     */
    private fun performGeometricNav(direction: String): Pair<Boolean, Boolean> {
        val root = try { rootInActiveWindow } catch (_: Exception) { null }
            ?: return false to false

        val focused = try {
            root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)
                ?: root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        } catch (_: Exception) { null }

        val fromBounds = Rect()
        if (focused != null) {
            focused.getBoundsInScreen(fromBounds)
        } else {
            val (sw, sh) = screenSize()
            fromBounds.set(sw / 2, sh / 2, sw / 2, sh / 2)
        }

        val candidates = mutableListOf<Pair<AccessibilityNodeInfo, Rect>>()
        collectFocusableNodes(root, candidates)
        root.recycle()

        val fromCx = fromBounds.exactCenterX()
        val fromCy = fromBounds.exactCenterY()

        var best: AccessibilityNodeInfo? = null
        var bestScore = Float.MAX_VALUE

        for ((node, bounds) in candidates) {
            if (bounds.isEmpty) continue
            if (focused != null && bounds == fromBounds) continue

            val cx = bounds.exactCenterX()
            val cy = bounds.exactCenterY()

            val inDirection = when (direction) {
                "dpad_up"    -> cy < fromCy - 2f
                "dpad_down"  -> cy > fromCy + 2f
                "dpad_left"  -> cx < fromCx - 2f
                "dpad_right" -> cx > fromCx + 2f
                else -> false
            }
            if (!inDirection) continue

            val primary = when (direction) {
                "dpad_up"    -> fromCy - cy
                "dpad_down"  -> cy - fromCy
                "dpad_left"  -> fromCx - cx
                "dpad_right" -> cx - fromCx
                else -> 0f
            }
            val lateral = when (direction) {
                "dpad_up", "dpad_down" -> Math.abs(cx - fromCx)
                else                   -> Math.abs(cy - fromCy)
            }

            val score = primary + lateral * 2f
            if (score < bestScore) {
                bestScore = score
                best?.recycle()
                best = AccessibilityNodeInfo.obtain(node)
            }
        }

        candidates.forEach { it.first.recycle() }
        focused?.recycle()

        if (best == null) {
            RemoteDebugLogger.log("dpad", "geometric dir=$direction no candidate")
            return false to false
        }

        val a11y = best.performAction(AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS)
        val input = best.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
        RemoteDebugLogger.log("dpad", "geometric dir=$direction score=$bestScore a11y=$a11y input=$input")
        best.recycle()
        return (a11y || input) to a11y
    }

    /** Recolecta recursivamente todos los nodos enfocables/clicables visibles. */
    private fun collectFocusableNodes(
        node: AccessibilityNodeInfo,
        result: MutableList<Pair<AccessibilityNodeInfo, Rect>>
    ) {
        if (!node.isVisibleToUser) return
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        if ((node.isFocusable || node.isClickable) && !bounds.isEmpty) {
            result.add(AccessibilityNodeInfo.obtain(node) to Rect(bounds))
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectFocusableNodes(child, result)
            child.recycle()
        }
    }

    // ------------------------------------------------------------------
    // Scroll action (estrategia 2 para leanback / RecyclerView apps)
    // ------------------------------------------------------------------

    /**
     * Aplica ACTION_SCROLL_FORWARD o BACKWARD al contenedor scrollable más
     * adecuado. En apps leanback (YouTube TV), BaseGridView responde a estos
     * actions moviéndose al siguiente ítem visualmente (setSelectedPositionSmooth).
     * En RecyclerViews estándar, simplemente desplaza el contenido.
     *
     * Orientación preferida: UP/DOWN → busca contenedor más alto que ancho
     * (scroll vertical). LEFT/RIGHT → busca contenedor más ancho que alto.
     */
    private fun tryScrollAction(direction: String): Boolean {
        val scrollAction = when (direction) {
            "dpad_down", "dpad_right" -> AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
            "dpad_up",   "dpad_left"  -> AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
            else -> return false
        }
        val preferVertical = direction == "dpad_up" || direction == "dpad_down"

        val root = try { rootInActiveWindow } catch (_: Exception) { null } ?: return false
        val scrollable = findScrollableForDirection(root, preferVertical)
        root.recycle()

        if (scrollable == null) {
            RemoteDebugLogger.log("dpad", "scroll dir=$direction no scrollable")
            return false
        }

        val ok = scrollable.performAction(scrollAction)
        RemoteDebugLogger.log("dpad", "scroll dir=$direction action=$scrollAction ok=$ok")
        scrollable.recycle()
        return ok
    }

    /**
     * Recolecta todos los nodos scrollables visibles y devuelve el que mejor
     * coincide con la orientación de desplazamiento deseada.
     */
    private fun findScrollableForDirection(
        root: AccessibilityNodeInfo,
        preferVertical: Boolean
    ): AccessibilityNodeInfo? {
        val all = mutableListOf<Pair<AccessibilityNodeInfo, Rect>>()
        collectScrollableNodes(root, all)
        if (all.isEmpty()) return null

        // Preferir el scrollable cuya orientación (aspect ratio) coincide
        val preferred = all.firstOrNull { (_, b) ->
            if (preferVertical) b.height() >= b.width() else b.width() > b.height()
        } ?: all.first()

        // Reciclar los que no se usan
        all.filter { it !== preferred }.forEach { (n, _) -> n.recycle() }
        return preferred.first
    }

    private fun collectScrollableNodes(
        node: AccessibilityNodeInfo,
        result: MutableList<Pair<AccessibilityNodeInfo, Rect>>
    ) {
        if (!node.isVisibleToUser) return
        if (node.isScrollable) {
            val bounds = Rect()
            node.getBoundsInScreen(bounds)
            if (!bounds.isEmpty) result.add(AccessibilityNodeInfo.obtain(node) to Rect(bounds))
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectScrollableNodes(child, result)
            child.recycle()
        }
    }

    // ------------------------------------------------------------------
    // Shell fallback
    // ------------------------------------------------------------------

    /** Inyecta un keyevent vía shell. Registra el exit code para diagnóstico. */
    private fun injectKeyShell(keycode: Int): Boolean {
        val candidates = listOf(
            arrayOf("input", "keyevent", keycode.toString()),
            arrayOf("sh", "-c", "input keyevent $keycode"),
            arrayOf("/system/bin/input", "keyevent", keycode.toString()),
        )
        for (cmd in candidates) {
            try {
                val exitCode = Runtime.getRuntime().exec(cmd).waitFor()
                RemoteDebugLogger.log("dpad", "shell cmd=${cmd[0]} keyevent=$keycode exitCode=$exitCode")
                if (exitCode == 0) return true
            } catch (e: Exception) {
                RemoteDebugLogger.log("dpad", "shell cmd=${cmd[0]} failed err=${e.message}")
            }
        }
        return false
    }

    // ------------------------------------------------------------------
    // Volumen y navegación global
    // ------------------------------------------------------------------

    fun adjustVolume(up: Boolean) {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val dir = if (up) AudioManager.ADJUST_RAISE else AudioManager.ADJUST_LOWER
            am.adjustStreamVolume(AudioManager.STREAM_MUSIC, dir, AudioManager.FLAG_SHOW_UI)
            RemoteDebugLogger.log("volume", if (up) "up" else "down")
        } catch (e: Exception) {
            RemoteDebugLogger.log("volume", "error=${e.message}")
        }
    }

    fun performBack(): Boolean = performGlobalAction(GLOBAL_ACTION_BACK)
    fun performHome(): Boolean = performGlobalAction(GLOBAL_ACTION_HOME)
    fun performRecents(): Boolean = performGlobalAction(GLOBAL_ACTION_RECENTS)

    // ------------------------------------------------------------------
    // Texto / teclado
    // ------------------------------------------------------------------

    /**
     * Reemplaza el texto completo del campo enfocado con [fullText].
     * Usado por el teclado en tiempo real del emisor: el emisor envía
     * el texto acumulado completo, evitando problemas con hint text de
     * Android 8+ (que node.text devuelve el hint cuando el campo está vacío)
     * y race conditions al tipear rápido.
     */
    fun setFullText(fullText: String) {
        val node = findFocusedEditableNode() ?: return
        try { setNodeText(node, fullText) }
        finally { node.recycle() }
    }

    fun insertText(text: String) {
        val node = findFocusedEditableNode() ?: return
        try {
            // En API 26+, node.text devuelve el hint cuando el campo está
            // vacío y mostrando hint text. En ese caso tratar como "".
            val current = if (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                node.isShowingHintText
            ) {
                ""
            } else {
                node.text?.toString().orEmpty()
            }
            setNodeText(node, current + text)
        } finally { node.recycle() }
    }

    fun backspace() {
        val node = findFocusedEditableNode() ?: return
        try {
            val current = if (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                node.isShowingHintText
            ) {
                ""
            } else {
                node.text?.toString().orEmpty()
            }
            if (current.isNotEmpty()) setNodeText(node, current.dropLast(1))
        } finally { node.recycle() }
    }

    fun pressEnter(): Boolean {
        val node = findFocusedEditableNode()
        if (node != null) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val ok = node.performAction(
                        AccessibilityNodeInfo.AccessibilityAction.ACTION_IME_ENTER.id
                    )
                    if (ok) return true
                }
            } finally { node.recycle() }
        }
        return false
    }

    // ------------------------------------------------------------------
    // Helpers privados
    // ------------------------------------------------------------------

    private fun setNodeText(node: AccessibilityNodeInfo, text: String) {
        val args = Bundle()
        args.putCharSequence(
            AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text
        )
        node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    private fun findFocusedEditableNode(): AccessibilityNodeInfo? {
        val node = findFocusedNode() ?: return null
        return if (node.isEditable) node else { node.recycle(); null }
    }

    private fun findFocusedNode(): AccessibilityNodeInfo? {
        return try {
            findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                ?: rootInActiveWindow?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        } catch (_: Exception) { null }
    }

    private fun screenSize(): Pair<Int, Int> {
        return try {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val b = wm.currentWindowMetrics.bounds
                b.width() to b.height()
            } else {
                val p = Point()
                @Suppress("DEPRECATION")
                wm.defaultDisplay.getSize(p)
                p.x to p.y
            }
        } catch (_: Exception) { 1920 to 1080 }
    }
}
