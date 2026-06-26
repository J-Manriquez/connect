import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connect/models/dictionary_entry.dart';

class DictionaryService {
  static const String _enBaseUrl = 'https://api.dictionaryapi.dev/api/v2/entries';
  static const String _wiktiApiBase = 'https://es.wiktionary.org/w/api.php';

  /// Busca el significado de una [word] en el idioma especificado.
  /// Para español usa la API de Wiktionary en español.
  /// Para inglés usa dictionaryapi.dev.
  Future<List<DictionaryEntry>> search(String word, {String language = 'es'}) async {
    if (language == 'es') {
      return _searchWiktionary(word.trim());
    }
    return _searchEnglish(word.trim());
  }

  Future<List<DictionaryEntry>> _searchEnglish(String word) async {
    final uri = Uri.parse('$_enBaseUrl/en/${Uri.encodeComponent(word)}');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => DictionaryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (response.statusCode == 404) {
      throw DictionaryNotFoundException('No se encontró la definición de "$word"');
    } else {
      throw DictionaryException('Error al consultar el diccionario (código ${response.statusCode})');
    }
  }

  Future<List<DictionaryEntry>> _searchWiktionary(String word) async {
    final uri = Uri.parse(
      '$_wiktiApiBase?action=query&titles=${Uri.encodeComponent(word)}'
      '&prop=extracts&format=json&explaintext=true&redirects=1',
    );
    final response = await http.get(
      uri,
      headers: {'User-Agent': 'Connect-App/1.0'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw DictionaryException('Error al consultar el diccionario (código ${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final pages = (json['query']?['pages'] as Map<String, dynamic>?) ?? {};
    if (pages.isEmpty) throw DictionaryNotFoundException('No se encontró "$word"');

    final page = pages.values.first as Map<String, dynamic>;
    if (page.containsKey('missing')) {
      throw DictionaryNotFoundException('No se encontró la definición de "$word"');
    }

    final extract = (page['extract'] as String? ?? '').trim();
    if (extract.isEmpty) throw DictionaryNotFoundException('No se encontró la definición de "$word"');

    return [_parseWiktionaryExtract(word, extract)];
  }

  /// Parsea el texto plano de Wiktionary en un [DictionaryEntry].
  DictionaryEntry _parseWiktionaryExtract(String word, String extract) {
    final meanings = <Meaning>[];
    // Split by sections (== or ===)
    final lines = extract.split('\n');
    String currentPos = '';
    final defs = <Definition>[];

    void flushPos() {
      if (defs.isNotEmpty && currentPos.isNotEmpty) {
        meanings.add(Meaning(
          partOfSpeech: currentPos,
          definitions: List<Definition>.from(defs),
          synonyms: [],
          antonyms: [],
        ));
        defs.clear();
      }
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Section headers like == Español == or === Sustantivo ===
      final headerMatch = RegExp(r'^={2,4}\s*(.+?)\s*={2,4}$').firstMatch(trimmed);
      if (headerMatch != null) {
        final header = headerMatch.group(1)!;
        // Skip language headers; treat grammar categories as partOfSpeech
        final isLang = RegExp(r'^(Español|English|Inglés|Francés|Alemán|Portugués)$', caseSensitive: false)
            .hasMatch(header);
        if (!isLang) {
          flushPos();
          currentPos = header;
        }
        continue;
      }

      // Numbered definition lines like "1. definición" or "# definición"
      final defMatch = RegExp(r'^[#\d][.:\s]\s*(.+)').firstMatch(trimmed);
      if (defMatch != null && currentPos.isNotEmpty) {
        final defText = defMatch.group(1)!.trim();
        if (defText.isNotEmpty && !defText.startsWith('=')) {
          defs.add(Definition(definition: defText, synonyms: [], antonyms: []));
        }
        continue;
      }

      // Bullet definitions
      if ((trimmed.startsWith('•') || trimmed.startsWith('-') || trimmed.startsWith('*')) &&
          currentPos.isNotEmpty) {
        final defText = trimmed.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim();
        if (defText.isNotEmpty) {
          defs.add(Definition(definition: defText, synonyms: [], antonyms: []));
        }
      }
    }
    flushPos();

    // If we got nothing structured, create a single "definition" entry with raw text
    if (meanings.isEmpty) {
      final firstLines = lines
          .where((l) => l.trim().isNotEmpty && !RegExp(r'^={2,}').hasMatch(l.trim()))
          .take(5)
          .join(' ');
      meanings.add(Meaning(
        partOfSpeech: 'definición',
        definitions: [Definition(definition: firstLines, synonyms: [], antonyms: [])],
        synonyms: [],
        antonyms: [],
      ));
    }

    return DictionaryEntry(word: word, meanings: meanings);
  }
}

class DictionaryException implements Exception {
  final String message;
  DictionaryException(this.message);
  @override
  String toString() => message;
}

class DictionaryNotFoundException extends DictionaryException {
  DictionaryNotFoundException(super.message);
}
