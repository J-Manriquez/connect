import 'package:connect/screens/emisor/stopwatch_timer_screen.dart';
import 'package:connect/screens/emisor/stopwatch_widget_editor_screen.dart';
import 'package:connect/services/stopwatch_timer_service.dart';
import 'package:connect/services/stopwatch_widget_config_service.dart';
import 'package:connect/widgets/stopwatch_widget_preview.dart';
import 'package:flutter/material.dart';

/// Lista los 3 estilos del widget de cronómetro/temporizador.
/// Acepta [embedded] para incrustar en una pestaña sin Scaffold propio.
class StopwatchWidgetListScreen extends StatefulWidget {
  final bool embedded;
  const StopwatchWidgetListScreen({super.key, this.embedded = false});

  @override
  State<StopwatchWidgetListScreen> createState() => _StopwatchWidgetListScreenState();
}

class _StopwatchWidgetListScreenState extends State<StopwatchWidgetListScreen> {
  // Snapshot de ejemplo para las previews
  final _previewState = StopwatchSnapshot(
    mode: StopwatchMode.stopwatch,
    state: StopwatchStateEnum.paused,
    elapsed: const Duration(minutes: 1, seconds: 23, milliseconds: 456),
    remaining: const Duration(minutes: 3, seconds: 41),
    timerTarget: const Duration(minutes: 5),
    laps: [
      LapEntry(number: 1, totalElapsed: const Duration(seconds: 43, milliseconds: 210), delta: const Duration(seconds: 43, milliseconds: 210)),
      LapEntry(number: 2, totalElapsed: const Duration(minutes: 1, seconds: 23, milliseconds: 456), delta: const Duration(seconds: 40, milliseconds: 246)),
    ],
  );

  final Map<String, StopwatchWidgetCfg> _cfgs = {};

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    for (final spec in StopwatchWidgetConfigSpec.widgets) {
      final cfg = await StopwatchWidgetConfigService.load(spec);
      if (mounted) setState(() => _cfgs[spec.id] = cfg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Widgets de Cronómetro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer_outlined),
            tooltip: 'Abrir cronómetro',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const StopwatchTimerScreen(),
            )),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Añade uno de estos widgets a tu pantalla de inicio. '
          'Toca "Configurar" para personalizar colores, tamaños e iconos.',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ...StopwatchWidgetConfigSpec.widgets.map((spec) {
          final cfg = _cfgs[spec.id];
          return _WidgetCard(
            spec: spec,
            cfg: cfg,
            previewState: _previewState,
            onConfigure: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => StopwatchWidgetEditorScreen(spec: spec),
              ));
              _loadConfigs();
            },
          );
        }),
      ],
    );
  }
}

class _WidgetCard extends StatelessWidget {
  final StopwatchWidgetConfigSpec spec;
  final StopwatchWidgetCfg? cfg;
  final StopwatchSnapshot previewState;
  final VoidCallback onConfigure;

  const _WidgetCard({
    required this.spec,
    required this.cfg,
    required this.previewState,
    required this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(spec.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(spec.description, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Configurar'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF4488FF)),
                  onPressed: onConfigure,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Preview
            if (cfg != null)
              LayoutBuilder(builder: (context, constraints) {
                final availW = constraints.maxWidth;
                final wW = _previewWidgetWidth(spec, availW);
                final wH = _previewWidgetHeight(spec, availW);
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2030),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: wW,
                      height: wH,
                      child: StopwatchWidgetPreview(
                        spec: spec,
                        cfg: cfg!,
                        previewState: previewState,
                      ),
                    ),
                  ),
                );
              })
            else
              const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          ],
        ),
      ),
    );
  }

  double _previewWidgetWidth(StopwatchWidgetConfigSpec spec, double availW) =>
      switch (spec.id) {
        'style1' => availW,
        'style3' => availW * 0.55,
        _ => availW,
      };

  double _previewWidgetHeight(StopwatchWidgetConfigSpec spec, double availW) {
    final w = _previewWidgetWidth(spec, availW);
    return switch (spec.id) {
      'style1' => (w * 0.38).clamp(90, 130),
      'style3' => w.clamp(140, 220),
      _ => w,
    };
  }
}
