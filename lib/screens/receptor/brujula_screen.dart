import 'dart:async';
import 'dart:math' as math;
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import '../../services/sensor_service.dart';

class BrujulaScreen extends StatefulWidget {
  const BrujulaScreen({super.key});

  @override
  State<BrujulaScreen> createState() => _BrujulaScreenState();
}

class _BrujulaScreenState extends State<BrujulaScreen> {
  double _azimuth = 0;
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = SensorService.compassStream.listen((az) {
      if (!mounted) return;
      setState(() => _azimuth = az);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String get _cardinal {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
    return dirs[((_azimuth + 22.5) / 45).floor() % 8];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brújula'),
        backgroundColor: customColor[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug',
            onPressed: () =>
                Navigator.pushNamed(context, '/receptor_salud_debug'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Aguja giratoria
            SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(
                painter: _CompassPainter(azimuth: _azimuth),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _cardinal,
              style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: customColor[700]),
            ),
            const SizedBox(height: 8),
            Text(
              '${_azimuth.toStringAsFixed(1)}°',
              style:
                  const TextStyle(fontSize: 28, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              color: customColor[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Sensor: GeoMagnetic Rotation Vector (AOSP)\n'
                  'Si la aguja tiembla, calibra el sensor haciendo\n'
                  'un movimiento en forma de 8 con el reloj.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double azimuth;
  _CompassPainter({required this.azimuth});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 10;

    // Círculo exterior
    final circlePaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, circlePaint);
    final borderPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), r, borderPaint);

    // Marcas cardinales
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    const cardinals = ['N', 'E', 'S', 'O'];
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2 - math.pi / 2;
      final tx = cx + (r - 20) * math.cos(angle);
      final ty = cy + (r - 20) * math.sin(angle);
      textPainter.text = TextSpan(
        text: cardinals[i],
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: i == 0 ? Colors.red : Colors.black87),
      );
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(tx - textPainter.width / 2, ty - textPainter.height / 2));
    }

    // Aguja (roja = norte, gris = sur)
    final needleAngle = (azimuth - 0) * math.pi / 180 - math.pi / 2;
    // Norte (rojo)
    final northPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + (r - 30) * math.cos(needleAngle),
          cy + (r - 30) * math.sin(needleAngle)),
      northPaint,
    );
    // Sur (gris)
    final southPaint = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + (r - 30) * math.cos(needleAngle + math.pi),
          cy + (r - 30) * math.sin(needleAngle + math.pi)),
      southPaint,
    );
    // Centro
    canvas.drawCircle(Offset(cx, cy), 8,
        Paint()..color = Colors.grey.shade700);
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.azimuth != azimuth;
}
