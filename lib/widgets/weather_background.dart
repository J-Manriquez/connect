import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:connect/models/weather_models.dart';

/// Fondo animado del widget de clima. Imita la condición meteorológica con
/// efectos sutiles, distintos de día y de noche:
///   - clear  : sol con destellos (día) / luna + estrellas (noche).
///   - clouds : nubes a la deriva.
///   - fog    : capas de niebla desplazándose.
///   - rain   : gotas cayendo (inclinadas según el viento).
///   - snow   : copos cayendo.
///   - thunder: lluvia + destellos de relámpago.
/// El [windSpeed] (km/h) inclina la lluvia y acelera nubes/ráfagas.
class WeatherBackground extends StatefulWidget {
  final int weatherCode;
  final bool isDay;
  final double windSpeed;

  /// 0-100: mezcla el degradado base hacia negro (personalización del usuario).
  final int darkenPct;

  /// Si se provee, congela la animación en este valor de tiempo (segundos
  /// virtuales) y detiene el controlador interno. Útil para el modo test del
  /// editor, que pausa externamente y avanza frame a frame.
  final double? overrideT;

  const WeatherBackground({
    super.key,
    required this.weatherCode,
    required this.isDay,
    this.windSpeed = 0,
    this.darkenPct = 0,
    this.overrideT,
  });

  @override
  State<WeatherBackground> createState() => _WeatherBackgroundState();
}

