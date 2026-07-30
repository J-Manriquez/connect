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

    private fun render(context: Context, mgr: AppWidgetManager, id: Int) {
        val layoutName = when (layoutResId) {
            R.layout.widget_stopwatch_style1 -> "style1"
            R.layout.widget_stopwatch_style3 -> "style3"
            else -> "unknown($layoutResId)"
        }
        println("[SwWidget] render() widgetId=$id layout=$layoutName")
        try {
            val prefs = getPrefs(context)
            val cfgId = layoutIdToCfgId()
            println("[SwWidget] render: leyendo cfg id='$cfgId'")
            val cfg   = readWidgetCfg(prefs, cfgId)
            println("[SwWidget] render: cfg bgArgb=0x${cfg.bgArgb.toUInt().toString(16)} timeSizeSp=${cfg.timeSizeSp} iconColorEnabled=${cfg.iconColorEnabled}")
            val state = readState(prefs)
            println("[SwWidget] render: state mode=${state.mode} state=${state.state} elapsed=${state.elapsed} remaining=${state.remaining}")
            val views = buildRemoteViews(context, cfg, state, layoutResId, this.javaClass)
            println("[SwWidget] render: RemoteViews listas, aplicando al widgetId=$id")
            mgr.updateAppWidget(id, views)
            println("[SwWidget] render: ✓ widgetId=$id actualizado OK")
        } catch (e: Exception) {
            println("[SwWidget] render ERROR layout=$layoutName id=$id: ${e.message}")
            e.printStackTrace()
        }
    }

    protected open fun layoutIdToCfgId(): String = when (layoutResId) {
        R.layout.widget_stopwatch_style1 -> "style1"
        R.layout.widget_stopwatch_style3 -> "style3"
        else -> "style1"
    }

    companion object {
        fun getPrefs(context: Context): SharedPreferences =
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // ── Lectura de estado ──────────────────────────────────────────────────────────────

        fun readState(prefs: SharedPreferences): SwState {
            val mode  = prefs.getString(StopwatchTimerFgService.KEY_MODE,  StopwatchTimerFgService.MODE_STOPWATCH) ?: StopwatchTimerFgService.MODE_STOPWATCH
            val state = prefs.getString(StopwatchTimerFgService.KEY_STATE, StopwatchTimerFgService.STATE_IDLE)     ?: StopwatchTimerFgService.STATE_IDLE
            val start = prefs.getLong(StopwatchTimerFgService.KEY_START, 0L)
            val accum = prefs.getLong(StopwatchTimerFgService.KEY_ACCUM, 0L)
            val tgtMs = prefs.getLong(StopwatchTimerFgService.KEY_TIMER_TGT, 5 * 60_000L)
            val remMs = prefs.getLong(StopwatchTimerFgService.KEY_TIMER_REM, tgtMs)
            println("[SwWidget] readState: mode=$mode state=$state start=$start accum=$accum tgtMs=$tgtMs remMs=$remMs")

            // El servicio ya escribe el total acumulado en KEY_ACCUM cada 50 ms — no sumar de nuevo
            val elapsed = accum

            // Para el temporizador calculamos en vivo entre actualizaciones de widget (~1 s)
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
            println("[SwWidget] readState: elapsed=$elapsed remaining=$remaining laps=${laps.size}")

            return SwState(mode, state, elapsed, remaining, tgtMs, laps)
        }

        // ── Lectura de configuración (defaults espejo de StopwatchWidgetConfigService.dart) ──

        fun readWidgetCfg(prefs: SharedPreferences, id: String): SwWidgetCfg {
            fun int(prop: String, def: Int)       = prefs.getInt("flutter.stopwatch_cfg_${id}_${prop}", def)
            fun bool(prop: String, def: Boolean)  = StopwatchTimerFgService.readFlutterBool(prefs, "flutter.stopwatch_cfg_${id}_${prop}", def)
            fun str(prop: String, def: String)    = (prefs.getString("flutter.stopwatch_cfg_${id}_${prop}", def) ?: def)

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
            val layoutName = when (layoutResId) {
                R.layout.widget_stopwatch_style1 -> "style1"
                R.layout.widget_stopwatch_style3 -> "style3"
                else -> "unknown($layoutResId)"
            }
            println("[SwWidget] buildRemoteViews: layout=$layoutName pkg=${context.packageName}")

            val views = RemoteViews(context.packageName, layoutResId)

            views.setInt(R.id.sw_root, "setBackgroundColor", cfg.bgArgb)
            println("[SwWidget] buildRemoteViews: bg=0x${cfg.bgArgb.toUInt().toString(16)}")

            // Texto de tiempo (sin milisegundos — widget actualiza ~1s)
            val timeMs   = if (state.mode == StopwatchTimerFgService.MODE_TIMER) state.remaining else state.elapsed
            val timeText = formatTime(timeMs)
            views.setTextViewText(R.id.sw_time, timeText)
            views.setTextColor(R.id.sw_time, cfg.timeColor)
            views.setFloat(R.id.sw_time, "setTextSize", cfg.timeSizeSp.toFloat())
            println("[SwWidget] buildRemoteViews: sw_time='$timeText' timeMs=$timeMs sizeSp=${cfg.timeSizeSp}")

            // Botones comunes: play/pause y reset → servicio directamente
            val piPlay  = makeSvcIntent(context, StopwatchTimerFgService.ACTION_TOGGLE_START_PAUSE, 10)
            val piReset = makeSvcIntent(context, StopwatchTimerFgService.ACTION_RESET, 11)
            views.setOnClickPendingIntent(R.id.btn_start_pause, piPlay)
            views.setOnClickPendingIntent(R.id.btn_reset, piReset)
            println("[SwWidget] buildRemoteViews: btn_start_pause y btn_reset configurados")

            // Botón de apagar alarma (visible SOLO cuando state == FINISHED)
            val isFinished = state.state == StopwatchTimerFgService.STATE_FINISHED
            val piStopAlarm = makeSvcIntent(context, StopwatchTimerFgService.ACTION_STOP_ALARM, 17)
            views.setOnClickPendingIntent(R.id.btn_stop_alarm, piStopAlarm)
            views.setViewVisibility(R.id.btn_stop_alarm, if (isFinished) View.VISIBLE else View.GONE)
            println("[SwWidget] buildRemoteViews: btn_stop_alarm isFinished=$isFinished visibility=${if (isFinished) "VISIBLE" else "GONE"}")

            // ── Por estilo ──────────────────────────────────────────────────────────────────

            println("[SwWidget] buildRemoteViews: delegando a build$layoutName")
            when (layoutResId) {
                R.layout.widget_stopwatch_style1 -> buildStyle1(context, views, cfg, state)
                R.layout.widget_stopwatch_style3 -> buildStyle3(context, views, cfg, state)
            }

            // Iconos estáticos con tinte
            applyStaticIconColors(views, cfg, layoutResId)
            println("[SwWidget] buildRemoteViews: applyStaticIconColors OK iconColorEnabled=${cfg.iconColorEnabled}")

            // Icono de play/pause según estado (puede usar b64 override)
            val isRunning = state.state == StopwatchTimerFgService.STATE_RUNNING
            println("[SwWidget] buildRemoteViews: applyPlayPauseIcon isRunning=$isRunning")
            applyPlayPauseIcon(views, cfg, state)

            // Tap en el tiempo → abre app solo en style1
            // En style3, sw_time es match_parent sobre el anillo; su listener capturaría todos los taps
            if (layoutResId == R.layout.widget_stopwatch_style1) {
                val piOpen = makeOpenAppIntent(context, 15)
                views.setOnClickPendingIntent(R.id.sw_time, piOpen)
                println("[SwWidget] buildRemoteViews: style1 — sw_time click → openApp")
            } else {
                println("[SwWidget] buildRemoteViews: style3 — sw_time sin click listener")
            }

            println("[SwWidget] buildRemoteViews: ✓ RemoteViews listas para $layoutName")
            return views
        }

        private fun buildStyle1(
            context: Context, views: RemoteViews, cfg: SwWidgetCfg,
            state: SwState,
        ) {
            val isTimer    = state.mode == StopwatchTimerFgService.MODE_TIMER
            val isFinished = state.state == StopwatchTimerFgService.STATE_FINISHED

            val modeText = if (isTimer) cfg.labelTimer else cfg.labelStopwatch
            views.setTextViewText(R.id.sw_mode_label, modeText)
            views.setTextColor(R.id.sw_mode_label, cfg.modeLabelColor)
            views.setFloat(R.id.sw_mode_label, "setTextSize", cfg.modeLabelSizeSp.toFloat())

            // Vuelta: solo en cronómetro y cuando no está en alarma
            views.setViewVisibility(R.id.btn_lap,
                if (!isTimer && !isFinished) View.VISIBLE else View.GONE)
            views.setOnClickPendingIntent(R.id.btn_lap,
                makeSvcIntent(context, StopwatchTimerFgService.ACTION_LAP, 12))

            // Cambiar modo
            views.setOnClickPendingIntent(R.id.btn_toggle_mode,
                makeSvcIntent(context, StopwatchTimerFgService.ACTION_TOGGLE_MODE, 13))

            // +/- solo en modo timer y cuando no está en alarma
            views.setViewVisibility(R.id.btn_timer_sub,
                if (isTimer && !isFinished) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.btn_timer_add,
                if (isTimer && !isFinished) View.VISIBLE else View.GONE)
            views.setOnClickPendingIntent(R.id.btn_timer_sub,
                makeSvcIntentWithStep(context, StopwatchTimerFgService.ACTION_TIMER_SUB_STEP, cfg.timerStepMinutes * 60_000L, 14))
            views.setOnClickPendingIntent(R.id.btn_timer_add,
                makeSvcIntentWithStep(context, StopwatchTimerFgService.ACTION_TIMER_ADD_STEP, cfg.timerStepMinutes * 60_000L, 16))
        }

        private fun buildStyle3(
            context: Context, views: RemoteViews, cfg: SwWidgetCfg,
            state: SwState,
        ) {
            val isFinished = state.state == StopwatchTimerFgService.STATE_FINISHED
            println("[SwWidget3] buildStyle3: mode=${state.mode} state=${state.state} elapsed=${state.elapsed} remaining=${state.remaining} timerTarget=${state.timerTarget} laps=${state.laps.size} isFinished=$isFinished")

            // Cuando la alarma está sonando: ocultar barra de botones normales
            views.setViewVisibility(R.id.sw_btn_bar, if (isFinished) View.GONE else View.VISIBLE)
            println("[SwWidget3] buildStyle3: sw_btn_bar ${if (isFinished) "GONE" else "VISIBLE"}")

            // Anillo de progreso como Bitmap
            val sizePx  = dpToPx(context, 220)
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
            println("[SwWidget3] buildStyle3: ring sizePx=$sizePx thickPx=$thickPx progress=$progress")
            val ring = drawRing(sizePx, cfg.ringTrackArgb, cfg.ringFillArgb, thickPx, progress)
            views.setImageViewBitmap(R.id.sw_ring, ring)
            println("[SwWidget3] buildStyle3: ring bitmap ${ring.width}x${ring.height}px asignado a sw_ring")

            // Etiqueta de modo
            val modeText = if (state.mode == StopwatchTimerFgService.MODE_TIMER) cfg.labelTimer else cfg.labelStopwatch
            views.setTextViewText(R.id.sw_mode_label, modeText)
            views.setTextColor(R.id.sw_mode_label, cfg.modeLabelColor)
            println("[SwWidget3] buildStyle3: sw_mode_label='$modeText'")

            // Vueltas (más reciente primero, hasta 3)
            val lapIds    = listOf(R.id.sw_lap_1, R.id.sw_lap_2, R.id.sw_lap_3)
            val maxLaps   = cfg.lapCount.coerceIn(1, 3)
            val totalLaps = state.laps.size
            println("[SwWidget3] buildStyle3: laps totalLaps=$totalLaps maxLaps=$maxLaps")
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
                    println("[SwWidget3] buildStyle3: lap_${i+1} text='${buildLapText(lap, cfg)}'")
                }
            }

            // Cambiar modo
            val piToggleMode = makeSvcIntent(context, StopwatchTimerFgService.ACTION_TOGGLE_MODE, 13)
            views.setOnClickPendingIntent(R.id.btn_toggle_mode, piToggleMode)
            println("[SwWidget3] buildStyle3: btn_toggle_mode PI configurado reqCode=13")
            println("[SwWidget3] buildStyle3: ✓ fin")
        }

        // ── Aplica icono + tinte de color a un ImageButton ────────────────────────────────

        private fun applyIcon(views: RemoteViews, viewId: Int, resId: Int, cfg: SwWidgetCfg) {
            views.setImageViewResource(viewId, resId)
            if (cfg.iconColorEnabled) views.setInt(viewId, "setColorFilter", cfg.iconColor)
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
            applyIcon(views, R.id.btn_start_pause,
                if (isRunning) R.drawable.ic_sw_pause else R.drawable.ic_sw_play, cfg)
        }

        // ── Aplica tinte a todos los botones estáticos ────────────────────────────────────

        private fun applyStaticIconColors(views: RemoteViews, cfg: SwWidgetCfg, layoutResId: Int) {
            applyIcon(views, R.id.btn_reset, R.drawable.ic_sw_reset, cfg)
            applyIcon(views, R.id.btn_toggle_mode, R.drawable.ic_sw_swap, cfg)
            applyIcon(views, R.id.btn_stop_alarm, R.drawable.ic_sw_alarm_off, cfg)
            if (layoutResId == R.layout.widget_stopwatch_style1) {
                val lapB64 = cfg.iconLap
                if (lapB64.isNotEmpty()) {
                    val bmp = decodeBase64Bitmap(lapB64, dpToPxStatic(cfg.iconSizeDp))
                    if (bmp != null) views.setImageViewBitmap(R.id.btn_lap, bmp)
                    else applyIcon(views, R.id.btn_lap, R.drawable.ic_sw_lap, cfg)
                } else {
                    applyIcon(views, R.id.btn_lap, R.drawable.ic_sw_lap, cfg)
                }
                applyIcon(views, R.id.btn_timer_sub, R.drawable.ic_sw_minus, cfg)
                applyIcon(views, R.id.btn_timer_add, R.drawable.ic_sw_plus, cfg)
            }
        }

        // ── Helpers ───────────────────────────────────────────────────────────────────────

        fun makeSvcIntent(context: Context, action: String, reqCode: Int): PendingIntent {
            val i = Intent(context, StopwatchTimerFgService::class.java).setAction(action)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val isFg = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            val pi = if (isFg)
                PendingIntent.getForegroundService(context, reqCode, i, flags)
            else
                PendingIntent.getService(context, reqCode, i, flags)
            println("[SwWidget] makeSvcIntent: action=$action reqCode=$reqCode isForeground=$isFg")
            return pi
        }

        fun makeSvcIntentWithStep(context: Context, action: String, stepMs: Long, reqCode: Int): PendingIntent {
            val i = Intent(context, StopwatchTimerFgService::class.java)
                .setAction(action)
                .putExtra(StopwatchTimerFgService.EXTRA_TIMER_STEP_MS, stepMs)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                PendingIntent.getForegroundService(context, reqCode, i, flags)
            else
                PendingIntent.getService(context, reqCode, i, flags)
        }

        fun makeOpenAppIntent(context: Context, reqCode: Int): PendingIntent {
            val i = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            i.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            i.putExtra("navigate_to", "stopwatch_timer")
            return PendingIntent.getActivity(context, reqCode, i,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        fun drawRing(sizePx: Int, trackArgb: Int, fillArgb: Int, thickPx: Int, progress: Float): Bitmap {
            val bmp    = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val inset  = thickPx / 2f
            val rect   = RectF(inset, inset, sizePx - inset, sizePx - inset)

            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style       = Paint.Style.STROKE
                strokeWidth = thickPx.toFloat()
                strokeCap   = Paint.Cap.ROUND
            }
            paint.color = trackArgb
            canvas.drawOval(rect, paint)
            paint.color = fillArgb
            canvas.drawArc(rect, -90f, progress * 360f, false, paint)
            return bmp
        }

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
            println("[SwWidget] Style1.updateAll: ${ids.size} widget(s) ids=${ids.toList()}")
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
                    println("[SwWidget] Style1.updateAll: ✓ widgetId=$id OK")
                } catch (e: Exception) {
                    println("[SwWidget] Style1.updateAll: ERROR id=$id: ${e.message}")
                }
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
            println("[SwWidget3] Style3.updateAll: ${ids.size} widget(s) ids=${ids.toList()}")
            if (ids.isEmpty()) {
                println("[SwWidget3] Style3.updateAll: NO hay widgets style3 en pantalla")
                return
            }
            for (id in ids) {
                println("[SwWidget3] Style3.updateAll: procesando widgetId=$id")
                try {
                    val prefs = BaseStopwatchWidgetProvider.getPrefs(context)
                    val cfg   = BaseStopwatchWidgetProvider.readWidgetCfg(prefs, "style3")
                    println("[SwWidget3] Style3.updateAll: cfg bgArgb=0x${cfg.bgArgb.toUInt().toString(16)} ringTrack=0x${cfg.ringTrackArgb.toUInt().toString(16)} ringFill=0x${cfg.ringFillArgb.toUInt().toString(16)}")
                    val state = BaseStopwatchWidgetProvider.readState(prefs)
                    println("[SwWidget3] Style3.updateAll: state mode=${state.mode} state=${state.state} elapsed=${state.elapsed} remaining=${state.remaining}")
                    val views = BaseStopwatchWidgetProvider.buildRemoteViews(
                        context, cfg, state, R.layout.widget_stopwatch_style3,
                        StopwatchWidgetProviderStyle3::class.java)
                    mgr.updateAppWidget(id, views)
                    println("[SwWidget3] Style3.updateAll: ✓ widgetId=$id actualizado")
                } catch (e: Exception) {
                    println("[SwWidget3] Style3.updateAll: ERROR id=$id: ${e.message}")
                    e.printStackTrace()
                }
            }
        }
    }
}
