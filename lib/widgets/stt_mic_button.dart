import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/ble_service.dart';
import '../services/preferences_service.dart';
import '../services/stt_service.dart';

/// Print simple (no `debugPrint`) que además reenvía al emisor por BT con la
/// llamada nativa directa (ver BleService.sendDebugLogToPeers) — el mismo
/// mecanismo confiable que usa `media_state`, sin Intent/startForegroundService.
void _log(String message) {
  print('[stt_mic_button] $message');
  try {
    unawaited(BleService.sendDebugLogToPeers('stt_mic_button', message));
  } catch (_) {}
}

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

/// Pide permiso de micrófono, inicializa el motor STT y abre el modal de
/// grabación de voz a pantalla completa. Es la función central reutilizada
/// tanto por [SttMicButton] (ícono de micrófono) como por cualquier botón
/// "Responder" que quiera abrir el modal STT directamente, sin un diálogo de
/// texto intermedio.
Future<void> showSttReplyModal(
  BuildContext context, {
  required void Function(String text) onResult,
  Color? accentColor,
  Color? backgroundColor,
}) async {
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
          'o intenta nuevamente con conexión a internet.',
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
  final bg = backgroundColor ?? Theme.of(context).colorScheme.surface;
  await showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    enableDrag: false,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SttRecordingModal(
      accentColor: accentColor ?? Theme.of(context).colorScheme.primary,
      backgroundColor: bg,
      onResult: onResult,
    ),
  );
}

/// Botón de micrófono: un toque abre el modal de grabación de voz.
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
          onTap: () => showSttReplyModal(
            context,
            onResult: onResult,
            accentColor: c,
            backgroundColor: modalBackgroundColor,
          ),
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

  /// Sonido de inicio/fin de grabación (beeps del motor STT del sistema).
  /// Activado por defecto; se persiste para no tener que desactivarlo cada
  /// vez (ver PreferencesService.getSttSoundEnabled/saveSttSoundEnabled).
  bool _soundEnabled = true;
  bool _mutedByUs = false;
  String _baseText = '';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    // La grabación ya NO inicia automáticamente al abrir el modal: el
    // usuario decide cuándo empezar con el botón Iniciar/Detener.
    _loadSoundPref();
  }

  Future<void> _loadSoundPref() async {
    final enabled = await PreferencesService.getSttSoundEnabled();
    if (!mounted) return;
    setState(() => _soundEnabled = enabled);
  }

  Future<void> _toggleSound() async {
    final next = !_soundEnabled;
    setState(() => _soundEnabled = next);
    unawaited(PreferencesService.saveSttSoundEnabled(next));
    // Si se desactiva mientras ya está escuchando, silencia de inmediato.
    if (!next && _isListening) {
      _mutedByUs = true;
      unawaited(BleService.sttSetMuted(true));
    } else if (next && _mutedByUs) {
      _mutedByUs = false;
      unawaited(BleService.sttSetMuted(false));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _textController.dispose();
    _focusNode.dispose();
    SttService.instance.cancel();
    if (_mutedByUs) {
      _mutedByUs = false;
      unawaited(BleService.sttSetMuted(false));
    }
    super.dispose();
  }

  Future<void> _startListening() async {
    if (!mounted) return;
    _baseText = _textController.text;
    _log('_startListening llamado soundEnabled=$_soundEnabled baseText="${_baseText.length > 40 ? _baseText.substring(0, 40) : _baseText}"');
    setState(() => _isListening = true);

    if (!_soundEnabled) {
      // Silenciar ANTES de iniciar para que el beep de inicio tampoco se oiga.
      _mutedByUs = true;
      await BleService.sttSetMuted(true);
    }

    await SttService.instance.listen(
      localeId: 'es',
      onResult: (text, isFinal) {
        _log('onResult text="$text" isFinal=$isFinal');
        if (!mounted) return;
        final merged = _baseText.isEmpty
            ? text
            : (text.isEmpty ? _baseText : '$_baseText $text');
        setState(() {
          _textController.text = merged;
          _textController.selection = TextSelection.collapsed(
            offset: merged.length,
          );
        });
      },
      onListening: () {
        _log('onListening — motor activo');
        if (!mounted) return;
        setState(() => _isListening = true);
      },
      onDone: () {
        _log('onDone — motor detenido');
        _restoreSoundIfMuted();
        if (!mounted) return;
        setState(() => _isListening = false);
      },
      onError: (err) {
        _log('onError err=$err');
        _restoreSoundIfMuted();
        if (!mounted) return;
        setState(() => _isListening = false);
      },
    );
  }

  /// Restaura el volumen tras el beep de FIN de grabación (que también
  /// queremos silenciado): se llama al recibir done/error, momento en el que
  /// ya sonó (silenciosamente) el beep de cierre del motor.
  void _restoreSoundIfMuted() {
    if (!_mutedByUs) return;
    _mutedByUs = false;
    unawaited(BleService.sttSetMuted(false));
  }

  Future<void> _stopListening() async {
    await SttService.instance.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
  }

  /// Botón único Iniciar/Detener (doble funcionalidad según el estado actual).
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _restart() async {
    await SttService.instance.cancel();
    _restoreSoundIfMuted();
    if (!mounted) return;
    setState(() {
      _textController.clear();
      _isListening = false;
    });
    await _startListening();
  }

  void _send() {
    final text = _textController.text.trim();
    SttService.instance.cancel();
    _restoreSoundIfMuted();
    Navigator.of(context).pop();
    if (text.isNotEmpty) {
      widget.onResult(text);
    }
  }

  void _close() {
    SttService.instance.cancel();
    _restoreSoundIfMuted();
    Navigator.of(context).pop();
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

    // El modal usa toda la altura disponible de la pantalla.
    final double targetHeight = media.size.height - media.padding.top;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: kbPad),
      child: SizedBox(
        height: targetHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Botón X para cerrar, arriba a la derecha.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Ícono de sonido (inicio/fin de grabación): activado por
                    // defecto, se persiste al desactivarlo (PreferencesService).
                    IconButton(
                      onPressed: _toggleSound,
                      icon: Icon(
                        _soundEnabled ? Icons.volume_up : Icons.volume_off,
                        color: onBg,
                      ),
                      tooltip: _soundEnabled ? 'Silenciar sonido' : 'Activar sonido',
                    ),
                    IconButton(
                      onPressed: _close,
                      icon: Icon(Icons.close, color: onBg),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
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
                      hintText: 'Presiona Iniciar y habla…',
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
                // Fila de 3 botones: Iniciar/Detener (izq) | Reiniciar (centro) | Enviar (der).
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _toggleListening,
                        icon: Icon(_isListening ? Icons.stop : Icons.mic, size: 18),
                        label: Text(_isListening ? 'Detener' : 'Iniciar'),
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
        ),
      ),
    );
  }
}
