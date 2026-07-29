import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:bush_track/features/ai/services/offline_ai_service.dart';

/// On-device AI using Google's Gemma model
/// Provides TRUE offline AI inference on supported devices:
/// - Android: arm64-v8a (most modern Android phones)
/// - iOS: arm64 devices (iPhone XS and newer, not simulator)
/// Falls back to rule-based offline AI on unsupported platforms
class OnDeviceAIService {
  static final OnDeviceAIService _instance = OnDeviceAIService._internal();
  factory OnDeviceAIService() => _instance;
  OnDeviceAIService._internal();

  bool _isInitialized = false;
  bool _isSupported = false;
  String _status = 'Not initialized';
  String? _lastError;

  bool get isInitialized => _isInitialized;
  bool get isSupported => _isSupported;
  String get status => _status;
  String? get lastError => _lastError;

  /// Check if this device supports on-device inference
  bool _checkPlatformSupport() {
    if (kIsWeb) {
      _status = 'Web not supported';
      return false;
    }
    
    if (Platform.isAndroid) {
      _status = 'Android detected - checking...';
      return true; // Will validate at runtime
    }
    
    if (Platform.isIOS) {
      _status = 'iOS detected - checking...';
      return true; // Will validate at runtime
    }
    
    _status = 'Platform not supported: ${Platform.operatingSystem}';
    return false;
  }

  /// Initialize the Gemma model
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isSupported = _checkPlatformSupport();
    if (!_isSupported) {
      print('📱 ANTIGRAVITY: On-device AI not supported - $_status');
      return;
    }

    try {
      _status = 'Initializing Gemma...';
      print('🤖 ANTIGRAVITY: Initializing on-device Gemma AI...');
      
      // Initialize Gemma with default settings
      // Note: First run downloads ~2.5GB model
      await Gemma.instance.init(maxTokens: 512);
      
      _isInitialized = true;
      _status = 'Gemma AI Ready';
      print('✅ ANTIGRAVITY: Gemma on-device AI initialized!');
      
    } catch (e) {
      _isInitialized = false;
      _isSupported = false;
      _lastError = e.toString();
      _status = 'Failed: ${e.toString().substring(0, e.toString().length > 50 ? 50 : e.toString().length)}...';
      print('❌ ANTIGRAVITY: Gemma initialization failed: $e');
      print('📱 ANTIGRAVITY: Falling back to rule-based offline AI');
    }
  }

  /// Generate response using on-device AI or fallback
  Future<String> generateResponse(
    String prompt, {
    Map<String, dynamic>? context,
  }) async {
    // Try on-device AI first if initialized
    if (_isInitialized) {
      try {
        final fullPrompt = _buildPrompt(prompt, context);
        
        print('🧠 ANTIGRAVITY: Running on-device inference...');
        
        final response = await Gemma.instance.getResponse(prompt: fullPrompt);
        
        if (response != null && response.isNotEmpty) {
          final cleanResponse = _cleanResponse(response);
          print('✅ ANTIGRAVITY: On-device response generated');
          return cleanResponse;
        } else {
          print('⚠️ ANTIGRAVITY: Gemma returned empty response');
        }
      } catch (e) {
        print('❌ ANTIGRAVITY: On-device inference failed: $e');
        // Fall through to rule-based fallback
      }
    }
    
    // Fallback to rule-based offline AI
    return _generateFallbackResponse(prompt, context);
  }

  /// Build the full prompt with context
  String _buildPrompt(String userPrompt, Map<String, dynamic>? context) {
    String systemContext = '''You are Antigravity, a survival AI for remote outdoor activities.
Safety first, be concise (under 20 seconds when spoken), calm tone, actionable advice.

Current situation:''';

    if (context != null) {
      final location = context['current_location'];
      final distance = context['distance_traveled'];
      final meshNodes = context['mesh_connected_nodes'];
      
      if (location != null) systemContext += '\n- Location: $location';
      if (distance != null) systemContext += '\n- Traveled: $distance';
      if (meshNodes != null) systemContext += '\n- Nearby devices: $meshNodes';
    }
    
    return '$systemContext\n\nUser: $userPrompt\nAntigravity:';
  }

  /// Clean up Gemma response for voice output
  String _cleanResponse(String response) {
    // Remove common prefixes
    String cleaned = response
        .replaceAll(RegExp(r'^(User:|Antigravity:|Assistant:)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\n\n+'), '\n')
        .trim();
    
    // Limit to ~200 words for voice
    final words = cleaned.split(' ');
    if (words.length > 200) {
      cleaned = words.take(200).join(' ') + '...';
    }
    
    return cleaned;
  }

  /// Generate fallback response using rule-based system
  String _generateFallbackResponse(String prompt, Map<String, dynamic>? context) {
    String? coordsDecimal;
    int? connectedPeers;
    
    if (context != null) {
      coordsDecimal = context['current_location']?.toString();
      final meshCount = context['mesh_connected_nodes'];
      if (meshCount is int) {
        connectedPeers = meshCount;
      }
    }
    
    return OfflineAIService.generateResponse(
      prompt,
      locationStats: coordsDecimal != null ? LocationStats(coordsDecimal: coordsDecimal) : null,
      meshState: OfflineMeshState(connectedEndpoints: connectedPeers != null ? List.filled(connectedPeers, 'peer') : []),
    );
  }

  /// Get model info
  Map<String, dynamic> getModelInfo() {
    return {
      'is_initialized': _isInitialized,
      'is_supported': _isSupported,
      'status': _status,
      'last_error': _lastError,
      'platform': Platform.operatingSystem,
      'model': 'Gemma (via flutter_gemma)',
      'type': 'On-device inference',
    };
  }
}

// Singleton instance
final onDeviceAIService = OnDeviceAIService();
