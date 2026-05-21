import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Unified Voice Service — flutter_tts on all platforms (web + mobile)
class UnifiedVoiceService {
  static final UnifiedVoiceService _instance = UnifiedVoiceService._internal();
  factory UnifiedVoiceService() => _instance;
  UnifiedVoiceService._internal();

  FlutterTts? _tts;
  bool _isInitialized = false;
  double _speechRate = 1.1;
  double _pitch = 1.0;
  String _language = 'en-AU';

  static const Map<String, double> speedPresets = {
    'slow': 0.8,
    'normal': 1.1,
    'fast': 1.4,
    'very_fast': 1.7,
  };

  Future<void> initialize() async {
    if (_isInitialized) return;
    _tts = FlutterTts();
    try {
      await _tts!.setLanguage(_language);
      await _tts!.setSpeechRate(_speechRate);
      await _tts!.setPitch(_pitch);
      await _tts!.setVolume(1.0);
    } catch (e) {
      debugPrint('⚠️ TTS init warning: $e');
    }
    _isInitialized = true;
    debugPrint('🎤 Voice: FlutterTTS ready (${kIsWeb ? "web" : "native"})');
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();
    if (text.isEmpty) return;
    try {
      await _tts?.speak(text);
    } catch (e) {
      debugPrint('❌ TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (e) {
      debugPrint('❌ TTS stop error: $e');
    }
  }

  Future<void> setSpeechRate(String speed) async {
    _speechRate = speedPresets[speed] ?? 1.1;
    try {
      await _tts?.setSpeechRate(_speechRate);
    } catch (_) {}
  }

  Future<void> setCustomSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.5, 2.0);
    try {
      await _tts?.setSpeechRate(_speechRate);
    } catch (_) {}
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    try {
      await _tts?.setPitch(pitch);
    } catch (_) {}
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    try {
      await _tts?.setLanguage(language);
    } catch (_) {}
  }

  bool get isSpeaking => false; // flutter_tts doesn't expose sync getter

  Map<String, dynamic> getSettings() => {
        'isWeb': kIsWeb,
        'speechRate': _speechRate,
        'pitch': _pitch,
        'language': _language,
      };
}

final unifiedVoiceService = UnifiedVoiceService();
