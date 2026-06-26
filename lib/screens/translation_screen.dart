import 'package:connect/services/translation_service.dart';
import 'package:connect/services/tts_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({Key? key}) : super(key: key);

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TextEditingController _inputController = TextEditingController();
  final TranslationService _translationService = TranslationService();
  final TtsService _ttsService = TtsService();

  TranslationResult? _result;
  bool _isLoading = false;
  String _errorMessage = '';

  // true = ES→EN, false = EN→ES
  bool _esToEn = true;

  String get _fromLang => _esToEn ? 'es' : 'en';
  String get _toLang => _esToEn ? 'en' : 'es';
  String get _fromLabel => _esToEn ? 'Español' : 'Inglés';
  String get _toLabel => _esToEn ? 'Inglés' : 'Español';
  String get _ttsFrom => _esToEn ? 'es-MX' : 'en-US';
  String get _ttsTo => _esToEn ? 'en-US' : 'es-MX';

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _result = null;
    });

    try {
      final result = await _translationService.translate(
        text,
        from: _fromLang,
        to: _toLang,
      );
      setState(() {
        _result = result;
      });
    } on TranslationException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Error de conexión. Verifica tu internet.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _swapLanguages() {
    final currentText = _result?.translated ?? '';
    setState(() {
      _esToEn = !_esToEn;
      _result = null;
      _errorMessage = '';
      if (currentText.isNotEmpty) {
        _inputController.text = currentText;
      }
    });
    if (currentText.isNotEmpty) {
      _translate();
    }
  }

  Future<void> _speak(String text, String ttsLang) async {
    try {
      await _ttsService.setLanguage(ttsLang);
      await _ttsService.speak(text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: customColor[700],
        title: const Text(
          'Traductor',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLanguageSelector(),
            const SizedBox(height: 16),
            _buildInputCard(),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _translate,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.translate),
                label: Text(
                  _isLoading ? 'Traduciendo...' : 'Traducir',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: customColor[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage.isNotEmpty) _buildErrorCard(),
            if (_result != null) _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLangChip(_fromLabel, isSource: true),
            IconButton(
              icon: Icon(Icons.swap_horiz, color: customColor[600], size: 30),
              tooltip: 'Invertir idiomas',
              onPressed: _swapLanguages,
            ),
            _buildLangChip(_toLabel, isSource: false),
          ],
        ),
      ),
    );
  }

  Widget _buildLangChip(String label, {required bool isSource}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: customColor[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: customColor[700],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  _fromLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: customColor[600],
                  ),
                ),
                const Spacer(),
                if (_inputController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    color: Colors.grey,
                    tooltip: 'Limpiar',
                    onPressed: () => setState(() {
                      _inputController.clear();
                      _result = null;
                      _errorMessage = '';
                    }),
                  ),
              ],
            ),
            TextField(
              controller: _inputController,
              maxLines: 4,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Escribe el texto a traducir...',
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _translate(),
            ),
            if (_inputController.text.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.volume_up_outlined, color: customColor[400]),
                  tooltip: 'Escuchar original',
                  onPressed: () => _speak(_inputController.text, _ttsFrom),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _result!;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: customColor[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  _toLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: customColor[600],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.copy, size: 20, color: customColor[400]),
                  tooltip: 'Copiar traducción',
                  onPressed: () => _copyToClipboard(result.translated),
                ),
                IconButton(
                  icon: Icon(Icons.volume_up, color: customColor[500]),
                  tooltip: 'Escuchar traducción',
                  onPressed: () => _speak(result.translated, _ttsTo),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              result.translated,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            if (result.alternatives.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Otras traducciones',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: result.alternatives
                    .map(
                      (alt) => GestureDetector(
                        onTap: () {
                          _inputController.text = alt;
                          _esToEn = !_esToEn;
                          _translate();
                          setState(() => _esToEn = !_esToEn);
                        },
                        child: Chip(
                          label: Text(
                            alt,
                            style: TextStyle(
                              fontSize: 13,
                              color: customColor[700],
                            ),
                          ),
                          backgroundColor: customColor[50],
                          side: BorderSide(color: customColor[200]!),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
