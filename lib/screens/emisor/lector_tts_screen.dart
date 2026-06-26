import 'package:connect/services/tts_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LectorTtsScreen extends StatefulWidget {
  final String? initialText;

  const LectorTtsScreen({super.key, this.initialText});

  @override
  State<LectorTtsScreen> createState() => _LectorTtsScreenState();
}

class _LectorTtsScreenState extends State<LectorTtsScreen> {
  late final TtsService _ttsService;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _linesScrollController = ScrollController();

  List<String> _lines = [];
  int _currentLineIndex = -1;
  bool _isPlaying = false;

  // Claves globales para scroll preciso a cada línea
  final Map<int, GlobalKey> _lineKeys = {};

  // Altura del área de texto (ajustable con drag)
  double _textAreaHeight = 120.0;
  static const double _minTextAreaHeight = 60.0;
  static const double _maxTextAreaHeight = 360.0;

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
    _ttsService.onComplete = _onLineComplete;
    _loadInitialText();
  }

  Future<void> _loadInitialText() async {
    String? text = widget.initialText;
    if (text == null || text.trim().isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      text = prefs.getString('floating_ball_tts_pending_text');
      if ((text ?? '').trim().isNotEmpty) {
        await prefs.remove('floating_ball_tts_pending_text');
      }
    }
    if (!mounted) return;
    final normalized = (text ?? '').trim();
    if (normalized.isEmpty) return;
    _textController.text = normalized;
    _onTextChanged(normalized);
  }

  @override
  void dispose() {
    _ttsService.stop();
    _ttsService.onComplete = null;
    _ttsService.dispose();
    _textController.dispose();
    _linesScrollController.dispose();
    super.dispose();
  }

  // ─── Lógica de texto ──────────────────────────────────────────

  void _onTextChanged(String value) {
    final newLines = _splitLines(value);
    _lineKeys.clear();
    setState(() {
      _lines = newLines;
      // Resetear reproducción si el texto cambia
      _currentLineIndex = -1;
      _isPlaying = false;
    });
    _ttsService.stop();
  }

  List<String> _splitLines(String text) {
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  // ─── Lógica TTS ───────────────────────────────────────────────

  Future<void> _startFromLine(int index) async {
    if (!mounted) return;
    if (index < 0 || index >= _lines.length) {
      setState(() {
        _isPlaying = false;
        _currentLineIndex = -1;
      });
      return;
    }
    setState(() {
      _currentLineIndex = index;
      _isPlaying = true;
    });
    _scrollToLine(index);
    try {
      await _ttsService.speak(_lines[index]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _onLineComplete() {
    if (!mounted) return;
    if (_isPlaying && _currentLineIndex >= 0) {
      _startFromLine(_currentLineIndex + 1);
    }
  }

  Future<void> _stopReading() async {
    await _ttsService.stop();
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _currentLineIndex = -1;
    });
  }

  void _onLineTapped(int index) {
    if (_currentLineIndex == index && _isPlaying) {
      _stopReading();
    } else {
      _startFromLine(index);
    }
  }

  GlobalKey _keyForIndex(int index) =>
      _lineKeys.putIfAbsent(index, () => GlobalKey());

  void _scrollToLine(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _lineKeys[index];
      if (key?.currentContext == null) return;
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.2,
      );
    });
  }

  // ─── Modal de configuración ───────────────────────────────────

  void _openSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => _VoiceSettingsModal(
          ttsService: _ttsService,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }

  // ─── UI ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lector TTS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurar voz',
            onPressed: _openSettingsModal,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Área de texto ──
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SizedBox(
                  height: _textAreaHeight,
                  child: TextField(
                    controller: _textController,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    keyboardType: TextInputType.multiline,
                    onChanged: _onTextChanged,
                    decoration: InputDecoration(
                      hintText: 'Pega tu texto aquí...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: customColor[500]!,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: 12,
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    setState(() {
                      _textAreaHeight = (_textAreaHeight + details.delta.dy)
                          .clamp(_minTextAreaHeight, _maxTextAreaHeight);
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: customColor[500]!.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(5),
                    child: const Icon(
                      Icons.open_in_full,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Controles de reproducción ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(
                      _isPlaying ? Icons.stop_circle : Icons.play_circle,
                    ),
                    label: Text(
                      _isPlaying ? 'Detener' : 'Reproducir desde el inicio',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isPlaying ? Colors.red[600] : customColor[500],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _lines.isEmpty
                        ? null
                        : () {
                            if (_isPlaying) {
                              _stopReading();
                            } else {
                              _startFromLine(0);
                            }
                          },
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 12),

          // ── Lista de líneas ──
          Expanded(
            child: _lines.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.text_snippet_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Pega un texto arriba para comenzar',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _linesScrollController,
                    itemCount: _lines.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemBuilder: (context, index) {
                      final isActive = index == _currentLineIndex;
                      return GestureDetector(
                        key: _keyForIndex(index),
                        onTap: () => _onLineTapped(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? customColor[100]
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isActive
                                ? Border.all(
                                    color: customColor[400]!,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Ícono de reproducción activa
                              if (isActive)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4, top: 1),
                                  child: Icon(
                                    Icons.volume_up,
                                    size: 14,
                                    color: customColor[600],
                                  ),
                                ),
                              // Texto de la línea (con salto de línea si es largo)
                              Expanded(
                                child: Text(
                                  _lines[index],
                                  style: TextStyle(
                                    fontSize: isActive ? 14 : 13,
                                    fontWeight: isActive
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isActive
                                        ? customColor[900]
                                        : Colors.black87,
                                  ),
                                  softWrap: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Modal de configuración de voz ────────────────────────────────────────────

class _VoiceSettingsModal extends StatefulWidget {
  final TtsService ttsService;
  final ScrollController scrollController;

  const _VoiceSettingsModal({
    required this.ttsService,
    required this.scrollController,
  });

  @override
  State<_VoiceSettingsModal> createState() => _VoiceSettingsModalState();
}

class _VoiceSettingsModalState extends State<_VoiceSettingsModal> {
  List<Map<dynamic, dynamic>> _voices = [];
  List<String> _languages = [];
  bool _loadingVoices = true;
  bool _downloadingVoice = false;
  String? _downloadError;
  double? _downloadProgress;

  bool _enabled = true;
  int _repeatCount = 1;
  int _repeatDelaySeconds = 0;

  late double _rate;
  late double _pitch;
  late double _volume;
  late String _language;
  Map<String, String>? _selectedVoice;

  @override
  void initState() {
    super.initState();
    _rate = widget.ttsService.speechRate;
    _pitch = widget.ttsService.pitch;
    _volume = widget.ttsService.volume;
    _language = widget.ttsService.language;
    _selectedVoice = widget.ttsService.selectedVoice;
    _enabled = widget.ttsService.enabled;
    _repeatCount = widget.ttsService.repeatCount;
    _repeatDelaySeconds = widget.ttsService.repeatDelaySeconds;
    _loadVoicesAndLanguages();
  }

  Future<void> _loadVoicesAndLanguages() async {
    final voices = await widget.ttsService.getVoices();
    final languages = await widget.ttsService.getLanguages();
    if (!mounted) return;
    setState(() {
      _voices = voices;
      _languages = languages..sort();
      _loadingVoices = false;
    });
  }

  List<Map<dynamic, dynamic>> get _voicesForLanguage {
    final key = _language.length >= 2
        ? _language.toLowerCase().substring(0, 2)
        : _language.toLowerCase();
    return _voices
        .where((v) =>
            (v['locale'] as String?)
                ?.toLowerCase()
                .startsWith(key) ??
            false)
        .toList();
  }

  Future<bool> _isSelectedVoiceDownloaded() async {
    final id = _selectedVoice?['id'];
    if (id == null || id.isEmpty) return false;
    return widget.ttsService.isModelDownloaded(id);
  }

  Future<void> _downloadSelectedVoice() async {
    final id = _selectedVoice?['id'];
    if (id == null || id.isEmpty) return;
    setState(() {
      _downloadingVoice = true;
      _downloadError = null;
      _downloadProgress = 0.0;
    });
    try {
      await widget.ttsService.downloadVoice(
        id,
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _downloadProgress = value);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloadError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _downloadingVoice = false);
      }
    }
  }

  Future<void> _deleteSelectedVoice() async {
    final id = _selectedVoice?['id'];
    if (id == null || id.isEmpty) return;
    await widget.ttsService.deleteVoice(id);
    if (!mounted) return;
    setState(() {
      _downloadProgress = null;
      _downloadError = null;
    });
  }

  Future<void> _previewVoice() async {
    try {
      await widget.ttsService.speak('Vista previa de voz Piper');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Título
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Configuración de voz',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          // Contenido con scroll
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // ── Idioma ──
                const Text(
                  'Activar voz',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  onChanged: (value) async {
                    setState(() => _enabled = value);
                    await widget.ttsService.setEnabled(value);
                  },
                  title: const Text('Usar Piper para síntesis'),
                  subtitle: const Text('Sin fallback al motor del sistema'),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Idioma',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                _loadingVoices
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        value: _languages.contains(_language)
                            ? _language
                            : (_languages.isNotEmpty ? _languages.first : null),
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: _languages
                            .map((l) => DropdownMenuItem(
                                  value: l,
                                  child: Text(l, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) async {
                          if (val == null) return;
                          setState(() {
                            _language = val;
                            _selectedVoice = null;
                          });
                          await widget.ttsService.setLanguage(val);
                        },
                      ),

                const SizedBox(height: 16),

                // ── Voz ──
                const Text(
                  'Voz',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                _loadingVoices
                    ? const SizedBox.shrink()
                    : _voicesForLanguage.isEmpty
                        ? Text(
                            'No hay voces instaladas para este idioma',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value: _selectedVoice != null &&
                                    _voicesForLanguage.any((v) =>
                                        v['name'] == _selectedVoice!['name'])
                                ? _selectedVoice!['name']
                                : null,
                            isExpanded: true,
                            hint: const Text('Voz por defecto'),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: _voicesForLanguage
                                .map((v) => DropdownMenuItem<String>(
                                      value: v['name'] as String?,
                                      child: Text(
                                        v['name'] as String? ?? '',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (name) async {
                              if (name == null) return;
                              final voice = _voicesForLanguage.firstWhere(
                                (v) => v['name'] == name,
                              );
                              final voiceMap = {
                                'name': voice['name'] as String,
                                'locale': voice['locale'] as String,
                                'id': (voice['id'] as String?) ?? '',
                              };
                              setState(() => _selectedVoice = voiceMap);
                              await widget.ttsService.setVoice(voiceMap);
                            },
                          ),

                const SizedBox(height: 12),
                FutureBuilder<bool>(
                  future: _isSelectedVoiceDownloaded(),
                  builder: (context, snapshot) {
                    final downloaded = snapshot.data ?? false;
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: downloaded
                            ? Colors.green.withValues(alpha: 0.08)
                            : Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: downloaded
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            downloaded ? Icons.check_circle : Icons.warning_amber,
                            color: downloaded ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              downloaded
                                  ? 'Modelo descargado y listo'
                                  : 'Modelo no descargado',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _downloadingVoice ? null : _downloadSelectedVoice,
                        icon: const Icon(Icons.download),
                        label: const Text('Descargar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _downloadingVoice ? null : _deleteSelectedVoice,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar'),
                      ),
                    ),
                  ],
                ),
                if (_downloadingVoice) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _downloadProgress),
                ],
                if (_downloadError != null && _downloadError!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _downloadError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _previewVoice,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Preview'),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Velocidad ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Velocidad',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _rate.toStringAsFixed(2),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                Slider(
                  value: _rate,
                  min: 0.1,
                  max: 1.2,
                  divisions: 22,
                  activeColor: customColor[500],
                  onChanged: (v) => setState(() => _rate = v),
                  onChangeEnd: (v) => widget.ttsService.setSpeechRate(v),
                ),

                // ── Tono ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tono',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _pitch.toStringAsFixed(2),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                Slider(
                  value: _pitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 30,
                  activeColor: customColor[500],
                  onChanged: (v) => setState(() => _pitch = v),
                  onChangeEnd: (v) => widget.ttsService.setPitch(v),
                ),

                // ── Volumen ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Volumen',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${(_volume * 100).round()}%',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                Slider(
                  value: _volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  activeColor: customColor[500],
                  onChanged: (v) => setState(() => _volume = v),
                  onChangeEnd: (v) => widget.ttsService.setVolume(v),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Repeticiones',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: _repeatCount,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 vez')),
                    DropdownMenuItem(value: 3, child: Text('3 veces')),
                    DropdownMenuItem(value: 5, child: Text('5 veces')),
                    DropdownMenuItem(value: -1, child: Text('Infinito')),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() => _repeatCount = value);
                    await widget.ttsService.setRepeatCount(value);
                  },
                ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pausa entre repeticiones',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text('$_repeatDelaySeconds s'),
                  ],
                ),
                Slider(
                  value: _repeatDelaySeconds.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  activeColor: customColor[500],
                  onChanged: (value) =>
                      setState(() => _repeatDelaySeconds = value.round()),
                  onChangeEnd: (value) =>
                      widget.ttsService.setRepeatDelaySeconds(value.round()),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
