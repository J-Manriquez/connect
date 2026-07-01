package com.example.connect

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import java.io.File
import java.io.InputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ImageSlideShowWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        log(context, "onUpdate ids=${appWidgetIds.toList()}")
        val cfg = readCfg(context)
        if (cfg.imageList.isNotEmpty()) {
            scheduleAdvance(context, cfg.intervalSec)
            log(context, "onUpdate scheduleAdvance intervalSec=${cfg.intervalSec}")
        } else {
            log(context, "onUpdate imageList vacía — mostrando placeholder con tap para configurar")
        }
        for (id in appWidgetIds) {
            try {
                appWidgetManager.updateAppWidget(id, buildRemoteViews(context, appWidgetManager, cfg, id))
            } catch (e: Throwable) {
                log(context, "onUpdate error id=$id: ${e.message}")
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action ?: return
        if (action !in listOf(
                ACTION_ADVANCE, ACTION_PREV, ACTION_NEXT,
                ACTION_TOGGLE_CONTROLS, ACTION_HIDE_CONTROLS)) return

        log(context, "onReceive action=$action")

        // goAsync() evita ANR mientras se decodifican bitmaps (el BR tiene 10-30s)
        val pending = goAsync()
        Thread {
            try {
                handleAction(context, action)
            } catch (e: Throwable) {
                log(context, "handleAction CRASH action=$action error=${e.message}")
            } finally {
                pending.finish()
            }
        }.start()
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val mgr = AppWidgetManager.getInstance(context)
        val remaining = mgr.getAppWidgetIds(ComponentName(context, ImageSlideShowWidgetProvider::class.java))
        log(context, "onDeleted ids=${appWidgetIds.toList()} remaining=${remaining.size}")
        if (remaining.isEmpty()) {
            cancelAdvance(context)
            cancelHideControls(context)
        }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        log(context, "onDisabled — cancelando alarmas")
        cancelAdvance(context)
        cancelHideControls(context)
    }

    companion object {
        private const val TAG = "img_widget"
        private const val PREFS_FLUTTER = "FlutterSharedPreferences"
        private const val PKG = "com.example.connect"
        const val ACTION_ADVANCE         = "$PKG.IMAGE_WIDGET_ADVANCE"
        const val ACTION_PREV            = "$PKG.IMAGE_WIDGET_PREV"
        const val ACTION_NEXT            = "$PKG.IMAGE_WIDGET_NEXT"
        const val ACTION_TOGGLE_CONTROLS = "$PKG.IMAGE_WIDGET_TOGGLE_CONTROLS"
        const val ACTION_HIDE_CONTROLS   = "$PKG.IMAGE_WIDGET_HIDE_CONTROLS"
        const val ACTION_OPEN_EDITOR     = "$PKG.IMAGE_WIDGET_OPEN_EDITOR"

        private const val PF = "flutter.widget_cfg_img_"
        private const val PROP_CURRENT_INDEX    = "current_index"
        private const val PROP_CONTROLS_VISIBLE = "controls_visible"

        private const val MAX_BITMAP_PX = 800

        // Defaults — deben ser idénticos a ImageWidgetService.dart
        private const val DEF_INTERVAL_SEC        = 10
        private const val DEF_CONTROLS_HIDE_DELAY = 5
        private const val DEF_FX_ZOOM_PCT         = 115
        private const val DEF_CORNER_RADIUS_DP    = 16
        private const val DEF_BORDER_THICKNESS_DP = 2
        private const val DEF_SCRIM_OPACITY       = 50
        private const val DEF_CAPTION_SIZE_SP     = 14
        private const val DEF_CAPTION_POSITION    = 1
        private const val DEF_CAPTION_PAD_DP      = 8
        private const val DEF_DOTS_SIZE_DP        = 8
        private const val DEF_DOTS_SPACING_DP     = 6
        private const val DEF_DOTS_POSITION       = 1

        // ── Logging BT ────────────────────────────────────────────────────────

        fun log(context: Context?, msg: String) {
            println("[$TAG] $msg")
            try {
                BtClassicServerService.sendDebugLogToPeers(TAG, msg)
            } catch (_: Throwable) {}
        }

        // ── Modelo ────────────────────────────────────────────────────────────

        data class ImageWidgetCfg(
            val imageList: List<String>,
            val currentIndex: Int,
            val loop: Boolean,
            val intervalSec: Int,
            val controlsHideDelaySec: Int,
            val controlsVisible: Boolean,
            val fxType: Int,
            val fxZoomPct: Int,
            val fxColor: Int,
            val cornerRadiusDp: Int,
            val paddingDp: Int,
            val borderShow: Boolean,
            val borderColor: Int,
            val borderThicknessDp: Int,
            val scaleType: Int,
            val bgColor: Int,
            val scrimShow: Boolean,
            val scrimColor: Int,
            val scrimOpacity: Int,
            val captionShow: Boolean,
            val captionSource: Int,
            val captionColor: Int,
            val captionSizeSp: Int,
            val captionBold: Boolean,
            val captionPosition: Int,
            val captionBg: Int,
            val captionPadDp: Int,
            val dotsShow: Boolean,
            val dotsActiveColor: Int,
            val dotsInactiveColor: Int,
            val dotsSizeDp: Int,
            val dotsSpacingDp: Int,
            val dotsPosition: Int
        )

        // ── Lógica principal ───────────────────────────────────────────────────

        private fun handleAction(context: Context, action: String) {
            val cfg = readCfg(context)
            log(context, "handleAction=$action imgCount=${cfg.imageList.size} idx=${cfg.currentIndex} ctrlVisible=${cfg.controlsVisible}")

            when (action) {
                ACTION_ADVANCE -> {
                    if (cfg.imageList.isEmpty()) {
                        log(context, "ADVANCE: lista vacía, reprogramando")
                        scheduleAdvance(context, cfg.intervalSec)
                        return
                    }
                    val newIdx = if (cfg.loop) {
                        (cfg.currentIndex + 1) % cfg.imageList.size
                    } else {
                        (cfg.currentIndex + 1).coerceAtMost(cfg.imageList.size - 1)
                    }
                    log(context, "ADVANCE: ${cfg.currentIndex} -> $newIdx (fxType=${cfg.fxType})")
                    writeCfgLong(context, PROP_CURRENT_INDEX, newIdx.toLong())
                    val newCfg = cfg.copy(currentIndex = newIdx)
                    if (cfg.fxType == 2 || cfg.fxType == 3) {
                        performFadeTransition(context, newCfg)
                    } else {
                        updateAll(context, newCfg)
                    }
                    scheduleAdvance(context, cfg.intervalSec)
                }
                ACTION_PREV -> {
                    if (cfg.imageList.isEmpty()) { log(context, "PREV: lista vacía"); return }
                    val newIdx = (cfg.currentIndex - 1 + cfg.imageList.size) % cfg.imageList.size
                    log(context, "PREV: ${cfg.currentIndex} -> $newIdx")
                    writeCfgLong(context, PROP_CURRENT_INDEX, newIdx.toLong())
                    updateAll(context, cfg.copy(currentIndex = newIdx))
                    scheduleAdvance(context, cfg.intervalSec)
                    scheduleHideControls(context, cfg.controlsHideDelaySec)
                }
                ACTION_NEXT -> {
                    if (cfg.imageList.isEmpty()) { log(context, "NEXT: lista vacía"); return }
                    val newIdx = (cfg.currentIndex + 1) % cfg.imageList.size
                    log(context, "NEXT: ${cfg.currentIndex} -> $newIdx")
                    writeCfgLong(context, PROP_CURRENT_INDEX, newIdx.toLong())
                    updateAll(context, cfg.copy(currentIndex = newIdx))
                    scheduleAdvance(context, cfg.intervalSec)
                    scheduleHideControls(context, cfg.controlsHideDelaySec)
                }
                ACTION_TOGGLE_CONTROLS -> {
                    val newVisible = !cfg.controlsVisible
                    log(context, "TOGGLE_CONTROLS: $newVisible")
                    writeCfgBool(context, PROP_CONTROLS_VISIBLE, newVisible)
                    if (newVisible) scheduleHideControls(context, cfg.controlsHideDelaySec)
                    else cancelHideControls(context)
                    updateAll(context, cfg.copy(controlsVisible = newVisible))
                }
                ACTION_HIDE_CONTROLS -> {
                    log(context, "HIDE_CONTROLS")
                    writeCfgBool(context, PROP_CONTROLS_VISIBLE, false)
                    updateAll(context, cfg.copy(controlsVisible = false))
                }
            }
        }

        fun readCfg(context: Context): ImageWidgetCfg {
            val p = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            val rawList = fStr(p, PF + "file_list", "[]")
            val imageList = try {
                val arr = JSONArray(rawList)
                (0 until arr.length()).map { arr.getString(it) }
            } catch (_: Exception) { emptyList() }
            val safeIdx = if (imageList.isEmpty()) 0
                else fInt(p, PF + PROP_CURRENT_INDEX, 0).coerceIn(0, imageList.size - 1)

            return ImageWidgetCfg(
                imageList            = imageList,
                currentIndex         = safeIdx,
                loop                 = readFlutterBool(p, PF + "loop", true),
                intervalSec          = fInt(p, PF + "interval_sec", DEF_INTERVAL_SEC).coerceIn(3, 300),
                controlsHideDelaySec = fInt(p, PF + "controls_hide_delay_sec", DEF_CONTROLS_HIDE_DELAY).coerceIn(2, 30),
                controlsVisible      = readFlutterBool(p, PF + PROP_CONTROLS_VISIBLE, false),
                fxType               = fInt(p, PF + "fx_type", 0).coerceIn(0, 3),
                fxZoomPct            = fInt(p, PF + "fx_zoom_pct", DEF_FX_ZOOM_PCT).coerceIn(100, 160),
                fxColor              = fColor(p, PF + "fx_color", 0xFF000000L),
                cornerRadiusDp       = fInt(p, PF + "corner_radius_dp", DEF_CORNER_RADIUS_DP).coerceIn(0, 80),
                paddingDp            = fInt(p, PF + "padding_dp", 0).coerceIn(0, 32),
                borderShow           = readFlutterBool(p, PF + "border_show", false),
                borderColor          = fColor(p, PF + "border_color", 0xFFFFFFFFL),
                borderThicknessDp    = fInt(p, PF + "border_thickness_dp", DEF_BORDER_THICKNESS_DP).coerceIn(0, 16),
                scaleType            = fInt(p, PF + "scale_type", 0).coerceIn(0, 4),
                bgColor              = fColor(p, PF + "bg_color", 0xFF000000L),
                scrimShow            = readFlutterBool(p, PF + "scrim_show", false),
                scrimColor           = fColor(p, PF + "scrim_color", 0x80000000L),
                scrimOpacity         = fInt(p, PF + "scrim_opacity", DEF_SCRIM_OPACITY).coerceIn(0, 100),
                captionShow          = readFlutterBool(p, PF + "caption_show", false),
                captionSource        = fInt(p, PF + "caption_source", 0).coerceIn(0, 1),
                captionColor         = fColor(p, PF + "caption_color", 0xFFFFFFFFL),
                captionSizeSp        = fInt(p, PF + "caption_size_sp", DEF_CAPTION_SIZE_SP).coerceIn(8, 36),
                captionBold          = readFlutterBool(p, PF + "caption_bold", false),
                captionPosition      = fInt(p, PF + "caption_position", DEF_CAPTION_POSITION).coerceIn(0, 1),
                captionBg            = fColor(p, PF + "caption_bg", 0x99000000L),
                captionPadDp         = fInt(p, PF + "caption_pad_dp", DEF_CAPTION_PAD_DP).coerceIn(0, 24),
                dotsShow             = readFlutterBool(p, PF + "dots_show", false),
                dotsActiveColor      = fColor(p, PF + "dots_active_color", 0xFFFFFFFFL),
                dotsInactiveColor    = fColor(p, PF + "dots_inactive_color", 0x80FFFFFFL),
                dotsSizeDp           = fInt(p, PF + "dots_size_dp", DEF_DOTS_SIZE_DP).coerceIn(4, 16),
                dotsSpacingDp        = fInt(p, PF + "dots_spacing_dp", DEF_DOTS_SPACING_DP).coerceIn(2, 16),
                dotsPosition         = fInt(p, PF + "dots_position", DEF_DOTS_POSITION).coerceIn(0, 1)
            )
        }

        fun updateAll(context: Context, cfg: ImageWidgetCfg? = null) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, ImageSlideShowWidgetProvider::class.java))
            if (ids.isEmpty()) {
                log(context, "updateAll: sin widget IDs registrados")
                return
            }
            val c = cfg ?: readCfg(context)
            log(context, "updateAll ids=${ids.toList()} imgCount=${c.imageList.size} idx=${c.currentIndex}")
            for (id in ids) {
                try {
                    val rv = buildRemoteViews(context, mgr, c, id)
                    mgr.updateAppWidget(id, rv)
                    log(context, "updateAll id=$id OK")
                } catch (e: Throwable) {
                    log(context, "updateAll id=$id ERROR: ${e.message}")
                }
            }
        }

        // ── RemoteViews ────────────────────────────────────────────────────────

        private fun buildRemoteViews(
            context: Context,
            mgr: AppWidgetManager,
            cfg: ImageWidgetCfg,
            appWidgetId: Int
        ): RemoteViews {
            val rv = RemoteViews(context.packageName, R.layout.widget_image_slideshow)

            // El click en la RAÍZ alterna controles.
            // Los botones prev/next son hijos con mayor z-order → capturan sus propios taps.
            rv.setOnClickPendingIntent(R.id.widget_image_root,
                makePi(context, ACTION_TOGGLE_CONTROLS, 200 + appWidgetId))
            rv.setOnClickPendingIntent(R.id.widget_image_prev_btn,
                makePi(context, ACTION_PREV, 300 + appWidgetId))
            rv.setOnClickPendingIntent(R.id.widget_image_next_btn,
                makePi(context, ACTION_NEXT, 400 + appWidgetId))

            val vis = if (cfg.controlsVisible) View.VISIBLE else View.GONE
            rv.setViewVisibility(R.id.widget_image_prev_btn, vis)
            rv.setViewVisibility(R.id.widget_image_next_btn, vis)

            if (cfg.imageList.isEmpty()) {
                // Sin imágenes: toque lleva a la app para configurar
                rv.setImageViewResource(R.id.widget_image_main, android.R.drawable.ic_menu_gallery)
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    action = ACTION_OPEN_EDITOR
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                val openPi = PendingIntent.getActivity(context, 500 + appWidgetId, openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                rv.setOnClickPendingIntent(R.id.widget_image_root, openPi)
                log(context, "buildRemoteViews id=$appWidgetId placeholder (sin imágenes)")
                return rv
            }

            val (widthDp, heightDp) = widgetDpSize(context, mgr, appWidgetId)
            val density = context.resources.displayMetrics.density
            val targetW = (widthDp * density).toInt().coerceAtMost(MAX_BITMAP_PX).coerceAtLeast(100)
            val targetH = (heightDp * density).toInt().coerceAtMost(MAX_BITMAP_PX).coerceAtLeast(100)

            log(context, "buildRemoteViews id=$appWidgetId size=${widthDp}x${heightDp}dp => bitmap=${targetW}x${targetH}px idx=${cfg.currentIndex}")

            val bmp = renderFrame(context, cfg, cfg.currentIndex, targetW, targetH, widthDp, heightDp)
            if (bmp != null) {
                rv.setImageViewBitmap(R.id.widget_image_main, bmp)
            } else {
                rv.setImageViewResource(R.id.widget_image_main, android.R.drawable.ic_menu_gallery)
                log(context, "buildRemoteViews id=$appWidgetId renderFrame devolvió null")
            }
            return rv
        }

        /** Dimensiones del widget en dp según AppWidgetOptions. */
        private fun widgetDpSize(context: Context, mgr: AppWidgetManager, id: Int): Pair<Int, Int> {
            return try {
                val opts = mgr.getAppWidgetOptions(id)
                val w = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 200).coerceAtLeast(60)
                val h = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 200).coerceAtLeast(60)
                w to h
            } catch (_: Exception) { 200 to 200 }
        }

        // ── Transición de fundido ─────────────────────────────────────────────

        private fun performFadeTransition(context: Context, cfg: ImageWidgetCfg) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, ImageSlideShowWidgetProvider::class.java))
            if (ids.isEmpty()) { log(context, "fade: sin widgets"); return }

            val firstId = ids.first()
            val (wDp, hDp) = widgetDpSize(context, mgr, firstId)
            val density = context.resources.displayMetrics.density
            val tW = (wDp * density).toInt().coerceAtMost(MAX_BITMAP_PX).coerceAtLeast(100)
            val tH = (hDp * density).toInt().coerceAtMost(MAX_BITMAP_PX).coerceAtLeast(100)
            val fadeColor = if (cfg.fxType == 3) Color.WHITE else Color.BLACK

            log(context, "fade inicio idx=${cfg.currentIndex} size=${tW}x${tH}px color=$fadeColor")

            // Renderizar el frame destino UNA vez
            val baseBmp = renderFrame(context, cfg, cfg.currentIndex, tW, tH, wDp, hDp)
            if (baseBmp == null) {
                log(context, "fade: renderFrame null, actualizando directo")
                updateAll(context, cfg)
                return
            }

            // 3 pasos de overlay: opaco → semi → sin overlay
            for (alpha in listOf(210, 100, 0)) {
                try {
                    val frameBmp = if (alpha > 0) {
                        val out = baseBmp.copy(Bitmap.Config.ARGB_8888, true)
                        Canvas(out).drawRect(0f, 0f, out.width.toFloat(), out.height.toFloat(),
                            Paint().apply { color = (fadeColor and 0x00FFFFFF) or (alpha shl 24) })
                        out
                    } else baseBmp

                    for (id in ids) {
                        try {
                            val rv = RemoteViews(context.packageName, R.layout.widget_image_slideshow)
                            rv.setOnClickPendingIntent(R.id.widget_image_root,
                                makePi(context, ACTION_TOGGLE_CONTROLS, 200 + id))
                            rv.setOnClickPendingIntent(R.id.widget_image_prev_btn,
                                makePi(context, ACTION_PREV, 300 + id))
                            rv.setOnClickPendingIntent(R.id.widget_image_next_btn,
                                makePi(context, ACTION_NEXT, 400 + id))
                            val vis = if (cfg.controlsVisible) View.VISIBLE else View.GONE
                            rv.setViewVisibility(R.id.widget_image_prev_btn, vis)
                            rv.setViewVisibility(R.id.widget_image_next_btn, vis)
                            rv.setImageViewBitmap(R.id.widget_image_main, frameBmp)
                            mgr.updateAppWidget(id, rv)
                        } catch (_: Throwable) {}
                    }

                    if (alpha > 0) Thread.sleep(110)
                } catch (_: Throwable) {}
            }

            updateAll(context, cfg)
            try { baseBmp.recycle() } catch (_: Throwable) {}
            log(context, "fade completado idx=${cfg.currentIndex}")
        }

        // ── Pipeline de render ─────────────────────────────────────────────────

        /**
         * Renderiza un frame completo.
         * [widthDp] / [heightDp]: dimensiones del widget en dp (para escalar dots correctamente).
         */
        private fun renderFrame(
            context: Context,
            cfg: ImageWidgetCfg,
            index: Int,
            targetW: Int,
            targetH: Int,
            widthDp: Int,
            heightDp: Int
        ): Bitmap? {
            return try {
                val path = cfg.imageList.getOrNull(index) ?: run {
                    log(context, "renderFrame idx=$index fuera de rango (size=${cfg.imageList.size})")
                    return null
                }
                val fileExists = try { File(path).exists() } catch (_: Exception) { false }
                if (!fileExists) {
                    log(context, "renderFrame file NOT found: $path")
                    return null
                }
                log(context, "renderFrame idx=$index path=$path target=${targetW}x${targetH}px")

                val density = context.resources.displayMetrics.density
                var bmp = decodeSampled(context, path, targetW, targetH) ?: run {
                    log(context, "renderFrame decodeSampled null")
                    return null
                }
                log(context, "renderFrame decoded ${bmp.width}x${bmp.height}")
                bmp = applyScaleType(bmp, targetW, targetH, cfg.scaleType, cfg.bgColor)
                if (cfg.fxType == 1) bmp = applyKenBurns(bmp, index, cfg.fxZoomPct)
                if (cfg.scrimShow) bmp = applyScrim(bmp, cfg.scrimColor, cfg.scrimOpacity)
                if (cfg.captionShow) {
                    val text = captionText(path, cfg)
                    if (text.isNotEmpty()) bmp = applyCaption(bmp, text, cfg, density)
                }
                if (cfg.dotsShow && cfg.imageList.size > 1) {
                    // Fórmula correcta: dotR_px = (dotsSizeDp/2) * bitmapWidth / widgetWidthDp
                    // Así el dot se ve igual de grande independientemente del cap de px.
                    bmp = applyDots(bmp, cfg.imageList.size, index, cfg, widthDp, heightDp)
                }
                bmp = applyFraming(
                    bmp,
                    padPx = (cfg.paddingDp * density).toInt(),
                    radiusPx = cfg.cornerRadiusDp * density,
                    bgColor = cfg.bgColor,
                    showBorder = cfg.borderShow,
                    borderColor = cfg.borderColor,
                    borderThickPx = cfg.borderThicknessDp * density
                )
                bmp
            } catch (e: Throwable) {
                log(context, "renderFrame CRASH idx=$index: ${e.message}")
                null
            }
        }

        private fun decodeSampled(context: Context, path: String, reqW: Int, reqH: Int): Bitmap? {
            return try {
                val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                openImageStream(context, path)?.use { BitmapFactory.decodeStream(it, null, opts) }
                if (opts.outWidth <= 0) return null
                opts.inSampleSize = calcSampleSize(opts, reqW, reqH)
                opts.inJustDecodeBounds = false
                opts.inPreferredConfig = Bitmap.Config.ARGB_8888
                openImageStream(context, path)?.use { BitmapFactory.decodeStream(it, null, opts) }
            } catch (e: Throwable) {
                log(null, "decodeSampled error: ${e.message}")
                null
            }
        }

        private fun openImageStream(context: Context, path: String): InputStream? {
            try { val f = File(path); if (f.exists()) return f.inputStream() } catch (_: Exception) {}
            return try { context.contentResolver.openInputStream(Uri.fromFile(File(path))) }
                catch (_: Exception) { null }
        }

        private fun calcSampleSize(opts: BitmapFactory.Options, reqW: Int, reqH: Int): Int {
            val h = opts.outHeight; val w = opts.outWidth
            var s = 1
            if (h > reqH || w > reqW) {
                val hh = h / 2; val hw = w / 2
                while ((hh / s) >= reqH && (hw / s) >= reqW) s *= 2
            }
            return s
        }

        private fun applyScaleType(src: Bitmap, tw: Int, th: Int, scaleType: Int, bgColor: Int): Bitmap {
            val out = Bitmap.createBitmap(tw, th, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(out)
            canvas.drawColor(bgColor)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
            val sw = src.width.toFloat(); val sh = src.height.toFloat()
            val dw = tw.toFloat();       val dh = th.toFloat()
            val dst = when (scaleType) {
                0 -> { val s = maxOf(dw / sw, dh / sh); RectF((dw - sw*s)/2, (dh - sh*s)/2, (dw + sw*s)/2, (dh + sh*s)/2) }
                1 -> { val s = minOf(dw / sw, dh / sh); RectF((dw - sw*s)/2, (dh - sh*s)/2, (dw + sw*s)/2, (dh + sh*s)/2) }
                2 -> RectF(0f, 0f, dw, dh)
                3 -> RectF((dw - sw)/2, (dh - sh)/2, (dw + sw)/2, (dh + sh)/2)
                4 -> { val s = dw/sw; RectF(0f, (dh - sh*s)/2, dw, (dh + sh*s)/2) }
                else -> RectF(0f, 0f, dw, dh)
            }
            canvas.drawBitmap(src, null, dst, paint)
            if (src !== out) try { src.recycle() } catch (_: Exception) {}
            return out
        }

        private fun applyKenBurns(src: Bitmap, index: Int, zoomPct: Int): Bitmap {
            val zoom = zoomPct / 100f
            val sw = src.width; val sh = src.height
            val scaledW = (sw * zoom).toInt().coerceAtLeast(sw)
            val scaledH = (sh * zoom).toInt().coerceAtLeast(sh)
            val positions = arrayOf(0f to 0f, 1f to 0f, 0.5f to 0.5f, 0f to 1f,
                                    1f to 1f, 0.25f to 0.75f, 0.75f to 0.25f)
            val (px, py) = positions[index % positions.size]
            val offX = ((scaledW - sw).coerceAtLeast(0) * px).toInt()
            val offY = ((scaledH - sh).coerceAtLeast(0) * py).toInt()
            val scaled = Bitmap.createScaledBitmap(src, scaledW, scaledH, true)
            val out = Bitmap.createBitmap(scaled, offX, offY, sw, sh)
            try { scaled.recycle() } catch (_: Exception) {}
            if (src !== out) try { src.recycle() } catch (_: Exception) {}
            return out
        }

        private fun applyScrim(src: Bitmap, baseColor: Int, opacityPct: Int): Bitmap {
            val out = src.copy(Bitmap.Config.ARGB_8888, true)
            val alpha = (opacityPct * 255 / 100).coerceIn(0, 255)
            Canvas(out).drawRect(0f, 0f, out.width.toFloat(), out.height.toFloat(),
                Paint().apply { color = (baseColor and 0x00FFFFFF) or (alpha shl 24) })
            return out
        }

        private fun captionText(path: String, cfg: ImageWidgetCfg): String {
            return if (cfg.captionSource == 0) File(path).nameWithoutExtension
            else {
                val ms = try { File(path).lastModified() } catch (_: Exception) { 0L }
                if (ms > 0) SimpleDateFormat("dd/MM/yyyy", Locale.getDefault()).format(Date(ms)) else ""
            }
        }

        private fun applyCaption(src: Bitmap, text: String, cfg: ImageWidgetCfg, density: Float): Bitmap {
            val out = src.copy(Bitmap.Config.ARGB_8888, true)
            val canvas = Canvas(out)
            val padPx = cfg.captionPadDp * density
            val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = cfg.captionColor; textSize = cfg.captionSizeSp * density; isFakeBoldText = cfg.captionBold
            }
            val fm = textPaint.fontMetrics
            val textH = fm.descent - fm.ascent
            val bgH = textH + padPx * 2
            val w = out.width.toFloat(); val h = out.height.toFloat()
            val bgRect = if (cfg.captionPosition == 0) RectF(0f, 0f, w, bgH) else RectF(0f, h - bgH, w, h)
            canvas.drawRect(bgRect, Paint().apply { color = cfg.captionBg })
            val maxW = w - padPx * 2
            var displayText = text
            while (displayText.isNotEmpty() && textPaint.measureText(displayText) > maxW) displayText = displayText.dropLast(1)
            val textX = ((w - textPaint.measureText(displayText)) / 2).coerceAtLeast(padPx)
            val textY = bgRect.top + padPx + textH - fm.descent
            canvas.drawText(displayText, textX, textY, textPaint)
            return out
        }

        /**
         * Dots con fórmula correcta de escala:
         * dotR_px = (dotsSizeDp / 2) × (bitmapWidth_px / widgetWidth_dp)
         * Esto garantiza que el dot aparezca como dotsSizeDp dp en pantalla,
         * independientemente del cap de píxeles aplicado al bitmap.
         */
        private fun applyDots(
            src: Bitmap, total: Int, current: Int, cfg: ImageWidgetCfg,
            widthDp: Int, heightDp: Int
        ): Bitmap {
            val out = src.copy(Bitmap.Config.ARGB_8888, true)
            val canvas = Canvas(out)
            val bmpW = out.width.toFloat()
            val bmpH = out.height.toFloat()

            // Ratio bitmap→dp: cuántos px del bitmap equivalen a 1dp en pantalla
            val pxPerDp = bmpW / widthDp.toFloat()

            val dotR = ((cfg.dotsSizeDp / 2f) * pxPerDp).coerceAtLeast(4f)
            val spacing = cfg.dotsSpacingDp * pxPerDp
            val margin = dotR + 8 * pxPerDp

            val maxDots = 12
            val display = minOf(total, maxDots)
            val windowStart = if (total <= maxDots) 0
                else (current - maxDots / 2).coerceIn(0, total - maxDots)
            val rowW = display * (dotR * 2 + spacing) - spacing
            var x = (bmpW - rowW) / 2 + dotR
            val y = if (cfg.dotsPosition == 0) margin else bmpH - margin

            for (i in 0 until display) {
                val actualIdx = windowStart + i
                canvas.drawCircle(x, y, dotR, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (actualIdx == current) cfg.dotsActiveColor else cfg.dotsInactiveColor
                })
                x += dotR * 2 + spacing
            }
            return out
        }

        private fun applyFraming(
            src: Bitmap, padPx: Int, radiusPx: Float, bgColor: Int,
            showBorder: Boolean, borderColor: Int, borderThickPx: Float
        ): Bitmap {
            if (padPx == 0 && radiusPx == 0f && !showBorder) return src
            val tw = src.width + padPx * 2; val th = src.height + padPx * 2
            val out = Bitmap.createBitmap(tw, th, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(out)
            val imgRect = RectF(padPx.toFloat(), padPx.toFloat(), (tw - padPx).toFloat(), (th - padPx).toFloat())
            if (radiusPx > 0f) {
                canvas.drawRoundRect(RectF(0f, 0f, tw.toFloat(), th.toFloat()), radiusPx, radiusPx,
                    Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bgColor })
                val path = Path().apply { addRoundRect(imgRect, radiusPx, radiusPx, Path.Direction.CW) }
                canvas.save(); canvas.clipPath(path)
                canvas.drawBitmap(src, padPx.toFloat(), padPx.toFloat(), null)
                canvas.restore()
            } else {
                canvas.drawBitmap(src, padPx.toFloat(), padPx.toFloat(), null)
            }
            if (showBorder && borderThickPx > 0f) {
                val half = borderThickPx / 2
                val borderRect = RectF(half, half, tw - half, th - half)
                val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = borderColor; style = Paint.Style.STROKE; strokeWidth = borderThickPx
                }
                if (radiusPx > 0f) canvas.drawRoundRect(borderRect, radiusPx, radiusPx, p)
                else canvas.drawRect(borderRect, p)
            }
            try { src.recycle() } catch (_: Exception) {}
            return out
        }

        // ── AlarmManager ───────────────────────────────────────────────────────

        fun scheduleAdvance(context: Context, intervalSec: Int) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = makePi(context, ACTION_ADVANCE, 100)
            val at = System.currentTimeMillis() + intervalSec * 1000L

            val canSchedule = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                am.canScheduleExactAlarms()
            } else true

            if (canSchedule) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                } else {
                    am.setExact(AlarmManager.RTC_WAKEUP, at, pi)
                }
                log(context, "scheduleAdvance exact in ${intervalSec}s")
            } else {
                // Fallback: alarma inexacta (menos precisa pero funciona sin el permiso)
                am.set(AlarmManager.RTC_WAKEUP, at, pi)
                log(context, "scheduleAdvance inexacto in ~${intervalSec}s (canScheduleExactAlarms=false)")
            }
        }

        fun cancelAdvance(context: Context) {
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
                .cancel(makePi(context, ACTION_ADVANCE, 100))
            log(context, "cancelAdvance")
        }

        fun scheduleHideControls(context: Context, delaySec: Int) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = makePi(context, ACTION_HIDE_CONTROLS, 101)
            val at = System.currentTimeMillis() + delaySec * 1000L
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, at, pi)
            }
            log(context, "scheduleHideControls in ${delaySec}s")
        }

        fun cancelHideControls(context: Context) {
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
                .cancel(makePi(context, ACTION_HIDE_CONTROLS, 101))
        }

        private fun makePi(context: Context, action: String, reqCode: Int): PendingIntent {
            val intent = Intent(context, ImageSlideShowWidgetProvider::class.java).apply { this.action = action }
            return PendingIntent.getBroadcast(context, reqCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        // ── SharedPreferences helpers ──────────────────────────────────────────

        fun writeCfgLong(context: Context, prop: String, value: Long) {
            context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
                .edit().putLong("flutter.widget_cfg_img_$prop", value).apply()
        }

        fun writeCfgBool(context: Context, prop: String, value: Boolean) {
            context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
                .edit().putBoolean("flutter.widget_cfg_img_$prop", value).apply()
        }

        private fun readFlutterBool(p: android.content.SharedPreferences, k: String, d: Boolean): Boolean =
            try { when (val v = p.all[k]) {
                is Boolean -> v; is String -> v.equals("true", true)
                is Int -> v != 0; is Long -> v != 0L; else -> d
            }} catch (_: Exception) { d }

        private fun fLong(p: android.content.SharedPreferences, k: String, d: Long): Long =
            try { when (val v = p.all[k]) {
                is Long -> v; is Int -> v.toLong(); is Float -> v.toLong()
                is Double -> v.toLong(); is String -> v.toLongOrNull() ?: d; else -> d
            }} catch (_: Exception) { d }

        private fun fInt(p: android.content.SharedPreferences, k: String, d: Int): Int =
            fLong(p, k, d.toLong()).toInt()

        private fun fColor(p: android.content.SharedPreferences, k: String, d: Long): Int =
            fLong(p, k, d).toInt()

        private fun fStr(p: android.content.SharedPreferences, k: String, d: String): String =
            try { (p.all[k] as? String)?.takeIf { it.isNotEmpty() } ?: d } catch (_: Exception) { d }
    }
}
