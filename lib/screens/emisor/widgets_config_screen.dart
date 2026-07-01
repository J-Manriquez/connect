import 'package:connect/screens/emisor/calculator_widget_editor_screen.dart';
import 'package:connect/screens/emisor/image_widget_editor_screen.dart';
import 'package:connect/screens/emisor/stopwatch_widget_editor_screen.dart';
import 'package:connect/screens/emisor/widget_editor_screen.dart';
import 'package:connect/services/stopwatch_widget_config_service.dart';
import 'package:connect/services/widget_config_service.dart';
import 'package:flutter/material.dart';

/// Lista de widgets de música configurables. Reutilizable desde los ajustes de
/// emisor y de receptor. Escala automáticamente con [WidgetConfigService.widgets].
class WidgetsConfigScreen extends StatelessWidget {
  /// Si es true se omite el [Scaffold]/[AppBar] para incrustarla en una pestaña.
  final bool embedded;

  const WidgetsConfigScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final list = _buildList(context);
    if (embedded) return list;
    return Scaffold(
      appBar: AppBar(title: const Text('Widgets')),
      body: list,
    );
  }

  Widget _buildList(BuildContext context) {
    final widgets = WidgetConfigService.widgets;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text(
            'Personaliza los widgets disponibles en la app y en la pantalla de '
            'inicio. Los cambios se aplican a este dispositivo.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        // Widget de calculadora.
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.calculate)),
            title: const Text('Widget de calculadora'),
            subtitle: const Text(
              'Calculadora básica con paréntesis e historial en la pantalla de inicio.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CalculatorWidgetEditorScreen(),
              ),
            ),
          ),
        ),
        // Widget de clima (dentro de la app, deslizable).
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.wb_cloudy)),
            title: const Text('Widget de clima'),
            subtitle: const Text(
              'Elige una ciudad y consulta el clima actual, por horas y por días.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/weather_settings'),
          ),
        ),
        // Widgets de cronómetro (3 estilos directos).
        ...StopwatchWidgetConfigSpec.widgets.map((spec) => Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.timer_outlined)),
            title: Text('Cronómetro — ${spec.name}'),
            subtitle: Text(spec.description),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StopwatchWidgetEditorScreen(spec: spec),
              ),
            ),
          ),
        )),
        // Widget de imágenes.
        Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.photo_library_outlined)),
            title: const Text('Widget de imágenes'),
            subtitle: const Text(
              'Presentación de fotos personalizada en la pantalla de inicio.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ImageWidgetEditorScreen(),
              ),
            ),
          ),
        ),
        ...widgets.map(
          (spec) => Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.music_note)),
              title: Text(spec.name),
              subtitle: Text(spec.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WidgetEditorScreen(spec: spec),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
