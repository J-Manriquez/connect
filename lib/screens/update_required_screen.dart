import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme_colors.dart';

/// Pantalla bloqueante que obliga a actualizar el APK antes de continuar.
class UpdateRequiredScreen extends StatefulWidget {
  final UpdateInfo info;
  const UpdateRequiredScreen({super.key, required this.info});
  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen> {
  bool _descargando = false;
  double _progreso = 0.0;
  String? _error;

  Future<void> _actualizarAhora() async {
    setState(() {
      _descargando = true;
      _progreso = 0.0;
      _error = null;
    });
    try {
      final archivo = await UpdateService.downloadAsset(widget.info, (p) {
        if (mounted) setState(() => _progreso = p);
      });
      await UpdateService.installAndroid(archivo);
    } catch (e) {
      if (mounted) {
        setState(() {
          _descargando = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // sin salida: hay que actualizar
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                customColor[500]!,
                customColor[900]!,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    elevation: 12,
                    shadowColor: Colors.black54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _IconoActualizacion(),
                          const SizedBox(height: 24),
                          Text(
                            'Actualización requerida',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: customColor[900],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: customColor[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Nueva versión  v${widget.info.version}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: customColor[700],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Para seguir usando Connect necesitas instalar '
                            'la última versión.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (_descargando)
                            _BloqueProgreso(progreso: _progreso)
                          else
                            _BotonActualizar(onPressed: _actualizarAhora),
                          if (_error != null) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red.shade400, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _actualizarAhora,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                              style: TextButton.styleFrom(
                                foregroundColor: customColor[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icono circular con halo, en el color de marca.
class _IconoActualizacion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: customColor[50],
      ),
      child: Center(
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [customColor[500]!, customColor[800]!],
            ),
          ),
          child: const Icon(
            Icons.system_update,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }
}

/// Botón principal de actualización.
class _BotonActualizar extends StatelessWidget {
  final VoidCallback onPressed;
  const _BotonActualizar({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.download_rounded),
        label: const Text('Actualizar ahora'),
        style: ElevatedButton.styleFrom(
          backgroundColor: customColor[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

/// Indicador de descarga con porcentaje.
class _BloqueProgreso extends StatelessWidget {
  final double progreso;
  const _BloqueProgreso({required this.progreso});

  @override
  Widget build(BuildContext context) {
    final tieneValor = progreso > 0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Descargando…',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: customColor[700],
              ),
            ),
            Text(
              tieneValor ? '${(progreso * 100).toStringAsFixed(0)}%' : '',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: customColor[900],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: tieneValor ? progreso : null,
            minHeight: 10,
            backgroundColor: customColor[50],
            valueColor: AlwaysStoppedAnimation<Color>(customColor[600]!),
          ),
        ),
      ],
    );
  }
}
