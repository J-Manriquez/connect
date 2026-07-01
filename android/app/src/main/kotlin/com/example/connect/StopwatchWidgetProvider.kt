package com.example.connect

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.util.Base64
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray

// ── Modelo de configuración del widget ──────────────────────────────────────────────────

data class SwWidgetCfg(
    val bgArgb: Int,
    val timeColor: Int,
    val timeSizeSp: Int,
    val timeBold: Boolean,
    val showMs: Boolean,
    val timeFormat: String,
    val lapColor: Int,
    val lapSizeSp: Int,
    val lapBold: Boolean,
    val lapCount: Int,
    val showLapNumber: Boolean,
    val showLapDelta: Boolean,
    val modeLabelColor: Int,
    val modeLabelSizeSp: Int,
    val iconColor: Int,
    val iconColorEnabled: Boolean,
    val iconSizeDp: Int,
    val iconPlay: String,
    val iconPause: String,
    val iconReset: String,
    val iconLap: String,
    val iconToggleMode: String,
    val ringTrackArgb: Int,
    val ringFillArgb: Int,
    val ringThicknessDp: Int,
    val barTrackArgb: Int,
    val barFillArgb: Int,
    val barThicknessDp: Int,
    val cornerRadiusDp: Int,
    val rowSpacingDp: Int,
    val contentScalePct: Int,
    val labelIdle: String,
    val labelPaused: String,
    val labelStopwatch: String,
    val labelTimer: String,
    val lapPrefix: String,
    val defaultMode: String,
    val timerStepMinutes: Int,
)

data class SwState(
    val mode: String,
    val state: String,
    val elapsed: Long,
    val remaining: Long,
    val timerTarget: Long,
    val laps: List<LapData>,
)

data class LapData(val number: Int, val elapsed: Long, val delta: Long)

// ── Proveedor base ────────────────────────────────────────────────────────────────────────

