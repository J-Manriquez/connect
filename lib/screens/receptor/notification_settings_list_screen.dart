import 'package:flutter/material.dart';
import 'package:connect/theme_colors.dart';
import 'package:connect/models/notification_settings.dart';
import 'package:connect/services/notification_settings_service.dart';

class NotificationSettingsListScreen extends StatefulWidget {
  const NotificationSettingsListScreen({super.key});

  @override
  State<NotificationSettingsListScreen> createState() =>
      _NotificationSettingsListScreenState();
}

class _NotificationSettingsListScreenState
    extends State<NotificationSettingsListScreen> {
  final NotificationSettingsService _settingsService =
      NotificationSettingsService();
  List<NotificationSettings> _settings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await _settingsService.getAllNotificationSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      // print('Error al cargar configuraciones: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSettings(NotificationSettings settings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta configuración?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      final success = await _settingsService.deleteNotificationSettings(settings.id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración eliminada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadSettings(); // Recargar la lista
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar la configuración'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getSettingsDescription(NotificationSettings settings) {
    List<String> features = [];
    
    if (settings.bloqueado) {
      features.add('Bloqueado');
    }
    if (settings.vibrationEnabled) {
      features.add('Vibración personalizada');
    }
    if (settings.soundEnabled) {
      features.add('Sonido personalizado');
    }
    
    return features.isEmpty ? 'Sin configuraciones' : features.join(', ');
  }

  String _getNotificationInfo(NotificationSettings settings) {
    final data = settings.notificationData;
    final packageName = data['packageName'] ?? 'Desconocido';
    final title = data['title'];
    final text = data['text'];
    
    List<String> info = [packageName];
    
    if (title != null && title.isNotEmpty) {
      info.add('Título: "$title"');
    }
    if (text != null && text.isNotEmpty) {
      info.add('Texto: "$text"');
    }
    
    return info.join(' • ');
  }

  void _showConfigurationModal(NotificationSettings setting) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                setting.bloqueado ? Icons.block : Icons.tune,
                color: setting.bloqueado ? Colors.red : customColor[600],
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Detalles de Configuración',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Estado', setting.bloqueado ? 'Bloqueado' : 'Configurado'),
                _buildInfoRow('Aplicación', setting.notificationData['appName'] ?? setting.notificationData['packageName'] ?? 'Desconocida'),
                _buildInfoRow('Título', (setting.notificationData['title'] ?? '').toString().trim().isEmpty ? 'No configurado' : setting.notificationData['title']),
                _buildInfoRow('Contenido', (setting.notificationData['text'] ?? '').toString().trim().isEmpty ? 'No configurado' : setting.notificationData['text']),
                _buildInfoRow('Vibración', setting.vibrationEnabled ? 'Habilitada' : 'Deshabilitada'),
                if (setting.vibrationEnabled && setting.additionalData['vibration'] is Map)
                  _buildInfoRow(
                    'Patrón',
                    ((setting.additionalData['vibration'] as Map)['patternName'] ??
                            (setting.additionalData['vibration'] as Map)['patternId'] ??
                            '')
                        .toString()
                        .trim()
                        .isEmpty
                        ? 'Desconocido'
                        : ((setting.additionalData['vibration'] as Map)['patternName'] ??
                                (setting.additionalData['vibration'] as Map)['patternId'])
                            .toString(),
                  ),
                _buildInfoRow('Sonido', setting.soundEnabled ? 'Habilitado' : 'Deshabilitado'),
                if (setting.soundEnabled && setting.additionalData['sound'] is Map)
                  _buildInfoRow(
                    'Sonido personalizado',
                    ((setting.additionalData['sound'] as Map)['soundName'] ??
                            (setting.additionalData['sound'] as Map)['soundId'] ??
                            '')
                        .toString()
                        .trim()
                        .isEmpty
                        ? 'Desconocido'
                        : ((setting.additionalData['sound'] as Map)['soundName'] ??
                                (setting.additionalData['sound'] as Map)['soundId'])
                            .toString(),
                  ),
                _buildInfoRow('Creado', _formatDate(setting.createdAt)),
                _buildInfoRow('Actualizado', _formatDate(setting.updatedAt)),
                if (setting.bloqueado)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Las notificaciones que coincidan con esta configuración serán bloqueadas.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteSettings(setting);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuraciones de Notificaciones'),
        backgroundColor: customColor[600],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _settings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.tune_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay configuraciones',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Las configuraciones aparecerán aquí cuando\nconfigures notificaciones desde el detalle',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSettings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _settings.length,
                    itemBuilder: (context, index) {
                      final setting = _settings[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 0,
                        ),
                        child: ListTile(
                          onTap: () => _showConfigurationModal(setting),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: setting.bloqueado
                                  ? Colors.red[100]
                                  : customColor[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              setting.bloqueado
                                  ? Icons.block
                                  : Icons.tune,
                              color: setting.bloqueado
                                  ? Colors.red[700]
                                  : customColor[600],
                              size: 24,
                            ),
                          ),
                          title: Text(
                            _getNotificationInfo(setting),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                _getSettingsDescription(setting),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Creado: ${setting.createdAt.day}/${setting.createdAt.month}/${setting.createdAt.year}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteSettings(setting);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Eliminar'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
