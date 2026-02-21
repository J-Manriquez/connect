import 'package:flutter/material.dart';
import 'package:connect/theme_colors.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:connect/services/notification_cache_service.dart';
import 'package:intl/intl.dart';

class NotificationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> notificationData;

  const NotificationDetailScreen({super.key, required this.notificationData});

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  final ReceptorService _receptorService = ReceptorService();
  bool _isMarkingAsRead = false;

  void _goBackToConexion() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/notificaciones',
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    if (_isMarkingAsRead) return;

    setState(() {
      _isMarkingAsRead = true;
    });

    try {
      final notificationId = (widget.notificationData['notificationId'] ??
              widget.notificationData['id'])
          ?.toString();
      if (notificationId != null && notificationId.isNotEmpty) {
        await NotificationCacheService.markAsVisualized(notificationId);
        await BtHiveStorageService.markVisualized(notificationId, true);
        await _receptorService.updateNotificationVisualizationStatus(
          notificationId,
          true,
        );
        //// print('Notificación marcada como leída: $notificationId');
      }
    } catch (e) {
      // print('Error al marcar notificación como leída: $e');
    } finally {
      setState(() {
        _isMarkingAsRead = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extraer datos de diferentes campos posibles
    final title = _getFieldValue(['title', 'titulo']) ?? 'Sin título';
    final body =
        _getFieldValue(['text', 'body', 'bigText', 'mensaje', 'contenido']) ??
        'Sin contenido';
    final appName =
        _getFieldValue(['appName', 'aplicacion']) ?? 'Aplicación desconocida';
    final subText = _getFieldValue(['subText', 'subtexto']);
    final summaryText = _getFieldValue(['summaryText', 'resumen']);
    final infoText = _getFieldValue(['infoText', 'info']);
    final contentInfo = _getFieldValue(['contentInfo', 'infoContenido']);

    // Intentar obtener timestamp si está disponible
    String formattedTime = 'Hora no disponible';
    try {
      final notificationId =
          (widget.notificationData['notificationId'] ?? widget.notificationData['id'])
              ?.toString();
      if (notificationId != null) {
        final timestamp = int.tryParse(notificationId.split('_')[0]);
        if (timestamp != null) {
          final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          formattedTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
        }
      }
    } catch (e) {
      // print('Error al formatear tiempo: $e');
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBackToConexion();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBackToConexion,
          ),
          title: const Text('Detalle de Notificación'),
          backgroundColor: customColor[700],
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Contenido principal de la notificación
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.message, color: customColor[700], size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Contenido Principal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    _buildContentField('Título', title),
                    const SizedBox(height: 10),
                    _buildContentField('Mensaje', body),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Contenido adicional (solo si existe)
            if (subText != null ||
                summaryText != null ||
                infoText != null ||
                contentInfo != null) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: customColor[700],
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Información Adicional',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (subText != null) ...[
                        _buildContentField('Subtexto', subText),
                        const SizedBox(height: 8),
                      ],
                      if (summaryText != null) ...[
                        _buildContentField('Resumen', summaryText),
                        const SizedBox(height: 8),
                      ],
                      if (infoText != null) ...[
                        _buildContentField('Información', infoText),
                        const SizedBox(height: 8),
                      ],
                      if (contentInfo != null) ...[
                        _buildContentField('Info del Contenido', contentInfo),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            // Información de la aplicación
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.apps, color: customColor[700], size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Información de la Aplicación',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow('Aplicación:', appName),
                    // _buildInfoRow('Paquete:', packageName),
                    _buildInfoRow('Fecha y Hora:', formattedTime),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Estado de lectura
            if (_isMarkingAsRead)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      const Text('Marcando como leída...'),
                    ],
                  ),
                ),
              )
            else
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      const Text(
                        'Notificación marcada como leída',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // Card para configurar notificación
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, color: customColor[700], size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Configuración Personalizada',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Crear configuraciones personalizadas de sonido, vibración o bloqueo para notificaciones similares.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/configure_notification',
                            arguments: widget.notificationData,
                          );
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text(
                          'Configurar Notificación',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: customColor[600],
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
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  // Método auxiliar para obtener valores de diferentes campos
  String? _getFieldValue(List<String> fieldNames) {
    for (final fieldName in fieldNames) {
      final value = widget.notificationData[fieldName];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  // Método auxiliar para construir campos de contenido
  Widget _buildContentField(String label, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: customColor[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: customColor[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   '$label:',
          //   style: TextStyle(
          //     fontWeight: FontWeight.bold,
          //     color: customColor[700],
          //     fontSize: 14,
          //   ),
          // ),
          // const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: customColor[700],
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
