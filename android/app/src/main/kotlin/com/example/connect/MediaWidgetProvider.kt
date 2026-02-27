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
                sendMediaCommand(context, "toggle")
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
                sendLaunchDefaultMediaApp(context)
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

        private const val ACTION_PREFIX = "com.example.connect.widget.MEDIA"
        const val ACTION_TOGGLE = "$ACTION_PREFIX.TOGGLE"
        const val ACTION_NEXT = "$ACTION_PREFIX.NEXT"
        const val ACTION_PREV = "$ACTION_PREFIX.PREV"
        const val ACTION_OPEN_APP = "$ACTION_PREFIX.OPEN_APP"
        const val ACTION_TOGGLE_VOLUME = "$ACTION_PREFIX.TOGGLE_VOLUME"
        const val ACTION_SET_VOLUME = "$ACTION_PREFIX.SET_VOLUME"
        const val ACTION_LAUNCH_DEFAULT_MEDIA_APP = "$ACTION_PREFIX.LAUNCH_DEFAULT_MEDIA_APP"

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
            val textSp = (try { prefsFlutter.getInt(KEY_FLUTTER_WIDGET_TEXT_SP, 22) } catch (_: Exception) { 22 }).coerceIn(12, 34)
            val scale = if (layoutResId == R.layout.widget_media_style2 || layoutResId == R.layout.widget_media_style3) 1.5f else 1f
            val titleSp = (textSp.toFloat() * scale).coerceAtLeast(12f)
            val subtitleSp = ((textSp - 8).coerceAtLeast(12).toFloat() * scale).coerceAtLeast(12f)
            val timeSp = ((textSp - 10).coerceAtLeast(12).toFloat() * scale).coerceAtLeast(12f)

            views.setTextViewTextSize(R.id.widget_title, android.util.TypedValue.COMPLEX_UNIT_SP, titleSp)
            views.setTextViewTextSize(R.id.widget_subtitle, android.util.TypedValue.COMPLEX_UNIT_SP, subtitleSp)
            views.setTextViewTextSize(R.id.widget_time, android.util.TypedValue.COMPLEX_UNIT_SP, timeSp)
            if (layoutResId == R.layout.widget_media_style3) {
                views.setTextViewTextSize(R.id.widget_time_current, android.util.TypedValue.COMPLEX_UNIT_SP, timeSp)
                views.setTextViewTextSize(R.id.widget_time_app, android.util.TypedValue.COMPLEX_UNIT_SP, timeSp)
                views.setTextViewTextSize(R.id.widget_time_total, android.util.TypedValue.COMPLEX_UNIT_SP, timeSp)
            }

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

            val uiPrefs = context.getSharedPreferences(uiPrefsName, Context.MODE_PRIVATE)
            val expandedKey = "volumeExpanded_$appWidgetId"
            val volumeExpanded = try { uiPrefs.getBoolean(expandedKey, false) } catch (_: Exception) { false }
            views.setViewVisibility(R.id.widget_volume_panel, if (volumeExpanded) android.view.View.VISIBLE else android.view.View.GONE)
            if (layoutResId == R.layout.widget_media_style3) {
                views.setViewVisibility(R.id.widget_title, if (volumeExpanded) android.view.View.GONE else android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_subtitle, if (volumeExpanded) android.view.View.GONE else android.view.View.VISIBLE)
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
            val remoteConnected = try { BtClassicServerService.connectedPeers > 0 } catch (_: Exception) { false }
            val remoteFresh = remoteConnected && !remoteJson.isNullOrBlank() && remoteUpdatedAtMs > 0L && now - remoteUpdatedAtMs <= 15_000L

            val localPrefs = context.getSharedPreferences(PREFS_LOCAL_MEDIA_CACHE, Context.MODE_PRIVATE)
            val localJson = localPrefs.getString(KEY_MEDIA_JSON, null)
            val localUpdatedAtMs = localPrefs.getLong(KEY_MEDIA_UPDATED_AT_MS, 0L)
            val localFresh = !localJson.isNullOrBlank() && localUpdatedAtMs > 0L && now - localUpdatedAtMs <= 15_000L

            val useLocal = if (prioritizeLocal) localFresh || !remoteFresh else !remoteFresh && localFresh
            val prefsMedia = if (useLocal) localPrefs else remotePrefs
            val json = if (useLocal) localJson else remoteJson
            val updatedAtMs = if (useLocal) localUpdatedAtMs else remoteUpdatedAtMs
            val stale = json.isNullOrBlank() || updatedAtMs <= 0L || now - updatedAtMs > 15_000L

            val volumePrefs = context.getSharedPreferences(PREFS_VOLUME_CACHE, Context.MODE_PRIVATE)
            val volumeUpdatedAtMs = volumePrefs.getLong(KEY_VOLUME_UPDATED_AT_MS, 0L)
            val volumeStale = volumeUpdatedAtMs <= 0L || now - volumeUpdatedAtMs > 15_000L
            val volumePct = if (useLocal) {
                readLocalVolumePct(context)
            } else {
                if (volumeStale) 0 else volumePrefs.getInt(KEY_VOLUME_PCT, 0).coerceIn(0, 100)
            }
            views.setProgressBar(R.id.widget_volume_progress, 100, volumePct, false)

            if (stale) {
                applyMedia(
                    views,
                    title = "Sin reproducción",
                    subtitle = "Conecta el emisor o reproduce local",
                    timeText = "0:00 / 0:00",
                    progress = 0,
                    isPlaying = false
                )
                views.setOnClickPendingIntent(R.id.widget_root, launchDefaultAppPending)
                applyNoPlaybackBackground(views, layoutResId)
                return views
            }

            val obj = try { JSONObject(json) } catch (_: Exception) { null }
            if (obj == null) {
                applyMedia(
                    views,
                    title = "Sin reproducción",
                    subtitle = "Conecta el emisor para controlar",
                    timeText = "0:00 / 0:00",
                    progress = 0,
                    isPlaying = false
                )
                views.setOnClickPendingIntent(R.id.widget_root, launchDefaultAppPending)
                applyNoPlaybackBackground(views, layoutResId)
                return views
            }

            val title = obj.optString("title", "").trim()
            val artist = obj.optString("artist", "").trim()
            val album = obj.optString("album", "").trim()
            val appName = obj.optString("appName", "").trim()
            val packageName = obj.optString("packageName", "").trim()
            val sourceLabel = if (useLocal) "Local" else "Emisor"
            val subtitle = when (layoutResId) {
                R.layout.widget_media_style2 -> artist.ifBlank { sourceLabel }
                R.layout.widget_media_style3 -> artist
                else -> when {
                    artist.isNotBlank() && appName.isNotBlank() -> "$artist • $appName"
                    artist.isNotBlank() -> artist
                    appName.isNotBlank() -> appName
                    else -> sourceLabel
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
                views,
                title = if (title.isNotBlank()) title else "Sin reproducción",
                subtitle = subtitle,
                timeText = timeText,
                progress = progress,
                isPlaying = isPlaying
            )
            if (layoutResId == R.layout.widget_media_style2) {
                try { views.setTextViewText(R.id.widget_app_name, appName) } catch (_: Exception) {}
            }
            if (layoutResId == R.layout.widget_media_style3) {
                try { views.setTextViewText(R.id.widget_time_current, formatMs(positionMs)) } catch (_: Exception) {}
                try { views.setTextViewText(R.id.widget_time_app, appName.ifBlank { sourceLabel }) } catch (_: Exception) {}
                try { views.setTextViewText(R.id.widget_time_total, formatMs(durationMs)) } catch (_: Exception) {}
            }

            val artKey = "${packageName}|${title}|${artist}|${album}|${durationMs}".trim()
            val artBase64 = obj.optString("artBase64", "").trim()
            val storedArtKey = try { prefsMedia.getString(KEY_ART_KEY, null) } catch (_: Exception) { null }
            val storedArtBase64 = try { prefsMedia.getString(KEY_ART_BASE64, null) } catch (_: Exception) { null }

            val effectiveArtBase64 = when {
                artBase64.isNotBlank() -> artBase64
                storedArtKey != null && storedArtKey == artKey && !storedArtBase64.isNullOrBlank() -> storedArtBase64
                else -> ""
            }

            if (artBase64.isNotBlank() && artKey.isNotBlank()) {
                try {
                    prefsMedia.edit()
                        .putString(KEY_ART_KEY, artKey)
                        .putString(KEY_ART_BASE64, artBase64)
                        .apply()
                } catch (_: Exception) {
                }
            }

            if (effectiveArtBase64.isNotBlank()) {
                val artBitmap = decodeArtBitmap(effectiveArtBase64, 340)
                if (artBitmap != null) {
                    views.setImageViewBitmap(R.id.widget_bg, artBitmap)
                }
            } else {
                applyNoPlaybackBackground(views, layoutResId)
            }

            return views
        }

        private fun applyMedia(
            views: RemoteViews,
            title: String,
            subtitle: String,
            timeText: String,
            progress: Int,
            isPlaying: Boolean
        ) {
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_subtitle, subtitle)
            views.setTextViewText(R.id.widget_time, timeText)
            views.setProgressBar(R.id.widget_progress, 1000, progress, false)
            views.setImageViewResource(
                R.id.widget_play_pause,
                if (isPlaying) R.drawable.widget_ic_pause else R.drawable.widget_ic_play
            )
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

        private fun applyNoPlaybackBackground(views: RemoteViews, layoutResId: Int) {
            if (layoutResId == R.layout.widget_media_style2 || layoutResId == R.layout.widget_media_style3) {
                try {
                    views.setInt(R.id.widget_bg, "setBackgroundColor", Color.BLACK)
                } catch (_: Exception) {
                }
                try {
                    views.setImageViewResource(R.id.widget_bg, R.drawable.widget_bg_black)
                } catch (_: Exception) {
                }
            } else {
                views.setImageViewResource(R.id.widget_bg, android.R.drawable.ic_menu_gallery)
            }
        }

        private fun sendLaunchDefaultMediaApp(context: Context) {
            try {
                val payload = org.json.JSONObject()
                payload.put("type", "launch_default_media_app")
                payload.put("packageName", "")
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
    }
}

class MediaWidgetProvider : BaseMediaWidgetProvider() {
    override val layoutResId: Int = R.layout.widget_media

    companion object {
        fun updateAll(context: Context) {
            BaseMediaWidgetProvider.updateAll(context, MediaWidgetProvider::class.java, R.layout.widget_media)
        }
    }
}

class MediaWidgetProviderStyle2 : BaseMediaWidgetProvider() {
    override val layoutResId: Int = R.layout.widget_media_style2

    companion object {
        fun updateAll(context: Context) {
            BaseMediaWidgetProvider.updateAll(context, MediaWidgetProviderStyle2::class.java, R.layout.widget_media_style2)
        }
    }
}

class MediaWidgetProviderStyle3 : BaseMediaWidgetProvider() {
    override val layoutResId: Int = R.layout.widget_media_style3

    companion object {
        fun updateAll(context: Context) {
            BaseMediaWidgetProvider.updateAll(context, MediaWidgetProviderStyle3::class.java, R.layout.widget_media_style3)
        }
    }
}

class MediaWidgetProviderStyle4 : BaseMediaWidgetProvider() {
    override val layoutResId: Int = R.layout.widget_media_style4

    companion object {
        fun updateAll(context: Context) {
            BaseMediaWidgetProvider.updateAll(context, MediaWidgetProviderStyle4::class.java, R.layout.widget_media_style4)
        }
    }
}

class MediaWidgetProviderStyle5 : BaseMediaWidgetProvider() {
    override val layoutResId: Int = R.layout.widget_media_style5

    companion object {
        fun updateAll(context: Context) {
            BaseMediaWidgetProvider.updateAll(context, MediaWidgetProviderStyle5::class.java, R.layout.widget_media_style5)
        }
    }
}
