package com.example.connect

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.os.Build
import android.text.SpannableString
import android.text.Spannable
import android.text.style.StyleSpan
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/// Widget de clima de la pantalla de inicio. Replica el diseño del widget de la
/// app (totalmente personalizable, ver [readWeatherWidgetCfg] ⇔
/// `WeatherWidgetConfigService`), pero como RemoteViews no admite gestos, la
/// navegación es por botones:
///   - ◀ ▶ cambian entre las 3 vistas (actual / por horas / por días).
///   - ▲ ▼ desplazan el contenido de las listas (horas y días).
///   - Tocar el nombre rota entre las ciudades guardadas.
/// No navega a la app al tocar. Los datos los obtiene Flutter (Open-Meteo) y los
/// deja en `flutter.weather_widget_json`; la personalización en
/// `flutter.weather_widget_cfg_<prop>`; aquí solo se pintan.
class WeatherWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) render(context, appWidgetManager, id)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val ui = context.getSharedPreferences(PREFS_UI, Context.MODE_PRIVATE).edit()
        for (id in appWidgetIds) {
            ui.remove("view_$id").remove("hoff_$id").remove("doff_$id").remove("city_$id")
        }
        ui.apply()
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val id = intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val mgr = AppWidgetManager.getInstance(context)
        when (intent.action) {
            // Acciones de navegación: cancelar animación en curso, renderizar limpio,
            // luego iniciar animación nueva si el trigger de toque está activo.
            ACTION_PREV_VIEW   -> {
                cancelAnimation(id)
                changeView(context, id, -1); render(context, mgr, id)
                maybeAnimateTap(context, mgr, id)
            }
            ACTION_NEXT_VIEW   -> {
                cancelAnimation(id)
                changeView(context, id, 1);  render(context, mgr, id)
                maybeAnimateTap(context, mgr, id)
            }
            ACTION_SCROLL_UP   -> {
                cancelAnimation(id)
                scroll(context, id, -1);     render(context, mgr, id)
                maybeAnimateTap(context, mgr, id)
            }
            ACTION_SCROLL_DOWN -> {
                cancelAnimation(id)
                scroll(context, id, 1);      render(context, mgr, id)
                maybeAnimateTap(context, mgr, id)
            }
            ACTION_CYCLE_CITY  -> {
                cancelAnimation(id)
                cycleCity(context, id);      render(context, mgr, id)
                maybeAnimateTap(context, mgr, id)
            }
            // Toque directo sobre el fondo del widget → animar (si no hay animación activa).
            ACTION_ANIMATE     -> {
                if (id != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    val cfg = readWeatherWidgetCfg(context)
                    startAnimateAsync(context, mgr, id, cfg)
                }
            }
            // Trigger de encendido de pantalla: animar todos los widgets activos.
            Intent.ACTION_SCREEN_ON,
            Intent.ACTION_USER_PRESENT -> {
                val cfg = readWeatherWidgetCfg(context)
                if (cfg.animTrigger == 1 || cfg.animTrigger == 2) {
                    val ids = mgr.getAppWidgetIds(
                        ComponentName(context, WeatherWidgetProvider::class.java)
                    )
                    for (wid in ids) startAnimateAsync(context, mgr, wid, cfg)
                }
            }
        }
    }

    private fun maybeAnimateTap(context: Context, mgr: AppWidgetManager, id: Int) {
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
        val cfg = readWeatherWidgetCfg(context)
        if (cfg.animTrigger == 0 || cfg.animTrigger == 2) {
            startAnimateAsync(context, mgr, id, cfg)
        }
    }

    /**
     * Interrumpe el thread de animación de [widgetId] (si existe) y espera hasta
     * 300 ms a que se detenga antes de permitir que [render] y una nueva animación
     * corran sin conflictos con [partiallyUpdateAppWidget].
     */
    private fun cancelAnimation(widgetId: Int) {
        animThreads.remove(widgetId)?.let {
            it.interrupt()
            it.join(300)
        }
    }

    /**
     * Inicia la animación para [widgetId] en un thread nuevo.
     * Si ya hay una animación activa para ese widget, no lanza otra (evita
     * que múltiples threads llamen a [partiallyUpdateAppWidget] en paralelo).
     */
    private fun startAnimateAsync(context: Context, mgr: AppWidgetManager, widgetId: Int, cfg: WeatherCfg) {
        // Si ya hay un thread activo para este widget, no iniciamos otro.
        if (animThreads.containsKey(widgetId)) return
        val pending = goAsync()
        val t = Thread {
            try { animateFrames(context, mgr, widgetId, cfg.animLoopMode) }
            catch (_: InterruptedException) { /* animación cancelada por acción de navegación */ }
            finally {
                animThreads.remove(widgetId)
                pending.finish()
            }
        }
        animThreads[widgetId] = t
        t.start()
    }

    private fun animateFrames(context: Context, mgr: AppWidgetManager, widgetId: Int, loopMode: Int) {
        // partiallyUpdateAppWidget requiere API 27+.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) return

        val dir   = framesDir(context)
        val files = dir.listFiles()
            ?.filter { it.name.matches(Regex("frame_\\d+\\.png")) }
            ?.sortedBy { it.name.removePrefix("frame_").removeSuffix(".png").toIntOrNull() ?: 0 }
            ?: return
        val n = files.size
        if (n <= 1) return

        // loopMode 0 = ping-pong (0,1,...,n-1,n-2,...,1), 1 = loop (0,1,...,n-1)
        val sequence: List<Int> = if (loopMode == 1) {
            (0 until n).toList()
        } else {
            (0 until n).toList() + (n - 2 downTo 1).toList()
        }

        for (idx in sequence) {
            if (Thread.currentThread().isInterrupted) throw InterruptedException()
            val bmp = try {
                BitmapFactory.decodeFile(files[idx].absolutePath) ?: continue
            } catch (_: Exception) { continue }
            try {
                val partial = RemoteViews(context.packageName, R.layout.widget_weather)
                partial.setImageViewBitmap(R.id.weather_bg_image, bmp)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    mgr.partiallyUpdateAppWidget(widgetId, partial)
                }
            } finally {
                bmp.recycle()
            }
            Thread.sleep(80) // lanza InterruptedException si el thread fue interrumpido
        }
    }

    private fun changeView(context: Context, id: Int, delta: Int) {
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
        val ui = context.getSharedPreferences(PREFS_UI, Context.MODE_PRIVATE)
        val cur = ui.getInt("view_$id", 0)
        val next = ((cur + delta) % 3 + 3) % 3
        ui.edit().putInt("view_$id", next).apply()
    }

    private fun scroll(context: Context, id: Int, delta: Int) {
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
        val ui = context.getSharedPreferences(PREFS_UI, Context.MODE_PRIVATE)
        val view = ui.getInt("view_$id", 0)
        val key = if (view == 1) "hoff_$id" else "doff_$id"
        val cur = ui.getInt(key, 0)
        ui.edit().putInt(key, (cur + delta).coerceAtLeast(0)).apply()
    }

    private fun cycleCity(context: Context, id: Int) {
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
        val ui = context.getSharedPreferences(PREFS_UI, Context.MODE_PRIVATE)
        val cities = readSnapshot(context)?.optJSONArray("cities")
        val count = cities?.length() ?: 0
        if (count <= 0) return
        val cur = ui.getInt("city_$id", -1).let { if (it < 0) 0 else it }
        val next = (cur + 1) % count
        // Al cambiar de ciudad, reiniciar el desplazamiento de las listas.
        ui.edit().putInt("city_$id", next).putInt("hoff_$id", 0).putInt("doff_$id", 0).apply()
    }

    /// Personalización del widget — ESPEJO de los defaults en
    /// `WeatherWidgetConfigService` (Dart). Cambiar un default obliga a
    /// cambiarlo en ambos lados.
    private data class WeatherCfg(
        val cityLabelSizeSp: Float, val cityLabelColor: Int, val cityLabelBold: Boolean,
        val showLocationPin: Boolean, val viewLabelSizeSp: Float, val viewLabelColor: Int,
        val tempSizeSp: Float, val tempColor: Int, val tempBold: Boolean,
        val descSizeSp: Float, val descColor: Int,
        val apparentSizeSp: Float, val apparentColor: Int,
        val emojiSizeSp: Float, val statSizeSp: Float, val statColor: Int,
        val rowLabelSizeSp: Float, val rowLabelColor: Int, val rowEmojiSizeSp: Float,
        val rowValueSizeSp: Float, val rowValueColor: Int, val rowValueBold: Boolean,
        val rowPpSizeSp: Float, val rowPpColor: Int, val rowSpacingDp: Int,
        val dotSizeDp: Int, val dotActiveColor: Int, val dotInactiveColor: Int,
        val arrowColor: Int, val arrowSizeSp: Float, val scrollArrowSizeSp: Float,
        val bgMode: Int, val bgSolidColor: Int, val bgGradientTop: Int, val bgGradientBottom: Int,
        val bgDarkenPct: Int, val cornerRadiusDp: Int,
        val animFrameCount: Int,
        val animLoopMode: Int,
        val animTrigger: Int,
    )

    companion object {
        // Threads de animación activos por widget ID. Acceso sincronizado.
        private val animThreads = java.util.concurrent.ConcurrentHashMap<Int, Thread>()

        private const val PREFS_FLUTTER = "FlutterSharedPreferences"
        private const val PREFS_UI = "weather_widget_ui"
        private const val KEY_SNAPSHOT = "flutter.weather_widget_json"
        private const val CFG_PREFIX = "flutter.weather_widget_cfg_"

        private const val ACTION_PREFIX = "com.example.connect.widget.WEATHER"
        const val ACTION_PREV_VIEW   = "$ACTION_PREFIX.PREV_VIEW"
        const val ACTION_NEXT_VIEW   = "$ACTION_PREFIX.NEXT_VIEW"
        const val ACTION_SCROLL_UP   = "$ACTION_PREFIX.SCROLL_UP"
        const val ACTION_SCROLL_DOWN = "$ACTION_PREFIX.SCROLL_DOWN"
        const val ACTION_CYCLE_CITY  = "$ACTION_PREFIX.CYCLE_CITY"
        const val ACTION_ANIMATE     = "$ACTION_PREFIX.ANIMATE"
        private const val EXTRA_WIDGET_ID = "appWidgetId"

        private const val VISIBLE_ROWS = 4
        // Lienzo base del fondo (se estira con fitXY al tamaño real del widget).
        private const val BG_W = 640
        private const val BG_H = 380

        private val VIEW_LABELS = arrayOf("Ahora", "Por horas", "Por días")
        private val HR_TIME = intArrayOf(R.id.hr0_time, R.id.hr1_time, R.id.hr2_time, R.id.hr3_time)
        private val HR_EMOJI = intArrayOf(R.id.hr0_emoji, R.id.hr1_emoji, R.id.hr2_emoji, R.id.hr3_emoji)
        private val HR_PP = intArrayOf(R.id.hr0_pp, R.id.hr1_pp, R.id.hr2_pp, R.id.hr3_pp)
        private val HR_TEMP = intArrayOf(R.id.hr0_temp, R.id.hr1_temp, R.id.hr2_temp, R.id.hr3_temp)
        private val HR_ROW = intArrayOf(R.id.hr0, R.id.hr1, R.id.hr2, R.id.hr3)
        private val DY_DAY = intArrayOf(R.id.dy0_day, R.id.dy1_day, R.id.dy2_day, R.id.dy3_day)
        private val DY_EMOJI = intArrayOf(R.id.dy0_emoji, R.id.dy1_emoji, R.id.dy2_emoji, R.id.dy3_emoji)
        private val DY_PP = intArrayOf(R.id.dy0_pp, R.id.dy1_pp, R.id.dy2_pp, R.id.dy3_pp)
        private val DY_TEMP = intArrayOf(R.id.dy0_temp, R.id.dy1_temp, R.id.dy2_temp, R.id.dy3_temp)
        private val DY_ROW = intArrayOf(R.id.dy0, R.id.dy1, R.id.dy2, R.id.dy3)
        private val DOTS = intArrayOf(R.id.weather_dot0, R.id.weather_dot1, R.id.weather_dot2)

        /// Repinta todas las instancias del widget en la pantalla de inicio.
        /// Regenera los frames de animación cuando los datos o la config cambian.
        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, WeatherWidgetProvider::class.java)
            val ids = mgr.getAppWidgetIds(component)
            if (ids.isEmpty()) return
            generateAndSaveFrames(context)
            for (id in ids) render(context, mgr, id)
        }

        private fun readSnapshot(context: Context): JSONObject? {
            val json = try {
                context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
                    .getString(KEY_SNAPSHOT, null)
            } catch (_: Throwable) { null }
            if (json.isNullOrBlank()) return null
            return try { JSONObject(json) } catch (_: Throwable) { null }
        }

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

        private fun fBool(p: android.content.SharedPreferences, k: String, d: Boolean): Boolean {
            return try {
                when (val v = p.all[k]) {
                    is Boolean -> v
                    is String -> v.equals("true", ignoreCase = true)
                    is Int -> v != 0
                    else -> d
                }
            } catch (_: Exception) { d }
        }

        /// Lee la personalización — ESPEJO de los defaults en
        /// `WeatherWidgetConfigService` (Dart).
        private fun readWeatherWidgetCfg(context: Context): WeatherCfg {
            val p = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            val white = 0xFFFFFFFF.toInt()
            val white70 = 0xB3FFFFFF.toInt()
            val dotOff = 0x5CFFFFFF.toInt()
            val ppColor = 0xFF80D8FF.toInt()
            fun gi(prop: String, d: Int) = fInt(p, CFG_PREFIX + prop, d)
            fun gc(prop: String, d: Int) = fColor(p, CFG_PREFIX + prop, d)
            fun gb(prop: String, d: Boolean) = fBool(p, CFG_PREFIX + prop, d)
            return WeatherCfg(
                cityLabelSizeSp = gi("city_label_size_sp", 16).toFloat(),
                cityLabelColor = gc("city_label_color_argb", white),
                cityLabelBold = gb("city_label_bold", true),
                showLocationPin = gb("show_location_pin", true),
                viewLabelSizeSp = gi("view_label_size_sp", 12).toFloat(),
                viewLabelColor = gc("view_label_color_argb", white70),
                tempSizeSp = gi("temp_size_sp", 48).toFloat(),
                tempColor = gc("temp_color_argb", white),
                tempBold = gb("temp_bold", false),
                descSizeSp = gi("desc_size_sp", 15).toFloat(),
                descColor = gc("desc_color_argb", white),
                apparentSizeSp = gi("apparent_size_sp", 13).toFloat(),
                apparentColor = gc("apparent_color_argb", white70),
                emojiSizeSp = gi("emoji_size_sp", 50).toFloat(),
                statSizeSp = gi("stat_size_sp", 13).toFloat(),
                statColor = gc("stat_color_argb", white),
                rowLabelSizeSp = gi("row_label_size_sp", 13).toFloat(),
                rowLabelColor = gc("row_label_color_argb", white),
                rowEmojiSizeSp = gi("row_emoji_size_sp", 18).toFloat(),
                rowValueSizeSp = gi("row_value_size_sp", 14).toFloat(),
                rowValueColor = gc("row_value_color_argb", white),
                rowValueBold = gb("row_value_bold", true),
                rowPpSizeSp = gi("row_pp_size_sp", 12).toFloat(),
                rowPpColor = gc("row_pp_color_argb", ppColor),
                rowSpacingDp = gi("row_spacing_dp", 3),
                dotSizeDp = gi("dot_size_dp", 6),
                dotActiveColor = gc("dot_active_color_argb", white),
                dotInactiveColor = gc("dot_inactive_color_argb", dotOff),
                arrowColor = gc("arrow_color_argb", white),
                arrowSizeSp = gi("arrow_size_sp", 16).toFloat(),
                scrollArrowSizeSp = gi("scroll_arrow_size_sp", 14).toFloat(),
                bgMode = gi("bg_mode", 0).coerceIn(0, 2),
                bgSolidColor = gc("bg_solid_argb", 0xFF2C3E73.toInt()),
                bgGradientTop = gc("bg_gradient_top_argb", 0xFF4A6FA5.toInt()),
                bgGradientBottom = gc("bg_gradient_bottom_argb", 0xFF2C3E73.toInt()),
                bgDarkenPct = gi("bg_darken_pct", 0).coerceIn(0, 80),
                cornerRadiusDp = gi("corner_radius_dp", 20).coerceIn(0, 40),
                animFrameCount = gi("anim_frame_count", 1).coerceIn(1, 36),
                animLoopMode = gi("anim_loop_mode", 0).coerceIn(0, 1),
                animTrigger = gi("anim_trigger", 0).coerceIn(0, 2),
            )
        }

        private fun render(context: Context, mgr: AppWidgetManager, appWidgetId: Int) {
            if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
            try {
                mgr.updateAppWidget(appWidgetId, buildViews(context, appWidgetId))
            } catch (t: Throwable) {
                t.printStackTrace()
            }
        }

        private fun styled(text: String, bold: Boolean): CharSequence {
            if (!bold || text.isEmpty()) return text
            val s = SpannableString(text)
            s.setSpan(StyleSpan(android.graphics.Typeface.BOLD), 0, text.length, Spannable.SPAN_INCLUSIVE_INCLUSIVE)
            return s
        }

        private fun setSize(views: RemoteViews, id: Int, sp: Float) {
            views.setTextViewTextSize(id, TypedValue.COMPLEX_UNIT_SP, sp)
        }

        private fun buildViews(context: Context, appWidgetId: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_weather)
            val cfg = readWeatherWidgetCfg(context)
            val snapshot = readSnapshot(context)
            val cities = snapshot?.optJSONArray("cities")

            if (cities == null || cities.length() == 0) {
                showEmpty(context, views, cfg)
                return views
            }

            val ui = context.getSharedPreferences(PREFS_UI, Context.MODE_PRIVATE)
            var cityIdx = ui.getInt("city_$appWidgetId", -1)
            if (cityIdx < 0) cityIdx = snapshot.optInt("selectedIndex", 0)
            cityIdx = cityIdx.coerceIn(0, cities.length() - 1)
            val city = cities.optJSONObject(cityIdx) ?: run { showEmpty(context, views, cfg); return views }
            val view = ui.getInt("view_$appWidgetId", 0).coerceIn(0, 2)

            // Fondo: usa frame 0 pre-renderizado si está disponible.
            views.setImageViewBitmap(R.id.weather_bg_image, loadFrame0OrFallback(context, cfg, city))

            // Cabecera
            views.setViewVisibility(R.id.weather_empty, View.GONE)
            views.setTextViewText(R.id.weather_city, styled(city.optString("name", "—"), cfg.cityLabelBold))
            setSize(views, R.id.weather_city, cfg.cityLabelSizeSp)
            views.setTextColor(R.id.weather_city, cfg.cityLabelColor)
            views.setTextColor(R.id.weather_city_caret, cfg.cityLabelColor)
            views.setViewVisibility(
                R.id.weather_city_caret,
                if (cities.length() > 1) View.VISIBLE else View.GONE
            )
            views.setTextViewText(R.id.weather_view_label, VIEW_LABELS[view])
            setSize(views, R.id.weather_view_label, cfg.viewLabelSizeSp)
            views.setTextColor(R.id.weather_view_label, cfg.viewLabelColor)
            // 📍: la primera TextView fija del grupo "weather_city_btn".
            views.setViewVisibility(R.id.weather_pin, if (cfg.showLocationPin) View.VISIBLE else View.GONE)

            // Visibilidad de cada vista
            views.setViewVisibility(R.id.weather_view_current, if (view == 0) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.weather_view_hourly, if (view == 1) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.weather_view_daily, if (view == 2) View.VISIBLE else View.GONE)

            when (view) {
                0 -> bindCurrent(views, city, cfg)
                1 -> bindHourly(views, city, ui.getInt("hoff_$appWidgetId", 0), cfg)
                2 -> bindDaily(views, city, ui.getInt("doff_$appWidgetId", 0), cfg)
            }

            // Indicadores de página
            for (i in DOTS.indices) {
                views.setTextColor(DOTS[i], if (i == view) cfg.dotActiveColor else cfg.dotInactiveColor)
                setSize(views, DOTS[i], (cfg.dotSizeDp + 4).toFloat())
            }

            bindClicks(context, views, appWidgetId, cfg)
            return views
        }

        /// Colores del degradado dinámico — ESPEJO de
        /// `WeatherCodeInfo.gradientColors` (Dart, lib/models/weather_models.dart).
        private fun dynamicGradientFor(category: String, isDay: Boolean): IntArray = when (category) {
            "clear" -> if (isDay) intArrayOf(0xFF4FA4E8.toInt(), 0xFF2D6FB5.toInt())
                       else intArrayOf(0xFF1B2A4A.toInt(), 0xFF0B1020.toInt())
            "clouds" -> if (isDay) intArrayOf(0xFF7E96AB.toInt(), 0xFF4A5D70.toInt())
                        else intArrayOf(0xFF2A3340.toInt(), 0xFF161C24.toInt())
            "fog" -> if (isDay) intArrayOf(0xFF9AA7B0.toInt(), 0xFF6B7780.toInt())
                     else intArrayOf(0xFF2B333A.toInt(), 0xFF181D22.toInt())
            "rain" -> if (isDay) intArrayOf(0xFF4A6075.toInt(), 0xFF2A3845.toInt())
                      else intArrayOf(0xFF1E2730.toInt(), 0xFF10151B.toInt())
            "snow" -> if (isDay) intArrayOf(0xFF8FB4D6.toInt(), 0xFF5E7E9C.toInt())
                      else intArrayOf(0xFF26303C.toInt(), 0xFF141A21.toInt())
            "thunder" -> intArrayOf(0xFF2A2E45.toInt(), 0xFF14161F.toInt())
            else -> intArrayOf(0xFF4A6FA5.toInt(), 0xFF2C3E73.toInt())
        }

        /// Mezcla [color] hacia negro en un [pct]% (0-100). Espejo de
        /// `WeatherWidgetState._darken` (Dart).
        private fun darken(color: Int, pct: Int): Int {
            if (pct <= 0) return color
            val f = 1f - (pct.coerceIn(0, 100) / 100f)
            val a = (color ushr 24) and 0xFF
            val r = (((color shr 16) and 0xFF) * f).toInt()
            val g = (((color shr 8) and 0xFF) * f).toInt()
            val b = ((color and 0xFF) * f).toInt()
            return (a shl 24) or (r shl 16) or (g shl 8) or b
        }

        private fun dp(context: Context, v: Float): Float = v * context.resources.displayMetrics.density

        /// Directorio donde se guardan los frames de animación.
        private fun framesDir(context: Context) = File(context.filesDir, "weather_frames")

        /// Genera N frames del fondo animado y los guarda como PNG en [framesDir].
        /// Solo actúa en modo dinámico; en modos sólido/degradado no hay frames.
        private fun generateAndSaveFrames(context: Context) {
            try {
                val cfg = readWeatherWidgetCfg(context)
                val dir = framesDir(context)
                dir.mkdirs()
                dir.listFiles()?.forEach { it.delete() }

                if (cfg.bgMode != 0) return  // solo modo dinámico

                val snapshot = readSnapshot(context) ?: return
                val cities   = snapshot.optJSONArray("cities") ?: return
                if (cities.length() == 0) return
                val selIdx   = snapshot.optInt("selectedIndex", 0).coerceIn(0, cities.length() - 1)
                val city     = cities.optJSONObject(selIdx) ?: return

                val category   = city.optString("bg", "clear")
                val isDay      = city.optInt("isDay", 1) == 1
                val windSpeed  = city.optDouble("wind", 0.0).toFloat()
                val gradColors = dynamicGradientFor(category, isDay)
                val radiusPx   = dp(context, cfg.cornerRadiusDp.toFloat())

                val particles = WeatherFrameRenderer.buildParticles(category, isDay)
                val cycle     = WeatherFrameRenderer.cycleDuration(category, isDay)
                val n         = cfg.animFrameCount

                for (i in 0 until n) {
                    val t   = if (n == 1) 0f else i.toFloat() / n * cycle
                    val bmp = Bitmap.createBitmap(BG_W, BG_H, Bitmap.Config.ARGB_8888)
                    WeatherFrameRenderer.renderFrame(
                        Canvas(bmp), BG_W.toFloat(), BG_H.toFloat(),
                        category, isDay, windSpeed, cfg.bgDarkenPct,
                        gradColors, radiusPx, t, particles,
                    )
                    File(dir, "frame_$i.png").outputStream().use { out ->
                        bmp.compress(Bitmap.CompressFormat.PNG, 90, out)
                    }
                    bmp.recycle()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        /// Carga el frame 0 pre-renderizado si existe; si no, genera el fondo simple.
        private fun loadFrame0OrFallback(context: Context, cfg: WeatherCfg, city: JSONObject?): Bitmap {
            if (cfg.bgMode == 0) {
                val f = File(framesDir(context), "frame_0.png")
                if (f.exists()) {
                    try {
                        BitmapFactory.decodeFile(f.absolutePath)?.let { return it }
                    } catch (_: Exception) {}
                }
            }
            return buildBgBitmap(context, cfg, city)
        }

        /// Dibuja el fondo gradiente simple a un Bitmap (modos sólido/degradado,
        /// o fallback cuando aún no hay frames generados).
        private fun buildBgBitmap(context: Context, cfg: WeatherCfg, city: JSONObject?): Bitmap {
            val bmp = Bitmap.createBitmap(BG_W, BG_H, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            val radiusPx = dp(context, cfg.cornerRadiusDp.toFloat())
            val rect = RectF(0f, 0f, BG_W.toFloat(), BG_H.toFloat())
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)

            val colors: IntArray = when (cfg.bgMode) {
                1 -> intArrayOf(cfg.bgSolidColor, cfg.bgSolidColor)
                2 -> intArrayOf(cfg.bgGradientTop, cfg.bgGradientBottom)
                else -> {
                    val cat = city?.optString("bg", "clear") ?: "clear"
                    val day = (city?.optInt("isDay", 1) ?: 1) == 1
                    dynamicGradientFor(cat, day)
                }
            }
            val top    = darken(colors[0], cfg.bgDarkenPct)
            val bottom = darken(colors[1], cfg.bgDarkenPct)

            paint.shader = if (top == bottom) null
            else LinearGradient(0f, 0f, BG_W.toFloat(), BG_H.toFloat(), top, bottom, Shader.TileMode.CLAMP)
            if (paint.shader == null) paint.color = top
            canvas.drawRoundRect(rect, radiusPx, radiusPx, paint)
            return bmp
        }

        private fun showEmpty(context: Context, views: RemoteViews, cfg: WeatherCfg) {
            views.setImageViewBitmap(R.id.weather_bg_image, buildBgBitmap(context, cfg, null))
            views.setViewVisibility(R.id.weather_empty, View.VISIBLE)
            views.setViewVisibility(R.id.weather_view_current, View.GONE)
            views.setViewVisibility(R.id.weather_view_hourly, View.GONE)
            views.setViewVisibility(R.id.weather_view_daily, View.GONE)
            views.setViewVisibility(R.id.weather_city_caret, View.GONE)
            views.setViewVisibility(R.id.weather_pin, if (cfg.showLocationPin) View.VISIBLE else View.GONE)
            views.setTextViewText(R.id.weather_city, "Clima")
            setSize(views, R.id.weather_city, cfg.cityLabelSizeSp)
            views.setTextColor(R.id.weather_city, cfg.cityLabelColor)
            views.setTextViewText(R.id.weather_view_label, "")
            for (d in DOTS) views.setTextColor(d, cfg.dotInactiveColor)
        }

        private fun bindCurrent(views: RemoteViews, city: JSONObject, cfg: WeatherCfg) {
            views.setTextViewText(R.id.weather_temp, styled("${city.optInt("temp", 0)}°", cfg.tempBold))
            setSize(views, R.id.weather_temp, cfg.tempSizeSp)
            views.setTextColor(R.id.weather_temp, cfg.tempColor)

            views.setTextViewText(R.id.weather_desc, city.optString("desc", ""))
            setSize(views, R.id.weather_desc, cfg.descSizeSp)
            views.setTextColor(R.id.weather_desc, cfg.descColor)

            views.setTextViewText(R.id.weather_apparent, "Sensación ${city.optInt("apparent", 0)}°")
            setSize(views, R.id.weather_apparent, cfg.apparentSizeSp)
            views.setTextColor(R.id.weather_apparent, cfg.apparentColor)

            views.setTextViewText(R.id.weather_emoji, city.optString("emoji", "🌡️"))
            setSize(views, R.id.weather_emoji, cfg.emojiSizeSp)

            views.setTextViewText(R.id.weather_humidity, "💧 ${city.optInt("humidity", 0)}%")
            setSize(views, R.id.weather_humidity, cfg.statSizeSp)
            views.setTextColor(R.id.weather_humidity, cfg.statColor)

            views.setTextViewText(R.id.weather_wind, "💨 ${city.optInt("wind", 0)} km/h")
            setSize(views, R.id.weather_wind, cfg.statSizeSp)
            views.setTextColor(R.id.weather_wind, cfg.statColor)
        }

        private fun bindHourly(views: RemoteViews, city: JSONObject, rawOffset: Int, cfg: WeatherCfg) {
            val list = city.optJSONArray("hourly") ?: JSONArray()
            val maxOffset = (list.length() - VISIBLE_ROWS).coerceAtLeast(0)
            val offset = rawOffset.coerceIn(0, maxOffset)
            for (i in 0 until VISIBLE_ROWS) {
                val idx = offset + i
                val item = if (idx < list.length()) list.optJSONObject(idx) else null
                applyRowStyle(views, HR_TIME[i], HR_EMOJI[i], HR_PP[i], HR_TEMP[i], cfg)
                if (item == null) {
                    views.setViewVisibility(HR_ROW[i], View.INVISIBLE)
                } else {
                    views.setViewVisibility(HR_ROW[i], View.VISIBLE)
                    views.setTextViewText(HR_TIME[i], item.optString("label", ""))
                    views.setTextViewText(HR_EMOJI[i], item.optString("emoji", ""))
                    val pp = item.optInt("pp", 0)
                    views.setTextViewText(HR_PP[i], if (pp > 0) "💧$pp%" else "")
                    views.setTextViewText(HR_TEMP[i], styled("${item.optInt("temp", 0)}°", cfg.rowValueBold))
                }
            }
            views.setTextColor(R.id.hr_up, if (offset > 0) cfg.arrowColor else dim(cfg.arrowColor))
            views.setTextColor(R.id.hr_down, if (offset < maxOffset) cfg.arrowColor else dim(cfg.arrowColor))
            setSize(views, R.id.hr_up, cfg.scrollArrowSizeSp)
            setSize(views, R.id.hr_down, cfg.scrollArrowSizeSp)
        }

        private fun bindDaily(views: RemoteViews, city: JSONObject, rawOffset: Int, cfg: WeatherCfg) {
            val list = city.optJSONArray("daily") ?: JSONArray()
            val maxOffset = (list.length() - VISIBLE_ROWS).coerceAtLeast(0)
            val offset = rawOffset.coerceIn(0, maxOffset)
            for (i in 0 until VISIBLE_ROWS) {
                val idx = offset + i
                val item = if (idx < list.length()) list.optJSONObject(idx) else null
                applyRowStyle(views, DY_DAY[i], DY_EMOJI[i], DY_PP[i], DY_TEMP[i], cfg)
                if (item == null) {
                    views.setViewVisibility(DY_ROW[i], View.INVISIBLE)
                } else {
                    views.setViewVisibility(DY_ROW[i], View.VISIBLE)
                    views.setTextViewText(DY_DAY[i], item.optString("day", ""))
                    views.setTextViewText(DY_EMOJI[i], item.optString("emoji", ""))
                    val pp = item.optInt("pp", 0)
                    views.setTextViewText(DY_PP[i], if (pp > 0) "💧$pp%" else "")
                    views.setTextViewText(
                        DY_TEMP[i],
                        styled("${item.optInt("max", 0)}° / ${item.optInt("min", 0)}°", cfg.rowValueBold)
                    )
                }
            }
            views.setTextColor(R.id.dy_up, if (offset > 0) cfg.arrowColor else dim(cfg.arrowColor))
            views.setTextColor(R.id.dy_down, if (offset < maxOffset) cfg.arrowColor else dim(cfg.arrowColor))
            setSize(views, R.id.dy_up, cfg.scrollArrowSizeSp)
            setSize(views, R.id.dy_down, cfg.scrollArrowSizeSp)
        }

        private fun dim(color: Int): Int = (color and 0x00FFFFFF) or 0x40000000

        private fun applyRowStyle(
            views: RemoteViews,
            labelId: Int,
            emojiId: Int,
            ppId: Int,
            valueId: Int,
            cfg: WeatherCfg
        ) {
            setSize(views, labelId, cfg.rowLabelSizeSp)
            views.setTextColor(labelId, cfg.rowLabelColor)
            setSize(views, emojiId, cfg.rowEmojiSizeSp)
            setSize(views, ppId, cfg.rowPpSizeSp)
            views.setTextColor(ppId, cfg.rowPpColor)
            setSize(views, valueId, cfg.rowValueSizeSp)
            views.setTextColor(valueId, cfg.rowValueColor)
        }

        private fun bindClicks(context: Context, views: RemoteViews, appWidgetId: Int, cfg: WeatherCfg) {
            // Toque sobre el fondo (área no cubierta por botones) → animar frames.
            views.setOnClickPendingIntent(R.id.weather_root, pi(context, ACTION_ANIMATE, appWidgetId, 8))
            views.setOnClickPendingIntent(R.id.weather_prev, pi(context, ACTION_PREV_VIEW, appWidgetId, 1))
            views.setOnClickPendingIntent(R.id.weather_next, pi(context, ACTION_NEXT_VIEW, appWidgetId, 2))
            views.setOnClickPendingIntent(R.id.hr_up, pi(context, ACTION_SCROLL_UP, appWidgetId, 3))
            views.setOnClickPendingIntent(R.id.hr_down, pi(context, ACTION_SCROLL_DOWN, appWidgetId, 4))
            views.setOnClickPendingIntent(R.id.dy_up, pi(context, ACTION_SCROLL_UP, appWidgetId, 5))
            views.setOnClickPendingIntent(R.id.dy_down, pi(context, ACTION_SCROLL_DOWN, appWidgetId, 6))
            views.setOnClickPendingIntent(R.id.weather_city_btn, pi(context, ACTION_CYCLE_CITY, appWidgetId, 7))
            views.setTextColor(R.id.weather_prev, cfg.arrowColor)
            views.setTextColor(R.id.weather_next, cfg.arrowColor)
            setSize(views, R.id.weather_prev, cfg.arrowSizeSp)
            setSize(views, R.id.weather_next, cfg.arrowSizeSp)
        }

        private fun pi(context: Context, action: String, appWidgetId: Int, code: Int): PendingIntent {
            val intent = Intent(context, WeatherWidgetProvider::class.java)
                .setAction(action)
                .putExtra(EXTRA_WIDGET_ID, appWidgetId)
            val req = appWidgetId * 100 + code
            return PendingIntent.getBroadcast(
                context, req, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            )
        }

        private fun immutableFlag(): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        }
    }
}
