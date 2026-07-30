package com.example.connect

import android.graphics.*
import kotlin.math.*

/**
 * Renderiza frames del fondo animado del widget de clima sobre un [Canvas].
 * Port directo de `_WeatherPainter` (lib/widgets/weather_background.dart).
 *
 * Las partículas se construyen con [buildParticles] (seed 7, misma distribución
 * que Dart aunque no bit-a-bit idéntica). [renderFrame] dibuja un frame completo
 * dado el tiempo virtual [t] en segundos.
 */
internal object WeatherFrameRenderer {

    // =========================================================================
    // Iconos de clima (estilo Material Design) para el widget nativo.
    // Reemplazan los emojis del sistema, que varían por dispositivo/versión.
    // =========================================================================

    /** Renderiza un icono de clima al estilo Material Design en un [Bitmap] cuadrado. */
    fun renderIconBitmap(category: String, isDay: Boolean, sizePx: Int): Bitmap {
        val bmp = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        bmp.eraseColor(0)
        val canvas = Canvas(bmp)
        val s = sizePx.toFloat()
        val cx = s / 2f
        val cy = s / 2f
        val p = Paint(Paint.ANTI_ALIAS_FLAG)

        // Colores espejo de WeatherCodeInfo.from() en Dart (lib/models/weather_models.dart).
        p.color = when (category) {
            "clear"   -> if (isDay) 0xFFFFB300.toInt() else 0xFF5C6BC0.toInt()
            "clouds"  -> 0xFF90A4AE.toInt()
            "fog"     -> 0xFFB0BEC5.toInt()
            "rain"    -> 0xFF29B6F6.toInt()
            "snow"    -> 0xFF81D4FA.toInt()
            "thunder" -> 0xFF5C6BC0.toInt()
            else      -> 0xFF90A4AE.toInt()
        }

        when (category) {
            "clear"   -> if (isDay) iconSun(canvas, cx, cy, s, p) else iconMoon(canvas, cx, cy, s, p)
            "clouds"  -> iconCloud(canvas, cx, cy, s, p)
            "fog"     -> iconFog(canvas, cx, cy, s, p)
            "rain"    -> iconRain(canvas, cx, cy, s, p)
            "snow"    -> iconSnow(canvas, cx, cy, s, p)
            "thunder" -> iconThunder(canvas, cx, cy, s, p)
            else      -> iconCloud(canvas, cx, cy, s, p)
        }
        return bmp
    }

    // --- Sol (wb_sunny): círculo + 8 rayos ------------------------------------
    private fun iconSun(canvas: Canvas, cx: Float, cy: Float, s: Float, p: Paint) {
        p.style = Paint.Style.FILL
        canvas.drawCircle(cx, cy, s * 0.22f, p)
        p.style = Paint.Style.STROKE
        p.strokeWidth = s * 0.07f
        p.strokeCap = Paint.Cap.ROUND
        for (i in 0 until 8) {
            val a = i * PI.toFloat() / 4f
            canvas.drawLine(cx + cos(a)*s*0.29f, cy + sin(a)*s*0.29f,
                            cx + cos(a)*s*0.42f, cy + sin(a)*s*0.42f, p)
        }
    }

    // --- Luna creciente (nightlight_round) ------------------------------------
    private fun iconMoon(canvas: Canvas, cx: Float, cy: Float, s: Float, p: Paint) {
        val path = Path().apply { addCircle(cx, cy, s * 0.34f, Path.Direction.CW) }
        path.op(Path().apply { addCircle(cx + s*0.21f, cy - s*0.15f, s * 0.28f, Path.Direction.CW) },
                Path.Op.DIFFERENCE)
        p.style = Paint.Style.FILL
        canvas.drawPath(path, p)
    }

    // --- Nube (cloud) ---------------------------------------------------------
    private fun iconCloud(canvas: Canvas, cx: Float, cy: Float, s: Float, p: Paint) {
        p.style = Paint.Style.FILL
        canvas.drawCircle(cx - s*0.14f, cy + s*0.05f, s*0.20f, p)
        canvas.drawCircle(cx + s*0.14f, cy + s*0.05f, s*0.17f, p)
        canvas.drawCircle(cx,           cy - s*0.05f, s*0.23f, p)
        canvas.drawRoundRect(RectF(cx-s*0.28f, cy+s*0.02f, cx+s*0.28f, cy+s*0.22f), s*0.12f, s*0.12f, p)
    }

