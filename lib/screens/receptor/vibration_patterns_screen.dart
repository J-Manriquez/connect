import 'package:flutter/material.dart';
import 'package:connect/services/vibration_pattern_service.dart';
import 'package:connect/theme_colors.dart';
import 'create_vibration_pattern_screen.dart';

class VibrationPatternsScreen extends StatefulWidget {
  const VibrationPatternsScreen({Key? key}) : super(key: key);

  @override
  State<VibrationPatternsScreen> createState() =>
      _VibrationPatternsScreenState();
}

class _VibrationPatternsScreenState extends State<VibrationPatternsScreen> {
  List<VibrationPattern> _patterns = [];
  VibrationPattern? _selectedPattern;
  bool _isLoading = true;
  bool _vibrationEnabled = true;

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
      final selectedPattern =
          await VibrationPatternService.getSelectedPattern();
      final vibrationEnabled =
          await VibrationPatternService.isVibrationEnabled();

      setState(() {
        _patterns = patterns;
        _selectedPattern = selectedPattern;
        _vibrationEnabled = vibrationEnabled;
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar patrones: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectPattern(VibrationPattern pattern) async {
    try {
      // Reproducir el patrón al seleccionarlo
      await VibrationPatternService.playPattern(pattern);

      // Guardar como seleccionado
      final success = await VibrationPatternService.setSelectedPattern(
        pattern.id,
      );

      if (success) {
        setState(() {
          _selectedPattern = pattern;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patrón "${pattern.name}" seleccionado'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error al seleccionar patrón: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar patrón: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePattern(VibrationPattern pattern) async {
    if (pattern.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede eliminar el patrón predeterminado'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Patrón'),
        content: Text(
          '¿Estás seguro de que quieres eliminar "${pattern.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await VibrationPatternService.deletePattern(pattern.id);
      if (success) {
        _loadPatterns(); // Recargar la lista
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patrón "${pattern.name}" eliminado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _toggleVibration(bool enabled) async {
    final success = await VibrationPatternService.setVibrationEnabled(enabled);
    if (success) {
      setState(() {
        _vibrationEnabled = enabled;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'Vibración habilitada' : 'Vibración deshabilitada',
          ),
          backgroundColor: enabled ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _testSimpleVibration() async {
    try {
      // Usar el nuevo método nativo para probar vibración
      await VibrationPatternService.testVibration();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test de vibración ejecutado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error en test de vibración: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en test de vibración: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

                  // Botones de acción
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón de reproducir
                      IconButton(
                        onPressed: () =>
                            VibrationPatternService.playPattern(pattern),
                        icon: const Icon(Icons.play_arrow),
                        tooltip: 'Reproducir patrón',
                        color: customColor[600],
                      ),

                      // Botón de eliminar (solo para patrones personalizados)
                      if (!pattern.isDefault)
                        IconButton(
                          onPressed: () => _deletePattern(pattern),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Eliminar patrón',
                          color: Colors.red[600],
                        ),
                    ],
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
                        'Patrón activo para notificaciones',
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
        title: const Text('Patrones de Vibración'),
        backgroundColor: customColor[600],
        foregroundColor: Colors.white,
        actions: [
          // Switch para habilitar/deshabilitar vibración
          // Padding(
          //   padding: const EdgeInsets.only(right: 8),
          //   child: Row(
          //     mainAxisSize: MainAxisSize.min,
          //     children: [
          //       Icon(
          //         _vibrationEnabled
          //             ? Icons.vibration
          //             : Icons.vibration_outlined,
          //         color: Colors.white,
          //         size: 20,
          //       ),
          //       Switch(
          //         value: _vibrationEnabled,
          //         onChanged: _toggleVibration,
          //         activeColor: Colors.white,
          //         activeTrackColor: Colors.white.withOpacity(0.3),
          //       ),
          //     ],
          //   ),
          // ),
        
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          // añadir scroll
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Botón de prueba de vibración simple
                  // Container(
                  //   width: double.infinity,
                  //   padding: const EdgeInsets.all(16),
                  //   margin: const EdgeInsets.all(16),
                  //   child: ElevatedButton.icon(
                  //     onPressed: _testSimpleVibration,
                  //     icon: const Icon(Icons.vibration),
                  //     label: const Text('Probar Vibración Simple'),
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: customColor[600],
                  //       foregroundColor: Colors.white,
                  //       padding: const EdgeInsets.symmetric(vertical: 12),
                  //     ),
                  //   ),
                  // ),

                  // Información sobre vibración
                  // Container(
                  //   width: double.infinity,
                  //   padding: const EdgeInsets.all(16),
                  //   margin: const EdgeInsets.all(16),
                  //   decoration: BoxDecoration(
                  //     color: _vibrationEnabled
                  //         ? Colors.green[50]
                  //         : Colors.orange[50],
                  //     borderRadius: BorderRadius.circular(12),
                  //     border: Border.all(
                  //       color: _vibrationEnabled
                  //           ? Colors.green[200]!
                  //           : Colors.orange[200]!,
                  //     ),
                  //   ),
                  //   child: Row(
                  //     children: [
                  //       Icon(
                  //         _vibrationEnabled ? Icons.info : Icons.warning,
                  //         color: _vibrationEnabled
                  //             ? Colors.green[600]
                  //             : Colors.orange[600],
                  //       ),
                  //       const SizedBox(width: 12),
                  //       Expanded(
                  //         child: Text(
                  //           _vibrationEnabled
                  //               ? 'La vibración está habilitada. Toca un patrón para seleccionarlo y reproducirlo.'
                  //               : 'La vibración está deshabilitada. Actívala para usar patrones personalizados.',
                  //           style: TextStyle(
                  //             color: _vibrationEnabled
                  //                 ? Colors.green[800]
                  //                 : Colors.orange[800],
                  //             fontWeight: FontWeight.w500,
                  //           ),
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),

                  // Lista de patrones
                  Container(
                    height: 400,
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
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateVibrationPatternScreen(),
            ),
          );

          // Recargar patrones si se creó uno nuevo
          if (result == true) {
            _loadPatterns();
          }
        },
        backgroundColor: customColor[600],
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
