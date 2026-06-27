import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Service pour interagir avec les API Google Cloud (Speech-to-Text et Translation).
class GoogleCloudVoiceService {
  final String apiKey;

  GoogleCloudVoiceService({required this.apiKey});

  /// Traduit du texte (Bambara, Wolof, Dioula, Peul, etc.) vers le Français (fr) via Google Cloud Translation API.
  Future<String> translateBambaraToFrench(String text) async {
    if (apiKey.isEmpty || text.trim().isEmpty) return text;

    final url = Uri.parse('https://translation.googleapis.com/language/translate/v2?key=$apiKey');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': text,
          // 'source' est omis pour permettre l'auto-détection automatique de la langue locale (Bambara, Wolof, Peul, etc.)
          'target': 'fr',
          'format': 'text',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['data'] != null && data['data']['translations'] != null && data['data']['translations'].isNotEmpty) {
          final translated = data['data']['translations'][0]['translatedText']?.toString() ?? text;
          debugPrint('[GoogleTranslate] Traduction réussie : "$text" -> "$translated"');
          return translated;
        }
      } else {
        debugPrint('[GoogleTranslate] Erreur API ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[GoogleTranslate] Exception: $e');
    }
    return text;
  }

  /// Transcrit de l'audio en Bambara (bm-ML) via Google Cloud Speech-to-Text API v1.
  Future<String> transcribeBambara(List<int> audioBytes, {int sampleRate = 16000}) async {
    if (apiKey.isEmpty || audioBytes.isEmpty) return '';

    final url = Uri.parse('https://speech.googleapis.com/v1/speech:recognize?key=$apiKey');
    final base64Audio = base64Encode(audioBytes);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'config': {
            'encoding': 'LINEAR16',
            'sampleRateHertz': sampleRate,
            'languageCode': 'fr-FR',
            'alternativeLanguageCodes': ['fr-ML', 'bm-ML', 'wo-SN', 'en-US'],
            'enableAutomaticPunctuation': true,
          },
          'audio': {
            'content': base64Audio,
          }
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['results'] != null && data['results'].isNotEmpty) {
          final List results = data['results'];
          final transcription = results.map((res) {
            if (res['alternatives'] != null && res['alternatives'].isNotEmpty) {
              return res['alternatives'][0]['transcript']?.toString() ?? '';
            }
            return '';
          }).join(' ');
          
          final finalTranscription = transcription.trim();
          debugPrint('[GoogleSTT] Transcription réussie : "$finalTranscription"');
          return finalTranscription;
        }
      } else {
        debugPrint('[GoogleSTT] Erreur API ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[GoogleSTT] Exception: $e');
    }
    return '';
  }
}