class _WeatherBackgroundState extends State<WeatherBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  final math.Random _rng = math.Random(7);

  @override
  void initState() {
    super.initState();
    // Controlador "monótono": value avanza ~1 por segundo (segundos virtuales),
    // así las partículas se mueven de forma continua sin saltos de ciclo.
    _controller = AnimationController.unbounded(vsync: this)
      ..repeat(min: 0, max: 1000, period: const Duration(seconds: 1000));
    _particles = _buildParticles();
  }

  @override
  void didUpdateWidget(covariant WeatherBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weatherCode != widget.weatherCode ||
        oldWidget.isDay != widget.isDay) {
      _particles
        ..clear()
        ..addAll(_buildParticles());
    }
    // Detener/reanudar el controller según si hay override externo.
    if (widget.overrideT != null && oldWidget.overrideT == null) {
      _controller.stop();
    } else if (widget.overrideT == null && oldWidget.overrideT != null) {
      _controller.repeat(min: 0, max: 1000, period: const Duration(seconds: 1000));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Particle> _buildParticles() {
    final cat = WeatherCodeInfo.category(widget.weatherCode);
    final list = <_Particle>[];
    int count;
    switch (cat) {
      case 'rain':
      case 'thunder':
        count = 70;
        break;
      case 'snow':
        count = 45;
        break;
      case 'clouds':
        count = 5;
        break;
      case 'fog':
        count = 4;
        break;
      case 'clear':
        count = widget.isDay ? 0 : 36; // estrellas de noche
        break;
      default:
        count = 0;
    }
    for (var i = 0; i < count; i++) {
      list.add(_Particle(
        x: _rng.nextDouble(),
        phase: _rng.nextDouble(),
        speed: 0.4 + _rng.nextDouble() * 0.8,
        size: _rng.nextDouble(),
      ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        WeatherCodeInfo.gradientColors(widget.weatherCode, isDay: widget.isDay);
    final category = WeatherCodeInfo.category(widget.weatherCode);

    // Modo override: frame estático en t dado (modo test del editor).
    if (widget.overrideT != null) {
      return CustomPaint(
        painter: _WeatherPainter(
          t: widget.overrideT!,
          category: category,
          isDay: widget.isDay,
          windSpeed: widget.windSpeed,
          colors: colors,
          particles: _particles,
          darkenPct: widget.darkenPct,
        ),
        size: Size.infinite,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _WeatherPainter(
            t: _controller.value,
            category: category,
            isDay: widget.isDay,
            windSpeed: widget.windSpeed,
            colors: colors,
            particles: _particles,
            darkenPct: widget.darkenPct,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  final double x; // posición horizontal base (0..1)
  final double phase; // desfase temporal (0..1)
  final double speed; // factor de velocidad
  final double size; // factor de tamaño (0..1)
  _Particle({
    required this.x,
    required this.phase,
    required this.speed,
    required this.size,
  });
}

class _WeatherPainter extends CustomPainter {
  final double t; // segundos virtuales monótonos
  final String category;
  final bool isDay;
  final double windSpeed;
  final List<Color> colors;
  final List<_Particle> particles;

  final int darkenPct;

  _WeatherPainter({
    required this.t,
    required this.category,
    required this.isDay,
    required this.windSpeed,
    required this.colors,
    required this.particles,
    this.darkenPct = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Degradado base.
    final grad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(colors[0], Colors.black, 0.05)!,
        Color.lerp(colors[1], Colors.black, 0.25)!,
      ],
    );
    canvas.drawRect(rect, Paint()..shader = grad.createShader(rect));

    switch (category) {
      case 'clear':
        if (isDay) {
          _paintSun(canvas, size);
        } else {
          _paintMoon(canvas, size);
          _paintStars(canvas, size);
        }
        break;
      case 'clouds':
        if (!isDay) _paintStars(canvas, size, dim: true);
        _paintClouds(canvas, size);
        break;
      case 'fog':
        _paintFog(canvas, size);
        break;
      case 'rain':
        _paintClouds(canvas, size, alpha: 0.18);
        _paintRain(canvas, size);
        break;
      case 'snow':
        _paintClouds(canvas, size, alpha: 0.16);
        _paintSnow(canvas, size);
        break;
      case 'thunder':
        _paintClouds(canvas, size, alpha: 0.22);
        _paintRain(canvas, size);
        _paintLightning(canvas, size);
        break;
    }

    // Ráfagas de viento sutiles cuando hay viento fuerte.
    if (windSpeed >= 20 && category != 'rain' && category != 'thunder') {
      _paintWind(canvas, size);
    }

    // Oscurecido configurable por el usuario (mejora contraste del texto).
    if (darkenPct > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.black.withValues(alpha: darkenPct.clamp(0, 100) / 100.0),
      );
    }
  }

  double get _windTilt => (windSpeed.clamp(0, 60) / 60.0) * 0.6;

  void _paintSun(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.20, size.height * 0.28); // sol a la izquierda
    final pulse = 0.5 + 0.5 * math.sin(t * 1.2);
    // Rayos de barrido horizontal (de izquierda a derecha).
    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    for (var i = 0; i < 4; i++) {
      final angle = -0.30 + i * 0.20;
      final phase = i * 0.28;
      final travel = (t * 0.10 + phase) % 1.0;
      final alpha = (0.10 * math.sin(travel * math.pi)).clamp(0.0, 1.0);
      if (alpha < 0.01) continue;
      sweep.color = const Color(0xFFFFE08A).withValues(alpha: alpha);
      final len = size.width * 1.3;
      canvas.drawLine(
        center + Offset(28, 0),
        center + Offset(28 + len * math.cos(angle), len * math.sin(angle)),
        sweep,
      );
    }
    // Halo.
    canvas.drawCircle(
      center,
      46 + pulse * 6,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFFFE08A).withValues(alpha: 0.55),
          const Color(0xFFFFE08A).withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: center, radius: 60)),
    );
    // Disco.
    canvas.drawCircle(
        center, 22, Paint()..color = const Color(0xFFFFE9A8));
    // Rayos giratorios.
    final ray = Paint()
      ..color = const Color(0xFFFFE08A).withValues(alpha: 0.35)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = t * 0.3 + i * (math.pi * 2 / 12);
      final r1 = 28.0;
      final r2 = 38.0 + pulse * 4;
      canvas.drawLine(
        center + Offset(math.cos(a) * r1, math.sin(a) * r1),
        center + Offset(math.cos(a) * r2, math.sin(a) * r2),
        ray,
      );
    }
  }

  void _paintMoon(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.80, size.height * 0.28);
    canvas.drawCircle(
      center,
      40,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: 0.30),
          Colors.white.withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: center, radius: 52)),
    );
    canvas.drawCircle(center, 20, Paint()..color = const Color(0xFFEDEFF5));
    // Recorte para dar forma de luna creciente.
    canvas.drawCircle(
      center.translate(10, -6),
      18,
      Paint()..color = Color.lerp(colors[0], Colors.black, 0.05)!,
    );
  }

  void _paintStars(Canvas canvas, Size size, {bool dim = false}) {
    final paint = Paint()..color = Colors.white;
    for (final p in particles) {
      final twinkle = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 2 + p.phase * 6.28));
      paint.color = Colors.white
          .withValues(alpha: (dim ? 0.4 : 0.9) * twinkle * (0.4 + p.size * 0.6));
      final pos = Offset(p.x * size.width, p.phase * size.height * 0.7);
      canvas.drawCircle(pos, 0.6 + p.size * 1.4, paint);
    }
  }

  void _paintClouds(Canvas canvas, Size size, {double alpha = 0.30}) {
    final speedBoost = 1 + windSpeed.clamp(0, 50) / 50.0;
    for (var i = 0; i < particles.length; i++) {
      final p = particles[i];
      final w = size.width * (0.5 + p.size * 0.5);
      final y = size.height * (0.15 + p.x * 0.5);
      final travel = (t * 0.02 * p.speed * speedBoost + p.phase) % 1.3 - 0.15;
      final x = travel * size.width;
      _drawCloud(canvas, Offset(x, y), w * 0.6, alpha * (0.6 + p.size * 0.4));
    }
  }

  void _drawCloud(Canvas canvas, Offset c, double w, double alpha) {
    final h = w * 0.42;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, (h * 0.38).clamp(4, 60));
    canvas.drawCircle(c, h * 0.6, paint);
    canvas.drawCircle(c + Offset(w * 0.28, h * 0.08), h * 0.5, paint);
    canvas.drawCircle(c + Offset(-w * 0.28, h * 0.1), h * 0.45, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: c + Offset(0, h * 0.32), width: w, height: h * 0.6),
        Radius.circular(h),
      ),
      paint,
    );
  }

  void _paintFog(Canvas canvas, Size size) {
    for (var i = 0; i < particles.length; i++) {
      final p = particles[i];
      final y = size.height * (0.15 + i / particles.length * 0.75);
      final bandH = 32 + p.size * 24;
      // Capa primaria.
      final trav1 = (t * 0.025 * p.speed + p.phase) % 1.5 - 0.25;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            trav1 * size.width - size.width * 0.25, y - bandH / 2,
            trav1 * size.width + size.width * 0.95, y + bandH / 2,
          ),
          const Radius.circular(50),
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12 + p.size * 0.07)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );
      // Capa secundaria (fase opuesta, más lenta).
      final trav2 = (t * 0.018 * p.speed + p.phase + 0.65) % 1.5 - 0.25;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            trav2 * size.width - size.width * 0.25, y - bandH * 0.55,
            trav2 * size.width + size.width * 0.95, y + bandH * 0.55,
          ),
          const Radius.circular(50),
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.07 + p.size * 0.04)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    final tilt = _windTilt;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final p in particles) {
      final len = 10 + p.size * 10;
      final fall = (t * (0.9 + p.speed) + p.phase) % 1.0;
      final y = fall * (size.height + len) - len;
      final x = (p.x + tilt * fall * 0.3) % 1.0 * size.width;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - len * tilt, y + len),
        paint,
      );
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    final tilt = _windTilt;
    final paint = Paint()..color = Colors.white;
    for (final p in particles) {
      final fall = (t * (0.18 + p.speed * 0.2) + p.phase) % 1.0;
      final sway = math.sin((t + p.phase * 6.28) * 1.5) * 0.04;
      final y = fall * (size.height + 8) - 8;
      final x = ((p.x + sway + tilt * fall * 0.2) % 1.0) * size.width;
      paint.color = Colors.white.withValues(alpha: 0.65 + p.size * 0.35);
      canvas.drawCircle(Offset(x, y), 1.4 + p.size * 2.2, paint);
    }
  }

  void _paintWind(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.2 + i * 0.16);
      final travel = (t * 0.6 + i * 0.2) % 1.3 - 0.15;
      final x = travel * size.width;
      final w = size.width * 0.3;
      canvas.drawLine(Offset(x, y), Offset(x + w, y - 4), paint);
    }
  }

  void _paintLightning(Canvas canvas, Size size) {
    // Destello breve cada ~4 s.
    final cycle = t % 4.0;
    if (cycle > 0.18) return;
    final intensity = (1 - cycle / 0.18).clamp(0.0, 1.0);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: 0.35 * intensity),
    );
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter old) =>
      old.t != t ||
      old.category != category ||
      old.isDay != isDay ||
      old.windSpeed != windSpeed ||
      old.darkenPct != darkenPct;
}
