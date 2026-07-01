package com.example.connect

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.Base64
import android.view.ViewGroup
import android.widget.RemoteViews
import org.json.JSONObject
 
abstract class BaseMediaWidgetProvider : AppWidgetProvider() {
    protected abstract val layoutResId: Int
    private fun logPrefix(): String = "[widget][${this.javaClass.simpleName}]"
 
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        println("${logPrefix()} onEnabled")
    }
 
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        println("${logPrefix()} onDisabled")
    }
 
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        println("${logPrefix()} onDeleted ids=${appWidgetIds.joinToString(",")}")
    }
 
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        println("${logPrefix()} onAppWidgetOptionsChanged id=$appWidgetId options=${bundleToShortString(newOptions)}")
        try {
            updateAppWidgets(context, appWidgetManager, intArrayOf(appWidgetId), layoutResId, uiPrefsName(), this.javaClass)
        } catch (t: Throwable) {
            println("${logPrefix()} onAppWidgetOptionsChanged update failed id=$appWidgetId t=${t::class.java.simpleName} msg=${t.message}")
            t.printStackTrace()
        }
    }
 
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        println("${logPrefix()} onUpdate ids=${appWidgetIds.joinToString(",")} layoutResId=$layoutResId")
        updateAppWidgets(context, appWidgetManager, appWidgetIds, layoutResId, uiPrefsName(), this.javaClass)
    }
 
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: ""
        val extrasKeys = try { intent.extras?.keySet()?.joinToString(",") ?: "" } catch (_: Exception) { "" }
        super.onReceive(context, intent)
 
        val appWidgetId = try { intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID) } catch (_: Exception) { AppWidgetManager.INVALID_APPWIDGET_ID }
        val pct = try { intent.getIntExtra(EXTRA_PCT, -1) } catch (_: Exception) { -1 }
        println("${logPrefix()} onReceive action='$action' id=$appWidgetId pct=$pct extras=[$extrasKeys]")
 
        when (intent.action) {
            ACTION_TOGGLE -> {
                val hasPlayback = try { hasSelectedPlaybackFresh(context) } catch (_: Exception) { false }
                if (hasPlayback) {
                    sendMediaCommand(context, "toggle")
                } else {
                    sendLaunchDefaultMediaApp(context, forcePlay = true, pauseOthers = false)
                }
                updateAll(context)
            }
            ACTION_NEXT -> {
                sendMediaCommand(context, "next")
                updateAll(context)
            }
            ACTION_PREV -> {
                sendMediaCommand(context, "previous")
                updateAll(context)
            }
            ACTION_TOGGLE_VOLUME -> {
                if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    toggleVolumeExpanded(context, uiPrefsName(), appWidgetId)
                }
                sendVolumeRequest(context)
                updateAll(context)
            }
            ACTION_SET_VOLUME -> {
                if (pct in 0..100) {
                    sendVolumeCommand(context, pct)
                }
                updateAll(context)
            }
            ACTION_LAUNCH_DEFAULT_MEDIA_APP -> {
                sendLaunchDefaultMediaApp(context, forcePlay = false, pauseOthers = false)
                updateAll(context)
            }
            ACTION_LAUNCH_DEFAULT_MEDIA_APP_PLAY -> {
                sendLaunchDefaultMediaApp(context, forcePlay = true, pauseOthers = true)
                updateAll(context)
            }
            ACTION_OPEN_APP -> {
                updateAll(context)
            }
        }
    }

    protected open fun uiPrefsName(): String = "bt_widget_ui_${this.javaClass.simpleName}"

    private fun updateAll(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, this.javaClass)
        val ids = mgr.getAppWidgetIds(component)
        println("${logPrefix()} updateAll ids=${ids.joinToString(",")}")
        if (ids.isEmpty()) return
        updateAppWidgets(context, mgr, ids, layoutResId, uiPrefsName(), this.javaClass)
    }
 
    companion object {
        private const val PREFS_MEDIA_CACHE = "bt_media_cache_v1"
        private const val KEY_MEDIA_JSON = "media_json"
        private const val KEY_MEDIA_UPDATED_AT_MS = "updatedAtMs"
        private const val KEY_ART_BASE64 = "artBase64"
        private const val KEY_ART_KEY = "artKey"
        private const val KEY_ART_PKG = "artPkg"
        private const val KEY_ART_UPDATED_AT_MS = "artUpdatedAtMs"

        private const val PREFS_LOCAL_MEDIA_CACHE = "local_media_cache_v1"
        private const val PREFS_FLUTTER_SHARED = "FlutterSharedPreferences"
        private const val KEY_FLUTTER_PRIORITIZE_LOCAL_MEDIA = "flutter.prioritize_local_media"

        private const val PREFS_VOLUME_CACHE = "bt_volume_cache_v1"
        private const val KEY_VOLUME_PCT = "pct"
        private const val KEY_VOLUME_UPDATED_AT_MS = "updatedAtMs"

        private const val PREFS_FLUTTER = "FlutterSharedPreferences"
        private const val KEY_FLUTTER_WIDGET_TEXT_SP = "flutter.widget_text_sp"
        private const val KEY_FLUTTER_WIDGET_ICON_SP = "flutter.widget_icon_sp"
        private const val KEY_FLUTTER_MEDIA_DEFAULT_APP_PACKAGE = "flutter.media_default_app_package"
        private const val KEY_FLUTTER_MEDIA_DEFAULT_APP_ICON_BASE64 = "flutter.media_default_app_icon_base64"
        private const val KEY_FLUTTER_MEDIA_DEFAULT_APP_WIDGET2_ICON_BASE64 = "flutter.media_default_app_widget2_icon_base64"
        private const val KEY_FLUTTER_MEDIA_DEFAULT_APP_INSTALLED = "flutter.media_default_app_installed"
        private const val KEY_FLUTTER_MEDIA_DEFAULT_APP_INSTALLED_PKG = "flutter.media_default_app_installed_pkg"

        private const val ACTION_PREFIX = "com.example.connect.widget.MEDIA"
        const val ACTION_TOGGLE = "$ACTION_PREFIX.TOGGLE"
        const val ACTION_NEXT = "$ACTION_PREFIX.NEXT"
        const val ACTION_PREV = "$ACTION_PREFIX.PREV"
        const val ACTION_OPEN_APP = "$ACTION_PREFIX.OPEN_APP"
        const val ACTION_TOGGLE_VOLUME = "$ACTION_PREFIX.TOGGLE_VOLUME"
        const val ACTION_SET_VOLUME = "$ACTION_PREFIX.SET_VOLUME"
        const val ACTION_LAUNCH_DEFAULT_MEDIA_APP = "$ACTION_PREFIX.LAUNCH_DEFAULT_MEDIA_APP"
        const val ACTION_LAUNCH_DEFAULT_MEDIA_APP_PLAY = "$ACTION_PREFIX.LAUNCH_DEFAULT_MEDIA_APP_PLAY"

        private const val EXTRA_PCT = "pct"
        private const val EXTRA_WIDGET_ID = "appWidgetId"
        private const val WIDGET_LOG_PREFIX = "[widget]"
 
        private fun bundleToShortString(bundle: Bundle?): String {
            if (bundle == null) return "null"
            return try {
                val keys = bundle.keySet().sorted()
                keys.joinToString(",") { k ->
                    val v = try { bundle.get(k) } catch (_: Exception) { null }
                    "$k=$v"
                }
            } catch (t: Throwable) {
                "err:${t::class.java.simpleName}"
            }
        }
 
        private fun safeResName(context: Context, resId: Int): String {
            return try { context.resources.getResourceName(resId) } catch (_: Exception) { resId.toString() }
        }

        private fun readFlutterBool(prefs: android.content.SharedPreferences, key: String, defaultValue: Boolean): Boolean {
            return try {
                val v = prefs.all[key]
                when (v) {
                    is Boolean -> v
                    is String -> v.equals("true", ignoreCase = true)
                    is Int -> v != 0
                    is Long -> v != 0L
                    else -> defaultValue
                }
            } catch (_: Exception) {
                defaultValue
            }
        }

        private fun readLocalVolumePct(context: Context): Int {
            return try {
                val audio = context.getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager ?: return 0
                val stream = android.media.AudioManager.STREAM_MUSIC
                val level = audio.getStreamVolume(stream)
                val max = audio.getStreamMaxVolume(stream)
                if (max <= 0) return 0
                ((level.toDouble() / max.toDouble()) * 100.0).toInt().coerceIn(0, 100)
            } catch (_: Exception) {
                0
            }
        }

        fun updateAll(context: Context, providerClass: Class<out AppWidgetProvider>, layoutResId: Int) {
            val mgr = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, providerClass)
            val ids = mgr.getAppWidgetIds(component)
            println("$WIDGET_LOG_PREFIX[${providerClass.simpleName}] updateAll(ids=${ids.joinToString(",")}, layout=${safeResName(context, layoutResId)})")
            if (ids.isEmpty()) return
            val uiPrefsName = "bt_widget_ui_${providerClass.simpleName}"
            updateAppWidgets(context, mgr, ids, layoutResId, uiPrefsName, providerClass)
        }
 
        // ===== Configuración editable del widget (claves flutter.widget_cfg_<id>_<prop>) =====

        private data class WidgetCfg(
            val scale: Float,
            val titleSp: Float, val titleColor: Int, val titleBold: Boolean,
            val subtitleSp: Float, val subtitleColor: Int, val subtitleBold: Boolean,
            val timeSp: Float, val timeColor: Int, val timeBold: Boolean,
            val bgNoImage: Int, val scrim: Int, val artAlpha: Int,
            val iconColor: Int, val applyIconColor: Boolean, val iconSizeDp: Int,
            val iconPrev: String, val iconPlay: String, val iconPause: String,
            val iconNext: String, val iconVolume: String,
            val barTrack: Int, val barFill: Int, val barProgThickDp: Int, val barVolThickDp: Int,
            val noMediaTitle: String, val noMediaSubtitle: String,
            val paddingDp: Int, val showDefaultAppBtn: Boolean, val rowSpacingDp: Int,
            val artAsBackground: Boolean, val artScaleType: String
        )

        private fun hasDefaultAppBtn(layoutResId: Int): Boolean =
            layoutResId == R.layout.widget_media_style2 ||
                layoutResId == R.layout.widget_media_style3 ||
                layoutResId == R.layout.widget_media_wide

        private fun dp(context: Context, v: Float): Int =
            (v * context.resources.displayMetrics.density).toInt().coerceAtLeast(1)

        private fun fLong(p: android.content.SharedPreferences, k: String, d: Long): Long {
            return try {
                when (val v = p.all[k]) {
                    is Long -> v
                    is Int -> v.toLong()
                    is Float -> v.toLong()
                    is Double -> v.toLong()
                    is String -> v.toLongOrNull() ?: d
                    else -> d
                }
            } catch (_: Exception) { d }
        }

        private fun fInt(p: android.content.SharedPreferences, k: String, d: Int): Int =
            fLong(p, k, d.toLong()).toInt()

        private fun fColor(p: android.content.SharedPreferences, k: String, d: Int): Int =
            fLong(p, k, d.toLong() and 0xFFFFFFFFL).toInt()

        private fun fStr(p: android.content.SharedPreferences, k: String, d: String): String {
            return try { (p.all[k] as? String)?.takeIf { it.isNotEmpty() } ?: d } catch (_: Exception) { d }
        }

        private fun readWidgetCfg(prefs: android.content.SharedPreferences, configId: String): WidgetCfg {
            val pf = "flutter.widget_cfg_${configId}_"
            val scale = fInt(prefs, pf + "content_scale_pct", 100).coerceIn(50, 200) / 100f
            val defProgThick = if (configId == "style3") 24 else 8
            return WidgetCfg(
                scale = scale,
                titleSp = fInt(prefs, pf + "title_size_sp", 33).coerceIn(8, 80) * scale,
                titleColor = fColor(prefs, pf + "title_color_argb", 0xFFFFFFFF.toInt()),
                titleBold = readFlutterBool(prefs, pf + "title_bold", true),
                subtitleSp = fInt(prefs, pf + "subtitle_size_sp", 21).coerceIn(8, 80) * scale,
                subtitleColor = fColor(prefs, pf + "subtitle_color_argb", 0xFFFFFFFF.toInt()),
                subtitleBold = readFlutterBool(prefs, pf + "subtitle_bold", false),
                timeSp = fInt(prefs, pf + "time_size_sp", 18).coerceIn(8, 80) * scale,
                timeColor = fColor(prefs, pf + "time_color_argb", 0xFFFFFFFF.toInt()),
                timeBold = readFlutterBool(prefs, pf + "time_bold", false),
                bgNoImage = fColor(prefs, pf + "bg_no_image_argb", 0xFF000000.toInt()),
                scrim = fColor(prefs, pf + "scrim_argb", 0x80000000.toInt()),
                artAlpha = fInt(prefs, pf + "art_alpha", 255).coerceIn(0, 255),
                iconColor = fColor(prefs, pf + "icon_color_argb", 0xFFFFFFFF.toInt()),
                applyIconColor = try { prefs.all.containsKey(pf + "icon_color_argb") } catch (_: Exception) { false },
                iconSizeDp = fInt(prefs, pf + "icon_size_dp", 0).coerceIn(0, 64),
                iconPrev = fStr(prefs, pf + "icon_prev_b64", ""),
                iconPlay = fStr(prefs, pf + "icon_play_b64", ""),
                iconPause = fStr(prefs, pf + "icon_pause_b64", ""),
                iconNext = fStr(prefs, pf + "icon_next_b64", ""),
                iconVolume = fStr(prefs, pf + "icon_volume_b64", ""),
                barTrack = fColor(prefs, pf + "bar_track_argb", 0x33FFFFFF),
                barFill = fColor(prefs, pf + "bar_fill_argb", 0xFFFFFFFF.toInt()),
                barProgThickDp = fInt(prefs, pf + "bar_progress_thickness_dp", defProgThick).coerceIn(1, 48),
                barVolThickDp = fInt(prefs, pf + "bar_volume_thickness_dp", 28).coerceIn(1, 48),
                noMediaTitle = fStr(prefs, pf + "no_media_title", "Sin reproducción"),
                noMediaSubtitle = fStr(prefs, pf + "no_media_subtitle", "Conecta el emisor para controlar"),
                paddingDp = (12 * scale).toInt().coerceAtLeast(0),
                showDefaultAppBtn = readFlutterBool(prefs, pf + "show_default_app_btn", true),
                rowSpacingDp = fInt(prefs, pf + "row_spacing_dp", 0).coerceIn(0, 48),
                artAsBackground = readFlutterBool(prefs, pf + "art_as_background", false),
                artScaleType = fStr(prefs, pf + "art_scale_type", "crop")
            )
        }

        private fun styled(text: String, bold: Boolean): CharSequence {
            if (!bold || text.isEmpty()) return text
            val s = android.text.SpannableString(text)
            s.setSpan(
                android.text.style.StyleSpan(android.graphics.Typeface.BOLD),
                0, text.length, android.text.Spannable.SPAN_INCLUSIVE_INCLUSIVE
            )
            return s
        }

        private fun applyTextStyles(views: RemoteViews, layoutResId: Int, cfg: WidgetCfg) {
            val sp = android.util.TypedValue.COMPLEX_UNIT_SP
            views.setTextViewTextSize(R.id.widget_title, sp, cfg.titleSp)
            views.setTextColor(R.id.widget_title, cfg.titleColor)
            views.setTextViewTextSize(R.id.widget_subtitle, sp, cfg.subtitleSp)
            views.setTextColor(R.id.widget_subtitle, cfg.subtitleColor)
            views.setTextViewTextSize(R.id.widget_time, sp, cfg.timeSp)
            views.setTextColor(R.id.widget_time, cfg.timeColor)
            if (layoutResId == R.layout.widget_media_style2) {
                try {
                    views.setTextViewTextSize(R.id.widget_app_name, sp, cfg.subtitleSp)
                    views.setTextColor(R.id.widget_app_name, cfg.subtitleColor)
                } catch (_: Exception) {}
            }
            if (layoutResId == R.layout.widget_media_style3) {
                try {
                    for (id in intArrayOf(R.id.widget_time_current, R.id.widget_time_app, R.id.widget_time_total)) {
                        views.setTextViewTextSize(id, sp, cfg.timeSp)
                        views.setTextColor(id, cfg.timeColor)
                    }
                } catch (_: Exception) {}
            }
        }

        private fun drawableToBitmap(context: Context, resId: Int, px: Int, tint: Int): Bitmap? {
            return try {
                val d = context.getDrawable(resId)?.mutate() ?: return null
                d.setTint(tint)
                val size = px.coerceAtLeast(1)
                val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
                val c = android.graphics.Canvas(bmp)
                d.setBounds(0, 0, size, size)
                d.draw(c)
                bmp
            } catch (_: Exception) { null }
        }

        private fun applyControlIcon(
            context: Context,
            views: RemoteViews,
            viewId: Int,
            overrideB64: String,
            builtinResId: Int,
            cfg: WidgetCfg
        ) {
            val px = when {
                cfg.iconSizeDp > 0 -> dp(context, cfg.iconSizeDp * cfg.scale)
                cfg.scale != 1f -> dp(context, 34f * cfg.scale)
                else -> 0
            }
            if (overrideB64.isNotBlank()) {
                val decoded = decodeArtBitmap(overrideB64, if (px > 0) px else 96)
                if (decoded != null) {
                    val out = if (px > 0) {
                        try { Bitmap.createScaledBitmap(decoded, px, px, true) } catch (_: Exception) { decoded }
                    } else decoded
                    try { views.setImageViewBitmap(viewId, out); return } catch (_: Exception) {}
                }
            }
            if (px > 0) {
                val tint = if (cfg.applyIconColor) cfg.iconColor else 0xFFFFFFFF.toInt()
                val bmp = drawableToBitmap(context, builtinResId, px, tint)
                if (bmp != null) {
                    try { views.setImageViewBitmap(viewId, bmp); return } catch (_: Exception) {}
                }
            }
            try { views.setImageViewResource(viewId, builtinResId) } catch (_: Exception) {}
            if (cfg.applyIconColor) {
                try { views.setInt(viewId, "setColorFilter", cfg.iconColor) } catch (_: Exception) {}
            }
        }

        private fun renderBar(
            widthPx: Int, heightPx: Int, thicknessPx: Int,
            progress: Float, track: Int, fill: Int, drawThumb: Boolean
        ): Bitmap {
            val w = widthPx.coerceAtLeast(1)
            val h = heightPx.coerceAtLeast(1)
            val th = thicknessPx.coerceIn(1, h)
            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val c = android.graphics.Canvas(bmp)
            val top = (h - th) / 2f
            val bottom = top + th
            val r = th / 2f
            val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
            paint.color = track
            c.drawRoundRect(android.graphics.RectF(0f, top, w.toFloat(), bottom), r, r, paint)
            val p = progress.coerceIn(0f, 1f)
            val fw = w * p
            if (fw > 0f) {
                paint.color = fill
                c.drawRoundRect(android.graphics.RectF(0f, top, fw, bottom), r, r, paint)
                if (drawThumb) {
                    val cx = fw.coerceIn(r, w - r)
                    c.drawCircle(cx, h / 2f, (th * 0.6f).coerceAtLeast(r), paint)
                }
            }
            return bmp
        }

        private fun updateAppWidgets(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray,
            layoutResId: Int,
            uiPrefsName: String,
            providerClass: Class<out AppWidgetProvider>
        ) {
            println("$WIDGET_LOG_PREFIX[${providerClass.simpleName}] updateAppWidgets(ids=${appWidgetIds.joinToString(",")}, layout=${safeResName(context, layoutResId)}, uiPrefs='$uiPrefsName')")
            for (appWidgetId in appWidgetIds) {
                val options = try { appWidgetManager.getAppWidgetOptions(appWidgetId) } catch (_: Exception) { null }
                println("$WIDGET_LOG_PREFIX[${providerClass.simpleName}] widgetId=$appWidgetId options=${bundleToShortString(options)}")
                try {
                    val views = buildRemoteViews(
                        context,
                        appWidgetId,
                        providerClass = providerClass,
                        layoutResId = layoutResId,
                        uiPrefsName = uiPrefsName
                    )
                    try {
                        views.apply(context, null as ViewGroup?)
                        println("$WIDGET_LOG_PREFIX[${providerClass.simpleName}] widgetId=$appWidgetId remoteviews_apply=OK")
                    } catch (t: Throwable) {
                        println("$WIDGET_LOG_PREFIX[${providerClass.simpleName}] widgetId=$appWidgetId remoteviews_apply=FAIL t=${t::class.java.simpleName} msg=${t.message}")
                        t.printStackTrace()
                    }
                    try {
                        appWidgetManager.updateAppWidget(appWidgetId, views)
                        println("$WIDGET_LOG_PREFIX[${providerClass.simpleName}] widgetId=$appWidgetId updateAppWidget=OK")
                    } catch (t: Throwable) {
                        println("$WIDGET_LOG_PREFIX[${providerClass.simpleName}] widgetId=$appWidgetId updateAppWidget=FAIL t=${t::class.java.simpleName} msg=${t.message}")
                        t.printStackTrace()
                    }
                } catch (t: Throwable) {
                    println("$WIDGET_LOG_PREFIX[${providerClass.simpleName}] widgetId=$appWidgetId buildRemoteViews=FAIL t=${t::class.java.simpleName} msg=${t.message}")
                    t.printStackTrace()
                }
            }
        }

        private fun buildRemoteViews(
            context: Context,
            appWidgetId: Int,
            providerClass: Class<out AppWidgetProvider>,
            layoutResId: Int,
            uiPrefsName: String
        ): RemoteViews {
            val views = RemoteViews(context.packageName, layoutResId)

            val prefsFlutter = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            val configId = providerClass.simpleName.removePrefix("MediaWidgetProvider").lowercase()
            val cfg = readWidgetCfg(prefsFlutter, configId)

            // Dimensiones reales del widget para pre-procesar el bitmap según artScaleType.
            val widgetMgr = try { AppWidgetManager.getInstance(context) } catch (_: Exception) { null }
            val widgetOpts = try { widgetMgr?.getAppWidgetOptions(appWidgetId) } catch (_: Exception) { null }
            val density = context.resources.displayMetrics.density
            val widthDp = widgetOpts?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0) ?: 0
            val heightDp = widgetOpts?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0
            val artCanvasW = if (widthDp > 0) (widthDp * density).toInt().coerceIn(100, 1200) else 600
            val artCanvasH = if (heightDp > 0) (heightDp * density).toInt().coerceIn(100, 1200) else 400

            applyTextStyles(views, layoutResId, cfg)
            val padPx = dp(context, cfg.paddingDp.toFloat())
            try { views.setViewPadding(R.id.widget_overlay, padPx, padPx, padPx, padPx) } catch (_: Exception) {}

            applyControlIcon(context, views, R.id.widget_prev, cfg.iconPrev, R.drawable.widget_ic_prev, cfg)
            applyControlIcon(context, views, R.id.widget_next, cfg.iconNext, R.drawable.widget_ic_next, cfg)
            applyControlIcon(context, views, R.id.widget_volume_btn, cfg.iconVolume, R.drawable.widget_ic_volume, cfg)

            val noopRootPending = PendingIntent.getBroadcast(
                context,
                stableRequestCode(providerClass.name, 100000, appWidgetId),
                Intent(context, providerClass)
                    .setAction(ACTION_OPEN_APP)
                    .putExtra(EXTRA_WIDGET_ID, appWidgetId),
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            )
            val launchDefaultAppPending = PendingIntent.getBroadcast(
                context,
                stableRequestCode(providerClass.name, 100100, appWidgetId),
                Intent(context, providerClass)
                    .setAction(ACTION_LAUNCH_DEFAULT_MEDIA_APP)
                    .putExtra(EXTRA_WIDGET_ID, appWidgetId),
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            )
            views.setOnClickPendingIntent(R.id.widget_root, noopRootPending)

            val prevPending = PendingIntent.getBroadcast(
                context,
                stableRequestCode(providerClass.name, 200000, appWidgetId),
                Intent(context, providerClass)
                    .setAction(ACTION_PREV)
                    .putExtra(EXTRA_WIDGET_ID, appWidgetId),
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            )
            val togglePending = PendingIntent.getBroadcast(
                context,
                stableRequestCode(providerClass.name, 300000, appWidgetId),
                Intent(context, providerClass)
                    .setAction(ACTION_TOGGLE)
                    .putExtra(EXTRA_WIDGET_ID, appWidgetId),
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            )
            val nextPending = PendingIntent.getBroadcast(
                context,
                stableRequestCode(providerClass.name, 400000, appWidgetId),
                Intent(context, providerClass)
                    .setAction(ACTION_NEXT)
                    .putExtra(EXTRA_WIDGET_ID, appWidgetId),
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            )
            val toggleVolumePending = PendingIntent.getBroadcast(
                context,
                stableRequestCode(providerClass.name, 500000, appWidgetId),
                Intent(context, providerClass)
                    .setAction(ACTION_TOGGLE_VOLUME)
                    .putExtra(EXTRA_WIDGET_ID, appWidgetId),
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            )

            views.setOnClickPendingIntent(R.id.widget_prev, prevPending)
            views.setOnClickPendingIntent(R.id.widget_play_pause, togglePending)
            views.setOnClickPendingIntent(R.id.widget_next, nextPending)
            views.setOnClickPendingIntent(R.id.widget_volume_btn, toggleVolumePending)

            if (hasDefaultAppBtn(layoutResId)) {
                val defaultAppPending = PendingIntent.getBroadcast(
                    context,
                    stableRequestCode(providerClass.name, 700000, appWidgetId),
                    Intent(context, providerClass)
                        .setAction(ACTION_LAUNCH_DEFAULT_MEDIA_APP_PLAY)
                        .putExtra(EXTRA_WIDGET_ID, appWidgetId),
                    PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
                )
                try { views.setOnClickPendingIntent(R.id.widget_default_app, defaultAppPending) } catch (_: Exception) {}
            }

            val uiPrefs = context.getSharedPreferences(uiPrefsName, Context.MODE_PRIVATE)
            val expandedKey = "volumeExpanded_$appWidgetId"
            val volumeExpanded = try { uiPrefs.getBoolean(expandedKey, false) } catch (_: Exception) { false }
            if (layoutResId == R.layout.widget_media_style2) {
                views.setViewVisibility(R.id.widget_volume_panel, if (volumeExpanded) android.view.View.VISIBLE else android.view.View.INVISIBLE)
                views.setViewVisibility(
                    R.id.widget_default_app,
                    if (volumeExpanded || !cfg.showDefaultAppBtn) android.view.View.GONE else android.view.View.VISIBLE
                )
            } else {
                views.setViewVisibility(R.id.widget_volume_panel, if (volumeExpanded) android.view.View.VISIBLE else android.view.View.GONE)
            }
            if (layoutResId == R.layout.widget_media_style3) {
                views.setViewVisibility(R.id.widget_title, if (volumeExpanded) android.view.View.GONE else android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_subtitle, if (volumeExpanded) android.view.View.GONE else android.view.View.VISIBLE)
                // Espaciado configurable entre filas (encima de la barra y de los controles).
                val gap = dp(context, cfg.rowSpacingDp.toFloat())
                try { views.setViewPadding(R.id.widget_middle, 0, gap, 0, 0) } catch (_: Exception) {}
                try { views.setViewPadding(R.id.widget_controls_row, 0, gap, 0, 0) } catch (_: Exception) {}
            }
            if (layoutResId == R.layout.widget_media_wide) {
                // El widget ancho intercambia la fila de controles por la barra de volumen.
                views.setViewVisibility(R.id.widget_controls_row, if (volumeExpanded) android.view.View.GONE else android.view.View.VISIBLE)
            }
            // Visibilidad del botón "abrir app" en los widgets que lo tienen aparte del centrado.
            if (layoutResId == R.layout.widget_media_style3 || layoutResId == R.layout.widget_media_wide) {
                views.setViewVisibility(
                    R.id.widget_default_app,
                    if (cfg.showDefaultAppBtn) android.view.View.VISIBLE else android.view.View.GONE
                )
            }

            fun bindVolumeSegment(viewId: Int, pct: Int) {
                val pi = PendingIntent.getBroadcast(
                    context,
                    stableRequestCode(providerClass.name, 600000 + pct, appWidgetId),
                    Intent(context, providerClass)
                        .setAction(ACTION_SET_VOLUME)
                        .putExtra(EXTRA_WIDGET_ID, appWidgetId)
                        .putExtra(EXTRA_PCT, pct),
                    PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
                )
                views.setOnClickPendingIntent(viewId, pi)
            }

            bindVolumeSegment(R.id.widget_vol_0, 0)
            bindVolumeSegment(R.id.widget_vol_10, 10)
            bindVolumeSegment(R.id.widget_vol_20, 20)
            bindVolumeSegment(R.id.widget_vol_30, 30)
            bindVolumeSegment(R.id.widget_vol_40, 40)
            bindVolumeSegment(R.id.widget_vol_50, 50)
            bindVolumeSegment(R.id.widget_vol_60, 60)
            bindVolumeSegment(R.id.widget_vol_70, 70)
            bindVolumeSegment(R.id.widget_vol_80, 80)
            bindVolumeSegment(R.id.widget_vol_90, 90)
            bindVolumeSegment(R.id.widget_vol_100, 100)

            val now = System.currentTimeMillis()

            val flutterPrefs = context.getSharedPreferences(PREFS_FLUTTER_SHARED, Context.MODE_PRIVATE)
            val prioritizeLocal = readFlutterBool(flutterPrefs, KEY_FLUTTER_PRIORITIZE_LOCAL_MEDIA, false)

            val remotePrefs = context.getSharedPreferences(PREFS_MEDIA_CACHE, Context.MODE_PRIVATE)
            val remoteJson = remotePrefs.getString(KEY_MEDIA_JSON, null)
            val remoteUpdatedAtMs = remotePrefs.getLong(KEY_MEDIA_UPDATED_AT_MS, 0L)
            val remoteFresh = !remoteJson.isNullOrBlank() && remoteUpdatedAtMs > 0L && now - remoteUpdatedAtMs <= 15_000L

            val localPrefs = context.getSharedPreferences(PREFS_LOCAL_MEDIA_CACHE, Context.MODE_PRIVATE)
            val localJson = localPrefs.getString(KEY_MEDIA_JSON, null)
            val localUpdatedAtMs = localPrefs.getLong(KEY_MEDIA_UPDATED_AT_MS, 0L)
            val localFresh = !localJson.isNullOrBlank() && localUpdatedAtMs > 0L && now - localUpdatedAtMs <= 15_000L

            val useLocal = if (prioritizeLocal) localFresh || !remoteFresh else !remoteFresh && localFresh
            val prefsMedia = if (useLocal) localPrefs else remotePrefs
            val json = if (useLocal) localJson else remoteJson
            val updatedAtMs = if (useLocal) localUpdatedAtMs else remoteUpdatedAtMs
            val stale = json.isNullOrBlank() || updatedAtMs <= 0L || now - updatedAtMs > 15_000L
            if (prioritizeLocal && !localFresh) {
                try {
                    refreshLocalMediaCache(context)
                } catch (_: Exception) {}
            }

            val volumePrefs = context.getSharedPreferences(PREFS_VOLUME_CACHE, Context.MODE_PRIVATE)
            val volumeUpdatedAtMs = volumePrefs.getLong(KEY_VOLUME_UPDATED_AT_MS, 0L)
            val volumeStale = volumeUpdatedAtMs <= 0L || now - volumeUpdatedAtMs > 15_000L
            val volumePct = if (useLocal) {
                readLocalVolumePct(context)
            } else {
                if (volumeStale) 0 else volumePrefs.getInt(KEY_VOLUME_PCT, 0).coerceIn(0, 100)
            }
            try {
                val volBar = renderBar(
                    600, dp(context, 28f), dp(context, cfg.barVolThickDp.toFloat()),
                    volumePct / 100f, cfg.barTrack, cfg.barFill, true
                )
                views.setImageViewBitmap(R.id.widget_volume_progress, volBar)
            } catch (_: Exception) {}

            if (stale) {
                applyMedia(
                    context,
                    views,
                    layoutResId,
                    cfg,
                    title = cfg.noMediaTitle,
                    subtitle = cfg.noMediaSubtitle,
                    timeText = "0:00 / 0:00",
                    progress = 0,
                    isPlaying = false
                )
                views.setOnClickPendingIntent(R.id.widget_root, launchDefaultAppPending)
                applyNoPlaybackBackground(views, cfg.bgNoImage)
                if (layoutResId == R.layout.widget_media_wide) {
                    try { views.setInt(R.id.widget_bg, "setImageAlpha", 0) } catch (_: Exception) {}
                    try { views.setViewVisibility(R.id.widget_art_thumb, android.view.View.VISIBLE) } catch (_: Exception) {}
                }
                if (hasDefaultAppBtn(layoutResId)) {
                    applyDefaultAppIcon(context, views, grayscaleIfMissing = true)
                }
                return views
            }

            val obj = try { JSONObject(json) } catch (_: Exception) { null }
            if (obj == null) {
                applyMedia(
                    context,
                    views,
                    layoutResId,
                    cfg,
                    title = cfg.noMediaTitle,
                    subtitle = cfg.noMediaSubtitle,
                    timeText = "0:00 / 0:00",
                    progress = 0,
                    isPlaying = false
                )
                views.setOnClickPendingIntent(R.id.widget_root, launchDefaultAppPending)
                applyNoPlaybackBackground(views, cfg.bgNoImage)
                if (layoutResId == R.layout.widget_media_wide) {
                    try { views.setInt(R.id.widget_bg, "setImageAlpha", 0) } catch (_: Exception) {}
                    try { views.setViewVisibility(R.id.widget_art_thumb, android.view.View.VISIBLE) } catch (_: Exception) {}
                }
                if (hasDefaultAppBtn(layoutResId)) {
                    applyDefaultAppIcon(context, views, grayscaleIfMissing = true)
                }
                return views
            }

            val title = obj.optString("title", "").trim()
            val artist = obj.optString("artist", "").trim()
            val album = obj.optString("album", "").trim()
            val appName = obj.optString("appName", "").trim()
            val packageName = obj.optString("packageName", "").trim()
            val subtitle = when (layoutResId) {
                R.layout.widget_media_style2 -> artist.ifBlank { appName }
                R.layout.widget_media_style3 -> artist
                else -> when {
                    artist.isNotBlank() && appName.isNotBlank() -> "$artist • $appName"
                    artist.isNotBlank() -> artist
                    appName.isNotBlank() -> appName
                    else -> ""
                }
            }

            val durationMs = try { obj.optLong("durationMs", 0L) } catch (_: Exception) { 0L }
            val positionMs = try { obj.optLong("positionMs", 0L) } catch (_: Exception) { 0L }
            val isPlaying = obj.optBoolean("isPlaying", false)

            val progress = if (durationMs > 0L) {
                val clamped = positionMs.coerceAtLeast(0L).coerceAtMost(durationMs)
                ((clamped.toDouble() / durationMs.toDouble()) * 1000.0).toInt().coerceIn(0, 1000)
            } else {
                0
            }
            val timeText = "${formatMs(positionMs)} / ${formatMs(durationMs)}"
            applyMedia(
                context,
                views,
                layoutResId,
                cfg,
                title = if (title.isNotBlank()) title else cfg.noMediaTitle,
                subtitle = subtitle,
                timeText = timeText,
                progress = progress,
                isPlaying = isPlaying
            )
            if (layoutResId == R.layout.widget_media_style2) {
                try { views.setTextViewText(R.id.widget_app_name, styled(appName, cfg.subtitleBold)) } catch (_: Exception) {}
            }
            if (layoutResId == R.layout.widget_media_style3) {
                try { views.setTextViewText(R.id.widget_time_current, styled(formatMs(positionMs), cfg.timeBold)) } catch (_: Exception) {}
                try { views.setTextViewText(R.id.widget_time_app, styled(appName, cfg.timeBold)) } catch (_: Exception) {}
                try { views.setTextViewText(R.id.widget_time_total, styled(formatMs(durationMs), cfg.timeBold)) } catch (_: Exception) {}
            }

            val artKey = "${packageName}|${title}|${artist}|${album}|${durationMs}".trim()
            val artBase64 = obj.optString("artBase64", "").trim()
            val storedArtKey = try { prefsMedia.getString(KEY_ART_KEY, null) } catch (_: Exception) { null }
            val storedArtBase64 = try { prefsMedia.getString(KEY_ART_BASE64, null) } catch (_: Exception) { null }
            val storedArtPkg = try { prefsMedia.getString(KEY_ART_PKG, null) } catch (_: Exception) { null }
            val storedArtUpdatedAtMs = try { prefsMedia.getLong(KEY_ART_UPDATED_AT_MS, 0L) } catch (_: Exception) { 0L }

            val effectiveArtBase64 = when {
                artBase64.isNotBlank() -> artBase64
                storedArtKey != null && storedArtKey == artKey && !storedArtBase64.isNullOrBlank() -> storedArtBase64
                !storedArtBase64.isNullOrBlank() &&
                    !storedArtPkg.isNullOrBlank() &&
                    storedArtPkg == packageName &&
                    storedArtUpdatedAtMs > 0L &&
                    now - storedArtUpdatedAtMs <= 5 * 60_000L -> storedArtBase64
                else -> ""
            }

            if (artBase64.isNotBlank() && artKey.isNotBlank()) {
                try {
                    prefsMedia.edit()
                        .putString(KEY_ART_KEY, artKey)
                        .putString(KEY_ART_BASE64, artBase64)
                        .putString(KEY_ART_PKG, packageName)
                        .putLong(KEY_ART_UPDATED_AT_MS, now)
                        .apply()
                } catch (_: Exception) {
                }
            }

            if (layoutResId == R.layout.widget_media_wide && !cfg.artAsBackground) {
                // Modo miniatura: carátula en widget_art_thumb (84×84), widget_bg invisible.
                try { views.setViewVisibility(R.id.widget_art_thumb, android.view.View.VISIBLE) } catch (_: Exception) {}
                try { views.setInt(R.id.widget_bg, "setImageAlpha", 0) } catch (_: Exception) {}
                if (effectiveArtBase64.isNotBlank()) {
                    val rawBitmap = decodeArtBitmap(effectiveArtBase64, 220)
                    if (rawBitmap != null) {
                        val artBitmap = applyArtScaleType(rawBitmap, 220, 220, cfg.artScaleType)
                        try { views.setImageViewBitmap(R.id.widget_art_thumb, artBitmap) } catch (_: Exception) {}
                    }
                }
            } else {
                // Modo fondo completo (style2, style3 y wide con artAsBackground=true).
                if (layoutResId == R.layout.widget_media_wide) {
                    try { views.setViewVisibility(R.id.widget_art_thumb, android.view.View.GONE) } catch (_: Exception) {}
                }
                if (effectiveArtBase64.isNotBlank()) {
                    val maxDim = maxOf(artCanvasW, artCanvasH).coerceAtMost(1200)
                    val rawBitmap = decodeArtBitmap(effectiveArtBase64, maxDim)
                    if (rawBitmap != null) {
                        val artBitmap = applyArtScaleType(rawBitmap, artCanvasW, artCanvasH, cfg.artScaleType)
                        views.setImageViewBitmap(R.id.widget_bg, artBitmap)
                        try { views.setInt(R.id.widget_bg, "setImageAlpha", cfg.artAlpha) } catch (_: Exception) {}
                        try { views.setInt(R.id.widget_overlay, "setBackgroundColor", cfg.scrim) } catch (_: Exception) {}
                    } else {
                        applyNoPlaybackBackground(views, cfg.bgNoImage)
                    }
                } else {
                    applyNoPlaybackBackground(views, cfg.bgNoImage)
                }
            }

            if (hasDefaultAppBtn(layoutResId)) {
                applyDefaultAppIcon(context, views, grayscaleIfMissing = true)
            }
            return views
        }

        private fun hasSelectedPlaybackFresh(context: Context): Boolean {
            val now = System.currentTimeMillis()
            val flutterPrefs = context.getSharedPreferences(PREFS_FLUTTER_SHARED, Context.MODE_PRIVATE)
            val prioritizeLocal = readFlutterBool(flutterPrefs, KEY_FLUTTER_PRIORITIZE_LOCAL_MEDIA, false)

            val remotePrefs = context.getSharedPreferences(PREFS_MEDIA_CACHE, Context.MODE_PRIVATE)
            val remoteJson = remotePrefs.getString(KEY_MEDIA_JSON, null)
            val remoteUpdatedAtMs = remotePrefs.getLong(KEY_MEDIA_UPDATED_AT_MS, 0L)
            val remoteFresh = !remoteJson.isNullOrBlank() && remoteUpdatedAtMs > 0L && now - remoteUpdatedAtMs <= 15_000L

            val localPrefs = context.getSharedPreferences(PREFS_LOCAL_MEDIA_CACHE, Context.MODE_PRIVATE)
            val localJson = localPrefs.getString(KEY_MEDIA_JSON, null)
            val localUpdatedAtMs = localPrefs.getLong(KEY_MEDIA_UPDATED_AT_MS, 0L)
            val localFresh = !localJson.isNullOrBlank() && localUpdatedAtMs > 0L && now - localUpdatedAtMs <= 15_000L

            val useLocal = if (prioritizeLocal) localFresh || !remoteFresh else !remoteFresh && localFresh
            val json = if (useLocal) localJson else remoteJson
            val updatedAtMs = if (useLocal) localUpdatedAtMs else remoteUpdatedAtMs
            if (json.isNullOrBlank()) return false
            if (updatedAtMs <= 0L || now - updatedAtMs > 15_000L) return false
            val obj = try { JSONObject(json) } catch (_: Exception) { null } ?: return false
            val title = obj.optString("title", "").trim()
            val pkg = obj.optString("packageName", "").trim()
            return title.isNotBlank() && pkg.isNotBlank()
        }

        private fun applyDefaultAppIcon(context: Context, views: RemoteViews, grayscaleIfMissing: Boolean) {
            val prefs = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            val defaultPkg = try { prefs.getString(KEY_FLUTTER_MEDIA_DEFAULT_APP_PACKAGE, null)?.trim().orEmpty() } catch (_: Exception) { "" }
            val widget2OverrideB64 = try { prefs.getString(KEY_FLUTTER_MEDIA_DEFAULT_APP_WIDGET2_ICON_BASE64, null)?.trim().orEmpty() } catch (_: Exception) { "" }
            val appIconB64 = try { prefs.getString(KEY_FLUTTER_MEDIA_DEFAULT_APP_ICON_BASE64, null)?.trim().orEmpty() } catch (_: Exception) { "" }
            val usingOverride = widget2OverrideB64.isNotBlank()
            val iconB64 = if (usingOverride) widget2OverrideB64 else appIconB64
            val installedFlag = try { prefs.getBoolean(KEY_FLUTTER_MEDIA_DEFAULT_APP_INSTALLED, true) } catch (_: Exception) { true }
            val installedPkg = try { prefs.getString(KEY_FLUTTER_MEDIA_DEFAULT_APP_INSTALLED_PKG, null)?.trim().orEmpty() } catch (_: Exception) { "" }
            val grayscale = !usingOverride && grayscaleIfMissing && !installedFlag && installedPkg.isNotBlank() && installedPkg == defaultPkg
            println("$WIDGET_LOG_PREFIX default_app_icon pkg='${defaultPkg.take(120)}' usingOverride=$usingOverride overrideLen=${widget2OverrideB64.length} iconLen=${iconB64.length} grayscale=$grayscale installedFlag=$installedFlag installedPkg='${installedPkg.take(80)}'")

            if (defaultPkg.isBlank()) {
                try { views.setImageViewResource(R.id.widget_default_app, android.R.drawable.ic_media_play) } catch (_: Exception) {}
                try { views.setInt(R.id.widget_default_app, "setColorFilter", Color.WHITE) } catch (_: Exception) {}
                return
            }

            if (iconB64.isBlank()) {
                println("$WIDGET_LOG_PREFIX default_app_icon missing icon base64, using fallback play icon")
                try { views.setImageViewResource(R.id.widget_default_app, android.R.drawable.ic_media_play) } catch (_: Exception) {}
                try { views.setInt(R.id.widget_default_app, "setColorFilter", Color.WHITE) } catch (_: Exception) {}
                return
            }

            val bmp = decodeArtBitmap(iconB64, 128) ?: run {
                println("$WIDGET_LOG_PREFIX default_app_icon decodeArtBitmap FAILED iconLen=${iconB64.length}")
                try { views.setImageViewResource(R.id.widget_default_app, android.R.drawable.ic_media_play) } catch (_: Exception) {}
                try { views.setInt(R.id.widget_default_app, "setColorFilter", Color.WHITE) } catch (_: Exception) {}
                return
            }
            val finalBmp = if (grayscale) toGrayscale(bmp) ?: bmp else bmp
            try {
                views.setImageViewBitmap(R.id.widget_default_app, finalBmp)
                println("$WIDGET_LOG_PREFIX default_app_icon setImageViewBitmap OK w=${finalBmp.width} h=${finalBmp.height}")
            } catch (t: Throwable) {
                println("$WIDGET_LOG_PREFIX default_app_icon setImageViewBitmap FAILED t=${t::class.java.simpleName} msg=${t.message}")
            }
            try { views.setInt(R.id.widget_default_app, "setColorFilter", 0) } catch (_: Exception) {}
        }

        private fun toGrayscale(src: Bitmap): Bitmap? {
            return try {
                val w = src.width
                val h = src.height
                if (w <= 0 || h <= 0) return src
                val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                val canvas = android.graphics.Canvas(out)
                val paint = android.graphics.Paint()
                val matrix = android.graphics.ColorMatrix()
                matrix.setSaturation(0f)
                paint.colorFilter = android.graphics.ColorMatrixColorFilter(matrix)
                canvas.drawBitmap(src, 0f, 0f, paint)
                out
            } catch (_: Exception) {
                null
            }
        }

        private fun applyMedia(
            context: Context,
            views: RemoteViews,
            layoutResId: Int,
            cfg: WidgetCfg,
            title: String,
            subtitle: String,
            timeText: String,
            progress: Int,
            isPlaying: Boolean
        ) {
            views.setTextViewText(R.id.widget_title, styled(title, cfg.titleBold))
            views.setTextViewText(R.id.widget_subtitle, styled(subtitle, cfg.subtitleBold))
            views.setTextViewText(R.id.widget_time, styled(timeText, cfg.timeBold))
            applyControlIcon(
                context, views, R.id.widget_play_pause,
                if (isPlaying) cfg.iconPause else cfg.iconPlay,
                if (isPlaying) R.drawable.widget_ic_pause else R.drawable.widget_ic_play,
                cfg
            )
            try {
                val boxDp = if (layoutResId == R.layout.widget_media_style3) 24f else 16f
                val bar = renderBar(
                    600, dp(context, boxDp), dp(context, cfg.barProgThickDp.toFloat()),
                    progress / 1000f, cfg.barTrack, cfg.barFill, true
                )
                views.setImageViewBitmap(R.id.widget_progress, bar)
            } catch (_: Exception) {}
        }

        private fun toggleVolumeExpanded(context: Context, uiPrefsName: String, appWidgetId: Int) {
            try {
                val prefs = context.getSharedPreferences(uiPrefsName, Context.MODE_PRIVATE)
                val key = "volumeExpanded_$appWidgetId"
                val current = try { prefs.getBoolean(key, false) } catch (_: Exception) { false }
                prefs.edit().putBoolean(key, !current).apply()
            } catch (_: Exception) {
            }
        }

        private fun decodeArtBitmap(base64: String, maxSide: Int): Bitmap? {
            if (base64.isBlank()) return null
            val bytes = try { Base64.decode(base64, Base64.DEFAULT) } catch (_: Exception) { null } ?: return null
            val decoded = try { BitmapFactory.decodeByteArray(bytes, 0, bytes.size) } catch (_: Exception) { null } ?: return null
            val w = decoded.width
            val h = decoded.height
            if (w <= 0 || h <= 0) return decoded
            if (w <= maxSide && h <= maxSide) return decoded

            val ratio = if (w >= h) {
                maxSide.toFloat() / w.toFloat()
            } else {
                maxSide.toFloat() / h.toFloat()
            }
            val nw = (w * ratio).toInt().coerceAtLeast(1)
            val nh = (h * ratio).toInt().coerceAtLeast(1)
            return try { Bitmap.createScaledBitmap(decoded, nw, nh, true) } catch (_: Exception) { decoded }
        }

        private fun applyArtScaleType(
            src: Bitmap,
            canvasW: Int,
            canvasH: Int,
            scaleType: String
        ): Bitmap {
            val w = canvasW.coerceAtLeast(1)
            val h = canvasH.coerceAtLeast(1)
            val srcW = src.width.coerceAtLeast(1)
            val srcH = src.height.coerceAtLeast(1)
            return when (scaleType) {
                "stretch" -> {
                    Bitmap.createScaledBitmap(src, w, h, true)
                }
                "contain", "inside" -> {
                    val result = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                    val canvas = android.graphics.Canvas(result)
                    canvas.drawColor(android.graphics.Color.BLACK)
                    val onlyDownscale = scaleType == "inside" && srcW <= w && srcH <= h
                    if (onlyDownscale) {
                        canvas.drawBitmap(src, ((w - srcW) / 2f), ((h - srcH) / 2f), null)
                    } else {
                        val scale = minOf(w.toFloat() / srcW, h.toFloat() / srcH)
                        val scaledW = (srcW * scale).toInt().coerceAtLeast(1)
                        val scaledH = (srcH * scale).toInt().coerceAtLeast(1)
                        val scaled = Bitmap.createScaledBitmap(src, scaledW, scaledH, true)
                        canvas.drawBitmap(scaled, ((w - scaledW) / 2f), ((h - scaledH) / 2f), null)
                    }
                    result
                }
                "center" -> {
                    val result = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                    val canvas = android.graphics.Canvas(result)
                    canvas.drawColor(android.graphics.Color.BLACK)
                    canvas.drawBitmap(src, ((w - srcW) / 2f), ((h - srcH) / 2f), null)
                    result
                }
                "start" -> {
                    val result = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                    val canvas = android.graphics.Canvas(result)
                    canvas.drawColor(android.graphics.Color.BLACK)
                    val scale = minOf(w.toFloat() / srcW, h.toFloat() / srcH)
                    val scaledW = (srcW * scale).toInt().coerceAtLeast(1)
                    val scaledH = (srcH * scale).toInt().coerceAtLeast(1)
                    canvas.drawBitmap(Bitmap.createScaledBitmap(src, scaledW, scaledH, true), 0f, 0f, null)
                    result
                }
                "end" -> {
                    val result = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                    val canvas = android.graphics.Canvas(result)
                    canvas.drawColor(android.graphics.Color.BLACK)
                    val scale = minOf(w.toFloat() / srcW, h.toFloat() / srcH)
                    val scaledW = (srcW * scale).toInt().coerceAtLeast(1)
                    val scaledH = (srcH * scale).toInt().coerceAtLeast(1)
                    val scaled = Bitmap.createScaledBitmap(src, scaledW, scaledH, true)
                    canvas.drawBitmap(scaled, (w - scaledW).toFloat(), (h - scaledH).toFloat(), null)
                    result
                }
                else -> {
                    // "crop" → CENTER_CROP: rellenar recortando el centro
                    val scale = maxOf(w.toFloat() / srcW, h.toFloat() / srcH)
                    val scaledW = (srcW * scale).toInt().coerceAtLeast(w)
                    val scaledH = (srcH * scale).toInt().coerceAtLeast(h)
                    val scaled = Bitmap.createScaledBitmap(src, scaledW, scaledH, true)
                    val x = ((scaledW - w) / 2).coerceAtLeast(0)
                    val y = ((scaledH - h) / 2).coerceAtLeast(0)
                    Bitmap.createBitmap(scaled, x, y, w, h)
                }
            }
        }

        private fun applyNoPlaybackBackground(views: RemoteViews, bgColor: Int) {
            // El color de fondo "sin imagen" lo pinta el velo (widget_overlay) y se oculta
            // la carátula para que solo se vea ese color.
            try { views.setInt(R.id.widget_overlay, "setBackgroundColor", bgColor) } catch (_: Exception) {}
            try { views.setInt(R.id.widget_bg, "setImageAlpha", 0) } catch (_: Exception) {}
        }

        private fun sendLaunchDefaultMediaApp(context: Context) {
            sendLaunchDefaultMediaApp(context, forcePlay = false, pauseOthers = false)
        }

        private fun sendLaunchDefaultMediaApp(context: Context, forcePlay: Boolean, pauseOthers: Boolean) {
            try {
                val prefs = try {
                    context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
                } catch (_: Exception) {
                    null
                }
                val selectedPkg = try {
                    prefs?.getString(KEY_FLUTTER_MEDIA_DEFAULT_APP_PACKAGE, null)?.trim().orEmpty()
                } catch (_: Exception) {
                    ""
                }
                val flutterPrefs = context.getSharedPreferences(PREFS_FLUTTER_SHARED, Context.MODE_PRIVATE)
                val prioritizeLocal = readFlutterBool(flutterPrefs, KEY_FLUTTER_PRIORITIZE_LOCAL_MEDIA, false)
                println("$WIDGET_LOG_PREFIX sendLaunchDefaultMediaApp forcePlay=$forcePlay pauseOthers=$pauseOthers pkg='${selectedPkg.take(120)}' prioritizeLocal=$prioritizeLocal")

                if (prioritizeLocal) {
                    if (selectedPkg.isNotBlank()) {
                        try {
                            val launchIntent = context.packageManager.getLaunchIntentForPackage(selectedPkg)
                            if (launchIntent != null) {
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                context.startActivity(launchIntent)
                            }
                        } catch (_: Exception) {}
                    }
                    return
                }

                val payload = org.json.JSONObject()
                payload.put("type", "launch_default_media_app")
                payload.put("packageName", selectedPkg)
                payload.put("forcePlay", forcePlay)
                payload.put("pauseOthers", pauseOthers)
                payload.put("time", System.currentTimeMillis())

                val i = Intent(context, BtClassicServerService::class.java)
                    .setAction(BtClassicServerService.ACTION_SEND_TO_PEERS)
                    .putExtra(BtClassicServerService.EXTRA_JSON, payload.toString())

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(i)
                } else {
                    context.startService(i)
                }
            } catch (_: Exception) {
            }
        }

        private fun immutableFlag(): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        }

        private fun stableRequestCode(providerClassName: String, base: Int, appWidgetId: Int): Int {
            val prefix = (providerClassName.hashCode() and 0x7FFF)
            val safeBase = base.coerceAtLeast(0)
            return (prefix * 100000) + (safeBase % 100000) + (appWidgetId % 1000)
        }

        private fun sendMediaCommand(context: Context, command: String) {
            try {
                val payload = JSONObject()
                payload.put("type", "media_command")
                payload.put("command", command)
                payload.put("time", System.currentTimeMillis())

                val i = Intent(context, BtClassicServerService::class.java)
                    .setAction(BtClassicServerService.ACTION_SEND_TO_PEERS)
                    .putExtra(BtClassicServerService.EXTRA_JSON, payload.toString())

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(i)
                } else {
                    context.startService(i)
                }
            } catch (_: Exception) {
            }
        }

        private fun sendVolumeCommand(context: Context, pct: Int) {
            try {
                val payload = JSONObject()
                payload.put("type", "volume_command")
                payload.put("pct", pct.coerceIn(0, 100))
                payload.put("time", System.currentTimeMillis())

                val i = Intent(context, BtClassicServerService::class.java)
                    .setAction(BtClassicServerService.ACTION_SEND_TO_PEERS)
                    .putExtra(BtClassicServerService.EXTRA_JSON, payload.toString())

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(i)
                } else {
                    context.startService(i)
                }
            } catch (_: Exception) {
            }
        }

        private fun sendVolumeRequest(context: Context) {
            try {
                val payload = JSONObject()
                payload.put("type", "volume_request")
                payload.put("time", System.currentTimeMillis())

                val i = Intent(context, BtClassicServerService::class.java)
                    .setAction(BtClassicServerService.ACTION_SEND_TO_PEERS)
                    .putExtra(BtClassicServerService.EXTRA_JSON, payload.toString())

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(i)
                } else {
                    context.startService(i)
                }
            } catch (_: Exception) {
            }
        }

        private fun formatMs(ms: Long): String {
            if (ms <= 0L) return "0:00"
            val totalSeconds = (ms / 1000L).coerceAtLeast(0L)
            val seconds = (totalSeconds % 60L).toInt()
            val totalMinutes = (totalSeconds / 60L).toInt()
            val minutes = totalMinutes % 60
            val hours = totalMinutes / 60
            val ss = if (seconds < 10) "0$seconds" else seconds.toString()
            return if (hours > 0) {
                val mm = if (minutes < 10) "0$minutes" else minutes.toString()
                "$hours:$mm:$ss"
            } else {
                "$minutes:$ss"
            }
        }

        private fun refreshLocalMediaCache(context: Context) {
            try {
                val msm = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as? android.media.session.MediaSessionManager ?: return
                val component = ComponentName(context, NotificationListener::class.java)
                val controllers = try { msm.getActiveSessions(component) } catch (_: Exception) { emptyList<android.media.session.MediaController>() }
                val controller = run {
                    if (controllers.isEmpty()) null else {
                        val playing = controllers.firstOrNull { c ->
                            val st = c.playbackState?.state ?: android.media.session.PlaybackState.STATE_NONE
                            st == android.media.session.PlaybackState.STATE_PLAYING || st == android.media.session.PlaybackState.STATE_BUFFERING
                        }
                        if (playing != null) playing else {
                            controllers.firstOrNull { c ->
                                val st = c.playbackState?.state ?: android.media.session.PlaybackState.STATE_NONE
                                st == android.media.session.PlaybackState.STATE_PAUSED
                            } ?: controllers.first()
                        }
                    }
                } ?: return
                val state = controller.playbackState
                val metadata = controller.metadata
                val playbackState = state?.state ?: android.media.session.PlaybackState.STATE_NONE
                val isPlaying = playbackState == android.media.session.PlaybackState.STATE_PLAYING ||
                        playbackState == android.media.session.PlaybackState.STATE_BUFFERING
                val actions = state?.actions ?: 0L
                val canPlayPause = (actions and android.media.session.PlaybackState.ACTION_PLAY) != 0L ||
                        (actions and android.media.session.PlaybackState.ACTION_PAUSE) != 0L ||
                        (actions and android.media.session.PlaybackState.ACTION_PLAY_PAUSE) != 0L
                val canSkipNext = (actions and android.media.session.PlaybackState.ACTION_SKIP_TO_NEXT) != 0L
                val canSkipPrev = (actions and android.media.session.PlaybackState.ACTION_SKIP_TO_PREVIOUS) != 0L
                val canSeek = (actions and android.media.session.PlaybackState.ACTION_SEEK_TO) != 0L
                val title = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_TITLE)
                    ?: metadata?.getString(android.media.MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
                val artist = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST)
                    ?: metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
                val album = metadata?.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM)
                val durationMs = metadata?.getLong(android.media.MediaMetadata.METADATA_KEY_DURATION) ?: 0L
                val positionMs = state?.position ?: 0L
                val packageName = controller.packageName ?: ""
                if (packageName.isBlank() || title.isNullOrBlank()) return
                val appName = try {
                    val appInfo = context.packageManager.getApplicationInfo(packageName, 0)
                    context.packageManager.getApplicationLabel(appInfo).toString()
                } catch (_: Exception) {
                    packageName
                }
                val obj = JSONObject()
                obj.put("type", "media_state")
                obj.put("time", System.currentTimeMillis())
                obj.put("packageName", packageName)
                obj.put("appName", appName)
                obj.put("title", title)
                obj.put("artist", artist ?: "")
                obj.put("album", album ?: "")
                obj.put("durationMs", durationMs)
                obj.put("positionMs", positionMs)
                obj.put("isPlaying", isPlaying)
                obj.put("canPlayPause", canPlayPause)
                obj.put("canSkipNext", canSkipNext)
                obj.put("canSkipPrev", canSkipPrev)
                obj.put("canSeek", canSeek)
                val prefs = context.getSharedPreferences(PREFS_LOCAL_MEDIA_CACHE, Context.MODE_PRIVATE)
                prefs.edit()
                    .putString(KEY_MEDIA_JSON, obj.toString())
                    .putLong(KEY_MEDIA_UPDATED_AT_MS, System.currentTimeMillis())
                    .apply()
            } catch (_: Exception) {
            }
        }
    }
}

