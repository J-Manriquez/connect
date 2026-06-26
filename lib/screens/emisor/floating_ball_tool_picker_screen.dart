import 'package:connect/services/floating_ball_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';

class FloatingBallToolPickerScreen extends StatefulWidget {
  const FloatingBallToolPickerScreen({super.key});

  @override
  State<FloatingBallToolPickerScreen> createState() =>
      _FloatingBallToolPickerScreenState();
}

class _FloatingBallToolPickerScreenState
    extends State<FloatingBallToolPickerScreen> {
  static const List<Map<String, dynamic>> _allTools = [
    {
      'id': 'tool:tts',
      'title': 'Lector TTS',
      'subtitle': 'Lee texto en voz alta línea a línea',
      'icon': Icons.record_voice_over,
    },
    {
      'id': 'tool:dict',
      'title': 'Diccionario',
      'subtitle': 'Busca el significado de palabras',
      'icon': Icons.menu_book,
    },
    {
      'id': 'tool:trans',
      'title': 'Traductor',
      'subtitle': 'Traduce entre español e inglés',
      'icon': Icons.translate,
    },
    {
      'id': 'tool:search',
      'title': 'Buscar',
      'subtitle': 'Busca texto en el navegador predeterminado',
      'icon': Icons.search,
    },
  ];

  bool _loading = true;
  Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tools = await FloatingBallService.getSelectedTools();
    if (!mounted) return;
    setState(() {
      _selected = tools.toSet();
      _loading = false;
    });
  }

  Future<void> _toggle(String toolId, bool checked) async {
    setState(() {
      if (checked) {
        _selected.add(toolId);
      } else {
        _selected.remove(toolId);
      }
    });
    await FloatingBallService.setSelectedTools(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: customColor[700],
        foregroundColor: Colors.white,
        title: const Text(
          'Herramientas del menú',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Selecciona las herramientas que aparecerán en el menú de la bola flotante.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: _allTools.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final tool = _allTools[index];
                      final id = tool['id'] as String;
                      final isChecked = _selected.contains(id);
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          value: isChecked,
                          onChanged: (v) => _toggle(id, v ?? false),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: customColor[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              tool['icon'] as IconData,
                              color: customColor[500],
                              size: 26,
                            ),
                          ),
                          title: Text(
                            tool['title'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            tool['subtitle'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          activeColor: customColor[600],
                          checkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
