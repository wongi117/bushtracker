import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Web Speech API bindings via dart:js_interop (Dart 3.x, replaces dart:js_util)
import 'dart:js_interop';

@JS('SpeechSynthesisUtterance')
extension type _SpeechUtterance._(JSObject _) implements JSObject {
  external factory _SpeechUtterance(String text);
  external set rate(double rate);
  external set pitch(double pitch);
  external set lang(String lang);
}

extension type _SpeechSynthesis._(JSObject _) implements JSObject {
  external void speak(_SpeechUtterance utterance);
  external void cancel();
  external bool get speaking;
}

@JS('window.speechSynthesis')
external _SpeechSynthesis? get _webSynth;

/// Unified Voice Service — Web Speech API on web, flutter_tts on mobile
class UnifiedVoiceService {
  static final UnifiedVoiceService _instance = UnifiedVoiceService._internal();
  factory UnifiedVoiceService() => _instance;
  UnifiedVoiceService._internal();

  FlutterTts? _flutterTts;
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
    if (kIsWeb) {
      _isInitialized = true;
      debugPrint('🎤 Voice: Web Speech API ready');
    } else {
      _flutterTts = FlutterTts();
      await _flutterTts!.setLanguage(_language);
      await _flutterTts!.setSpeechRate(_speechRate);
      await _flutterTts!.setPitch(_pitch);
      await _flutterTts!.setVolume(1.0);
      _isInitialized = true;
      debugPrint('🎤 Voice: FlutterTTS initialized');
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();
    if (text.isEmpty) return;
    if (kIsWeb) {
      _speakWeb(text);
    } else {
      await _flutterTts?.speak(text);
    }
  }

  Future<void> stop() async {
    if (kIsWeb) {
      _stopWeb();
    } else {
      await _flutterTts?.stop();
    }
  }

  Future<void> setSpeechRate(String speed) async {
    _speechRate = speedPresets[speed] ?? 1.1;
    if (!kIsWeb) await _flutterTts?.setSpeechRate(_speechRate);
  }

  Future<void> setCustomSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.5, 2.0);
    if (!kIsWeb) await _flutterTts?.setSpeechRate(_speechRate);
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    if (!kIsWeb) await _flutterTts?.setPitch(pitch);
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    if (!kIsWeb) await _flutterTts?.setLanguage(language);
  }

  void _speakWeb(String text) {
    try {
      final synth = _webSynth;
      if (synth == null) {
        debugPrint('⚠️ Web Speech API not available');
        return;
      }
      final utterance = _SpeechUtterance(text);
      utterance.rate = _speechRate;
      utterance.pitch = _pitch;
      utterance.lang = _language;
      synth.speak(utterance);
      debugPrint('🎤 Web Speech: Speaking');
    } catch (e) {
      debugPrint('❌ Web Speech Error: $e');
    }
  }

  void _stopWeb() {
    try {
      _webSynth?.cancel();
    } catch (e) {
      debugPrint('❌ Stop Web Speech Error: $e');
    }
  }

  bool get isSpeaking {
    if (kIsWeb) {
      try {
        return _webSynth?.speaking ?? false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  Map<String, dynamic> getSettings() => {
        'isWeb': kIsWeb,
        'speechRate': _speechRate,
        'pitch': _pitch,
        'language': _language,
      };
}

final unifiedVoiceService = UnifiedVoiceService();
