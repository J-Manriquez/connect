import 'package:flutter/material.dart';

import 'package:connect/models/floating_ball_config_backup.dart';
import 'package:connect/services/floating_ball_backup_service.dart';
import 'package:connect/theme_colors.dart';

/// Sección de respaldo/restauración de la configuración de la bola flotante.
///
/// Se usa dentro de la pestaña "Respaldo" de la pantalla "Personalizar bola".
/// Es autónoma: gestiona su propio estado (consulta de la nube, ocupado, etc.).
class FloatingBallBackupSection extends StatefulWidget {
  /// Se invoca tras restaurar correctamente, para que la pantalla padre recargue
  /// sus valores desde SharedPreferences y refleje la config restaurada.
  final Future<void> Function()? onRestored;

  const FloatingBallBackupSection({super.key, this.onRestored});

  @override
  State<FloatingBallBackupSection> createState() =>
      _FloatingBallBackupSectionState();
}

class _FloatingBallBackupSectionState extends State<FloatingBallBackupSection> {
  final FloatingBallBackupService _service = FloatingBallBackupService();

  bool _loadingStatus = true;
  bool _busy = false;
  FloatingBallConfigBackup? _cloudBackup;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loadingStatus = true;
      _error = null;
    });
    try {
      final b = await _service.fetchCloudBackup();
      if (!mounted) return;
      setState(() {
        _cloudBackup = b;
        _loadingStatus = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo consultar la nube: $e';
        _loadingStatus = false;
      });
    }
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final b = await _service.backupToCloud();
      if (!mounted) return;
      setState(() {
        _cloudBackup = b;
        _busy = false;
      });
      _snack('Respaldo guardado en la nube (${b.entryCount} ajustes).');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Error al respaldar: $e');
    }
  }

  Future<bool> _confirm(String content) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar configuración'),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _restore() async {
    if (!await _confirm(
      'Se sobrescribirá la configuración actual de la bola flotante con la '
      'última copia guardada en la nube. ¿Continuar?',
    )) {
      return;
    }

    setState(() => _busy = true);
    try {
      final applied = await _service.restoreFromCloud();
      if (applied == null) {
        if (!mounted) return;
        setState(() => _busy = false);
        _snack('No hay ningún respaldo en la nube todavía.');
        return;
      }
      await widget.onRestored?.call();
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Configuración restaurada ($applied ajustes).');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Error al restaurar: $e');
    }
  }

  Future<void> _exportFile() async {
    setState(() => _busy = true);
    try {
      final path = await _service.exportConfigToFile();
      if (!mounted) return;
      setState(() => _busy = false);
      if (path == null) return; // el usuario canceló
      _snack('Configuración guardada en el archivo seleccionado.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Error al guardar el archivo: $e');
    }
  }

  Future<void> _importFile() async {
    if (!await _confirm(
      'Se sobrescribirá la configuración actual de la bola flotante con la del '
      'archivo .json que elijas. ¿Continuar?',
    )) {
      return;
    }

    setState(() => _busy = true);
    try {
      final applied = await _service.importConfigFromFile();
      if (applied == null) {
        if (!mounted) return;
        setState(() => _busy = false);
        return; // el usuario canceló
      }
      await widget.onRestored?.call();
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Configuración restaurada desde archivo ($applied ajustes).');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Error al restaurar desde archivo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = _cloudBackup;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: customColor[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: customColor[100] ?? Colors.black12),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_done, color: customColor[600]),
              const SizedBox(width: 12),
              Expanded(
                child: _loadingStatus
                    ? const Text('Consultando la nube…')
                    : cloud == null
                        ? const Text(
                            'Aún no hay ninguna copia guardada en la nube.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Última copia en la nube:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_formatDate(cloud.updatedAt)}  •  ${cloud.entryCount} ajustes',
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'En la nube',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _busy ? null : _backup,
          icon: const Icon(Icons.cloud_upload),
          label: const Text('Respaldar ahora en la nube'),
          style: ElevatedButton.styleFrom(
            backgroundColor: customColor[600],
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: (_busy || cloud == null) ? null : _restore,
          icon: const Icon(Icons.cloud_download),
          label: const Text('Restaurar desde la nube'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _busy ? null : _loadStatus,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar estado de la nube'),
        ),
        const SizedBox(height: 20),
        const Text(
          'En un archivo (.json)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _busy ? null : _exportFile,
          icon: const Icon(Icons.save_alt),
          label: const Text('Guardar JSON en un archivo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: customColor[600],
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : _importFile,
          icon: const Icon(Icons.folder_open),
          label: const Text('Restaurar desde un archivo JSON'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'El respaldo incluye TODO lo relativo a la bola flotante: colores, '
          'tamaños y estilos (popup y pantalla completa), gestos, apps y '
          'herramientas seleccionadas y su orden, el menú de chats y los iconos '
          'personalizados. Se guarda por dispositivo para que puedas recuperarlo '
          'si reinstalas o cambias algo por error.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}
