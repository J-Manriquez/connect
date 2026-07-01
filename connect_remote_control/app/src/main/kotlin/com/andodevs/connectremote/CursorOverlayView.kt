package com.andodevs.connectremote

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.WindowManager
import android.widget.ImageView
import kotlin.math.max
import kotlin.math.min

/**
 * Cursor flotante para el modo touchpad remoto.
 *
 * WindowManager.addView / updateViewLayout / removeView DEBEN ejecutarse en el
 * main thread. Esta clase recibe llamadas desde el hilo RFCOMM (Thread-5) y
 * despacha todas las operaciones UI al main thread.
 *
 * Fluidez mejorada con Choreographer: en vez de postear un updateViewLayout
 * por cada moveBy (que puede inundar el main looper), se acumula la posición
 * destino y solo se aplica UNA vez por frame de Vsync. Esto elimina el
 * stuttering que ocurría cuando varios paquetes de movimiento llegaban en el
 * mismo intervalo de frame.
 */
class CursorOverlayView(private val context: Context) {

    private val mainHandler = Handler(Looper.getMainLooper())

    // Tamaño del cursor en dp (configurable desde los ajustes del receptor).
    // El valor 0 usa el tamaño por defecto del drawable (WRAP_CONTENT).
    @Volatile var cursorSizeDp: Int = 0

    @Volatile private var windowManager: WindowManager? = null
    @Volatile private var view: ImageView? = null
    @Volatile private var params: WindowManager.LayoutParams? = null
    @Volatile private var wanted = false

    @Volatile var x: Float = 0f
        private set
    @Volatile var y: Float = 0f
        private set

    // Posición acumulada; solo se aplica una vez por ciclo del main looper
    // (flag movePosted colapsa varios moveBy en un solo updateViewLayout).
    @Volatile private var pendingFrameX: Float = 0f
    @Volatile private var pendingFrameY: Float = 0f
    @Volatile private var movePosted = false

    private var screenWidth = 0
    private var screenHeight = 0
    private var lastCreateAttemptAtMs = 0L
    private var lastAttemptedType = -1

    // ------------------------------------------------------------------
    // API pública (puede llamarse desde cualquier hilo)
    // ------------------------------------------------------------------

    fun show() {
        wanted = true
        ensureScreenSizeKnown()
        attemptCreateView()
    }

    fun hide() {
        wanted = false
        mainHandler.post {
            val wm = windowManager
            val v = view
            if (wm != null && v != null) {
                try { wm.removeView(v) } catch (_: Exception) {}
            }
            view = null
            params = null
        }
    }

    fun isVisible(): Boolean = view != null

    /**
     * Mueve el cursor [dx],[dy] píxeles. Acumula la posición destino y despacha
     * UN SOLO updateViewLayout por ciclo del main looper (varios paquetes RFCOMM
     * que lleguen antes de que el looper los procese se colapsan en uno solo).
     */
    fun moveBy(dx: Float, dy: Float) {
        ensureScreenSizeKnown()
        x = clamp(x + dx, 0f, screenWidth.toFloat())
        y = clamp(y + dy, 0f, screenHeight.toFloat())
        pendingFrameX = x
        pendingFrameY = y

        if (view != null) {
            if (!movePosted) {
                movePosted = true
                mainHandler.post { applyPendingPosition() }
            }
        } else if (wanted) {
            attemptCreateView()
        }
    }

    private fun applyPendingPosition() {
        movePosted = false
        val v = view ?: return
        val lp = params ?: return
        val wm = windowManager ?: return
        lp.x = pendingFrameX.toInt()
        lp.y = pendingFrameY.toInt()
        try {
            wm.updateViewLayout(v, lp)
        } catch (_: Exception) {
            view = null
            params = null
        }
    }

    // ------------------------------------------------------------------
    // Internals
    // ------------------------------------------------------------------

    private fun attemptCreateView() {
        if (!wanted) return
        val now = System.currentTimeMillis()

        val svc = RemoteAccessibilityService.instance
        val overlayCtx: Context = svc ?: context

        val type = when {
            svc != null -> WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ->
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else -> @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }

        if (type == lastAttemptedType && now - lastCreateAttemptAtMs < 2000L) return
        lastCreateAttemptAtMs = now
        lastAttemptedType = type

        RemoteDebugLogger.log("overlay", "attempting type=$type via_svc=${svc != null}")

        mainHandler.post {
            if (view != null || !wanted) return@post
            try {
                val wm = (overlayCtx.getSystemService(Context.WINDOW_SERVICE) as WindowManager)
                    .also { windowManager = it }
                val iv = ImageView(context)
                iv.setImageResource(R.drawable.cursor_pointer)

                // Aplicar tamaño configurado (0 = usar WRAP_CONTENT del drawable)
                val sizePx = if (cursorSizeDp > 0) dpToPx(cursorSizeDp) else WindowManager.LayoutParams.WRAP_CONTENT

                val lp = WindowManager.LayoutParams(
                    sizePx,
                    sizePx,
                    type,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                    PixelFormat.TRANSLUCENT
                )
                lp.gravity = Gravity.TOP or Gravity.START
                lp.x = x.toInt()
                lp.y = y.toInt()
                wm.addView(iv, lp)
                view = iv
                params = lp
                RemoteDebugLogger.log("overlay", "created ok at x=${lp.x} y=${lp.y} sizeDp=$cursorSizeDp")
            } catch (e: Exception) {
                lastAttemptedType = -1
                RemoteDebugLogger.log("overlay", "failed err=${e.message}")
            }
        }
    }

    /** Actualiza el tamaño del cursor en caliente si ya está visible. */
    fun applyCursorSize() {
        mainHandler.post {
            val v = view ?: return@post
            val lp = params ?: return@post
            val wm = windowManager ?: return@post
            val sizePx = if (cursorSizeDp > 0) dpToPx(cursorSizeDp) else WindowManager.LayoutParams.WRAP_CONTENT
            lp.width = sizePx
            lp.height = sizePx
            try { wm.updateViewLayout(v, lp) } catch (_: Exception) {}
        }
    }

    private fun dpToPx(dp: Int): Int {
        val density = context.resources.displayMetrics.density
        return (dp * density + 0.5f).toInt()
    }

    private fun clamp(value: Float, minV: Float, maxV: Float): Float =
        max(minV, min(value, maxV))

    private fun ensureScreenSizeKnown() {
        if (screenWidth > 0 && screenHeight > 0) return
        try {
            val wm = windowManager
                ?: (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager)
                    .also { windowManager = it }
            readScreenSize(wm)
        } catch (_: Exception) {
            screenWidth = 1920
            screenHeight = 1080
        }
        if (x == 0f && y == 0f) {
            x = screenWidth / 2f
            y = screenHeight / 2f
        }
    }

    private fun readScreenSize(wm: WindowManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = wm.currentWindowMetrics.bounds
            screenWidth = bounds.width()
            screenHeight = bounds.height()
        } else {
            @Suppress("DEPRECATION")
            val size = android.graphics.Point()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getSize(size)
            screenWidth = size.x
            screenHeight = size.y
        }
    }
}
