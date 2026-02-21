import 'package:flutter/material.dart';
import 'package:connect/services/custom_sound_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:connect/models/notification_settings.dart';
import 'package:connect/services/notification_settings_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class NotificationSoundSelectionScreen extends StatefulWidget {
  final NotificationConfigSelection configSelection;
  final Map<String, dynamic> notificationData;

  const NotificationSoundSelectionScreen({
    Key? key,
    required this.configSelection,
    required this.notificationData,
  }) : super(key: key);

  @override
  State<NotificationSoundSelectionScreen> createState() =>
      _NotificationSoundSelectionScreenState();
}

class _NotificationSoundSelectionScreenState
    extends State<NotificationSoundSelectionScreen> {
  List<CustomSound> _sounds = [];
  CustomSound? _selectedSound;
  bool _isLoading = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSounds() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sounds = await CustomSoundService.getAllSounds();
      setState(() {
        _sounds = sounds;
        _isLoading = false;
      });
    } catch (e) {
      // print('Error al cargar sonidos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectSound(CustomSound sound) async {
    setState(() {
      _selectedSound = sound;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sonido "${sound.name}" seleccionado'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _playSound(CustomSound sound) async {
    try {
      // Detener cualquier sonido que esté reproduciéndose
      await _audioPlayer.stop();

      setState(() {
        _currentlyPlayingId = sound.id;
      });

      // Reproducir el sonido
      await _audioPlayer.play(DeviceFileSource(sound.filePath));

      // Escuchar cuando termine la reproducción
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _currentlyPlayingId = null;
          });
        }
      });
    } catch (e) {
      // print('Error al reproducir sonido: $e');
      setState(() {
        _currentlyPlayingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reproducir sonido: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopSound() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _currentlyPlayingId = null;
      });
    } catch (e) {
      // print('Error al detener sonido: $e');
    }
  }

  Future<void> _addNewSound() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        // Mostrar diálogo para el nombre del sonido
        final soundName = await _showNameDialog(fileName);
        if (soundName == null || soundName.trim().isEmpty) return;

        // Guardar el sonido
        final success = await CustomSoundService.addSound(
          soundName.trim(),
          file.path,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sonido agregado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          _loadSounds(); // Recargar la lista
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al agregar el sonido'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // print('Error al agregar sonido: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al agregar sonido: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _showNameDialog(String defaultName) async {
    final controller = TextEditingController(text: defaultName.split('.').first);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nombre del Sonido'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveConfiguration() async {
    if (_selectedSound == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un sonido'),
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
          'sound': {
            'soundId': _selectedSound!.id,
            'soundName': _selectedSound!.name,
            'filePath': _selectedSound!.filePath,
          },
        },
        vibrationEnabled: false,
        bloqueado: false,
        soundEnabled: true,
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
              content: Text('Configuración de sonido guardada exitosamente'),
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

  Widget _buildSoundCard(CustomSound sound) {
    final isSelected = _selectedSound?.id == sound.id;
    final isPlaying = _currentlyPlayingId == sound.id;

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
        onTap: () => _selectSound(sound),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icono del sonido
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? customColor[600] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  isSelected ? Icons.music_note : Icons.music_note_outlined,
                  color: isSelected ? Colors.white : Colors.grey[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Información del sonido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sound.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? customColor[600] : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sound.fileName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'SELECCIONADO',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Botones de acción
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón de reproducir/detener
                  IconButton(
                    onPressed: isPlaying ? _stopSound : () => _playSound(sound),
                    icon: Icon(
                      isPlaying ? Icons.stop : Icons.play_arrow,
                      color: customColor[600],
                    ),
                    tooltip: isPlaying ? 'Detener' : 'Reproducir',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note, color: customColor[600], size: 64),
          const SizedBox(height: 16),
          const Text(
            'No hay sonidos personalizados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega archivos de audio para personalizar\nel sonido de tus notificaciones',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addNewSound,
            icon: const Icon(Icons.add),
            label: const Text('Agregar Sonido'),
            style: ElevatedButton.styleFrom(
              backgroundColor: customColor[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Sonido'),
        backgroundColor: customColor[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _addNewSound,
            icon: const Icon(Icons.add),
            tooltip: 'Agregar sonido',
          ),
        ],
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
                            'Configuración de Sonido',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selecciona el sonido personalizado que se aplicará cuando lleguen notificaciones que coincidan con los criterios seleccionados.',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de sonidos
                Expanded(
                  child: _sounds.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: _sounds.length,
                          itemBuilder: (context, index) {
                            return _buildSoundCard(_sounds[index]);
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _sounds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _selectedSound != null ? _saveConfiguration : null,
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
                  _selectedSound != null
                      ? 'Guardar Configuración'
                      : 'Selecciona un sonido',
                ),
              ),
            )
          : null,
    );
  }
}