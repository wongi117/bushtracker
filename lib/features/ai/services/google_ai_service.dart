import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:bush_track/core/config/api_config.dart';
import 'package:flutter/foundation.dart';

/// Service for Google's Cloud AI (Gemini/Gemma)
class GoogleAIService {
  late final GenerativeModel _model;
  bool _isInitialized = false;

  GoogleAIService() {
    _initialize();
  }

  void _initialize() {
    try {
      if (ApiConfig.geminiKey.isEmpty) {
        debugPrint('⚠️ GoogleAIService: API Key is missing');
        return;
      }

      // Initialize the model with the provided name
      _model = GenerativeModel(
        model: ApiConfig.googleModelName,
        apiKey: ApiConfig.geminiKey,
      );
      _isInitialized = true;
      debugPrint('✅ GoogleAIService: Initialized with model ${ApiConfig.googleModelName}');
    } catch (e) {
      debugPrint('❌ GoogleAIService: Initialization failed: $e');
    }
  }

  Future<String?> getResponse(String prompt, {Map<String, dynamic>? context}) async {
    if (!_isInitialized) {
      _initialize();
      if (!_isInitialized) return null;
    }

    try {
      String contextString = '';
      if (context != null && context.isNotEmpty) {
        contextString = '\n\nContext: ${context.toString()}';
      }

      final content = [Content.text(prompt + contextString)];
      final response = await _model.generateContent(content);
      
      return response.text;
    } catch (e) {
      debugPrint('❌ GoogleAIService: Error generating content: $e');
      return null;
    }
  }

  bool get isReady => _isInitialized;
}