    // --- Niebla (foggy): bandas horizontales ----------------------------------
    private fun iconFog(canvas: Canvas, cx: Float, cy: Float, s: Float, p: Paint) {
        p.style = Paint.Style.STROKE
        p.strokeWidth = s * 0.09f
        p.strokeCap = Paint.Cap.ROUND
        for (i in 0 until 3) {
            val y = cy - s*0.13f + i * s*0.14f
            val xOff = if (i == 1) s*0.04f else 0f
            canvas.drawLine(cx - s*0.35f + xOff, y, cx + s*0.35f - xOff, y, p)
        }
    }

    // --- Lluvia (umbrella/grain): nube + gotas --------------------------------
    private fun iconRain(canvas: Canvas, cx: Float, cy: Float, s: Float, p: Paint) {
        // Nube pequeña en parte superior
        p.style = Paint.Style.FILL
        canvas.drawCircle(cx - s*0.11f, cy - s*0.10f, s*0.17f, p)
        canvas.drawCircle(cx + s*0.11f, cy - s*0.08f, s*0.15f, p)
        canvas.drawCircle(cx,           cy - s*0.20f, s*0.19f, p)
        canvas.drawRoundRect(RectF(cx-s*0.22f, cy-s*0.13f, cx+s*0.22f, cy+s*0.01f), s*0.09f, s*0.09f, p)
        // Gotas inclinadas
        p.style = Paint.Style.STROKE
        p.strokeWidth = s * 0.07f
        p.strokeCap = Paint.Cap.ROUND
        for (i in -1..1) {
            val dx = i * s * 0.13f
            canvas.drawLine(cx+dx-s*0.03f, cy+s*0.08f, cx+dx+s*0.03f, cy+s*0.22f, p)
        }
    }

    // --- Nieve (ac_unit): copo de nieve de 6 brazos --------------------------
    private fun iconSnow(canvas: Canvas, cx: Float, cy: Float, s: Float, p: Paint) {
        p.style = Paint.Style.STROKE
        p.strokeWidth = s * 0.08f
        p.strokeCap = Paint.Cap.ROUND
        val r = s * 0.37f
        for (i in 0 until 6) {
            val a = i * PI.toFloat() / 3f
            canvas.drawLine(cx, cy, cx + cos(a)*r, cy + sin(a)*r, p)
        }
        p.style = Paint.Style.FILL
        canvas.drawCircle(cx, cy, s * 0.07f, p)
    }

    // --- Tormenta (thunderstorm): nube + rayo --------------------------------
    private fun iconThunder(canvas: Canvas, cx: Float, cy: Float, s: Float, p: Paint) {
        // Nube
        p.style = Paint.Style.FILL
        canvas.drawCircle(cx - s*0.10f, cy - s*0.12f, s*0.16f, p)
        canvas.drawCircle(cx + s*0.10f, cy - s*0.10f, s*0.14f, p)
        canvas.drawCircle(cx,           cy - s*0.22f, s*0.17f, p)
        canvas.drawRoundRect(RectF(cx-s*0.20f, cy-s*0.14f, cx+s*0.20f, cy-s*0.01f), s*0.08f, s*0.08f, p)
        // Rayo
        val bolt = Path().apply {
            moveTo(cx + s*0.05f, cy + s*0.01f)
            lineTo(cx - s*0.08f, cy + s*0.18f)
            lineTo(cx + s*0.02f, cy + s*0.18f)
            lineTo(cx - s*0.05f, cy + s*0.40f)
            lineTo(cx + s*0.12f, cy + s*0.16f)
            lineTo(cx + s*0.02f, cy + s*0.16f)
            close()
        }
        canvas.drawPath(bolt, p)
    }

    data class Particle(val x: Float, val phase: Float, val speed: Float, val size: Float)

    /** Duración de un ciclo de animación por categoría (segundos virtuales). */
    fun cycleDuration(category: String, isDay: Boolean): Float = when (category) {
        "rain", "thunder" -> 2.0f
        "snow"            -> 5.0f
        "fog"             -> 6.0f
        "clouds"          -> 8.0f
        "clear"           -> if (isDay) 4.0f else 3.0f
        else              -> 2.0f
    }

    /** Construye la lista de partículas con seed fijo (equivale a Random(7) de Dart). */
    fun buildParticles(category: String, isDay: Boolean): List<Particle> {
        val rng = java.util.Random(7L)
        val count = when (category) {
            "rain", "thunder" -> 70
            "snow"            -> 45
            "clouds"          -> 5
            "fog"             -> 4
            "clear"           -> if (!isDay) 36 else 0
            else              -> 0
        }
        return List(count) {
            Particle(
                x     = rng.nextFloat(),
                phase = rng.nextFloat(),
                speed = 0.4f + rng.nextFloat() * 0.8f,
                size  = rng.nextFloat(),
            )
        }
    }

