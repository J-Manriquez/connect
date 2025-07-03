import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/services/vibration_pattern_service.dart';
import 'package:connect/theme_colors.dart';
import 'dart:async';

class CreateVibrationPatternScreen extends StatefulWidget {
  const CreateVibrationPatternScreen({Key? key}) : super(key: key);

  @override
  State<CreateVibrationPatternScreen> createState() =>
      _CreateVibrationPatternScreenState();
}

class _CreateVibrationPatternScreenState
    extends State<CreateVibrationPatternScreen>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final List<int> _recordedPattern = [];
  bool _isRecording = false;
  bool _isPressed = false;
  DateTime? _lastPressTime;
  DateTime? _tapStartTime;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const int maxRecordingDuration = 10000; // 10 segundos
  static const int minTapDuration = 50; // Duración mínima de un toque
  static const int maxTapDuration = 2000; // Duración máxima de un toque

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _recordingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordedPattern.clear();
      _recordingDuration = 0;
    });

    _recordingStartTime = DateTime.now();

    // Timer para actualizar la duración de grabación
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (_recordingStartTime != null) {
        final elapsed = DateTime.now()
            .difference(_recordingStartTime!)
            .inMilliseconds;
        setState(() {
          _recordingDuration = elapsed;
        });

        // Detener automáticamente después del tiempo máximo
        if (elapsed >= maxRecordingDuration) {
          _stopRecording();
        }
      }
    });

    // Iniciar animación de pulso
    _pulseController.repeat(reverse: true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Grabación iniciada. Toca el botón para crear tu patrón.',
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _stopRecording() {
    _recordingTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    setState(() {
      _isRecording = false;
      _isPressed = false;
    });

    if (_recordedPattern.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se grabó ningún patrón. Intenta de nuevo.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Patrón grabado: ${_recordedPattern.length ~/ 2} toques',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _onTapDown() {
    if (!_isRecording) return;

    final now = DateTime.now();

    // Si no es el primer toque, calcular pausa desde el último
    if (_lastPressTime != null) {
      final pauseDuration = now.difference(_lastPressTime!).inMilliseconds;
      _recordedPattern.add(pauseDuration);
    }

    // Marcar el inicio del toque actual
    _tapStartTime = now;

    setState(() {
      _isPressed = true;
    });

    // Vibración de feedback
    HapticFeedback.lightImpact();
    
    // Vibración real para probar el patrón
    VibrationPatternService.testVibration();
  }

  void _onTapUp() {
    if (!_isRecording || !_isPressed || _tapStartTime == null) return;

    final now = DateTime.now();

    // Calcular duración del toque
    final tapDuration = now.difference(_tapStartTime!).inMilliseconds;

    // Validar duración del toque
    final clampedDuration = tapDuration.clamp(minTapDuration, maxTapDuration);
    _recordedPattern.add(clampedDuration);

    // Actualizar el tiempo del último evento
    _lastPressTime = now;
    _tapStartTime = null;

    setState(() {
      _isPressed = false;
    });
  }

  Future<void> _playRecordedPattern() async {
    if (_recordedPattern.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay patrón para reproducir'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final pattern = VibrationPattern(
        id: 'temp',
        name: 'Patrón temporal',
        pattern: _recordedPattern,
        createdAt: DateTime.now(),
        isDefault: false,
      );

      await VibrationPatternService.playPattern(pattern);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reproducir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _savePattern() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa un nombre para el patrón'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_recordedPattern.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor graba un patrón primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final pattern = VibrationPattern(
        id: VibrationPatternService.generatePatternId(),
        name: name,
        pattern: _recordedPattern,
        createdAt: DateTime.now(),
        isDefault: false,
      );

      final success = await VibrationPatternService.savePattern(pattern);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patrón "$name" guardado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Regresar a la pantalla anterior indicando éxito
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar el patrón'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _clearPattern() {
    setState(() {
      _recordedPattern.clear();
      _lastPressTime = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Patrón borrado'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final seconds = milliseconds / 1000;
    return '${seconds.toStringAsFixed(1)}s';
  }

  String _formatPattern() {
    if (_recordedPattern.isEmpty) return 'Sin patrón grabado';

    final segments = <String>[];
    for (int i = 0; i < _recordedPattern.length; i += 2) {
      if (i + 1 < _recordedPattern.length) {
        segments.add('${_recordedPattern[i]}ms/${_recordedPattern[i + 1]}ms');
      }
    }
    return segments.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final progress = _recordingDuration / maxRecordingDuration;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Patrón de Vibración'),
        backgroundColor: customColor[600],
        foregroundColor: Colors.white,
        actions: [
          if (_recordedPattern.isNotEmpty)
            IconButton(
              onPressed: _clearPattern,
              icon: const Icon(Icons.clear),
              tooltip: 'Borrar patrón',
            ),
        ],
      ),
      // añadir scroll
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Instrucciones
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: customColor[600]),
                          const SizedBox(width: 8),
                          const Text(
                            'Instrucciones',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1. Presiona "Iniciar Grabación"\n'
                        '2. Toca el botón circular repetidamente para crear tu patrón\n'
                        '3. Presiona "Detener" cuando termines\n'
                        '4. Ingresa un nombre y guarda tu patrón',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Estado de grabación
              if (_isRecording) ...[
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.fiber_manual_record, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text(
                              'GRABANDO',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDuration(_recordingDuration),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Toques grabados: ${_recordedPattern.length ~/ 2}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Botón de grabación
              Container(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Botón circular principal
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isRecording ? _pulseAnimation.value : 1.0,
                            child: GestureDetector(
                              onTapDown: (_) => _onTapDown(),
                              onTapUp: (_) => _onTapUp(),
                              onTapCancel: () => _onTapUp(),
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isPressed
                                      ? customColor[800]
                                      : _isRecording
                                      ? customColor[600]
                                      : Colors.grey[400],
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isPressed || _isRecording)
                                          ? customColor[600]!.withOpacity(0.3)
                                          : Colors.grey.withOpacity(0.3),
                                      blurRadius: _isPressed ? 20 : 10,
                                      spreadRadius: _isPressed ? 5 : 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isRecording
                                      ? Icons.touch_app
                                      : Icons.vibration,
                                  size: 80,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Texto de estado
                      Text(
                        _isRecording
                            ? 'Toca el botón para crear tu patrón'
                            : 'Presiona "Iniciar" para comenzar',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              // Controles de grabación
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRecording
                          ? _stopRecording
                          : _startRecording,
                      icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        _isRecording ? 'Detener' : 'Iniciar Grabación',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRecording
                            ? Colors.red
                            : customColor[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_recordedPattern.isNotEmpty && !_isRecording) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _playRecordedPattern,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Reproducir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // Información del patrón grabado
              if (_recordedPattern.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Patrón Grabado:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatPattern(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Campo de nombre y botón guardar
              if (_recordedPattern.isNotEmpty && !_isRecording) ...[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre del patrón',
                    hintText: 'Ej: Mi patrón personalizado',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.edit),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _savePattern,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar Patrón'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: customColor[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
