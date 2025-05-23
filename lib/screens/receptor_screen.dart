import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceptorScreen extends StatefulWidget {
  const ReceptorScreen({Key? key}) : super(key: key);

  @override
  State<ReceptorScreen> createState() => _ReceptorScreenState();
}

class _ReceptorScreenState extends State<ReceptorScreen> {
  final TextEditingController _codeController = TextEditingController();
  final ReceptorService _receptorService = ReceptorService();
  
  bool _isLinked = false;
  bool _isLoading = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription? _notificationSubscription;
  String? _linkedDeviceId;

  @override
  void initState() {
    super.initState();
    _checkLinkedStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // Verificar si ya hay un dispositivo vinculado
  Future<void> _checkLinkedStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener el ID del dispositivo emisor vinculado
      final deviceId = await _receptorService.getLinkedDeviceId();
      
      if (deviceId != null) {
        setState(() {
          _isLinked = true;
          _linkedDeviceId = deviceId;
        });
        
        // Iniciar escucha de notificaciones
        _startListeningForNotifications();
      }
    } catch (e) {
      print('Error al verificar estado de vinculación: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Verificar código y actualizar estado de vinculación
  Future<void> _verifyAndLink() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final code = _codeController.text.trim();
      if (code.isEmpty) {
        setState(() {
          _errorMessage = 'Por favor, ingresa un código';
          _isLoading = false;
        });
        return;
      }

      // Verificar si el código existe en la colección de dispositivos
      final deviceId = await _receptorService.verifyLinkCode(code);
      if (deviceId == null) {
        setState(() {
          _errorMessage = 'Código inválido o no encontrado';
          _isLoading = false;
        });
        return;
      }

      // Guardar el ID del dispositivo emisor vinculado
      final success = await _receptorService.saveLinkedDeviceId(deviceId);
      if (success) {
        setState(() {
          _isLinked = true;
          _linkedDeviceId = deviceId;
          _isLoading = false;
        });
        
        // Iniciar escucha de notificaciones
        _startListeningForNotifications();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dispositivo vinculado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Error al vincular dispositivo';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // Iniciar escucha de notificaciones
  void _startListeningForNotifications() {
    _notificationSubscription = _receptorService
        .listenForNotifications()
        .listen((notifications) {
      setState(() {
        _notifications = notifications;
      });
    }, onError: (error) {
      print('Error en la suscripción de notificaciones: $error');
    });
  }

  // Desvincular dispositivo
  Future<void> _unlinkDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ReceptorService.KEY_LINKED_DEVICE_ID);
      
      // Cancelar la suscripción a notificaciones
      _notificationSubscription?.cancel();
      
      setState(() {
        _isLinked = false;
        _linkedDeviceId = null;
        _notifications = [];
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispositivo desvinculado correctamente'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('Error al desvincular dispositivo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al desvincular dispositivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receptor de Notificaciones'),
        actions: _isLinked
            ? [
                IconButton(
                  icon: const Icon(Icons.link_off),
                  tooltip: 'Desvincular',
                  onPressed: _unlinkDevice,
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isLinked) ...[
                    // Sección de vinculación
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vincular Dispositivo',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _codeController,
                              decoration: const InputDecoration(
                                labelText: 'Código de vinculación',
                                border: OutlineInputBorder(),
                                hintText: 'Ingresa el código de 6 dígitos',
                              ),
                              keyboardType: TextInputType.text,
                            ),
                            if (_errorMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _errorMessage,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _verifyAndLink,
                                child: _isLoading
                                    ? const CircularProgressIndicator()
                                    : const Text('Vincular'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Sección de notificaciones (visible después de vincular)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.link, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Dispositivo vinculado',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      Text(
                                        'ID: $_linkedDeviceId',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Notificaciones recibidas:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _notifications.isEmpty
                          ? const Center(
                              child: Text('No hay notificaciones recibidas'),
                            )
                          : ListView.builder(
                              itemCount: _notifications.length,
                              itemBuilder: (context, index) {
                                final notification = _notifications[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  child: ListTile(
                                    title: Text(notification['title'] ?? 'Sin título'),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(notification['text'] ?? 'Sin contenido'),
                                        Text(
                                          'App: ${notification['appName'] ?? notification['packageName'] ?? 'Desconocida'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Text(
                                      _formatTimestamp(notification['timestamp']),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  // Formatear timestamp para mostrar
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    final DateTime date = (timestamp as Timestamp).toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}