// Widget de música 2x5: texto centrado + botón de app de música por defecto.
class MediaWidgetProviderStyle2 : BaseMediaWidgetProvider() {
    override val layoutResId: Int = R.layout.widget_media_style2

    companion object {
        fun updateAll(context: Context) {
            BaseMediaWidgetProvider.updateAll(context, MediaWidgetProviderStyle2::class.java, R.layout.widget_media_style2)
        }
    }
}

// Widget de música 2x5: texto a la izquierda + barra de progreso con tiempos.
class MediaWidgetProviderStyle3 : BaseMediaWidgetProvider() {
    override val layoutResId: Int = R.layout.widget_media_style3

    companion object {
        fun updateAll(context: Context) {
            BaseMediaWidgetProvider.updateAll(context, MediaWidgetProviderStyle3::class.java, R.layout.widget_media_style3)
        }
    }
}

// Widget de música ancho (4x2): carátula a la izquierda + controles y volumen a la derecha.
class MediaWidgetProviderWide : BaseMediaWidgetProvider() {
    override val layoutResId: Int = R.layout.widget_media_wide

    companion object {
        fun updateAll(context: Context) {
            BaseMediaWidgetProvider.updateAll(context, MediaWidgetProviderWide::class.java, R.layout.widget_media_wide)
        }
    }
}