abstract class BaseStopwatchWidgetProvider : AppWidgetProvider() {
    protected abstract val layoutResId: Int

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) render(context, mgr, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_START_PAUSE    -> toggleStartPause(context)
            ACTION_RESET          -> sendToService(context, StopwatchTimerFgService.ACTION_RESET)
            ACTION_LAP            -> sendToService(context, StopwatchTimerFgService.ACTION_LAP)
            ACTION_TOGGLE_MODE    -> toggleMode(context)
            ACTION_OPEN_APP       -> openApp(context)
            ACTION_TIMER_ADD_STEP -> adjustTimerStep(context, add = true)
            ACTION_TIMER_SUB_STEP -> adjustTimerStep(context, add = false)
        }
    }

    private fun toggleStartPause(context: Context) {
        val prefs = getPrefs(context)
        val state = prefs.getString(StopwatchTimerFgService.KEY_STATE, StopwatchTimerFgService.STATE_IDLE) ?: ""
        if (state == StopwatchTimerFgService.STATE_RUNNING) {
            sendToService(context, StopwatchTimerFgService.ACTION_PAUSE)
        } else {
            sendToService(context, StopwatchTimerFgService.ACTION_START)
        }
    }

    private fun toggleMode(context: Context) {
        val prefs   = getPrefs(context)
        val current = prefs.getString(StopwatchTimerFgService.KEY_MODE, StopwatchTimerFgService.MODE_STOPWATCH) ?: ""
        val newMode = if (current == StopwatchTimerFgService.MODE_STOPWATCH)
            StopwatchTimerFgService.MODE_TIMER else StopwatchTimerFgService.MODE_STOPWATCH
        sendToServiceWithMode(context, StopwatchTimerFgService.ACTION_SET_MODE, newMode)
    }

    private fun adjustTimerStep(context: Context, add: Boolean) {
        val prefs  = getPrefs(context)
        val cfgId  = layoutIdToCfgId()
        val cfg    = readWidgetCfg(prefs, cfgId)
        val stepMs = cfg.timerStepMinutes * 60_000L
        val i = Intent(context, StopwatchTimerFgService::class.java)
            .setAction(if (add) StopwatchTimerFgService.ACTION_TIMER_ADD_STEP
                       else     StopwatchTimerFgService.ACTION_TIMER_SUB_STEP)
            .putExtra(StopwatchTimerFgService.EXTRA_TIMER_STEP_MS, stepMs)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(i)
            else context.startService(i)
        } catch (_: Exception) { context.startService(i) }
    }

    private fun sendToService(context: Context, action: String) {
        val i = Intent(context, StopwatchTimerFgService::class.java).setAction(action)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(i)
            else context.startService(i)
        } catch (_: Exception) { context.startService(i) }
    }

    private fun sendToServiceWithMode(context: Context, action: String, mode: String) {
        val i = Intent(context, StopwatchTimerFgService::class.java).setAction(action)
            .putExtra(StopwatchTimerFgService.EXTRA_MODE, mode)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(i)
            else context.startService(i)
        } catch (_: Exception) { context.startService(i) }
    }

    private fun openApp(context: Context) {
        val i = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
        i.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        i.putExtra("navigate_to", "stopwatch_timer")
        context.startActivity(i)
    }

    private fun render(context: Context, mgr: AppWidgetManager, id: Int) {
        try {
            val prefs = getPrefs(context)
            val cfgId = layoutIdToCfgId()
            val cfg   = readWidgetCfg(prefs, cfgId)
            val state = readState(prefs)
            val views = buildRemoteViews(context, cfg, state, layoutResId, this.javaClass)
            mgr.updateAppWidget(id, views)
        } catch (e: Exception) {
            android.util.Log.e("SwWidget", "render error: ${e.message}")
        }
    }

    protected open fun layoutIdToCfgId(): String = when (layoutResId) {
        R.layout.widget_stopwatch_style1 -> "style1"
        R.layout.widget_stopwatch_style3 -> "style3"
        else -> "style1"
    }

    companion object {
        // Acciones propias del widget
        const val ACTION_START_PAUSE    = "com.example.connect.sw_widget.START_PAUSE"
        const val ACTION_RESET          = "com.example.connect.sw_widget.RESET"
        const val ACTION_LAP            = "com.example.connect.sw_widget.LAP"
        const val ACTION_TOGGLE_MODE    = "com.example.connect.sw_widget.TOGGLE_MODE"
        const val ACTION_OPEN_APP       = "com.example.connect.sw_widget.OPEN_APP"
        const val ACTION_TIMER_ADD_STEP = "com.example.connect.sw_widget.TIMER_ADD_STEP"
        const val ACTION_TIMER_SUB_STEP = "com.example.connect.sw_widget.TIMER_SUB_STEP"

        fun getPrefs(context: Context): SharedPreferences =
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // ── Lectura de estado ──────────────────────────────────────────────────────────────

        fun readState(prefs: SharedPreferences): SwState {
            val mode     = prefs.getString(StopwatchTimerFgService.KEY_MODE,  StopwatchTimerFgService.MODE_STOPWATCH) ?: StopwatchTimerFgService.MODE_STOPWATCH
            val state    = prefs.getString(StopwatchTimerFgService.KEY_STATE, StopwatchTimerFgService.STATE_IDLE)     ?: StopwatchTimerFgService.STATE_IDLE
            val start    = prefs.getLong(StopwatchTimerFgService.KEY_START, 0L)
            val accum    = prefs.getLong(StopwatchTimerFgService.KEY_ACCUM, 0L)
            val tgtMs    = prefs.getLong(StopwatchTimerFgService.KEY_TIMER_TGT, 5 * 60_000L)
            val remMs    = prefs.getLong(StopwatchTimerFgService.KEY_TIMER_REM, tgtMs)

            val elapsed = if (state == StopwatchTimerFgService.STATE_RUNNING && mode == StopwatchTimerFgService.MODE_STOPWATCH)
                accum + (System.currentTimeMillis() - start)
            else
                accum

            val remaining = if (state == StopwatchTimerFgService.STATE_RUNNING && mode == StopwatchTimerFgService.MODE_TIMER) {
                val e = System.currentTimeMillis() - start
                (tgtMs - e).coerceAtLeast(0L)
            } else remMs

            val lapsJson = prefs.getString(StopwatchTimerFgService.KEY_LAPS, "[]") ?: "[]"
            val laps = mutableListOf<LapData>()
            try {
                val arr = JSONArray(lapsJson)
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    laps.add(LapData(obj.optInt("number", i + 1), obj.getLong("elapsed"), obj.optLong("delta", 0L)))
                }
            } catch (_: Exception) { }

            return SwState(mode, state, elapsed, remaining, tgtMs, laps)
        }

        // ── Lectura de configuración (defaults espejo de StopwatchWidgetConfigService.dart) ──

        fun readWidgetCfg(prefs: SharedPreferences, id: String): SwWidgetCfg {
            fun int(prop: String, def: Int)    = prefs.getInt("flutter.stopwatch_cfg_${id}_${prop}", def)
            fun bool(prop: String, def: Boolean) = StopwatchTimerFgService.readFlutterBool(prefs, "flutter.stopwatch_cfg_${id}_${prop}", def)
            fun str(prop: String, def: String)  = (prefs.getString("flutter.stopwatch_cfg_${id}_${prop}", def) ?: def)

            return SwWidgetCfg(
                bgArgb           = int("bgArgb",            0xCC000000.toInt()),
                timeColor        = int("timeColor",          0xFFFFFFFF.toInt()),
                timeSizeSp       = int("timeSizeSp",         28),
                timeBold         = bool("timeBold",          true),
                showMs           = bool("showMs",            true),
                timeFormat       = str("timeFormat",         "hms"),
                lapColor         = int("lapColor",           0xFFCCCCCC.toInt()),
                lapSizeSp        = int("lapSizeSp",          11),
                lapBold          = bool("lapBold",           false),
                lapCount         = int("lapCount",           3),
                showLapNumber    = bool("showLapNumber",     true),
                showLapDelta     = bool("showLapDelta",      true),
                modeLabelColor   = int("modeLabelColor",     0xFF88AAFF.toInt()),
                modeLabelSizeSp  = int("modeLabelSizeSp",    9),
                iconColor        = int("iconColor",          0xFFFFFFFF.toInt()),
                iconColorEnabled = bool("iconColorEnabled",  true),
                iconSizeDp       = int("iconSizeDp",         24),
                iconPlay         = str("iconPlay",           ""),
                iconPause        = str("iconPause",          ""),
                iconReset        = str("iconReset",          ""),
                iconLap          = str("iconLap",            ""),
                iconToggleMode   = str("iconToggleMode",     ""),
                ringTrackArgb    = int("ringTrackArgb",      0x33FFFFFF),
                ringFillArgb     = int("ringFillArgb",       0xFF4488FF.toInt()),
                ringThicknessDp  = int("ringThicknessDp",    8),
                barTrackArgb     = int("barTrackArgb",       0x33FFFFFF),
                barFillArgb      = int("barFillArgb",        0xFF4488FF.toInt()),
                barThicknessDp   = int("barThicknessDp",     4),
                cornerRadiusDp   = int("cornerRadiusDp",     12),
                rowSpacingDp     = int("rowSpacingDp",       4),
                contentScalePct  = int("contentScalePct",    100),
                labelIdle        = str("labelIdle",          "Listo"),
                labelPaused      = str("labelPaused",        "Pausado"),
                labelStopwatch   = str("labelStopwatch",     "CRONÓMETRO"),
                labelTimer       = str("labelTimer",         "TEMPORIZADOR"),
                lapPrefix        = str("lapPrefix",          "V"),
                defaultMode      = str("defaultMode",        StopwatchTimerFgService.MODE_STOPWATCH),
                timerStepMinutes = int("timerStepMinutes",   5),
            )
        }

        // ── Construcción de RemoteViews ────────────────────────────────────────────────────

        fun buildRemoteViews(
            context: Context,
            cfg: SwWidgetCfg,
            state: SwState,
            layoutResId: Int,
            providerClass: Class<*>,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, layoutResId)

            views.setInt(R.id.sw_root, "setBackgroundColor", cfg.bgArgb)

            // Texto de tiempo (sin milisegundos — widget actualiza ~1s)
            val timeText = formatTime(
                if (state.mode == StopwatchTimerFgService.MODE_TIMER) state.remaining else state.elapsed
            )
            views.setTextViewText(R.id.sw_time, timeText)
            views.setTextColor(R.id.sw_time, cfg.timeColor)
            views.setFloat(R.id.sw_time, "setTextSize", cfg.timeSizeSp.toFloat())

            // PendingIntents de botones comunes
            views.setOnClickPendingIntent(R.id.btn_start_pause,
                makeActionIntent(context, ACTION_START_PAUSE, providerClass, 10))
            views.setOnClickPendingIntent(R.id.btn_reset,
                makeActionIntent(context, ACTION_RESET, providerClass, 11))

            // ── Por estilo ──────────────────────────────────────────────────────────────────

            when (layoutResId) {
                R.layout.widget_stopwatch_style1 -> buildStyle1(context, views, cfg, state, providerClass)
                R.layout.widget_stopwatch_style3 -> buildStyle3(context, views, cfg, state, providerClass)
            }

            // Iconos de play/pause según estado
            applyPlayPauseIcon(views, cfg, state)

            // Tap en el tiempo → abre app
            views.setOnClickPendingIntent(R.id.sw_time,
                makeActionIntent(context, ACTION_OPEN_APP, providerClass, 15))

            return views
        }

        private fun buildStyle1(
            context: Context, views: RemoteViews, cfg: SwWidgetCfg,
            state: SwState, cls: Class<*>
        ) {
            val isTimer = state.mode == StopwatchTimerFgService.MODE_TIMER

            // Etiqueta de modo como título
            val modeText = if (isTimer) cfg.labelTimer else cfg.labelStopwatch
            views.setTextViewText(R.id.sw_mode_label, modeText)
            views.setTextColor(R.id.sw_mode_label, cfg.modeLabelColor)
            views.setFloat(R.id.sw_mode_label, "setTextSize", cfg.modeLabelSizeSp.toFloat())

            // Botón de vuelta (solo cronómetro)
            views.setViewVisibility(R.id.btn_lap,
                if (!isTimer) View.VISIBLE else View.GONE)
            views.setOnClickPendingIntent(R.id.btn_lap,
                makeActionIntent(context, ACTION_LAP, cls, 12))

            // Botón cambiar modo
            views.setOnClickPendingIntent(R.id.btn_toggle_mode,
                makeActionIntent(context, ACTION_TOGGLE_MODE, cls, 13))

            // Botones de paso para temporizador (solo en modo timer)
            views.setViewVisibility(R.id.btn_timer_sub,
                if (isTimer) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.btn_timer_add,
                if (isTimer) View.VISIBLE else View.GONE)
            views.setOnClickPendingIntent(R.id.btn_timer_sub,
                makeActionIntent(context, ACTION_TIMER_SUB_STEP, cls, 14))
            views.setOnClickPendingIntent(R.id.btn_timer_add,
                makeActionIntent(context, ACTION_TIMER_ADD_STEP, cls, 16))
        }

        private fun buildStyle3(
            context: Context, views: RemoteViews, cfg: SwWidgetCfg,
            state: SwState, cls: Class<*>
        ) {
            // Anillo de progreso como Bitmap
            val sizePx = dpToPx(context, 90)
            val thickPx = dpToPx(context, cfg.ringThicknessDp)
            val progress: Float = when {
                state.mode == StopwatchTimerFgService.MODE_TIMER && state.timerTarget > 0 ->
                    (state.remaining.toFloat() / state.timerTarget).coerceIn(0f, 1f)
                state.mode == StopwatchTimerFgService.MODE_STOPWATCH -> {
                    val lapTarget = if (state.laps.isEmpty()) 60_000L
                    else state.laps.last().elapsed / state.laps.size
                    val currentLapElapsed = if (state.laps.isEmpty()) state.elapsed
                    else (state.elapsed - state.laps.last().elapsed).coerceAtLeast(0L)
                    (currentLapElapsed.toFloat() / lapTarget.coerceAtLeast(1L)).let {
                        it - it.toLong()
                    }.coerceIn(0f, 1f)
                }
                else -> 0f
            }
            val ring = drawRing(sizePx, cfg.ringTrackArgb, cfg.ringFillArgb, thickPx, progress)
            views.setImageViewBitmap(R.id.sw_ring, ring)

            // Etiqueta de modo
            val modeText = if (state.mode == StopwatchTimerFgService.MODE_TIMER) cfg.labelTimer else cfg.labelStopwatch
            views.setTextViewText(R.id.sw_mode_label, modeText)
            views.setTextColor(R.id.sw_mode_label, cfg.modeLabelColor)

            // Vueltas (más reciente primero, hasta 3)
            val lapIds = listOf(R.id.sw_lap_1, R.id.sw_lap_2, R.id.sw_lap_3)
            val maxLaps = cfg.lapCount.coerceIn(1, 3)
            val totalLaps = state.laps.size
            for (i in lapIds.indices) {
                val lapViewId = lapIds[i]
                val lapIndex  = totalLaps - 1 - i
                if (i >= maxLaps || lapIndex < 0) {
                    views.setViewVisibility(lapViewId, View.GONE)
                } else {
                    val lap = state.laps[lapIndex]
                    views.setViewVisibility(lapViewId, View.VISIBLE)
                    views.setTextViewText(lapViewId, buildLapText(lap, cfg))
                    views.setTextColor(lapViewId, cfg.lapColor)
                    views.setFloat(lapViewId, "setTextSize", cfg.lapSizeSp.toFloat())
                }
            }

            // Botón toggle modo
            views.setOnClickPendingIntent(R.id.btn_toggle_mode,
                makeActionIntent(context, ACTION_TOGGLE_MODE, cls, 13))
        }

        // ── Play/Pause icon según estado ──────────────────────────────────────────────────

        private fun applyPlayPauseIcon(views: RemoteViews, cfg: SwWidgetCfg, state: SwState) {
            val isRunning = state.state == StopwatchTimerFgService.STATE_RUNNING
            val b64 = if (isRunning) cfg.iconPause else cfg.iconPlay
            if (b64.isNotEmpty()) {
                val bmp = decodeBase64Bitmap(b64, dpToPxStatic(cfg.iconSizeDp))
                if (bmp != null) {
                    views.setImageViewBitmap(R.id.btn_start_pause, bmp)
                    return
                }
            }
            views.setImageViewResource(R.id.btn_start_pause,
                if (isRunning) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)
            if (cfg.iconColorEnabled) {
                views.setInt(R.id.btn_start_pause, "setColorFilter", cfg.iconColor)
            }
        }

        // ── Helpers ───────────────────────────────────────────────────────────────────────

        fun makeActionIntent(context: Context, action: String, cls: Class<*>, reqCode: Int): PendingIntent {
            val i = Intent(context, cls).setAction(action)
            return PendingIntent.getBroadcast(context, reqCode, i,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        fun drawRing(sizePx: Int, trackArgb: Int, fillArgb: Int, thickPx: Int, progress: Float): Bitmap {
            val bmp = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val inset = thickPx / 2f
            val rect = RectF(inset, inset, sizePx - inset, sizePx - inset)

            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = thickPx.toFloat()
                strokeCap = Paint.Cap.ROUND
            }
            paint.color = trackArgb
            canvas.drawOval(rect, paint)
            paint.color = fillArgb
            canvas.drawArc(rect, -90f, progress * 360f, false, paint)
            return bmp
        }

        // Siempre H:M:S — sin milisegundos (widget actualiza ~1s, ms se verían en saltos)
        fun formatTime(ms: Long): String {
            val total = ms.coerceAtLeast(0L)
            val h = total / 3_600_000L
            val m = (total % 3_600_000L) / 60_000L
            val s = (total % 60_000L) / 1_000L
            return if (h > 0) "%02d:%02d:%02d".format(h, m, s)
                   else       "%02d:%02d".format(m, s)
        }

        fun buildLapText(lap: LapData, cfg: SwWidgetCfg): String {
            val time = formatTime(lap.elapsed)
            return if (cfg.showLapNumber && cfg.showLapDelta) {
                val deltaAbs = if (lap.delta >= 0) lap.delta else -lap.delta
                val sign = if (lap.delta >= 0) "+" else "-"
                "${cfg.lapPrefix}${lap.number}  $time  $sign${formatTime(deltaAbs)}"
            } else if (cfg.showLapNumber) {
                "${cfg.lapPrefix}${lap.number}  $time"
            } else {
                time
            }
        }

        fun decodeBase64Bitmap(b64: String, sizePx: Int): Bitmap? {
            return try {
                val bytes = Base64.decode(b64, Base64.DEFAULT)
                val src = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
                Bitmap.createScaledBitmap(src, sizePx, sizePx, true)
            } catch (_: Exception) { null }
        }

        fun dpToPx(context: Context, dp: Int): Int =
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp.toFloat(), context.resources.displayMetrics).toInt()

        fun dpToPxStatic(dp: Int): Int = (dp * 2.5f).toInt()
    }
}

