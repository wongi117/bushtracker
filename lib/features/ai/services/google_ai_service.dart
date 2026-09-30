import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bush_track/core/config/api_config.dart';
import 'package:flutter/foundation.dart';

/// Google Gemini via REST — avoids SDK CORS issues on Flutter web
class GoogleAIService {
  // The dated preview id 404s — preview models are withdrawn once the stable
  // release lands. Use the stable name.
  static String selectedModel = 'gemini-2.5-flash';

  String get currentModel => selectedModel;
  bool get isReady => kIsWeb || ApiConfig.geminiKey.isNotEmpty;

  Future<String?> getResponse(String prompt,
      {Map<String, dynamic>? context,
      String? systemPrompt,
      List<Map<String, String>>? conversationHistory}) async {
    // On web the key lives server-side in the proxy, so an empty client key
    // is expected and must not stop the attempt.
    if (!kIsWeb && ApiConfig.geminiKey.isEmpty) {
      debugPrint('⚠️ GoogleAIService: GEMINI_KEY not configured');
      return null;
    }

    try {
      String contextString = '';
      if (context != null && context.isNotEmpty) {
        contextString =
            '\n\nContext: ${context.entries.map((e) => '${e.key}: ${e.value}').join(', ')}';
      }

      // On web the key goes through our own proxy. It used to be pasted into
      // the query string of a request made from the browser, which put a live
      // Google API key in the page's network log for anyone to lift.
      final url = kIsWeb
          ? '/api/gemini?model=$selectedModel'
          : 'https://generativelanguage.googleapis.com/v1beta/models/$selectedModel:generateContent?key=${ApiConfig.geminiKey}';

      // Every earlier turn, not just the latest message. Gemini was the only
      // tier not given the history, and it is the tier that actually answers
      // — so the assistant forgot the previous question every single time.
      final contents = <Map<String, dynamic>>[];
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        for (final m in conversationHistory) {
          final text = m['content'] ?? '';
          if (text.isEmpty) continue;
          contents.add({
            // Gemini calls the assistant side "model".
            'role': m['role'] == 'assistant' ? 'model' : 'user',
            'parts': [
              {'text': text}
            ],
          });
        }
        // A conversation has to start with the user.
        while (contents.isNotEmpty && contents.first['role'] == 'model') {
          contents.removeAt(0);
        }
      }

      if (contents.isEmpty) {
        contents.add({
          'role': 'user',
          'parts': [
            {'text': prompt + contextString}
          ],
        });
      } else if (contextString.isNotEmpty) {
        // Keep the live context (position, time, waypoints) attached to the
        // most recent user message.
        final last = contents.last;
        if (last['role'] == 'user') {
          final parts = last['parts'] as List;
          final text = (parts.first as Map)['text'] as String;
          parts[0] = {'text': text + contextString};
        }
      }

      final body = <String, dynamic>{
        'contents': contents,
        'generationConfig': {
          'maxOutputTokens': 1024,
          'temperature': 0.7,
        },
      };

      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        body['systemInstruction'] = {
          'parts': [
            {'text': systemPrompt}
          ]
        };
      }

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null && text.toString().isNotEmpty) {
          return text.toString();
        }
      } else {
        debugPrint('⚠️ Gemini error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ GoogleAIService: $e');
    }
    return null;
  }
}
