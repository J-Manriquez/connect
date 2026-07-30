import 'dart:math' as math;
import 'package:connect/services/stopwatch_timer_service.dart';
import 'package:connect/services/stopwatch_widget_config_service.dart';
import 'package:flutter/material.dart';

// Preview en vivo que replica visualmente los estilos de RemoteViews.
// Se usa en el editor de widget con datos de ejemplo.

class StopwatchWidgetPreview extends StatelessWidget {
  final StopwatchWidgetConfigSpec spec;
  final StopwatchWidgetCfg cfg;
  final StopwatchSnapshot previewState;

  const StopwatchWidgetPreview({
    super.key,
    required this.spec,
    required this.cfg,
    required this.previewState,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(cfg.cornerRadiusDp.toDouble()),
      child: Container(
        color: Color(cfg.bgArgb),
        child: switch (spec.id) {
          'style1' => _Style1Preview(cfg: cfg, state: previewState),
          'style3' => _Style3Preview(cfg: cfg, state: previewState),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

// ── Helpers compartidos ────────────────────────────────────────────────────────────────

// Formatea tiempo sin milisegundos, igual que el widget real
String _fmtTime(Duration d) {
  final total = d.inSeconds.abs();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  return h > 0
      ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
      : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

Widget _timeText(String time, StopwatchWidgetCfg cfg, {double? sizeSp, TextAlign align = TextAlign.center}) {
  return Text(
    time,
    textAlign: align,
    style: TextStyle(
      color: Color(cfg.timeColor),
      fontSize: (sizeSp ?? cfg.timeSizeSp.toDouble()),
      fontWeight: cfg.timeBold ? FontWeight.bold : FontWeight.normal,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

Widget _modeLabel(String label, StopwatchWidgetCfg cfg) {
  return Text(
    label,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: Color(cfg.modeLabelColor),
      fontSize: cfg.modeLabelSizeSp.toDouble(),
      letterSpacing: 1.5,
    ),
  );
}

Widget _iconBtn(IconData icon, StopwatchWidgetCfg cfg, {double? size}) {
  return Icon(
    icon,
    color: cfg.iconColorEnabled ? Color(cfg.iconColor) : Colors.white,
    size: (size ?? cfg.iconSizeDp.toDouble()),
  );
}

// ── Style 1: Compacto — fila única ───────────────────────────────────────────────────
//  Cronómetro: [flag][reset][play][swap] | tiempo+etiqueta
//  Temporizador: [reset][play][swap] | [−] tiempo+etiqueta [+]

class _Style1Preview extends StatelessWidget {
  final StopwatchWidgetCfg cfg;
  final StopwatchSnapshot state;
  const _Style1Preview({required this.cfg, required this.state});

  @override
  Widget build(BuildContext context) {
    final isTimer  = state.mode == StopwatchMode.timer;
    final duration = isTimer ? state.remaining : state.elapsed;
    final time     = _fmtTime(duration);
    final modeText = isTimer ? cfg.labelTimer : cfg.labelStopwatch;
    final isRunning = state.state == StopwatchStateEnum.running;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Título centrado
          _modeLabel(modeText, cfg),
          const SizedBox(height: 2),
          // Fila: botones izquierda | [−]contador[+] derecha
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Botones izquierda ──
              if (!isTimer) _iconBtn(Icons.flag,       cfg, size: 20),
              _iconBtn(Icons.replay,                   cfg, size: 22),
              _iconBtn(isRunning ? Icons.pause : Icons.play_arrow, cfg, size: 28),
              _iconBtn(Icons.swap_horiz,               cfg, size: 20),
              const Spacer(),
              // ── [−] contador [+] derecha ──
              if (isTimer) _iconBtn(Icons.remove, cfg, size: 18),
              _timeText(time, cfg, sizeSp: 22, align: TextAlign.end),
              if (isTimer) _iconBtn(Icons.add,    cfg, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Style 3: Circular ─────────────────────────────────────────────────────────────────

class _Style3Preview extends StatelessWidget {
  final StopwatchWidgetCfg cfg;
  final StopwatchSnapshot state;
  const _Style3Preview({required this.cfg, required this.state});

  @override
  Widget build(BuildContext context) {
    final isTimer  = state.mode == StopwatchMode.timer;
    final duration = isTimer ? state.remaining : state.elapsed;
    final time     = _fmtTime(duration);
    final modeLabel = isTimer ? cfg.labelTimer : cfg.labelStopwatch;

    final progress = _calcProgress();

    final maxLaps  = cfg.lapCount.clamp(1, 3);
    final lapCount = state.laps.length;
    final visibleLaps = List.generate(
      math.min(maxLaps, lapCount),
      (i) => state.laps[lapCount - 1 - i],
    );

    final isRunning = state.state == StopwatchStateEnum.running;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Fila: [−] anillo+tiempo [+]
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Botón − (solo temporizador)
                if (isTimer)
                  Center(child: _iconBtn(Icons.remove, cfg, size: 22))
                else
                  const SizedBox(width: 22),
                // Anillo con tiempo centrado
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RingPainter(
                            progress: progress,
                            trackColor: Color(cfg.ringTrackArgb),
                            fillColor: Color(cfg.ringFillArgb),
                            thickness: cfg.ringThicknessDp.toDouble(),
                          ),
                        ),
                      ),
                      _timeText(time, cfg, sizeSp: cfg.timeSizeSp * 0.7),
                    ],
                  ),
                ),
                // Botón + (solo temporizador)
                if (isTimer)
                  Center(child: _iconBtn(Icons.add, cfg, size: 22))
                else
                  const SizedBox(width: 22),
              ],
            ),
          ),
          _modeLabel(modeLabel, cfg),
          // Vueltas
          ...visibleLaps.map((lap) => Text(
            _buildLapText(lap, cfg),
            style: TextStyle(
              color: Color(cfg.lapColor),
              fontSize: cfg.lapSizeSp.toDouble(),
              fontWeight: cfg.lapBold ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          )),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Vuelta/flag (solo cronómetro)
              if (!isTimer) ...[
                _iconBtn(Icons.flag, cfg, size: 24),
                const SizedBox(width: 4),
              ],
              _iconBtn(Icons.replay, cfg, size: 26),
              const SizedBox(width: 8),
              _iconBtn(isRunning ? Icons.pause : Icons.play_arrow, cfg, size: 32),
              const SizedBox(width: 8),
              _iconBtn(Icons.swap_horiz, cfg, size: 26),
            ],
          ),
        ],
      ),
    );
  }

  double _calcProgress() {
    if (state.mode == StopwatchMode.timer) {
      final tgt = state.timerTarget.inMilliseconds;
      if (tgt <= 0) return 1.0;
      return (state.remaining.inMilliseconds / tgt).clamp(0.0, 1.0);
    }
    final lapTarget = state.laps.isEmpty ? const Duration(minutes: 1).inMilliseconds
        : (state.laps.last.totalElapsed.inMilliseconds / state.laps.length);
    final currentLap = state.currentLapElapsed.inMilliseconds;
    if (lapTarget <= 0) return 0;
    return ((currentLap / lapTarget) % 1.0).clamp(0.0, 1.0);
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;
  final double thickness;
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - thickness / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    paint.color = trackColor;
    canvas.drawCircle(center, radius, paint);

    paint.color = fillColor;
    canvas.drawArc(rect, -math.pi / 2, progress * 2 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor ||
      old.thickness != thickness;
}

// ── Helper de texto de vuelta ──────────────────────────────────────────────────────────

String _buildLapText(LapEntry lap, StopwatchWidgetCfg cfg) {
  final time = _fmtTime(lap.totalElapsed);
  if (cfg.showLapNumber && cfg.showLapDelta) {
    final dMs  = lap.delta.inMilliseconds;
    final sign = dMs >= 0 ? '+' : '-';
    final deltaStr = _fmtTime(Duration(milliseconds: dMs.abs()));
    return '${cfg.lapPrefix}${lap.number}  $time  $sign$deltaStr';
  } else if (cfg.showLapNumber) {
    return '${cfg.lapPrefix}${lap.number}  $time';
  }
  return time;
}
