import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Unified Voice Service — flutter_tts on all platforms (web + mobile)
class UnifiedVoiceService {
  static final UnifiedVoiceService _instance = UnifiedVoiceService._internal();
  factory UnifiedVoiceService() => _instance;
  UnifiedVoiceService._internal();

  FlutterTts? _tts;
  bool _isInitialized = false;

  /// Speed on a scale where 1.0 is ordinary talking speed, whatever the
  /// platform. Converted by [_platformRate] on the way to the engine.
  double _speechRate = 1.0;
  double _pitch = 1.0;
  String _language = 'en-AU';

  static const Map<String, double> speedPresets = {
    'slow': 0.8,
    'normal': 1.0,
    'fast': 1.25,
    'very_fast': 1.5,
  };

  /// flutter_tts does not use one scale.
  ///
  /// Android and iOS take 0.0-1.0 where **0.5** is normal speech; the web
  /// speech API takes 0-10 where **1.0** is normal. The app set 1.1 on every
  /// platform, which is about right on the web and roughly double speed on a
  /// phone — which is exactly how it sounded in the field.
  static double _platformRate(double normalised) {
    if (kIsWeb) return normalised.clamp(0.1, 3.0);
    return (normalised * 0.5).clamp(0.0, 1.0);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _tts = FlutterTts();
    try {
      await _tts!.setLanguage(_language);
      await _tts!.setSpeechRate(_platformRate(_speechRate));
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
    _speechRate = speedPresets[speed] ?? 1.0;
    try {
      await _tts?.setSpeechRate(_platformRate(_speechRate));
    } catch (_) {}
  }

  Future<void> setCustomSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.5, 2.0);
    try {
      await _tts?.setSpeechRate(_platformRate(_speechRate));
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
