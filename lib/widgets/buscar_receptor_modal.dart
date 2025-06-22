import 'package:flutter/material.dart';
import 'package:connect/services/device_search_service.dart';
import 'package:connect/theme_colors.dart';

class BuscarReceptorModal extends StatefulWidget {
  const BuscarReceptorModal({super.key});

  @override
  State<BuscarReceptorModal> createState() => _BuscarReceptorModalState();
}

class _BuscarReceptorModalState extends State<BuscarReceptorModal> {
  bool _isLoading = false;
  bool _buscarReceptorActivo = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: customColor[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search,
                size: 32,
                color: customColor[700],
              ),
            ),
            const SizedBox(height: 16),
            
            // Título
            Text(
              'Buscar Dispositivo Receptor',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: customColor[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Descripción
            Text(
              'Esta función activará una señal sonora y vibración en el dispositivo receptor vinculado para ayudarte a encontrarlo.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Botón principal
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _activarBusquedaReceptor,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _buscarReceptorActivo ? Colors.red[600] : customColor[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _buscarReceptorActivo ? 'Desactivar Búsqueda' : 'Activar Búsqueda',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Botón cancelar
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activarBusquedaReceptor() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final nuevoEstado = !_buscarReceptorActivo;
      await DeviceSearchService.instance.updateBuscarReceptor(nuevoEstado);
      
      setState(() {
        _buscarReceptorActivo = nuevoEstado;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevoEstado 
                ? 'Búsqueda de receptor activada'
                : 'Búsqueda de receptor desactivada',
            ),
            backgroundColor: nuevoEstado ? customColor[600] : Colors.grey[600],
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Cerrar el modal después de un breve delay
        // Future.delayed(const Duration(milliseconds: 500), () {
        //   if (mounted) {
        //     Navigator.of(context).pop();
        //   }
        // });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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