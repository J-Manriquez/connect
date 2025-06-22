import 'package:flutter/material.dart';
import 'package:connect/services/device_search_service.dart';
import 'package:connect/theme_colors.dart';

class BuscarEmisorScreen extends StatefulWidget {
  const BuscarEmisorScreen({super.key});

  @override
  State<BuscarEmisorScreen> createState() => _BuscarEmisorScreenState();
}

class _BuscarEmisorScreenState extends State<BuscarEmisorScreen> {
  bool _isLoading = false;
  bool _buscarEmisorActivo = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Dispositivo Emisor'),
        backgroundColor: customColor[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Icono principal
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: customColor[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search,
                size: 64,
                color: customColor[700],
              ),
            ),
            const SizedBox(height: 32),
            
            // Título
            Text(
              'Buscar Dispositivo Emisor',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: customColor[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Descripción
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: customColor[600],
                    size: 28,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Esta función activará una señal sonora y vibración en el dispositivo emisor vinculado para ayudarte a encontrarlo.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '• El dispositivo emisor sonará con una alarma\n• Vibrará con un patrón fuerte\n• La pantalla se encenderá automáticamente\n• La búsqueda se detendrá automáticamente en 30 segundos',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            
            // Botón principal
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _activarBusquedaEmisor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _buscarEmisorActivo ? Colors.red[600] : customColor[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _buscarEmisorActivo ? Icons.stop : Icons.search,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _buscarEmisorActivo ? 'Desactivar Búsqueda' : 'Activar Búsqueda',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Botón volver
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Volver',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _activarBusquedaEmisor() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final nuevoEstado = !_buscarEmisorActivo;
      await DeviceSearchService.instance.updateBuscarEmisor(nuevoEstado);
      
      setState(() {
        _buscarEmisorActivo = nuevoEstado;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevoEstado 
                ? 'Búsqueda de emisor activada - El dispositivo emisor comenzará a sonar'
                : 'Búsqueda de emisor desactivada',
            ),
            backgroundColor: nuevoEstado ? customColor[600] : Colors.grey[600],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al activar búsqueda: $e'),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}