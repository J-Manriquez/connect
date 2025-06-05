import 'package:flutter/material.dart';
import 'package:connect/theme_colors.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:intl/intl.dart';

class NotificationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> notificationData;
  
  const NotificationDetailScreen({
    Key? key,
    required this.notificationData,
  }) : super(key: key);

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  final ReceptorService _receptorService = ReceptorService();
  bool _isMarkingAsRead = false;

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
      final notificationId = widget.notificationData['notificationId'] as String?;
      if (notificationId != null) {
        await _receptorService.updateNotificationVisualizationStatus(notificationId, true);
        print('Notificación marcada como leída: $notificationId');
      }
    } catch (e) {
      print('Error al marcar notificación como leída: $e');
    } finally {
      setState(() {
        _isMarkingAsRead = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.notificationData['title'] as String? ?? 'Sin título';
    final body = widget.notificationData['body'] as String? ?? 'Sin contenido';
    final appName = widget.notificationData['appName'] as String? ?? 'Aplicación desconocida';
    final packageName = widget.notificationData['packageName'] as String? ?? '';
    
    // Intentar obtener timestamp si está disponible
    String formattedTime = 'Hora no disponible';
    try {
      final notificationId = widget.notificationData['notificationId'] as String?;
      if (notificationId != null) {
        final timestamp = int.tryParse(notificationId);
        if (timestamp != null) {
          final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          formattedTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
        }
      }
    } catch (e) {
      print('Error al formatear tiempo: $e');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Notificación'),
        backgroundColor: customColor[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información de la aplicación
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.apps,
                          color: customColor[700],
                          size: 24,
                        ),
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
                    const SizedBox(height: 12),
                    _buildInfoRow('Aplicación:', appName),
                    _buildInfoRow('Paquete:', packageName),
                    _buildInfoRow('Fecha y Hora:', formattedTime),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Contenido de la notificación
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.message,
                          color: customColor[700],
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Contenido de la Notificación',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Título
                    Container(
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
                          Text(
                            'Título:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: customColor[700],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Contenido
                    Container(
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
                          Text(
                            'Mensaje:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: customColor[700],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: const TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Estado de lectura
            if (_isMarkingAsRead)
              Card(
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
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
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
          ],
        ),
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
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}