import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bush_track/core/config/api_config.dart';
import 'package:flutter/foundation.dart';

/// Google Gemini via REST — avoids SDK CORS issues on Flutter web
class GoogleAIService {
  static String selectedModel = 'gemini-2.5-flash-preview-04-17';

  String get currentModel => selectedModel;
  bool get isReady => ApiConfig.geminiKey.isNotEmpty;

  Future<String?> getResponse(String prompt,
      {Map<String, dynamic>? context, String? systemPrompt}) async {
    if (ApiConfig.geminiKey.isEmpty) {
      debugPrint('⚠️ GoogleAIService: GEMINI_KEY not configured');
      return null;
    }

    try {
      String contextString = '';
      if (context != null && context.isNotEmpty) {
        contextString =
            '\n\nContext: ${context.entries.map((e) => '${e.key}: ${e.value}').join(', ')}';
      }

      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/$selectedModel:generateContent?key=${ApiConfig.geminiKey}';

      final body = <String, dynamic>{
        'contents': [
          {
            'parts': [
              {'text': prompt + contextString}
            ]
          }
        ],
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
