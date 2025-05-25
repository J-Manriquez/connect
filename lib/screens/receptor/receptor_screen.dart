import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/theme_colors.dart';
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
          : Column(
              children: [
                // Botón para volver a la pantalla emisor (se mantiene arriba)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: _backToEmisor,
                    icon: const Icon(Icons.arrow_back, color: Colors.white,),
                    label: const Text(
                      'Usar App como Emisor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor:
                          customColor[400], // Dos tonos más claro que el original
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                // Espacio flexible para centrar la Card verticalmente
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Card(
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
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.black),
                                  ),
                                  hintText: 'Ingresa el código de 6 dígitos',
                                ),
                                keyboardType: TextInputType.number,
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
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    backgroundColor:
                                        customColor[400], // Dos tonos más claro que el original
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator()
                                      : const Text(
                                          'Vincular',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
