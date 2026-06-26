import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/stt_service.dart';

/// Botón de micrófono: un toque abre un modal de grabación.
///
/// El modal inicia la grabación automáticamente y muestra el texto transcrito
/// en un TextField editable. El usuario puede reiniciar, detener o enviar.
/// [onResult] se invoca con el texto cuando el usuario toca "Enviar".
class SttMicButton extends StatelessWidget {
  final void Function(String text) onResult;
  final Color? color;
  final double size;

  /// Color de fondo del modal de grabación. Si es null usa el color de
  /// superficie del tema.
  final Color? modalBackgroundColor;

  const SttMicButton({
    super.key,
    required this.onResult,
    this.color,
    this.size = 44,
    this.modalBackgroundColor,
  });

  Future<bool> _requestMicPermission(BuildContext context) async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      if (context.mounted) await _showPermDenied(context);
      return false;
    }
    status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied && context.mounted) {
      await _showPermDenied(context);
    }
    return false;
  }

  Future<void> _showPermDenied(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permiso de micrófono'),
        content: const Text(
          'La app necesita acceso al micrófono para convertir voz a texto. '
          'Ve a Ajustes → Aplicaciones → esta app → Permisos → Micrófono.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Abrir Ajustes'),
          ),
        ],
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    final hasPerm = await _requestMicPermission(context);
    if (!hasPerm) return;

    final available = await SttService.instance.initialize();
    if (!available) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('STT no disponible'),
          content: const Text(
            'Este dispositivo no tiene un motor de reconocimiento de voz '
            'compatible con español.\n\n'
            'Asegúrate de tener Google o cualquier motor STT instalado, '
            'o escribe el mensaje manualmente.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final bg = modalBackgroundColor ?? Theme.of(context).colorScheme.surface;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SttRecordingModal(
        accentColor: color ?? Theme.of(context).colorScheme.primary,
        backgroundColor: bg,
        onResult: onResult,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: size,
      width: size,
      child: Material(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size / 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: () => _onTap(context),
          child: Icon(Icons.mic, color: c, size: size * 0.5),
        ),
      ),
    );
  }
}

// ── Modal de grabación ────────────────────────────────────────────────────────

class _SttRecordingModal extends StatefulWidget {
  final Color accentColor;
  final Color backgroundColor;
  final void Function(String) onResult;

  const _SttRecordingModal({
    required this.accentColor,
    required this.backgroundColor,
    required this.onResult,
  });

  @override
  State<_SttRecordingModal> createState() => _SttRecordingModalState();
}

class _SttRecordingModalState extends State<_SttRecordingModal>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _pulse;
  bool _isListening = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    // Al enfocar el textfield, crece el modal para ver el contenido con el
    // teclado abierto.
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !_expanded && mounted) {
        setState(() => _expanded = true);
      }
    });
    _startListening();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _textController.dispose();
    _focusNode.dispose();
    SttService.instance.cancel();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!mounted) return;
    setState(() => _isListening = true);

    await SttService.instance.listen(
      localeId: 'es',
      preferOffline: true,
      allowOnlineFallback: true,
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          _textController.text = text;
          _textController.selection = TextSelection.collapsed(
            offset: text.length,
          );
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _isListening = false);
      },
      onError: (err) {
        if (!mounted) return;
        setState(() => _isListening = false);
      },
    );
  }

  Future<void> _restart() async {
    await SttService.instance.cancel();
    if (!mounted) return;
    setState(() {
      _textController.clear();
      _isListening = false;
    });
    await _startListening();
  }

  Future<void> _stop() async {
    await SttService.instance.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
  }

  void _send() {
    final text = _textController.text.trim();
    SttService.instance.cancel();
    Navigator.of(context).pop();
    if (text.isNotEmpty) {
      widget.onResult(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    final bg = widget.backgroundColor;
    final media = MediaQuery.of(context);
    final kbPad = media.viewInsets.bottom;

    // Color de texto/iconos legible sobre el fondo configurado.
    final onBg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final onBgMuted = onBg.withValues(alpha: 0.6);

    // Altura adaptable: al enfocar el textfield (o abrir teclado) crece para
    // ocupar el espacio disponible sobre el teclado.
    final maxH = media.size.height;
    final available = maxH - kbPad - media.padding.top - 24;
    final double targetHeight =
        (_expanded ? available.clamp(320.0, maxH) : 360.0).toDouble();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: kbPad),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: targetHeight,
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Indicador de estado
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Icon(
                    _isListening ? Icons.mic : Icons.mic_off,
                    color: _isListening
                        ? Color.lerp(accent, Colors.red, _pulse.value)
                        : onBgMuted,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _isListening ? 'Escuchando…' : 'Grabación detenida',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _isListening ? accent : onBgMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // TextField editable con la transcripción (ocupa el alto disponible)
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: onBg),
                decoration: InputDecoration(
                  hintText: 'El texto transcrito aparecerá aquí…',
                  hintStyle: TextStyle(color: onBgMuted),
                  filled: true,
                  fillColor: onBg.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: onBg.withValues(alpha: 0.25)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: onBg.withValues(alpha: 0.25)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Fila de 3 botones (todos con apariencia de botón)
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _restart,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reiniciar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: onBg.withValues(alpha: 0.12),
                      foregroundColor: onBg,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _isListening ? _stop : null,
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('Detener'),
                    style: FilledButton.styleFrom(
                      backgroundColor: onBg.withValues(alpha: 0.12),
                      foregroundColor: onBg,
                      disabledBackgroundColor: onBg.withValues(alpha: 0.05),
                      disabledForegroundColor: onBgMuted,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _send,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Enviar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor:
                          ThemeData.estimateBrightnessForColor(accent) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
