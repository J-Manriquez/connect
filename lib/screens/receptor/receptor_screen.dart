import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/services/preferences_service.dart';

class ReceptorScreen extends StatefulWidget {
  const ReceptorScreen({Key? key}) : super(key: key);

  @override
  State<ReceptorScreen> createState() => _ReceptorScreenState();
}

class _ReceptorScreenState extends State<ReceptorScreen> {
  final TextEditingController _codeController = TextEditingController();
  final ReceptorService _receptorService = ReceptorService();
  
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkLinkedStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
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
        // Si ya hay un dispositivo vinculado, redirigir a la pantalla de notificaciones
        Navigator.pushReplacementNamed(context, '/notificaciones');
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
        // Guardar preferencia de usar como receptor
        await PreferencesService.saveUseAsReceptor(true);
        
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dispositivo vinculado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Redirigir a la pantalla de notificaciones
        Navigator.pushReplacementNamed(context, '/notificaciones');
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

  // Método para volver a la pantalla emisor
  Future<void> _backToEmisor() async {
    // Guardar preferencia de no usar como receptor
    await PreferencesService.saveUseAsReceptor(false);
    
    // Navegar a la pantalla emisor
    Navigator.pushReplacementNamed(context, '/');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vincular Dispositivo'),
        automaticallyImplyLeading: false, // Eliminar la flecha de retroceso
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Botón para volver a la pantalla emisor
                  ElevatedButton.icon(
                    onPressed: _backToEmisor,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver a Emisor'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                ],
              ),
            ),
    );
  }
}