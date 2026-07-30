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
        // Controles siempre ocultos al iniciar/refrescar el widget
        writeCfgBool(context, PROP_CONTROLS_VISIBLE, false)
        cancelHideControls(context)
        val cfg = readCfg(context)
        if (cfg.imageList.isNotEmpty()) {
            scheduleAdvance(context, cfg.intervalSec)
            log(context, "onUpdate scheduleAdvance intervalSec=${cfg.intervalSec}")
        }
        for (id in appWidgetIds) {
            try { appWidgetManager.updateAppWidget(id, buildRemoteViews(context, appWidgetManager, cfg, id)) }
            catch (e: Throwable) { log(context, "onUpdate error id=$id: ${e.message}") }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action ?: return
        if (action !in listOf(ACTION_ADVANCE, ACTION_PREV, ACTION_NEXT,
                ACTION_TOGGLE_CONTROLS, ACTION_HIDE_CONTROLS)) return
        log(context, "onReceive action=$action")
        val pending = goAsync()
        Thread {
            try { handleAction(context, action) }
            catch (e: Throwable) { log(context, "handleAction CRASH $action: ${e.message}") }
            finally { pending.finish() }
        }.start()
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val remaining = AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, ImageSlideShowWidgetProvider::class.java))
        if (remaining.isEmpty()) { cancelAdvance(context); cancelHideControls(context) }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelAdvance(context); cancelHideControls(context)
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

        // ── Logging ──────────────────────────────────────────────────────────
        fun log(context: Context?, msg: String) {
            println("[$TAG] $msg")
            try { BtClassicServerService.sendDebugLogToPeers(TAG, msg) } catch (_: Throwable) {}
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
            val dotsPosition: Int,
            // Flechas
            val arrowColor: Int,
            val arrowBgColor: Int,
            val arrowSizeDp: Int,
            val arrowPosition: Int,   // 0=top  1=center  2=bottom
            val arrowBgRoundDp: Int
        )

        // ── Lógica principal ──────────────────────────────────────────────────

        private fun ts() = System.currentTimeMillis()

        private fun handleAction(context: Context, action: String) {
            val t0 = ts()
            val cfg = readCfg(context)
            log(context, "handleAction=$action imgCount=${cfg.imageList.size} idx=${cfg.currentIndex} ctrl=${cfg.controlsVisible}")
            when (action) {
                ACTION_ADVANCE -> {
                    if (cfg.imageList.isEmpty()) { scheduleAdvance(context, cfg.intervalSec); return }
                    val newIdx = if (cfg.loop) (cfg.currentIndex + 1) % cfg.imageList.size
                                 else (cfg.currentIndex + 1).coerceAtMost(cfg.imageList.size - 1)
                    log(context, "ADVANCE ${cfg.currentIndex}→$newIdx fxType=${cfg.fxType}")
                    writeCfgLong(context, PROP_CURRENT_INDEX, newIdx.toLong())
                    val newCfg = cfg.copy(currentIndex = newIdx)
                    if (cfg.fxType == 2 || cfg.fxType == 3) performFadeTransition(context, newCfg)
                    else updateAll(context, newCfg)
                    scheduleAdvance(context, cfg.intervalSec)
                }
                ACTION_PREV -> {
                    if (cfg.imageList.isEmpty()) return
                    val newIdx = (cfg.currentIndex - 1 + cfg.imageList.size) % cfg.imageList.size
                    log(context, "PREV ${cfg.currentIndex}→$newIdx")
                    writeCfgLong(context, PROP_CURRENT_INDEX, newIdx.toLong())
                    updateAll(context, cfg.copy(currentIndex = newIdx))
                    scheduleAdvance(context, cfg.intervalSec)
                    scheduleHideControls(context, cfg.controlsHideDelaySec)
                }
                ACTION_NEXT -> {
                    if (cfg.imageList.isEmpty()) return
                    val newIdx = (cfg.currentIndex + 1) % cfg.imageList.size
                    log(context, "NEXT ${cfg.currentIndex}→$newIdx")
                    writeCfgLong(context, PROP_CURRENT_INDEX, newIdx.toLong())
                    updateAll(context, cfg.copy(currentIndex = newIdx))
                    scheduleAdvance(context, cfg.intervalSec)
                    scheduleHideControls(context, cfg.controlsHideDelaySec)
                }
                ACTION_TOGGLE_CONTROLS -> {
                    val newVisible = !cfg.controlsVisible
                    log(context, "TOGGLE_CONTROLS → $newVisible")
                    writeCfgBool(context, PROP_CONTROLS_VISIBLE, newVisible)
                    if (newVisible) scheduleHideControls(context, cfg.controlsHideDelaySec)
                    else cancelHideControls(context)
                    updateAll(context, cfg.copy(controlsVisible = newVisible))
                }
                ACTION_HIDE_CONTROLS -> {
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
                intervalSec          = fInt(p, PF + "interval_sec", 10).coerceIn(3, 300),
                controlsHideDelaySec = fInt(p, PF + "controls_hide_delay_sec", 5).coerceIn(2, 30),
                controlsVisible      = readFlutterBool(p, PF + PROP_CONTROLS_VISIBLE, false),
                fxType               = fInt(p, PF + "fx_type", 0).coerceIn(0, 3),
                fxZoomPct            = fInt(p, PF + "fx_zoom_pct", 115).coerceIn(100, 160),
                fxColor              = fColor(p, PF + "fx_color", 0xFF000000L),
                cornerRadiusDp       = fInt(p, PF + "corner_radius_dp", 16).coerceIn(0, 80),
                paddingDp            = fInt(p, PF + "padding_dp", 0).coerceIn(0, 32),
                borderShow           = readFlutterBool(p, PF + "border_show", false),
                borderColor          = fColor(p, PF + "border_color", 0xFFFFFFFFL),
                borderThicknessDp    = fInt(p, PF + "border_thickness_dp", 2).coerceIn(0, 16),
                scaleType            = fInt(p, PF + "scale_type", 0).coerceIn(0, 4),
                bgColor              = fColor(p, PF + "bg_color", 0xFF000000L),
                scrimShow            = readFlutterBool(p, PF + "scrim_show", false),
                scrimColor           = fColor(p, PF + "scrim_color", 0x80000000L),
                scrimOpacity         = fInt(p, PF + "scrim_opacity", 50).coerceIn(0, 100),
                captionShow          = readFlutterBool(p, PF + "caption_show", false),
                captionSource        = fInt(p, PF + "caption_source", 0).coerceIn(0, 1),
                captionColor         = fColor(p, PF + "caption_color", 0xFFFFFFFFL),
                captionSizeSp        = fInt(p, PF + "caption_size_sp", 14).coerceIn(8, 36),
                captionBold          = readFlutterBool(p, PF + "caption_bold", false),
                captionPosition      = fInt(p, PF + "caption_position", 1).coerceIn(0, 1),
                captionBg            = fColor(p, PF + "caption_bg", 0x99000000L),
                captionPadDp         = fInt(p, PF + "caption_pad_dp", 8).coerceIn(0, 24),
                dotsShow             = readFlutterBool(p, PF + "dots_show", false),
                dotsActiveColor      = fColor(p, PF + "dots_active_color", 0xFFFFFFFFL),
                dotsInactiveColor    = fColor(p, PF + "dots_inactive_color", 0x80FFFFFFL),
                dotsSizeDp           = fInt(p, PF + "dots_size_dp", 8).coerceIn(4, 16),
                dotsSpacingDp        = fInt(p, PF + "dots_spacing_dp", 6).coerceIn(2, 16),
                dotsPosition         = fInt(p, PF + "dots_position", 1).coerceIn(0, 1),
                arrowColor           = fColor(p, PF + "arrow_color", 0xFFFFFFFFL),
                arrowBgColor         = fColor(p, PF + "arrow_bg_color", 0x66000000L),
                arrowSizeDp          = fInt(p, PF + "arrow_size_dp", 24).coerceIn(12, 44),
                arrowPosition        = fInt(p, PF + "arrow_position", 1).coerceIn(0, 2),
                arrowBgRoundDp       = fInt(p, PF + "arrow_bg_round_dp", 6).coerceIn(0, 24)
            )
        }

        fun updateAll(context: Context, cfg: ImageWidgetCfg? = null) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, ImageSlideShowWidgetProvider::class.java))
            if (ids.isEmpty()) { log(context, "updateAll: sin widgets"); return }
            val c = cfg ?: readCfg(context)
            log(context, "updateAll ids=${ids.toList()} imgCount=${c.imageList.size} idx=${c.currentIndex}")
            for (id in ids) {
                try {
                    mgr.updateAppWidget(id, buildRemoteViews(context, mgr, c, id))
                    log(context, "updateAll id=$id OK")
                } catch (e: Throwable) {
                    log(context, "updateAll id=$id ERROR: ${e.message}")
                }
            }
        }

        // ── RemoteViews ───────────────────────────────────────────────────────
        private fun buildRemoteViews(
            context: Context, mgr: AppWidgetManager,
            cfg: ImageWidgetCfg, appWidgetId: Int
        ): RemoteViews {
            val rv = RemoteViews(context.packageName, R.layout.widget_image_slideshow)

            // Click en root → toggle controles
            rv.setOnClickPendingIntent(R.id.widget_image_root,
                makePi(context, ACTION_TOGGLE_CONTROLS, 200 + appWidgetId))
            // Zonas de tap prev/next (FrameLayouts transparentes)
            rv.setOnClickPendingIntent(R.id.widget_image_prev_zone,
                makePi(context, ACTION_PREV, 300 + appWidgetId))
            rv.setOnClickPendingIntent(R.id.widget_image_next_zone,
                makePi(context, ACTION_NEXT, 400 + appWidgetId))

            val zoneVis = if (cfg.controlsVisible) View.VISIBLE else View.GONE
            rv.setViewVisibility(R.id.widget_image_prev_zone, zoneVis)
            rv.setViewVisibility(R.id.widget_image_next_zone, zoneVis)

            if (cfg.imageList.isEmpty()) {
                rv.setImageViewResource(R.id.widget_image_main, android.R.drawable.ic_menu_gallery)
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    action = ACTION_OPEN_EDITOR
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                rv.setOnClickPendingIntent(R.id.widget_image_root,
                    PendingIntent.getActivity(context, 500 + appWidgetId, openIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                log(context, "buildRV id=$appWidgetId sin imágenes → placeholder")
                return rv
            }

            val (wDp, hDp) = widgetDpSize(context, mgr, appWidgetId)
            val density = context.resources.displayMetrics.density
            val rawW = (wDp * density).toInt().coerceAtLeast(100)
            val rawH = (hDp * density).toInt().coerceAtLeast(100)
            val bmpScale = minOf(1f, MAX_BITMAP_PX.toFloat() / maxOf(rawW, rawH))
            val tW = (rawW * bmpScale).toInt()
            val tH = (rawH * bmpScale).toInt()
            log(context, "buildRV id=$appWidgetId ${wDp}x${hDp}dp → bitmap ${tW}x${tH}px idx=${cfg.currentIndex}")

            val bmp = renderFrame(context, cfg, cfg.currentIndex, tW, tH, wDp, hDp)
            if (bmp != null) rv.setImageViewBitmap(R.id.widget_image_main, bmp)
            else rv.setImageViewResource(R.id.widget_image_main, android.R.drawable.ic_menu_gallery)
            return rv
        }

        private fun widgetDpSize(context: Context, mgr: AppWidgetManager, id: Int): Pair<Int, Int> =
            try {
                val opts = mgr.getAppWidgetOptions(id)
                val w = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 200).coerceAtLeast(60)
                val h = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 200).coerceAtLeast(60)
                w to h
            } catch (_: Exception) { 200 to 200 }

        // ── Fade transition ───────────────────────────────────────────────────
        private fun performFadeTransition(context: Context, cfg: ImageWidgetCfg) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, ImageSlideShowWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val firstId = ids.first()
            val (wDp, hDp) = widgetDpSize(context, mgr, firstId)
            val density = context.resources.displayMetrics.density
            val rawW = (wDp * density).toInt().coerceAtLeast(100)
            val rawH = (hDp * density).toInt().coerceAtLeast(100)
            val bmpScale = minOf(1f, MAX_BITMAP_PX.toFloat() / maxOf(rawW, rawH))
            val tW = (rawW * bmpScale).toInt()
            val tH = (rawH * bmpScale).toInt()
            val fadeColor = if (cfg.fxType == 3) Color.WHITE else Color.BLACK
            log(context, "fade idx=${cfg.currentIndex} ${tW}x${tH}")

            val baseBmp = renderFrame(context, cfg, cfg.currentIndex, tW, tH, wDp, hDp)
                ?: run { updateAll(context, cfg); return }

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
                            rv.setOnClickPendingIntent(R.id.widget_image_root, makePi(context, ACTION_TOGGLE_CONTROLS, 200 + id))
                            rv.setOnClickPendingIntent(R.id.widget_image_prev_zone, makePi(context, ACTION_PREV, 300 + id))
                            rv.setOnClickPendingIntent(R.id.widget_image_next_zone, makePi(context, ACTION_NEXT, 400 + id))
                            val vis = if (cfg.controlsVisible) View.VISIBLE else View.GONE
                            rv.setViewVisibility(R.id.widget_image_prev_zone, vis)
                            rv.setViewVisibility(R.id.widget_image_next_zone, vis)
                            rv.setImageViewBitmap(R.id.widget_image_main, frameBmp)
                            mgr.updateAppWidget(id, rv)
                        } catch (_: Throwable) {}
                    }
                    if (alpha > 0) Thread.sleep(110)
                } catch (_: Throwable) {}
            }
            updateAll(context, cfg)
            try { baseBmp.recycle() } catch (_: Throwable) {}
        }

        // ── Pipeline de render ────────────────────────────────────────────────
        private fun renderFrame(
            context: Context, cfg: ImageWidgetCfg,
            index: Int, targetW: Int, targetH: Int,
            widthDp: Int, heightDp: Int
        ): Bitmap? {
            return try {
                val path = cfg.imageList.getOrNull(index) ?: run {
                    log(context, "renderFrame idx=$index fuera de rango size=${cfg.imageList.size}"); return null
                }
                val density = context.resources.displayMetrics.density
                val tDecode = ts()
                var bmp = decodeSampled(context, path, targetW, targetH) ?: run {
                    log(context, "renderFrame decodeSampled null path=$path"); return null
                }
                log(context, "renderFrame idx=$index decoded ${bmp.width}x${bmp.height} → target ${targetW}x${targetH}")
                bmp = applyScaleType(bmp, targetW, targetH, cfg.scaleType, cfg.bgColor)
                if (cfg.fxType == 1) bmp = applyKenBurns(bmp, index, cfg.fxZoomPct)
                if (cfg.scrimShow) bmp = applyScrim(bmp, cfg.scrimColor, cfg.scrimOpacity)
                if (cfg.captionShow) {
                    val text = captionText(path, cfg)
                    if (text.isNotEmpty()) bmp = applyCaption(bmp, text, cfg, density)
                }
                if (cfg.dotsShow && cfg.imageList.size > 1) {
                    bmp = applyDots(bmp, cfg.imageList.size, index, cfg, widthDp)
                }
                // Flechas dibujadas en el bitmap para control total de apariencia
                if (cfg.controlsVisible) {
                    bmp = applyArrows(bmp, cfg, widthDp, heightDp)
                }
                bmp = applyFraming(bmp, (cfg.paddingDp * density).toInt(),
                    cfg.cornerRadiusDp * density, cfg.bgColor,
                    cfg.borderShow, cfg.borderColor, cfg.borderThicknessDp * density)
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
            } catch (e: Throwable) { log(null, "decodeSampled error: ${e.message}"); null }
        }

        private fun openImageStream(context: Context, path: String): InputStream? {
            try { val f = File(path); if (f.exists()) return f.inputStream() } catch (_: Exception) {}
            return try { context.contentResolver.openInputStream(Uri.fromFile(File(path))) }
                   catch (_: Exception) { null }
        }

        private fun calcSampleSize(opts: BitmapFactory.Options, reqW: Int, reqH: Int): Int {
            val h = opts.outHeight; val w = opts.outWidth; var s = 1
            if (h > reqH || w > reqW) {
                val hh = h / 2; val hw = w / 2
                while ((hh / s) >= reqH && (hw / s) >= reqW) s *= 2
            }
            return s
        }

        /**
         * Escalado de imagen con fórmula simétrica basada en el centro.
         * Usa half-widths para garantizar que ambos márgenes sean idénticos
         * (evita el error de redondeo float de la fórmula (dw±sw*s)/2).
         */
        private fun applyScaleType(src: Bitmap, tw: Int, th: Int, scaleType: Int, bgColor: Int): Bitmap {
            val out = Bitmap.createBitmap(tw, th, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(out)
            canvas.drawColor(bgColor)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
            val sw = src.width.toFloat(); val sh = src.height.toFloat()
            val dw = tw.toFloat(); val dh = th.toFloat()
            val cx = dw / 2f; val cy = dh / 2f

            val dst: RectF = when (scaleType) {
                0, 1 -> { // cover (1=contain eliminado, se trata como cover)
                    val s = maxOf(dw / sw, dh / sh)
                    val hw = sw * s / 2f; val hh = sh * s / 2f
                    RectF(cx - hw, cy - hh, cx + hw, cy + hh)
                }
                2 -> RectF(0f, 0f, dw, dh) // stretch
                3 -> { // none: tamaño original centrado
                    val hw = sw / 2f; val hh = sh / 2f
                    RectF(cx - hw, cy - hh, cx + hw, cy + hh)
                }
                4 -> { // fitWidth
                    val s = dw / sw
                    val hh = sh * s / 2f
                    RectF(0f, cy - hh, dw, cy + hh)
                }
                else -> RectF(0f, 0f, dw, dh)
            }
            // LOG: dimensiones de escalado para diagnosticar centrado
            val scaleName = arrayOf("COVER","CONTAIN","FILL","NONE","FIT_WIDTH").getOrElse(scaleType) { "?" }
            log(null, "applyScaleType[$scaleName] src=${sw.toInt()}x${sh.toInt()} target=${tw}x${th} dst=[${dst.left.toInt()},${dst.top.toInt()},${dst.right.toInt()},${dst.bottom.toInt()}] dstSize=${(dst.right-dst.left).toInt()}x${(dst.bottom-dst.top).toInt()}")
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

        private fun captionText(path: String, cfg: ImageWidgetCfg): String =
            if (cfg.captionSource == 0) File(path).nameWithoutExtension
            else {
                val ms = try { File(path).lastModified() } catch (_: Exception) { 0L }
                if (ms > 0) SimpleDateFormat("dd/MM/yyyy", Locale.getDefault()).format(Date(ms)) else ""
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
            canvas.drawText(displayText, ((w - textPaint.measureText(displayText)) / 2).coerceAtLeast(padPx),
                bgRect.top + padPx + textH - fm.descent, textPaint)
            return out
        }

        /** Dots con fórmula de escala correcta: dotR_px = (sizeDp/2) × (bitmapPx / widgetDp). */
        private fun applyDots(src: Bitmap, total: Int, current: Int, cfg: ImageWidgetCfg, widthDp: Int): Bitmap {
            val out = src.copy(Bitmap.Config.ARGB_8888, true)
            val canvas = Canvas(out)
            val bmpW = out.width.toFloat(); val bmpH = out.height.toFloat()
            val pxPerDp = bmpW / widthDp.toFloat()
            val dotR = ((cfg.dotsSizeDp / 2f) * pxPerDp).coerceAtLeast(4f)
            val spacing = cfg.dotsSpacingDp * pxPerDp
            val margin = dotR + 8 * pxPerDp
            val maxDots = 12
            val display = minOf(total, maxDots)
            val windowStart = if (total <= maxDots) 0 else (current - maxDots / 2).coerceIn(0, total - maxDots)
            val rowW = display * (dotR * 2 + spacing) - spacing
            var x = (bmpW - rowW) / 2 + dotR
            val y = if (cfg.dotsPosition == 0) margin else bmpH - margin
            for (i in 0 until display) {
                canvas.drawCircle(x, y, dotR, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = if (windowStart + i == current) cfg.dotsActiveColor else cfg.dotsInactiveColor
                })
                x += dotR * 2 + spacing
            }
            return out
        }

        /**
         * Dibuja las flechas prev/next directamente sobre el bitmap.
         * Tamaño, color, fondo y posición vertical completamente configurables.
         * La escala usa pxPerDp igual que los dots para coherencia visual.
         */
        private fun applyArrows(src: Bitmap, cfg: ImageWidgetCfg, widthDp: Int, heightDp: Int): Bitmap {
            val out = src.copy(Bitmap.Config.ARGB_8888, true)
            val canvas = Canvas(out)
            val bmpW = out.width.toFloat(); val bmpH = out.height.toFloat()
            val pxPerDp = bmpW / widthDp.toFloat()

            val arrowPx = (cfg.arrowSizeDp * pxPerDp).coerceAtLeast(12f)
            val bgPad = arrowPx * 0.4f
            val bgHalf = (arrowPx + bgPad) / 2f
            val bgRadius = cfg.arrowBgRoundDp * pxPerDp
            val margin = bgHalf + 6 * pxPerDp

            val cy = when (cfg.arrowPosition) {
                0 -> margin + bgHalf         // top
                2 -> bmpH - margin - bgHalf  // bottom
                else -> bmpH / 2f            // center
            }

            drawArrow(canvas, margin + bgHalf, cy, arrowPx, bgHalf, bgRadius,
                cfg.arrowBgColor, cfg.arrowColor, isNext = false)
            drawArrow(canvas, bmpW - margin - bgHalf, cy, arrowPx, bgHalf, bgRadius,
                cfg.arrowBgColor, cfg.arrowColor, isNext = true)

            return out
        }

        private fun drawArrow(
            canvas: Canvas, cx: Float, cy: Float,
            arrowPx: Float, bgHalf: Float, bgRadius: Float,
            bgColor: Int, iconColor: Int, isNext: Boolean
        ) {
            // Fondo
            val bgRect = RectF(cx - bgHalf, cy - bgHalf, cx + bgHalf, cy + bgHalf)
            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = bgColor }
            if (bgRadius > 0f) canvas.drawRoundRect(bgRect, bgRadius, bgRadius, bgPaint)
            else canvas.drawRect(bgRect, bgPaint)

            // Chevron
            val arm = arrowPx * 0.36f
            val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = iconColor; style = Paint.Style.STROKE
                strokeWidth = (arrowPx * 0.18f).coerceAtLeast(2f)
                strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
            }
            val path = Path()
            if (isNext) {
                path.moveTo(cx - arm * 0.5f, cy - arm)
                path.lineTo(cx + arm * 0.5f, cy)
                path.lineTo(cx - arm * 0.5f, cy + arm)
            } else {
                path.moveTo(cx + arm * 0.5f, cy - arm)
                path.lineTo(cx - arm * 0.5f, cy)
                path.lineTo(cx + arm * 0.5f, cy + arm)
            }
            canvas.drawPath(path, iconPaint)
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
            } else canvas.drawBitmap(src, padPx.toFloat(), padPx.toFloat(), null)
            if (showBorder && borderThickPx > 0f) {
                val half = borderThickPx / 2
                val br = RectF(half, half, tw - half, th - half)
                val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = borderColor; style = Paint.Style.STROKE; strokeWidth = borderThickPx
                }
                if (radiusPx > 0f) canvas.drawRoundRect(br, radiusPx, radiusPx, p) else canvas.drawRect(br, p)
            }
            try { src.recycle() } catch (_: Exception) {}
            return out
        }

        // ── AlarmManager ─────────────────────────────────────────────────────
        fun scheduleAdvance(context: Context, intervalSec: Int) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = makePi(context, ACTION_ADVANCE, 100)
            val at = System.currentTimeMillis() + intervalSec * 1000L
            val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) am.canScheduleExactAlarms() else true
            if (canExact) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                else am.setExact(AlarmManager.RTC_WAKEUP, at, pi)
                log(context, "scheduleAdvance exact ${intervalSec}s")
            } else {
                am.set(AlarmManager.RTC_WAKEUP, at, pi)
                log(context, "scheduleAdvance inexacto ~${intervalSec}s (canScheduleExactAlarms=false)")
            }
        }

        fun cancelAdvance(context: Context) =
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
                .cancel(makePi(context, ACTION_ADVANCE, 100))

        fun scheduleHideControls(context: Context, delaySec: Int) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = makePi(context, ACTION_HIDE_CONTROLS, 101)
            val at = System.currentTimeMillis() + delaySec * 1000L
            val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) am.canScheduleExactAlarms() else true
            if (canExact) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                else am.setExact(AlarmManager.RTC_WAKEUP, at, pi)
                log(context, "scheduleHideControls exact ${delaySec}s")
            } else {
                am.set(AlarmManager.RTC_WAKEUP, at, pi)
                log(context, "scheduleHideControls inexacto ~${delaySec}s (canScheduleExactAlarms=false)")
            }
        }

        fun cancelHideControls(context: Context) =
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
                .cancel(makePi(context, ACTION_HIDE_CONTROLS, 101))

        private fun makePi(context: Context, action: String, reqCode: Int): PendingIntent {
            val intent = Intent(context, ImageSlideShowWidgetProvider::class.java).apply { this.action = action }
            return PendingIntent.getBroadcast(context, reqCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        // ── SharedPreferences ─────────────────────────────────────────────────
        fun writeCfgLong(context: Context, prop: String, value: Long) =
            context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
                .edit().putLong("flutter.widget_cfg_img_$prop", value).apply()

        fun writeCfgBool(context: Context, prop: String, value: Boolean) =
            context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
                .edit().putBoolean("flutter.widget_cfg_img_$prop", value).apply()

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

        private fun fInt(p: android.content.SharedPreferences, k: String, d: Int): Int = fLong(p, k, d.toLong()).toInt()
        private fun fColor(p: android.content.SharedPreferences, k: String, d: Long): Int = fLong(p, k, d).toInt()
        private fun fStr(p: android.content.SharedPreferences, k: String, d: String): String =
            try { (p.all[k] as? String)?.takeIf { it.isNotEmpty() } ?: d } catch (_: Exception) { d }
    }
}
