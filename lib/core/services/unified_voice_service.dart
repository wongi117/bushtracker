import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

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
    _flutterTts = FlutterTts();
    await _flutterTts!.setLanguage(_language);
    await _flutterTts!.setSpeechRate(_speechRate);
    await _flutterTts!.setPitch(_pitch);
    await _flutterTts!.setVolume(1.0);
    _isInitialized = true;
    debugPrint('Voice: FlutterTTS initialized');
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();
    if (text.isEmpty) return;
    await _flutterTts?.stop();
    await _flutterTts?.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts?.stop();
  }

  Future<void> cancel() => stop();

  Future<void> setSpeechRate(String speed) async {
    final rate = speedPresets[speed] ?? 1.1;
    _speechRate = rate;
    await _flutterTts?.setSpeechRate(rate);
  }

  Future<void> setCustomSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.5, 2.0);
    await _flutterTts?.setSpeechRate(_speechRate);
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    await _flutterTts?.setPitch(pitch);
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    await _flutterTts?.setLanguage(_language);
  }

  Map<String, dynamic> getSettings() {
    return {
      'isWeb': kIsWeb,
      'speechRate': _speechRate,
      'pitch': _pitch,
      'language': _language,
    };
  }
}

final voiceService = VoiceService();
