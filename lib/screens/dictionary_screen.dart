import 'package:connect/models/dictionary_entry.dart';
import 'package:connect/services/dictionary_service.dart';
import 'package:connect/services/tts_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({Key? key}) : super(key: key);

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DictionaryService _dictionaryService = DictionaryService();
  final TtsService _ttsService = TtsService();

  List<DictionaryEntry> _results = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _selectedLanguage = 'es';

  final Map<String, String> _languages = {
    'es': 'Español',
    'en': 'Inglés',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final word = _searchController.text.trim();
    if (word.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _results = [];
    });

    try {
      final entries = await _dictionaryService.search(word, language: _selectedLanguage);
      setState(() {
        _results = entries;
      });
    } on DictionaryNotFoundException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } on DictionaryException catch (e) {
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

  Future<void> _speakText(String text) async {
    final lang = _selectedLanguage == 'es' ? 'es-MX' : 'en-US';
    try {
      await _ttsService.setLanguage(lang);
      await _ttsService.speak(text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: customColor[700],
        title: const Text(
          'Diccionario',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? _buildErrorState()
                    : _results.isEmpty
                        ? _buildEmptyState()
                        : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: customColor[700],
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar palabra...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _results = [];
                                _errorMessage = '';
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isLoading ? null : _search,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: customColor[700],
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Buscar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Idioma:',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(width: 12),
              ..._languages.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _selectedLanguage == entry.key,
                      onSelected: (_) {
                        setState(() {
                          _selectedLanguage = entry.key;
                          _results = [];
                          _errorMessage = '';
                        });
                      },
                      selectedColor: Colors.white,
                      labelStyle: TextStyle(
                        color: _selectedLanguage == entry.key
                            ? customColor[700]
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: customColor[700]!.withValues(alpha: 0.5),
                      side: const BorderSide(color: Colors.white54),
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 72, color: customColor[200]),
          const SizedBox(height: 16),
          Text(
            'Busca el significado de una palabra',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Escribe en el campo de arriba y presiona Buscar',
            style: TextStyle(fontSize: 14, color: Colors.grey[400], fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) => _buildEntryCard(_results[index]),
    );
  }

  Widget _buildEntryCard(DictionaryEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado: palabra + fonética + botón TTS
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.word,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: customColor[700],
                        ),
                      ),
                      if (entry.phonetic != null && entry.phonetic!.isNotEmpty)
                        Text(
                          entry.phonetic!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.volume_up, color: customColor[600]),
                  tooltip: 'Escuchar pronunciación',
                  onPressed: () => _speakText(entry.word),
                ),
              ],
            ),
            const Divider(height: 20),
            // Significados
            ...entry.meanings.map((meaning) => _buildMeaning(meaning)),
          ],
        ),
      ),
    );
  }

  Widget _buildMeaning(Meaning meaning) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Categoría gramatical
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: customColor[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              meaning.partOfSpeech,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: customColor[700],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Definiciones
          ...meaning.definitions.take(3).toList().asMap().entries.map(
                (e) => _buildDefinition(e.key + 1, e.value),
              ),
          // Sinónimos
          if (meaning.synonyms.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildWordChips('Sinónimos', meaning.synonyms.take(5).toList(), Colors.green[100]!, Colors.green[800]!),
          ],
          // Antónimos
          if (meaning.antonyms.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildWordChips('Antónimos', meaning.antonyms.take(5).toList(), Colors.red[100]!, Colors.red[800]!),
          ],
        ],
      ),
    );
  }

  Widget _buildDefinition(int index, Definition definition) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index. ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: customColor[600],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.definition,
                  style: const TextStyle(fontSize: 15),
                ),
                if (definition.example != null && definition.example!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          definition.example!,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.volume_up_outlined, size: 18, color: customColor[400]),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Escuchar ejemplo',
                        onPressed: () => _speakText(definition.example!),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordChips(String label, List<String> words, Color bgColor, Color textColor) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Text(
          '$label:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[700]),
        ),
        ...words.map(
          (w) => GestureDetector(
            onTap: () {
              _searchController.text = w;
              _search();
            },
            child: Chip(
              label: Text(w, style: TextStyle(fontSize: 12, color: textColor)),
              backgroundColor: bgColor,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
