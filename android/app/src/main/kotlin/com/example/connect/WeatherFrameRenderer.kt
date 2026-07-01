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
        val cx = w * 0.80f
        val cy = h * 0.28f
        val pulse = 0.5f + 0.5f * sin(t * 1.2f)

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
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = argb(alpha, 0xFFFFFF) }
        val h = cw * 0.42f
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
            maskFilter = BlurMaskFilter(14f, BlurMaskFilter.Blur.NORMAL)
        }
        for (i in particles.indices) {
            val p    = particles[i]
            val py   = h * (0.2f + i.toFloat() / particles.size * 0.7f)
            val trav = (t * 0.03f * p.speed + p.phase) % 1.4f - 0.2f
            val px   = trav * w
            val bandH = 26f + p.size * 18f
            paint.color = argb(0.10f + p.size * 0.06f, 0xFFFFFF)
            canvas.drawRoundRect(
                RectF(px + w * 0.3f - w * 0.6f, py - bandH / 2f,
                      px + w * 0.3f + w * 0.6f, py + bandH / 2f),
                40f, 40f, paint,
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