    /**
     * Renderiza un frame completo al [canvas] del bitmap dado.
     * [gradColors] = intArray[top, bottom] del degradado dinámico.
     * [cornerRadiusPx] = radio de esquinas ya en px.
     * [t] = tiempo virtual en segundos (0 .. cycleDuration).
     */
    fun renderFrame(
        canvas: Canvas,
        w: Float,
        h: Float,
        category: String,
        isDay: Boolean,
        windSpeed: Float,
        darkenPct: Int,
        gradColors: IntArray,
        cornerRadiusPx: Float,
        t: Float,
        particles: List<Particle>,
    ) {
        val rect = RectF(0f, 0f, w, h)

        // Recortar al radio de esquinas igual que el widget real.
        val clip = Path().apply { addRoundRect(rect, cornerRadiusPx, cornerRadiusPx, Path.Direction.CW) }
        canvas.clipPath(clip)

        // Degradado base: mismo ligero oscurecido que el Dart (5 % arriba, 25 % abajo).
        val c0 = mixToBlack(gradColors[0], 0.05f)
        val c1 = mixToBlack(gradColors[1], 0.25f)
        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(0f, 0f, w, h, c0, c1, Shader.TileMode.CLAMP)
        }
        canvas.drawRect(rect, bgPaint)

        // Elementos climáticos.
        when (category) {
            "clear" ->
                if (isDay) paintSun(canvas, w, h, t)
                else { paintMoon(canvas, w, h, gradColors); paintStars(canvas, w, h, t, particles) }
            "clouds" -> {
                if (!isDay) paintStars(canvas, w, h, t, particles, dim = true)
                paintClouds(canvas, w, h, t, particles, windSpeed)
            }
            "fog"     -> paintFog(canvas, w, h, t, particles)
            "rain"    -> { paintClouds(canvas, w, h, t, particles, windSpeed, alpha = 0.18f); paintRain(canvas, w, h, t, particles, windSpeed) }
            "snow"    -> { paintClouds(canvas, w, h, t, particles, windSpeed, alpha = 0.16f); paintSnow(canvas, w, h, t, particles, windSpeed) }
            "thunder" -> { paintClouds(canvas, w, h, t, particles, windSpeed, alpha = 0.22f); paintRain(canvas, w, h, t, particles, windSpeed); paintLightning(canvas, w, h, t) }
        }

        if (windSpeed >= 20f && category != "rain" && category != "thunder") {
            paintWind(canvas, w, h, t)
        }

