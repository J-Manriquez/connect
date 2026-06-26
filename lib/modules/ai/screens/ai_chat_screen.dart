import 'package:flutter/material.dart';

import '../models/ai_model_catalog.dart';
import '../services/ai_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _ChatLine {
  final String text;
  final bool isUser;
  final bool isError;
  final DateTime timestamp;

  _ChatLine({
    required this.text,
    required this.isUser,
    this.isError = false,
  }) : timestamp = DateTime.now();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final AiService _ai = AiService.instance;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatLine> _lines = <_ChatLine>[];

  bool _ready = false;
  bool _sending = false;
  String? _status;
  String? _activeModelName;
  int _messageCount = 0;

  // Si generateText no responde en este tiempo, se muestra aviso al usuario.
  static const Duration _responseTimeout = Duration(seconds: 90);

  @override
  void initState() {
    super.initState();
    debugPrint('[AI][chat] initState — verificando modelo activo');
    _checkModel();
  }

  @override
  void dispose() {
    debugPrint('[AI][chat] dispose');
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkModel() async {
    debugPrint('[AI][chat][_checkModel] START');
    setState(() {
      _status = 'Verificando modelo activo...';
      _ready = false;
      _activeModelName = null;
    });

    try {
      final id = await _ai.activeModelId();
      debugPrint('[AI][chat][_checkModel] activeModelId=$id');

      if (id == null) {
        debugPrint('[AI][chat][_checkModel] sin modelo activo');
        if (!mounted) return;
        setState(() => _status = 'No hay un modelo activo. Descarga y activa uno desde el gestor.');
        return;
      }

      final entry = AiModelCatalog.byId(id);
      final name = entry?.displayName ?? id;
      debugPrint('[AI][chat][_checkModel] modelo encontrado en catálogo: $name  entry=${entry != null}');

      final downloaded = await _ai.isModelDownloaded(id);
      debugPrint('[AI][chat][_checkModel] modelo descargado=$downloaded');

      if (!mounted) return;
      setState(() {
        _ready = downloaded;
        _activeModelName = name;
        _status = downloaded
            ? 'Modelo activo: $name'
            : 'El modelo "$name" no está descargado. Descárgalo desde el gestor.';
      });
      debugPrint('[AI][chat][_checkModel] OK  ready=$downloaded  name=$name');
    } catch (e, st) {
      debugPrint('[AI][chat][_checkModel] ERROR: $e\n$st');
      if (!mounted) return;
      setState(() => _status = 'Error al verificar modelo: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    debugPrint('[AI][chat][_sendMessage] intento de envío  text="${text.length > 80 ? text.substring(0, 80) : text}"  ready=$_ready  sending=$_sending  textEmpty=${text.isEmpty}');

    if (!_ready || text.isEmpty || _sending) {
      debugPrint('[AI][chat][_sendMessage] bloqueado — condición no cumplida');
      return;
    }

    _messageCount++;
    final msgNum = _messageCount;
    debugPrint('[AI][chat][_sendMessage] #$msgNum INICIO  modelo=$_activeModelName');

    _inputController.clear();
    setState(() {
      _lines.add(_ChatLine(text: text, isUser: true));
      _sending = true;
      _status = 'Generando respuesta... (puede tardar 10-60 seg según el modelo)';
    });
    _scrollToBottom();

    final stopwatch = Stopwatch()..start();
    debugPrint('[AI][chat][_sendMessage] #$msgNum llamando AiService.generateText()...');

    try {
      final answer = await _ai.generateText(
        prompt: text,
        systemInstruction: 'Eres un asistente breve, claro y útil. Responde en español.',
        maxOutputTokens: 512,
      ).timeout(
        _responseTimeout,
        onTimeout: () {
          debugPrint('[AI][chat][_sendMessage] #$msgNum TIMEOUT después de ${_responseTimeout.inSeconds}s — el modelo no respondió');
          throw TimeoutException(
            'El modelo tardó más de ${_responseTimeout.inSeconds} segundos. '
            'Puede que el dispositivo no tenga suficiente RAM/GPU para este modelo.',
          );
        },
      );

      stopwatch.stop();
      debugPrint('[AI][chat][_sendMessage] #$msgNum RESPUESTA OK en ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[AI][chat][_sendMessage] #$msgNum PROMPT: "$text"');
      debugPrint('[AI][chat][_sendMessage] #$msgNum RESPUESTA: "${answer.length > 200 ? answer.substring(0, 200) : answer}"');
      debugPrint('[AI][chat][_sendMessage] #$msgNum longitud respuesta: ${answer.length} chars');

      if (!mounted) return;
      setState(() {
        _lines.add(
          _ChatLine(
            text: answer.isEmpty ? '(Respuesta vacía)' : answer,
            isUser: false,
          ),
        );
        _status = 'Modelo: $_activeModelName  |  ${stopwatch.elapsedMilliseconds}ms';
      });
      _scrollToBottom();
    } on TimeoutException catch (e) {
      stopwatch.stop();
      debugPrint('[AI][chat][_sendMessage] #$msgNum TimeoutException: $e');
      if (!mounted) return;
      _showErrorBanner(e.message ?? e.toString());
      setState(() {
        _lines.add(_ChatLine(
          text: '⏱ Timeout: el modelo no respondió en ${_responseTimeout.inSeconds}s. '
              'Prueba con un modelo más liviano.',
          isUser: false,
          isError: true,
        ));
        _status = 'Timeout — prueba un modelo más liviano';
      });
    } catch (e, st) {
      stopwatch.stop();
      debugPrint('[AI][chat][_sendMessage] #$msgNum ERROR en ${stopwatch.elapsedMilliseconds}ms: $e\n$st');
      if (!mounted) return;
      _showErrorBanner(e.toString());
      setState(() {
        _lines.add(_ChatLine(
          text: 'Error: $e',
          isUser: false,
          isError: true,
        ));
        _status = 'Error — revisa los logs';
      });
    } finally {
      debugPrint('[AI][chat][_sendMessage] #$msgNum finally — sending=false');
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showErrorBanner(String message) {
    debugPrint('[AI][chat][_showErrorBanner] mostrando banner: $message');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Error del módulo IA',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            const Text(
              'Revisa los logs (flutter run) para el detalle completo.',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Cerrar',
          textColor: Colors.white,
          onPressed: () =>
              ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _unloadModel() async {
    debugPrint('[AI][chat][_unloadModel] descargando modelo de memoria');
    _ai.unload();
    setState(() {
      _status = 'Modelo liberado de memoria';
    });
    debugPrint('[AI][chat][_unloadModel] OK');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_activeModelName != null ? 'Chat — $_activeModelName' : 'Chat IA'),
        actions: [
          IconButton(
            tooltip: 'Liberar modelo de memoria',
            icon: const Icon(Icons.memory),
            onPressed: _unloadModel,
          ),
          IconButton(
            tooltip: 'Revisar modelo activo',
            icon: const Icon(Icons.refresh),
            onPressed: _checkModel,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Banner de estado ──────────────────────────────────────────
          if (_status != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _ready ? Colors.green.shade50 : Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(
                    _ready ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                    size: 16,
                    color: _ready ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _status!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _ready ? Colors.green.shade900 : Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // ── Mensajes ─────────────────────────────────────────────────
          Expanded(
            child: !_ready
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.smart_toy_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _status ?? 'Descarga y activa un modelo desde el gestor para poder usar el chat.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _lines.length,
                    itemBuilder: (context, index) {
                      final line = _lines[index];
                      return Align(
                        alignment: line.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: line.isError
                                ? Colors.red.shade100
                                : line.isUser
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                            border: line.isError
                                ? Border.all(color: Colors.red.shade300)
                                : null,
                          ),
                          child: Text(
                            line.text,
                            style: TextStyle(
                              color: line.isError ? Colors.red.shade900 : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // ── Input ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    enabled: _ready && !_sending,
                    decoration: InputDecoration(
                      hintText: _sending ? 'Esperando respuesta...' : 'Escribe un mensaje...',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (!_ready || _sending) ? null : _sendMessage,
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Excepción local para timeout de respuesta del modelo.
class TimeoutException implements Exception {
  final String? message;
  const TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
