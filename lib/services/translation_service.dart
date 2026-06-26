import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  static const String _baseUrl = 'https://api.mymemory.translated.net/get';

  /// Traduce [text] del idioma [from] al idioma [to].
  /// Ej: from='es', to='en' o from='en', to='es'.
  /// Lanza [TranslationException] si hay error.
  Future<TranslationResult> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'q': text.trim(),
      'langpair': '$from|$to',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final responseData = data['responseData'] as Map<String, dynamic>?;
      final translatedText = responseData?['translatedText'] as String?;

      if (translatedText == null || translatedText.isEmpty) {
        throw TranslationException('No se obtuvo traducción para el texto.');
      }

      // Extraer coincidencias alternativas si existen
      final matches = (data['matches'] as List<dynamic>? ?? [])
          .take(3)
          .map((m) => (m as Map<String, dynamic>)['translation'] as String? ?? '')
          .where((t) => t.isNotEmpty && t != translatedText)
          .toSet()
          .toList();

      return TranslationResult(
        original: text.trim(),
        translated: translatedText,
        alternatives: matches,
        fromLang: from,
        toLang: to,
      );
    } else {
      throw TranslationException(
          'Error al traducir (código ${response.statusCode})');
    }
  }
}

class TranslationResult {
  final String original;
  final String translated;
  final List<String> alternatives;
  final String fromLang;
  final String toLang;

  TranslationResult({
    required this.original,
    required this.translated,
    required this.alternatives,
    required this.fromLang,
    required this.toLang,
  });
}

class TranslationException implements Exception {
  final String message;
  TranslationException(this.message);
  @override
  String toString() => message;
}
