import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connect/services/vibration_pattern_service.dart';
import 'package:connect/theme_colors.dart';
import 'dart:async';
import 'dart:ui'; // <<< CORRECCIÓN: Importación añadida para FontVariant.

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

  DateTime? _pressStartTime;
  DateTime? _lastEventTime;

  Timer? _recordingTimer;
  Timer? _continuousVibrationTimer;
  int _recordingDuration = 0; // en milisegundos
  bool _isPressed = false;

  static const int maxRecordingDuration = 10000; // 10 segundos
  static const int minTapDuration = 50; // ms
  static const int maxTapDuration = 2000; // ms

  @override
  void dispose() {
    _nameController.dispose();
    _recordingTimer?.cancel();
    _continuousVibrationTimer?.cancel();
    super.dispose();
  }

  /// Inicia el proceso de grabación del patrón.
  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordedPattern.clear();
      _recordingDuration = 0;
      // La primera pausa comienza desde este momento.
      _lastEventTime = DateTime.now();
    });

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      // Calcula la duración total hasta ahora.
      final elapsed = _calculateTotalDuration();
      
      setState(() {
        _recordingDuration = elapsed;
      });

      if (elapsed >= maxRecordingDuration) {
        _stopRecording();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Grabación iniciada. Mantén pulsado el botón.'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Calcula la duración total del patrón que se está grabando.
  int _calculateTotalDuration() {
      int patternDuration = _recordedPattern.isEmpty ? 0 : _recordedPattern.reduce((a, b) => a + b);
      if (_pressStartTime != null) {
          // Si se está presionando, añade el tiempo actual de la pulsación
          patternDuration += DateTime.now().difference(_pressStartTime!).inMilliseconds;
      } else if (_isRecording && _lastEventTime != null) {
          // Si no, añade el tiempo de la pausa actual
          patternDuration += DateTime.now().difference(_lastEventTime!).inMilliseconds;
      }
      return patternDuration;
  }

  /// Detiene la grabación.
  void _stopRecording() {
    // Si el botón todavía está presionado, finaliza el último toque.
    if (_pressStartTime != null) {
      _onTapUp(isStopping: true);
    }
    
    _recordingTimer?.cancel();

    setState(() {
      _isRecording = false;
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
          content: Text('Patrón grabado con ${_recordedPattern.length ~/ 2} toques.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Se ejecuta cuando el usuario presiona el botón.
  void _onTapDown() {
    // El primer toque en la pantalla inicia la grabación.
    if (!_isRecording) {
      _startRecording();
      return;
    }
    
    if (_pressStartTime != null) return;

    final now = DateTime.now();
    _pressStartTime = now;
    
    // La duración entre el último evento y este toque es la pausa.
    if (_lastEventTime != null) {
      final pauseDuration = now.difference(_lastEventTime!).inMilliseconds;
      _recordedPattern.add(pauseDuration);
    }
    
    // Vibración inicial inmediata
    HapticFeedback.lightImpact();
    _startContinuousVibration();

    setState(() {
      _isPressed = true;
    });
  }

  /// Se ejecuta cuando el usuario suelta el botón.
  void _onTapUp({bool isStopping = false}) {
    if (!_isRecording || _pressStartTime == null) return;
    
    final now = DateTime.now();
    final tapDuration = now.difference(_pressStartTime!).inMilliseconds;
    
    // Detener vibración continua
    _stopContinuousVibration();
    
    // Limita la duración a valores válidos.
    final clampedDuration = tapDuration.clamp(minTapDuration, maxTapDuration);
    _recordedPattern.add(clampedDuration as int);

    _lastEventTime = now;
    _pressStartTime = null;
    
    if (!isStopping) {
        setState(() {
          _isPressed = false;
        });
    }
  }
  
  Future<void> _playRecordedPattern() async {
    if (_recordedPattern.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay un patrón válido para reproducir.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Mostrar feedback visual durante la reproducción
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reproduciendo patrón...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
      
      final pattern = VibrationPattern(
        id: 'temp_play',
        name: 'Patrón Temporal',
        pattern: _recordedPattern,
        createdAt: DateTime.now(),
        isDefault: false,
      );
      
      // Reproducir el patrón usando el servicio optimizado
      await VibrationPatternService.playPattern(pattern);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reproducir el patrón: $e'),
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
          content: Text('Por favor, ingresa un nombre para el patrón.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_recordedPattern.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, graba un patrón válido primero.'),
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
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patrón "$name" guardado exitosamente.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar. El patrón podría ya existir.'),
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
      _lastEventTime = null;
      _recordingDuration = 0;
      if (_isRecording) {
        _recordingTimer?.cancel();
        _isRecording = false;
        _pressStartTime = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Patrón borrado.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final seconds = milliseconds / 1000;
    return '${seconds.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPattern = _recordedPattern.isNotEmpty;
    final bool isFinished = hasPattern && !_isRecording;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Patrón de Vibración'),
        backgroundColor: customColor[600],
        foregroundColor: Colors.white,
        actions: [
          if (hasPattern)
            IconButton(
              onPressed: _clearPattern,
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Borrar Patrón',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRecordingStatus(),
            const SizedBox(height: 24),
            _buildInteractionButton(),
            const SizedBox(height: 24),
            if (isFinished) ...[
              _buildFinishedControls(),
              const SizedBox(height: 24),
            ],
            _buildInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingStatus() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, axisAlignment: -1.0, child: child));
      },
      child: Card(
              key: const ValueKey('recording_status'),
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fiber_manual_record, color: Colors.red),
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
                          '${_formatDuration(_recordingDuration)} / ${_formatDuration(maxRecordingDuration)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_recordingDuration / maxRecordingDuration).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toques grabados: ${_recordedPattern.length ~/ 2}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          // : const SizedBox(key: ValueKey('not_recording')),
    );
  }

  /// Inicia la vibración continua mientras se mantiene presionado.
  void _startContinuousVibration() {
    _continuousVibrationTimer?.cancel();
    _continuousVibrationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_pressStartTime == null || !_isRecording) {
        timer.cancel();
        return;
      }
      HapticFeedback.lightImpact();
    });
  }

  /// Detiene la vibración continua.
  void _stopContinuousVibration() {
    _continuousVibrationTimer?.cancel();
  }

  Widget _buildInteractionButton() {
    final isPressed = _isPressed;
    final buttonColor = isPressed ? Colors.red[600]! : customColor[600]!;
    final shadowColor = isPressed ? Colors.red.withOpacity(0.4) : customColor[600]!.withOpacity(0.4);
    
    return Column(
      children: [
        GestureDetector(
          onTapDown: (_) => _onTapDown(),
          onTapUp: (_) => _onTapUp(),
          onTapCancel: () => _onTapUp(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: buttonColor,
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: isPressed ? 20 : 10,
                  spreadRadius: isPressed ? 5 : 2,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isRecording ? Icons.touch_app : Icons.vibration,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRecording 
                        ? (isPressed ? "Vibrando" : "Mantén presionado") 
                        : "Iniciar Grabación",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  )
                ],
              ),
            ),
          ),
        ),
        if (_isRecording) ...[
            const SizedBox(height: 24),
            SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('Detener'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                ),
            )
        ]
      ],
    );
  }

  Widget _buildFinishedControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Patrón Listo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _playRecordedPattern,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Probar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nombre del Patrón',
                hintText: 'Ej: Mi patrón personalizado',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.edit),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
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
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: customColor[600]),
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
              '1. Toca el botón azul para iniciar la grabación.\n'
              '2. Mantén presionado el botón (rojo) para crear vibraciones.\n'
              '3. Suelta el botón para crear pausas.\n'
              '4. Presiona "Detener" cuando termines.\n'
              '5. Dale un nombre a tu patrón y guárdalo.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}