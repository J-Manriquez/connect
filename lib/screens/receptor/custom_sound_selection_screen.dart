import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:connect/services/custom_sound_service.dart';
import 'package:connect/theme_colors.dart';
import 'dart:io';

class CustomSoundSelectionScreen extends StatefulWidget {
  const CustomSoundSelectionScreen({Key? key}) : super(key: key);

  @override
  State<CustomSoundSelectionScreen> createState() =>
      _CustomSoundSelectionScreenState();
}

class _CustomSoundSelectionScreenState
    extends State<CustomSoundSelectionScreen> {
  List<CustomSound> _sounds = [];
  CustomSound? _selectedSound;
  bool _isLoading = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadSounds();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _currentlyPlayingId = null;
          _isPlaying = false;
        }
      });
    });
  }

  Future<void> _loadSounds() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sounds = await CustomSoundService.getAllSounds();
      final selectedSound = await CustomSoundService.getSelectedSound();

      setState(() {
        _sounds = sounds;
        _selectedSound = selectedSound;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar sonidos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addCustomSound() async {
    try {
      // Verificar permisos de almacenamiento
      final hasPermission = await CustomSoundService.checkStoragePermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Se requieren permisos de almacenamiento para seleccionar archivos'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Mostrar selector de archivos
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
        dialogTitle: 'Seleccionar archivos de audio',
      );

      if (result != null && result.files.isNotEmpty) {
        int addedCount = 0;
        
        for (final file in result.files) {
          if (file.path != null) {
            // Obtener información del archivo
            final fileInfo = await CustomSoundService.getAudioFileInfo(file.path!);
            if (fileInfo != null) {
              // Crear el sonido personalizado
              final customSound = CustomSound(
                id: CustomSoundService.generateSoundId(),
                name: fileInfo['name'].toString().replaceAll(RegExp(r'\.[^.]*$'), ''), // Remover extensión
                filePath: file.path!,
                createdAt: DateTime.now(),
                duration: 0, // Se podría calcular la duración real si es necesario
              );

              // Guardar el sonido
              final success = await CustomSoundService.saveSound(customSound);
              if (success) {
                addedCount++;
              }
            }
          }
        }

        if (addedCount > 0) {
          await _loadSounds(); // Recargar la lista
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$addedCount sonido(s) agregado(s) exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudieron agregar los archivos seleccionados'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agregar sonidos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _playSound(CustomSound sound) async {
    try {
      // Detener cualquier sonido que esté reproduciéndose
      await _audioPlayer.stop();

      setState(() {
        _currentlyPlayingId = sound.id;
      });

      if (sound.isDefault) {
        // Reproducir sonido del sistema usando el servicio
        await CustomSoundService.playSound(sound);
        // Para el sonido del sistema, simular que terminó después de 1 segundo
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _currentlyPlayingId = null;
              _isPlaying = false;
            });
          }
        });
      } else {
        // Reproducir archivo personalizado
        await _audioPlayer.play(DeviceFileSource(sound.filePath));
      }
    } catch (e) {
      setState(() {
        _currentlyPlayingId = null;
        _isPlaying = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reproducir sonido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopSound() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _currentlyPlayingId = null;
        _isPlaying = false;
      });
    } catch (e) {
      print('Error al detener sonido: $e');
    }
  }

  Future<void> _selectSound(CustomSound sound) async {
    try {
      final success = await CustomSoundService.setSelectedSound(sound.id);
      if (success) {
        setState(() {
          _selectedSound = sound;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${sound.name}" seleccionado como sonido predeterminado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar sonido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSound(CustomSound sound) async {
    if (sound.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede eliminar el sonido predeterminado'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Sonido'),
        content: Text('¿Estás seguro de que quieres eliminar "${sound.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await CustomSoundService.deleteSound(sound.id);
        if (success) {
          await _loadSounds(); // Recargar la lista
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"${sound.name}" eliminado exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar sonido: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sonidos Personalizados'),
        backgroundColor: customColor[600],
        foregroundColor: Colors.white,
        actions: [
          if (_sounds.length > 1) // Solo mostrar si hay sonidos personalizados
            IconButton(
              onPressed: () => _showClearAllDialog(),
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Limpiar todos los sonidos',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  _sounds.isEmpty
                      ? _buildEmptyState()
                      : _buildSoundsList(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCustomSound,
        backgroundColor: customColor[600],
        foregroundColor: Colors.white,
        tooltip: 'Agregar sonidos',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.music_note, color: customColor[600], size: 28),
          const SizedBox(height: 12),
          Text(
            'Personaliza el sonido de tus notificaciones agregando archivos de audio desde tu dispositivo.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (_selectedSound != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Actual: ${_selectedSound!.name}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay sonidos personalizados',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca el botón + para agregar archivos de audio',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundsList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: _sounds.map((sound) {
          final isSelected = _selectedSound?.id == sound.id;
          final isPlaying = _currentlyPlayingId == sound.id && _isPlaying;

          return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isSelected ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? customColor[600]! : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _selectSound(sound),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Icono del sonido
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? customColor[600]
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      sound.isDefault ? Icons.volume_up : Icons.music_note,
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
                            color: isSelected ? customColor[600] : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (sound.isDefault)
                          Text(
                            'Sonido del sistema',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          )
                        else
                          FutureBuilder<Map<String, dynamic>?>(
                            future: CustomSoundService.getAudioFileInfo(sound.filePath),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                final info = snapshot.data!;
                                return Text(
                                  '${info['extension'].toString().toUpperCase()} • ${_formatFileSize(info['size'])}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                );
                              }
                              return Text(
                                'Archivo personalizado',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              );
                            },
                          ),
                        if (isSelected)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'SELECCIONADO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
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
                      
                      // Botón de eliminar (solo para sonidos personalizados)
                      if (!sound.isDefault)
                        IconButton(
                          onPressed: () => _deleteSound(sound),
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                          tooltip: 'Eliminar',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        }).toList(),
      ),
    );
  }

  Future<void> _showClearAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Todos los Sonidos'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar todos los sonidos personalizados? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar Todo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await CustomSoundService.clearAllCustomSounds();
        if (success) {
          await _loadSounds();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Todos los sonidos personalizados eliminados'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al limpiar sonidos: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}