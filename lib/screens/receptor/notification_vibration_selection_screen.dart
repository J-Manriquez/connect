import 'package:flutter/material.dart';
import 'package:connect/services/vibration_pattern_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:connect/models/notification_settings.dart';
import 'package:connect/services/notification_settings_service.dart';

class NotificationVibrationSelectionScreen extends StatefulWidget {
  final NotificationConfigSelection configSelection;
  final Map<String, dynamic> notificationData;

  const NotificationVibrationSelectionScreen({
    Key? key,
    required this.configSelection,
    required this.notificationData,
  }) : super(key: key);

  @override
  State<NotificationVibrationSelectionScreen> createState() =>
      _NotificationVibrationSelectionScreenState();
}

class _NotificationVibrationSelectionScreenState
    extends State<NotificationVibrationSelectionScreen> {
  List<VibrationPattern> _patterns = [];
  VibrationPattern? _selectedPattern;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatterns();
  }

  Future<void> _loadPatterns() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final patterns = await VibrationPatternService.getAllPatterns();
      setState(() {
        _patterns = patterns;
        _isLoading = false;
      });
    } catch (e) {
      // print('Error al cargar patrones: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectPattern(VibrationPattern pattern) async {
    try {
      // Reproducir el patrón al seleccionarlo
      await VibrationPatternService.playPattern(pattern);

      setState(() {
        _selectedPattern = pattern;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Patrón "${pattern.name}" seleccionado'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      // print('Error al seleccionar patrón: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar patrón: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveConfiguration() async {
    if (_selectedPattern == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un patrón de vibración'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Crear la configuración de notificación
      final notificationSettings = NotificationSettings.create(
        notificationData: widget.configSelection.generateNotificationData(),
        additionalData: {
          'vibration': {
            'patternId': _selectedPattern!.id,
            'patternName': _selectedPattern!.name,
            'pattern': _selectedPattern!.pattern,
          },
        },
        vibrationEnabled: true,
        bloqueado: false,
        soundEnabled: false,
      );

      // Guardar en Firebase
      final notificationSettingsService = NotificationSettingsService();
      final success = await notificationSettingsService.saveNotificationSettings(
        notificationSettings,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configuración de vibración guardada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al guardar la configuración'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // print('Error al guardar configuración: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar configuración: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatPattern(List<int> pattern) {
    if (pattern.isEmpty) return 'Sin patrón';

    final segments = <String>[];
    for (int i = 0; i < pattern.length; i += 2) {
      if (i + 1 < pattern.length) {
        segments.add('${pattern[i]}ms/${pattern[i + 1]}ms');
      }
    }
    return segments.join(' • ');
  }

  Widget _buildPatternCard(VibrationPattern pattern) {
    final isSelected = _selectedPattern?.id == pattern.id;

    return Card(
      elevation: isSelected ? 8 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? customColor[600]! : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _selectPattern(pattern),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icono de estado
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? customColor[600] : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? Icons.vibration : Icons.vibration_outlined,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Nombre del patrón
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              pattern.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? customColor[600] : null,
                              ),
                            ),
                            if (pattern.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Predeterminado',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatPattern(pattern.pattern),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Botón de reproducir
                  IconButton(
                    onPressed: () => VibrationPatternService.playPattern(pattern),
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Reproducir patrón',
                    color: customColor[600],
                  ),
                ],
              ),

              if (isSelected) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: customColor[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: customColor[600],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Patrón seleccionado para esta configuración',
                        style: TextStyle(
                          fontSize: 12,
                          color: customColor[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Vibración'),
        backgroundColor: customColor[600],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Información de la configuración
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[600]),
                          const SizedBox(width: 8),
                          const Text(
                            'Configuración de Vibración',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selecciona el patrón de vibración que se aplicará cuando lleguen notificaciones que coincidan con los criterios seleccionados.',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de patrones
                Expanded(
                  child: _patterns.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay patrones disponibles',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _patterns.length,
                          itemBuilder: (context, index) {
                            return _buildPatternCard(_patterns[index]);
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _selectedPattern != null ? _saveConfiguration : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: customColor[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: Text(
            _selectedPattern != null
                ? 'Guardar Configuración'
                : 'Selecciona un patrón',
          ),
        ),
      ),
    );
  }
}