// ── Subclases por estilo ───────────────────────────────────────────────────────────────────

class StopwatchWidgetProviderStyle1 : BaseStopwatchWidgetProvider() {
    override val layoutResId = R.layout.widget_stopwatch_style1
    companion object {
        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, StopwatchWidgetProviderStyle1::class.java))
            if (ids.isEmpty()) return
            for (id in ids) {
                try {
                    val prefs = BaseStopwatchWidgetProvider.getPrefs(context)
                    val cfg   = BaseStopwatchWidgetProvider.readWidgetCfg(prefs, "style1")
                    val state = BaseStopwatchWidgetProvider.readState(prefs)
                    val views = BaseStopwatchWidgetProvider.buildRemoteViews(
                        context, cfg, state, R.layout.widget_stopwatch_style1,
                        StopwatchWidgetProviderStyle1::class.java)
                    mgr.updateAppWidget(id, views)
                } catch (_: Exception) { }
            }
        }
    }
}

class StopwatchWidgetProviderStyle3 : BaseStopwatchWidgetProvider() {
    override val layoutResId = R.layout.widget_stopwatch_style3
    companion object {
        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, StopwatchWidgetProviderStyle3::class.java))
            if (ids.isEmpty()) return
            for (id in ids) {
                try {
                    val prefs = BaseStopwatchWidgetProvider.getPrefs(context)
                    val cfg   = BaseStopwatchWidgetProvider.readWidgetCfg(prefs, "style3")
                    val state = BaseStopwatchWidgetProvider.readState(prefs)
                    val views = BaseStopwatchWidgetProvider.buildRemoteViews(
                        context, cfg, state, R.layout.widget_stopwatch_style3,
                        StopwatchWidgetProviderStyle3::class.java)
                    mgr.updateAppWidget(id, views)
                } catch (_: Exception) { }
            }
        }
    }
}
