import 'package:flutter/material.dart';
import 'package:connect/theme_colors.dart';
import 'package:connect/models/notification_settings.dart';
import 'package:connect/services/notification_settings_service.dart';
import 'package:connect/screens/receptor/notification_vibration_selection_screen.dart';
import 'package:connect/screens/receptor/notification_sound_selection_screen.dart';

class ConfigureNotificationScreen extends StatefulWidget {
  final Map<String, dynamic> notificationData;

  const ConfigureNotificationScreen({
    Key? key,
    required this.notificationData,
  }) : super(key: key);

  @override
  State<ConfigureNotificationScreen> createState() =>
      _ConfigureNotificationScreenState();
}

class _ConfigureNotificationScreenState
    extends State<ConfigureNotificationScreen> {
  final NotificationSettingsService _settingsService =
      NotificationSettingsService();

  bool _titleSelected = false;
  bool _textSelected = false;
  bool _extrasSelected = false;

  @override
  void initState() {
    super.initState();
  }

  String? get _title => widget.notificationData['title'];
  String? get _text => widget.notificationData['text'] ??
      widget.notificationData['body'] ??
      widget.notificationData['bigText'];
  Map<String, dynamic>? get _extras => widget.notificationData['extras'];
  String? get _packageName => widget.notificationData['packageName'];
  String? get _appName => widget.notificationData['appName'];

  bool get _hasSelection => _titleSelected || _textSelected || _extrasSelected;

  NotificationConfigSelection get _selection => NotificationConfigSelection(
        titleSelected: _titleSelected,
        textSelected: _textSelected,
        extrasSelected: _extrasSelected,
        originalNotification: widget.notificationData,
      );

  Future<void> _handleBlockAction() async {
    if (!_hasSelection) {
      _showSelectionRequiredDialog();
      return;
    }

    final confirmed = await _showConfirmationDialog(
      'Bloquear Notificaciones',
      'Se bloquearán todas las notificaciones futuras de $_appName que contengan la información seleccionada.',
    );

    if (confirmed) {
      final settings = NotificationSettings.create(
        notificationData: _selection.generateNotificationData(),
        bloqueado: true,
      );

      final success = await _settingsService.saveNotificationSettings(settings);
      if (success) {
        _showSuccessAndReturn('Configuración de bloqueo guardada correctamente');
      } else {
        _showErrorDialog('Error al guardar la configuración de bloqueo');
      }
    }
  }

  Future<void> _configureVibration() async {
    if (!_hasSelection) {
      _showSelectionRequiredDialog();
      return;
    }

    final configSelection = NotificationConfigSelection(
      titleSelected: _titleSelected,
      textSelected: _textSelected,
      extrasSelected: _extrasSelected,
      originalNotification: widget.notificationData,
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationVibrationSelectionScreen(
          configSelection: configSelection,
          notificationData: widget.notificationData,
        ),
      ),
    );

    if (result == true && mounted) {
      _showSuccessAndReturn('Configuración de vibración guardada correctamente');
    }
  }

  void _handleVibrationAction() async {
    await _configureVibration();
  }

  Future<void> _configureSound() async {
    if (!_hasSelection) {
      _showSelectionRequiredDialog();
      return;
    }

    final configSelection = NotificationConfigSelection(
      titleSelected: _titleSelected,
      textSelected: _textSelected,
      extrasSelected: _extrasSelected,
      originalNotification: widget.notificationData,
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationSoundSelectionScreen(
          configSelection: configSelection,
          notificationData: widget.notificationData,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración de sonido guardada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleSoundAction() async {
    await _configureSound();
  }

  void _showSelectionRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selección requerida'),
        content: const Text(
          'Debes seleccionar al menos una parte del contenido de la notificación para configurar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showSuccessAndReturn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Notificación'),
        backgroundColor: customColor[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información de la notificación
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: customColor[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Información de la Notificación',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aplicación: $_appName',
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (_packageName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Paquete: $_packageName',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Selección de contenido
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist, color: customColor[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Seleccionar Contenido a Configurar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selecciona qué partes del contenido quieres usar para la configuración:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Título
                    if (_title != null && _title!.isNotEmpty)
                      CheckboxListTile(
                        value: _titleSelected,
                        onChanged: (value) {
                          setState(() {
                            _titleSelected = value ?? false;
                          });
                        },
                        title: const Text('Título'),
                        subtitle: Text(
                          _title!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        activeColor: customColor[600],
                      ),

                    // Texto/Contenido
                    if (_text != null && _text!.isNotEmpty)
                      CheckboxListTile(
                        value: _textSelected,
                        onChanged: (value) {
                          setState(() {
                            _textSelected = value ?? false;
                          });
                        },
                        title: const Text('Contenido'),
                        subtitle: Text(
                          _text!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        activeColor: customColor[600],
                      ),

                    // Información adicional
                    if (_extras != null && _extras!.isNotEmpty)
                      CheckboxListTile(
                        value: _extrasSelected,
                        onChanged: (value) {
                          setState(() {
                            _extrasSelected = value ?? false;
                          });
                        },
                        title: const Text('Información Adicional'),
                        subtitle: Text(
                          'Datos extras de la notificación',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        activeColor: customColor[600],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Opciones de configuración
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings, color: customColor[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Opciones de Configuración',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Botón Bloquear
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleBlockAction,
                        icon: const Icon(Icons.block),
                        label: const Text(
                          'Bloquear Notificaciones',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Botón Vibración
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleVibrationAction,
                        icon: const Icon(Icons.vibration),
                        label: const Text(
                          'Configurar Vibración',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Botón Sonido
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleSoundAction,
                        icon: const Icon(Icons.music_note),
                        label: const Text(
                          'Configurar Sonido',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Información adicional
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Las configuraciones se aplicarán a todas las notificaciones futuras que contengan la información seleccionada.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}