        // Capa de oscurecido configurable.
        if (darkenPct > 0) {
            val a = (darkenPct.coerceIn(0, 100) * 255 / 100)
            canvas.drawRect(rect, Paint().apply { color = (a shl 24) })
        }
    }

    // -------------------------------------------------------------------------
    // Helpers de color
    // -------------------------------------------------------------------------

    /** Mezcla [color] hacia negro en [pct] (0..1). Espejo de Color.lerp(c, black, pct). */
    private fun mixToBlack(color: Int, pct: Float): Int {
        val f = 1f - pct.coerceIn(0f, 1f)
        val a = (color ushr 24) and 0xFF
        val r = (((color shr 16) and 0xFF) * f).toInt()
        val g = (((color shr 8)  and 0xFF) * f).toInt()
        val b = ((color          and 0xFF) * f).toInt()
        return (a shl 24) or (r shl 16) or (g shl 8) or b
    }

    private fun argb(alpha: Float, rgb: Int): Int =
        ((alpha.coerceIn(0f, 1f) * 255).toInt() shl 24) or (rgb and 0x00FFFFFF)

    private fun windTilt(windSpeed: Float) = (windSpeed.coerceIn(0f, 60f) / 60f) * 0.6f

    // -------------------------------------------------------------------------
    // Sol
    // -------------------------------------------------------------------------

    private fun paintSun(canvas: Canvas, w: Float, h: Float, t: Float) {
        val cx = w * 0.20f  // sol en la izquierda
        val cy = h * 0.28f
        val pulse = 0.5f + 0.5f * sin(t * 1.2f)

        // Rayos de barrido horizontal (de izquierda a derecha).
        val sweepPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 18f
            strokeCap = Paint.Cap.BUTT
            maskFilter = BlurMaskFilter(24f, BlurMaskFilter.Blur.NORMAL)
        }
        for (i in 0 until 4) {
            val angle = (-0.30f + i * 0.20f)
            val phase = i * 0.28f
            val travel = ((t * 0.10f + phase) % 1.0f)
            val alpha = (0.10f * sin(travel * PI.toFloat())).coerceAtLeast(0f)
            if (alpha < 0.01f) continue
            sweepPaint.color = argb(alpha, 0xFFE08A)
            val len = w * 1.3f
            canvas.drawLine(cx + 28f, cy, cx + 28f + len * cos(angle), cy + len * sin(angle), sweepPaint)
        }

        // Halo radial.
        canvas.drawCircle(cx, cy, 46f + pulse * 6f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = RadialGradient(cx, cy, 60f,
                intArrayOf(argb(0.55f, 0xFFE08A), argb(0f, 0xFFE08A)),
                null, Shader.TileMode.CLAMP)
        })
        // Disco.
        canvas.drawCircle(cx, cy, 22f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFE9A8.toInt()
        })
        // Rayos giratorios.
        val rayPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = argb(0.35f, 0xFFE08A)
            strokeWidth = 3f
            strokeCap = Paint.Cap.ROUND
            style = Paint.Style.STROKE
        }
        for (i in 0 until 12) {
            val a = t * 0.3f + i * (PI * 2 / 12).toFloat()
            val r1 = 28f
            val r2 = 38f + pulse * 4f
            canvas.drawLine(cx + cos(a) * r1, cy + sin(a) * r1,
                            cx + cos(a) * r2, cy + sin(a) * r2, rayPaint)
        }
    }

    // -------------------------------------------------------------------------
    // Luna
    // -------------------------------------------------------------------------

    private fun paintMoon(canvas: Canvas, w: Float, h: Float, gradColors: IntArray) {
        val cx = w * 0.80f
        val cy = h * 0.28f
        // Halo.
        canvas.drawCircle(cx, cy, 40f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = RadialGradient(cx, cy, 52f,
                intArrayOf(argb(0.30f, 0xFFFFFF), argb(0f, 0xFFFFFF)),
                null, Shader.TileMode.CLAMP)
        })
        // Disco lunar.
        canvas.drawCircle(cx, cy, 20f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFEDEFF5.toInt()
        })
        // Recorte creciente: mismo color que la esquina superior del degradado.
        canvas.drawCircle(cx + 10f, cy - 6f, 18f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = mixToBlack(gradColors[0], 0.05f)
        })
    }

    // -------------------------------------------------------------------------
    // Estrellas
    // -------------------------------------------------------------------------

    private fun paintStars(
        canvas: Canvas, w: Float, h: Float, t: Float,
        particles: List<Particle>, dim: Boolean = false,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        for (p in particles) {
            val twinkle = 0.4f + 0.6f * (0.5f + 0.5f * sin(t * 2f + p.phase * 6.28f))
            val alpha = (if (dim) 0.4f else 0.9f) * twinkle * (0.4f + p.size * 0.6f)
            paint.color = argb(alpha, 0xFFFFFF)
            canvas.drawCircle(p.x * w, p.phase * h * 0.7f, 0.6f + p.size * 1.4f, paint)
        }
    }

    // -------------------------------------------------------------------------
    // Nubes
    // -------------------------------------------------------------------------

    private fun paintClouds(
        canvas: Canvas, w: Float, h: Float, t: Float,
        particles: List<Particle>, windSpeed: Float, alpha: Float = 0.30f,
    ) {
        val speedBoost = 1f + windSpeed.coerceIn(0f, 50f) / 50f
        for (p in particles) {
            val cw   = w * (0.5f + p.size * 0.5f)
            val cy   = h * (0.15f + p.x * 0.5f)
            val trav = (t * 0.02f * p.speed * speedBoost + p.phase) % 1.3f - 0.15f
            drawCloud(canvas, trav * w, cy, cw * 0.6f, alpha * (0.6f + p.size * 0.4f))
        }
    }

    private fun drawCloud(canvas: Canvas, cx: Float, cy: Float, cw: Float, alpha: Float) {
        val h = cw * 0.42f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = argb(alpha, 0xFFFFFF)
            maskFilter = BlurMaskFilter((h * 0.38f).coerceAtLeast(4f), BlurMaskFilter.Blur.NORMAL)
        }
        canvas.drawCircle(cx,                  cy,             h * 0.6f,  paint)
        canvas.drawCircle(cx + cw * 0.28f,     cy + h * 0.08f, h * 0.5f,  paint)
        canvas.drawCircle(cx - cw * 0.28f,     cy + h * 0.1f,  h * 0.45f, paint)
        canvas.drawRoundRect(
            RectF(cx - cw * 0.5f, cy + h * 0.02f, cx + cw * 0.5f, cy + h * 0.62f),
            h, h, paint,
        )
    }

    // -------------------------------------------------------------------------
    // Niebla
    // -------------------------------------------------------------------------

    private fun paintFog(canvas: Canvas, w: Float, h: Float, t: Float, particles: List<Particle>) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            maskFilter = BlurMaskFilter(22f, BlurMaskFilter.Blur.NORMAL)
        }
        for (i in particles.indices) {
            val p     = particles[i]
            val py    = h * (0.15f + i.toFloat() / particles.size * 0.75f)
            val bandH = 32f + p.size * 24f
            // Capa primaria (movimiento hacia la derecha)
            val trav1 = (t * 0.025f * p.speed + p.phase) % 1.5f - 0.25f
            paint.color = argb(0.12f + p.size * 0.07f, 0xFFFFFF)
            canvas.drawRoundRect(
                RectF(trav1 * w - w * 0.25f, py - bandH / 2f,
                      trav1 * w + w * 0.95f, py + bandH / 2f),
                50f, 50f, paint,
            )
            // Capa secundaria (movimiento más lento, fase opuesta)
            val trav2 = (t * 0.018f * p.speed + p.phase + 0.65f) % 1.5f - 0.25f
            paint.color = argb(0.07f + p.size * 0.04f, 0xFFFFFF)
            canvas.drawRoundRect(
                RectF(trav2 * w - w * 0.25f, py - bandH * 0.55f,
                      trav2 * w + w * 0.95f, py + bandH * 0.55f),
                50f, 50f, paint,
            )
        }
    }

    // -------------------------------------------------------------------------
    // Lluvia
    // -------------------------------------------------------------------------

    private fun paintRain(
        canvas: Canvas, w: Float, h: Float, t: Float,
        particles: List<Particle>, windSpeed: Float,
    ) {
        val tilt  = windTilt(windSpeed)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color      = argb(0.45f, 0xFFFFFF)
            strokeWidth = 1.6f
            strokeCap  = Paint.Cap.ROUND
            style      = Paint.Style.STROKE
        }
        for (p in particles) {
            val len  = 10f + p.size * 10f
            val fall = (t * (0.9f + p.speed) + p.phase) % 1.0f
            val py   = fall * (h + len) - len
            val px   = ((p.x + tilt * fall * 0.3f) % 1.0f) * w
            canvas.drawLine(px, py, px - len * tilt, py + len, paint)
        }
    }

    // -------------------------------------------------------------------------
    // Nieve
    // -------------------------------------------------------------------------

    private fun paintSnow(
        canvas: Canvas, w: Float, h: Float, t: Float,
        particles: List<Particle>, windSpeed: Float,
    ) {
        val tilt  = windTilt(windSpeed)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        for (p in particles) {
            val fall = (t * (0.18f + p.speed * 0.2f) + p.phase) % 1.0f
            val sway = sin((t + p.phase * 6.28f) * 1.5f) * 0.04f
            val py   = fall * (h + 8f) - 8f
            val px   = ((p.x + sway + tilt * fall * 0.2f) % 1.0f) * w
            paint.color = argb(0.65f + p.size * 0.35f, 0xFFFFFF)
            canvas.drawCircle(px, py, 1.4f + p.size * 2.2f, paint)
        }
    }

    // -------------------------------------------------------------------------
    // Viento
    // -------------------------------------------------------------------------

    private fun paintWind(canvas: Canvas, w: Float, h: Float, t: Float) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color      = argb(0.12f, 0xFFFFFF)
            strokeWidth = 2f
            strokeCap  = Paint.Cap.ROUND
            style      = Paint.Style.STROKE
        }
        for (i in 0 until 5) {
            val py   = h * (0.2f + i * 0.16f)
            val trav = (t * 0.6f + i * 0.2f) % 1.3f - 0.15f
            val px   = trav * w
            canvas.drawLine(px, py, px + w * 0.3f, py - 4f, paint)
        }
    }

    // -------------------------------------------------------------------------
    // Relámpago
    // -------------------------------------------------------------------------

    private fun paintLightning(canvas: Canvas, w: Float, h: Float, t: Float) {
        val cycle = t % 4.0f
        if (cycle > 0.18f) return
        val intensity = (1f - cycle / 0.18f).coerceIn(0f, 1f)
        canvas.drawRect(0f, 0f, w, h, Paint().apply {
            color = argb(intensity * 0.35f, 0xFFFFFF)
        })
    }
}
