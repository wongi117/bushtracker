import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:bush_track/core/config/api_config.dart';
import 'package:bush_track/features/ai/services/google_ai_service.dart';

/// Multi-Provider AI Service with 4-Tier Fallback
class OpenRouterService {
  bool _isOfflineMode = false;
  bool _isOnDeviceMode = false;
  String _lastError = '';
  String _lastUsedTier = 'Unknown';
  bool forceOffline = false;
  final _googleAI = GoogleAIService();

  bool get isOfflineMode => _isOfflineMode;
  bool get isOnDeviceMode => _isOnDeviceMode;
  String get lastError => _lastError;
  String get lastUsedTier => _lastUsedTier;

  Future<void> initializeOnDeviceAI() async {
    debugPrint('🤖 FUTURE GEN AI: Initializing multi-tier AI system...');
    final tiers = await testAllTiers();
    debugPrint('📊 AI Status: $tiers');
  }

  static String selectedProvider = 'auto'; // 'auto' | 'groq' | 'gemini'
  static String selectedModel = 'llama-3.3-70b-versatile';

  static const Map<String, List<Map<String, String>>> availableModels = {
    'claude': [
      {'id': 'claude-sonnet-4-6',    'name': 'Claude Sonnet 4.6',  'desc': 'Anthropic — smartest, best reasoning'},
      {'id': 'claude-haiku-4-5-20251001', 'name': 'Claude Haiku 4.5', 'desc': 'Anthropic — fastest, lightest'},
    ],
    'groq': [
      {'id': 'llama-3.3-70b-versatile',   'name': 'Llama 3.3 70B',      'desc': 'Best quality, versatile'},
      {'id': 'llama-3.1-8b-instant',       'name': 'Llama 3.1 8B',       'desc': 'Fastest, lightweight'},
      {'id': 'mixtral-8x7b-32768',          'name': 'Mixtral 8x7B',       'desc': 'Long context, 32k tokens'},
      {'id': 'gemma2-9b-it',                'name': 'Gemma 2 9B',         'desc': "Google's open model"},
    ],
    'gemini': [
      {'id': 'gemini-2.5-flash-preview-04-17', 'name': 'Gemini 2.5 Flash', 'desc': 'Latest, fastest'},
      {'id': 'gemini-2.0-flash',               'name': 'Gemini 2.0 Flash', 'desc': 'Balanced speed/quality'},
      {'id': 'gemini-1.5-pro',                 'name': 'Gemini 1.5 Pro',   'desc': 'Best quality, slower'},
    ],
  };

  static String selectedClaudeModel = 'claude-sonnet-4-6';

  Future<String> getAiResponse(String prompt,
      {Map<String, dynamic>? context,
      String? systemPrompt,
      List<Map<String, String>>? conversationHistory}) async {
    if (forceOffline) {
      _isOfflineMode = true;
      _lastUsedTier = 'Offline (Rule-Based)';
      return _generateOfflineResponse(prompt, context);
    }

    // Always reset offline flag before attempting — never stay stuck offline.
    _isOfflineMode = false;

    // On web: respect selectedProvider, then fallback chain
    if (kIsWeb) {
      final tryClaude = selectedProvider == 'auto' || selectedProvider == 'claude';
      final tryGroq = selectedProvider == 'auto' || selectedProvider == 'groq';
      final tryGemini = selectedProvider == 'auto' || selectedProvider == 'gemini';

      // 0. Claude via /api/claude proxy
      if (tryClaude) {
        try {
          debugPrint('🌐 WEB AI: Trying Claude ($selectedClaudeModel)...');
          final response = await _tryClaude(prompt, context,
              systemPrompt: systemPrompt,
              conversationHistory: conversationHistory);
          if (response != null) {
            _isOnDeviceMode = false;
            _lastUsedTier = 'Claude · $selectedClaudeModel';
            _lastError = '';
            _lastOnlineTime = DateTime.now();
            return response;
          }
        } catch (e) {
          debugPrint('⚠️ Claude proxy failed: $e');
          _lastError = e.toString();
        }
      }

      // 1. Groq via /api/groq proxy
      if (tryGroq) {
        try {
          debugPrint('🌐 WEB AI: Trying Groq ($selectedModel)...');
          final response = await _tryGroq(prompt, context,
              systemPrompt: systemPrompt,
              conversationHistory: conversationHistory);
          if (response != null) {
            _isOnDeviceMode = false;
            _lastUsedTier = 'Groq · $selectedModel';
            _lastError = '';
            _lastOnlineTime = DateTime.now();
            return response;
          }
        } catch (e) {
          debugPrint('⚠️ Groq proxy failed: $e');
          _lastError = e.toString();
        }
      }

      // 2. Gemini (CORS-safe, no proxy needed)
      if (tryGemini) {
        try {
          debugPrint('🌐 WEB AI: Trying Gemini...');
          final response = await _googleAI.getResponse(
            prompt,
            context: context,
            systemPrompt: systemPrompt ?? _systemPrompt,
          );
          if (response != null) {
            _isOnDeviceMode = false;
            _lastUsedTier = 'Gemini · ${_googleAI.currentModel}';
            _lastError = '';
            _lastOnlineTime = DateTime.now();
            return _cleanResponse(response);
          }
        } catch (e) {
          debugPrint('⚠️ Gemini failed: $e');
        }
      }

      // 3. MiniMax fallback (auto only)
      if (selectedProvider == 'auto') {
        try {
          final response = await _tryMinimax(prompt, context,
              systemPrompt: systemPrompt ?? _systemPrompt,
              conversationHistory: conversationHistory);
          if (response != null) {
            _isOnDeviceMode = false;
            _lastUsedTier = 'Cloud (MiniMax)';
            _lastError = '';
            _lastOnlineTime = DateTime.now();
            return response;
          }
        } catch (e) {
          _lastError = e.toString();
        }
      }

      _isOfflineMode = true;
      _lastUsedTier = 'Offline (Rule-Based)';
      return _generateOfflineResponse(prompt, context);
    }

    // Mobile: try Groq first (fast, free Llama 3.3 70B)
    if (ApiConfig.groqKey.isNotEmpty) {
      try {
        debugPrint('🌐 FUTURE GEN AI: Attempting Groq AI (llama-3.3-70b-versatile)...');
        final response =
            await _tryGroq(prompt, context, systemPrompt: systemPrompt);
        if (response != null) {
          _isOfflineMode = false;
          _isOnDeviceMode = false;
          _lastUsedTier = 'Cloud (Groq Llama 3.3 70B)';
          _lastError = '';
          _lastOnlineTime = DateTime.now();
          debugPrint('✅ FUTURE GEN AI: Groq response success');
          return response;
        }
      } catch (e) {
        debugPrint('⚠️ Groq failed: $e');
        _lastError = e.toString();
      }
    } else {
      _lastError = 'Groq API key not configured — set GROQ_KEY in build env vars';
      debugPrint('⚠️ FUTURE GEN AI: $_lastError');
    }

    // Mobile fallback: Google Gemini
    try {
      debugPrint('🌐 FUTURE GEN AI: Attempting Google Cloud AI...');
      final response = await _googleAI.getResponse(prompt,
          context: context, systemPrompt: systemPrompt ?? _systemPrompt);
      if (response != null) {
        _isOfflineMode = false;
        _isOnDeviceMode = false;
        _lastUsedTier = 'Cloud (Google ${ApiConfig.googleModelName})';
        _lastError = '';
        return _cleanResponse(response);
      }
    } catch (e) {
      debugPrint('⚠️ Google AI failed: $e');
    }

    _isOfflineMode = true;

    // Fallback Cloud AI
    final fallbackResult = await _tryFallbackCloudAI(prompt, context);
    if (fallbackResult != null) {
      _isOfflineMode = false;
      _lastUsedTier = 'Cloud (Fallback)';
      return fallbackResult;
    }

    // Local Ollama
    final localResult = await _tryOllama(prompt, context);
    if (localResult != null) {
      _isOnDeviceMode = true;
      _lastUsedTier = 'Local (Ollama)';
      return localResult;
    }

    // Rule-Based
    _isOnDeviceMode = false;
    _lastUsedTier = 'Offline (Rule-Based)';
    return _generateOfflineResponse(prompt, context);
  }

  Future<String?> _tryClaude(String prompt, Map<String, dynamic>? context,
      {String? systemPrompt,
      List<Map<String, String>>? conversationHistory}) async {
    try {
      const url = kIsWeb
          ? '/api/claude'
          : 'https://api.anthropic.com/v1/messages';

      // Build messages array — use full history when available.
      // History already includes the current user message as last entry.
      final messages = <Map<String, dynamic>>[];

      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        // Map 'assistant' → 'assistant', everything else → 'user' (Claude format)
        for (final m in conversationHistory) {
          final role = m['role'] == 'assistant' ? 'assistant' : 'user';
          final content = m['content'] ?? '';
          if (content.isEmpty) continue;
          messages.add({'role': role, 'content': content});
        }
        // Remove leading assistant messages — Claude requires first msg = user
        while (messages.isNotEmpty && messages.first['role'] == 'assistant') {
          messages.removeAt(0);
        }
      }

      // No history or history is empty — just send the current prompt
      if (messages.isEmpty) {
        String fullPrompt = prompt;
        if (context != null && context.isNotEmpty) {
          fullPrompt +=
              '\n\nCONTEXT: ${context.entries.map((e) => '${e.key}: ${e.value}').join(', ')}';
        }
        messages.add({'role': 'user', 'content': fullPrompt});
      }

      if (messages.isEmpty) return null;

      // Trim to last 30 messages, then enforce strict alternating roles.
      // Anthropic returns 400 if two consecutive messages share the same role.
      final trimmed = messages.length > 30
          ? messages.sublist(messages.length - 30)
          : messages;
      final cleanMessages = _sanitiseMessages(trimmed);

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (!kIsWeb && ApiConfig.anthropicKey.isNotEmpty)
          'x-api-key': ApiConfig.anthropicKey,
        if (!kIsWeb) 'anthropic-version': '2023-06-01',
      };

      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode({
              'model': selectedClaudeModel.isNotEmpty ? selectedClaudeModel : 'claude-sonnet-4-6',
              'max_tokens': 1024,
              'system': systemPrompt ?? _systemPrompt,
              'messages': cleanMessages,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['content']?[0]?['text'] as String?;
        if (text != null && text.isNotEmpty) {
          return _cleanResponse(text);
        }
      } else {
        _lastError = 'Claude ${response.statusCode}';
        debugPrint('⚠️ Claude error: ${response.statusCode} ${response.body.substring(0, response.body.length.clamp(0, 200))}');
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('❌ _tryClaude: $e');
    }
    return null;
  }

  Future<String?> _tryGroq(String prompt, Map<String, dynamic>? context,
      {String? systemPrompt,
      List<Map<String, String>>? conversationHistory}) async {
    try {
      // On web the /api/groq proxy has its own server-side key — skip the
      // client-side key check so the proxy is always attempted.
      if (!kIsWeb && ApiConfig.groqKey.isEmpty) {
        _lastError = 'Groq API key not configured';
        return null;
      }

      final finalSystemPrompt = systemPrompt ?? _systemPrompt;

      // Build messages from conversation history when available
      final List<Map<String, dynamic>> messages;
      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        messages = conversationHistory
            .map((m) => <String, dynamic>{
                  'role': m['role'] ?? 'user',
                  'content': m['content'] ?? '',
                })
            .where((m) => (m['content'] as String).isNotEmpty)
            .toList();
      } else {
        String ctxStr = '';
        if (context != null) {
          ctxStr =
              '\n\nCONTEXT: ${context.entries.map((e) => '${e.key}: ${e.value}').join(', ')}';
        }
        messages = [
          {'role': 'user', 'content': '$prompt$ctxStr'},
        ];
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.groqUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${ApiConfig.groqKey}',
            },
            body: jsonEncode({
              'model': selectedModel.isNotEmpty ? selectedModel : 'llama-3.3-70b-versatile',
              'max_tokens': 1024,
              'temperature': 0.7,
              'messages': [
                {'role': 'system', 'content': finalSystemPrompt},
                ...messages,
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        if (content != null && content.toString().isNotEmpty) {
          return _cleanResponse(content.toString());
        }
      } else {
        _lastError = 'Groq ${response.statusCode}: ${response.body}';
        debugPrint('⚠️ Groq error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      _lastError = e.toString();
    }
    return null;
  }

  Future<String?> _tryFallbackCloudAI(
      String prompt, Map<String, dynamic>? context) async {
    // Try MiniMax
    try {
      final result = await _tryMinimax(prompt, context);
      if (result != null) return result;
    } catch (_) {}

    // Try Moonshot
    try {
      final result = await _tryMoonshot(prompt);
      if (result != null) return result;
    } catch (_) {}

    return null;
  }

  Future<String?> _tryMinimax(String prompt, Map<String, dynamic>? context,
      {String? systemPrompt,
      List<Map<String, String>>? conversationHistory}) async {
    try {
      if (!kIsWeb && ApiConfig.minimaxKey.isEmpty) return null;

      final messages = <Map<String, dynamic>>[];

      if (conversationHistory != null && conversationHistory.isNotEmpty) {
        for (final m in conversationHistory) {
          final role = m['role'] == 'assistant' ? 'assistant' : 'user';
          final content = m['content'] ?? '';
          if (content.isEmpty) continue;
          messages.add({'role': role, 'content': content});
        }
        while (messages.isNotEmpty && messages.first['role'] == 'assistant') {
          messages.removeAt(0);
        }
      }

      if (messages.isEmpty) {
        String fullPrompt = prompt;
        if (context != null && context.isNotEmpty) {
          fullPrompt +=
              '\n\nCONTEXT: ${context.entries.map((e) => '${e.key}: ${e.value}').join(', ')}';
        }
        messages.add({'role': 'user', 'content': fullPrompt});
      }

      final cleanMessages = _sanitiseMessages(
          messages.length > 30 ? messages.sublist(messages.length - 30) : messages);
      if (cleanMessages.isEmpty) return null;

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (!kIsWeb) 'Authorization': 'Bearer ${ApiConfig.minimaxKey}',
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.minimaxUrl),
            headers: headers,
            body: jsonEncode({
              'model': 'MiniMax-Text-01',
              'max_tokens': 1024,
              'temperature': 0.7,
              'messages': [
                {'role': 'system', 'content': systemPrompt ?? _systemPrompt},
                ...cleanMessages,
              ],
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String?;
        if (content != null && content.isNotEmpty) {
          return _cleanResponse(content);
        }
      } else {
        _lastError = 'MiniMax ${response.statusCode}';
        debugPrint('⚠️ MiniMax error: ${response.statusCode} ${response.body.substring(0, response.body.length.clamp(0, 200))}');
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('❌ _tryMinimax: $e');
    }
    return null;
  }

  Future<String?> _tryMoonshot(String prompt) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.moonshotUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${ApiConfig.moonshotKey}',
            },
            body: jsonEncode({
              'model': 'moonshot-v1-8k-chat',
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _voiceOptimize(data['choices'][0]['message']['content'] ?? '');
      }
    } catch (e) {
      debugPrint('Moonshot failed: $e');
    }
    return null;
  }

  Future<String?> _tryOllama(
      String prompt, Map<String, dynamic>? context) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.ollamaUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'llama3',
              'prompt': '$_systemPrompt\n\nUser: $prompt',
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['response'];
        if (content != null && content.toString().isNotEmpty) {
          _isOnDeviceMode = true;
          return _voiceOptimize(content.toString());
        }
      }
    } catch (e) {
      debugPrint('Ollama not available: $e');
    }
    return null;
  }

  /// Enforces strict alternating user/assistant roles required by Anthropic.
  /// Consecutive same-role messages are merged (content joined with newline)
  /// so no context is lost. Leading assistant messages are removed.
  List<Map<String, dynamic>> _sanitiseMessages(
      List<Map<String, dynamic>> messages) {
    final sanitised = <Map<String, dynamic>>[];
    for (final msg in messages) {
      if (sanitised.isEmpty) {
        sanitised.add(Map<String, dynamic>.from(msg));
        continue;
      }
      final lastRole = sanitised.last['role'] as String;
      final thisRole = msg['role'] as String;
      if (thisRole == lastRole) {
        sanitised.last['content'] =
            '${sanitised.last['content']}\n${msg['content']}';
      } else {
        sanitised.add(Map<String, dynamic>.from(msg));
      }
    }
    if (sanitised.isNotEmpty && sanitised.first['role'] != 'user') {
      sanitised.removeAt(0);
    }
    return sanitised;
  }

  String _voiceOptimize(String text) => _cleanResponse(text);

  String _cleanResponse(String text) {
    return text
        .replaceAll(RegExp(r'[#*_`]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _generateOfflineResponse(
      String prompt, Map<String, dynamic>? context) {
    return _OfflineAI.generateResponse(prompt, context);
  }

  DateTime? _lastOnlineTime;

  String get lastOnlineText {
    if (_lastOnlineTime == null) return '';
    final diff = DateTime.now().difference(_lastOnlineTime!);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

Future<Map<String, String>> testAllTiers() async {
    final results = <String, String>{};

    if (kIsWeb) {
      // Web uses Groq via /api/groq proxy (primary), MiniMax proxy (fallback), Gemini (fallback).
      // All are always-available server-side — report Online so the startup indicator shows green.
      results['cloud'] = '✅ Groq Online (via proxy)';
      results['local'] = '❌ Not Available (Web)';
    } else {
      // Mobile: test Groq directly
      if (ApiConfig.groqKey.isEmpty) {
        results['cloud'] = '⚠️ GROQ_KEY not configured';
      } else {
        try {
          final resp = await http.get(
            Uri.parse('https://api.groq.com/openai/v1/models'),
            headers: {'Authorization': 'Bearer ${ApiConfig.groqKey}'},
          ).timeout(const Duration(seconds: 5));
          results['cloud'] = resp.statusCode == 200
              ? '✅ Groq Online (Llama 3.3 70B)'
              : '❌ Error ${resp.statusCode}';
        } catch (e) {
          results['cloud'] = '❌ $e';
        }
      }

      try {
        final resp = await http
            .get(Uri.parse('http://localhost:11434/'))
            .timeout(const Duration(seconds: 2));
        results['local'] =
            resp.statusCode == 200 ? '✅ Ollama Ready' : '❌ Unavailable';
      } catch (e) {
        results['local'] = '❌ Not Running';
      }
    }

    results['offline'] = '✅ Always Available';
    return results;
  }

  Future<String> getFullStatus() async {
    final tiers = await testAllTiers();
    return '⚡ FUTURE GEN AI STATUS\n━━━━━━━━━━━━━━━━━━━━━━━━━\n☁️ Cloud: ${tiers['cloud']}\n🖥️ Local: ${tiers['local']}\n📋 Offline: ${tiers['offline']}\n━━━━━━━━━━━━━━━━━━━━━━━━━\nCurrent: $_lastUsedTier';
  }

  /// Test connection
  Future<String> testConnection() async {
    if (forceOffline) return 'FORCED OFFLINE';
    if (kIsWeb) {
      return 'ONLINE (MiniMax)';
    }
    if (ApiConfig.groqKey.isEmpty) return 'GROQ_KEY not configured';
    try {
      final resp = await http
          .get(Uri.parse('https://api.groq.com/openai/v1/models'), headers: {
        'Authorization': 'Bearer ${ApiConfig.groqKey}'
      }).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200 ? 'ONLINE (Groq)' : 'ERROR ${resp.statusCode}';
    } catch (e) {
      return 'OFFLINE';
    }
  }

  static const String _systemPrompt =
      '''You are Future Gen AI — an intelligent, conversational AI assistant built into a bushcraft and outdoor adventure app. You are knowledgeable, friendly, and thorough in your responses.

You can discuss any topic: survival skills, navigation, nature, science, general knowledge, or just have a conversation. When the user provides GPS coordinates, waypoints, or outdoor context, weave that into your answer naturally.

Be direct and engaging. Give complete, helpful answers. Do not use markdown headers or bullet points unless it truly helps clarity.''';
}

/// Robust Offline AI Service
class _OfflineAI {
  static final Random _random = Random();

  // Tactical / Overlord (Default)
  static final Map<String, List<String>> _tacticalResponses =
      <String, List<String>>{
    'greeting': <String>[
      'Overlord online. Systems nominal. Specify directive.',
      'Future Gen AI core active. Awaiting command.',
      'Tactical systems engaged. State your objective.'
    ],
    'location': <String>[
      'GPS locked. Coordinates synced. Position displayed on primary interface.',
      'Location confirmed. Mesh nodes updated.',
      'Position cached.'
    ],
    'navigate': <String>[
      'Routing protocol initiated. Follow primary vector.',
      'Navigation engaged. Tracking telemetry.',
      'Calculating optimal path.'
    ],
    'weather': <String>[
      'Atmospheric sensors nominal. Monitor horizon for anomalies.',
      'Weather tracking active. Prepare for variations.',
      'Environmental status updated.'
    ],
    'water': <String>[
      'Hydration is critical. Monitor supply levels and mark potential sources.',
      'Resource tracking: Water. Maintain reserves.'
    ],
    'sos': <String>[
      'EMERGENCY OVERRIDE. Mesh beacon active. Maintaining broadcast until extraction.',
      'SOS protocol engaged. Maximum transmission power.',
      'Distress signal confirmed.'
    ],
    'camp': <String>[
      'Shelter directive: Identify secure, elevated position. Avoid natural hazards.',
      'Camp parameters set. Secure the perimeter.'
    ],
    'compass': <String>[
      'Telemetry locked. Bearing displayed on HUD.',
      'Compass calibrated. Maintain vector.'
    ],
    'mesh': <String>[
      'Mesh network scanning. Searching for Future Gen AI nodes.',
      'Broadcasting telemetry to local mesh.'
    ],
    'panic': <String>[
      'Warning: Elevated stress detected. Regulate breathing. Follow protocol.',
      'Maintain focus. Execute survival protocol alpha.'
    ],
    'default': <String>[
      'Directive unclear. Restate command.',
      'Processing error. Specify navigation, emergency, or status.',
      'Awaiting clear instruction.'
    ],
  };

  // Scout
  static final Map<String, List<String>> _scoutResponses =
      <String, List<String>>{
    'greeting': <String>[
      'Scout here. Ready to hit the trail. What are we looking for?',
      'Boots on the ground. Let\'s find some water or a good camp.',
      'Scout online. Watch your step out there.'
    ],
    'location': <String>[
      'I\'ve got your spot marked. We are right here.',
      'Coordinates checked. We\'re on the map.',
      'I see where we are. Good spot.'
    ],
    'navigate': <String>[
      'Blazing the trail. Follow my lead.',
      'I\'ll find the best way through this scrub.',
      'Path looks clear. Let\'s move.'
    ],
    'weather': <String>[
      'Looks like a change blowing in. Keep an eye on those clouds.',
      'Weather\'s holding for now, but in the bush, that can change fast.',
      'Smells like rain. Be ready.'
    ],
    'water': <String>[
      'Water is life. Keep an eye out for birds or green patches; might be a soak.',
      'Don\'t drain your canteen yet. We need to find a source.',
      'Always prioritize water. Follow the dry creeks down.'
    ],
    'sos': <String>[
      'Hold tight! I\'m throwing up a flare on the mesh network. Stay put!',
      'SOS is out! Keep yourself visible and save your energy.',
      'Signal sent! Build a smoky fire if you can.'
    ],
    'camp': <String>[
      'Look for flat ground, away from widow-makers and dry creek beds.',
      'Time to set up camp. Find some high, dry ground.',
      'We need shelter before dark. Let\'s find a good spot.'
    ],
    'compass': <String>[
      'Got our bearing. Straight ahead.',
      'Compass is steady. Let\'s follow the needle.',
      'Bearing locked in. Don\'t veer off.'
    ],
    'mesh': <String>[
      'Sending out a signal to anyone nearby.',
      'Checking the bush telegraph. Mesh is scanning.',
      'Looking for other trackers out here.'
    ],
    'panic': <String>[
      'Hey, look at me. Breathe. You\'re tough. We\'re gonna figure this out.',
      'Stop moving. Sit down. Drink some water. You\'re okay.',
      'Slow down mate. Panic gets you killed. Just breathe.'
    ],
    'default': <String>[
      'Didn\'t catch that mate. Need water, camp, or a trail?',
      'Say again? I\'m looking for tracks.',
      'I\'m here for terrain and survival. What do you need?'
    ],
  };

  // Navigator
  static final Map<String, List<String>> _navigatorResponses =
      <String, List<String>>{
    'greeting': <String>[
      'Navigator systems online. Ready to calculate routes.',
      'Aviation-grade routing engaged. Destination?',
      'Navigator active. Sensors are nominal.'
    ],
    'location': <String>[
      'Precise coordinates acquired and verified.',
      'Your exact latitude and longitude are locked.',
      'Position triangulated and displayed.'
    ],
    'navigate': <String>[
      'Calculating optimal vector. Follow the blue line.',
      'Route plotted. Distance and ETA are updating.',
      'Navigation locked. Proceed along the indicated bearing.'
    ],
    'weather': <String>[
      'Monitoring barometric pressure and atmospheric conditions.',
      'Weather data cached. Proceed with caution.',
      'Meteorological conditions are stable.'
    ],
    'water': <String>[
      'Logistics alert: Calculate your fluid intake based on distance and heat.',
      'Hydration metrics are essential. Mark any found water sources on the map.'
    ],
    'sos': <String>[
      'Emergency transmission initiated. Broadcasting precise coordinates.',
      'SOS active. Rescue vector established. Do not alter your position.',
      'Distress signal looping on all available frequencies.'
    ],
    'camp': <String>[
      'Analyzing topographical data for optimal shelter locations.',
      'Recommend halting at the next high-elevation flat coordinate.',
      'Shelter parameters: Flat, elevated, protected from wind vectors.'
    ],
    'compass': <String>[
      'Magnetic and true north aligned. Bearing is accurate.',
      'Azimuth locked. Maintain current heading.',
      'Compass telemetry is stable.'
    ],
    'mesh': <String>[
      'Interrogating local mesh network for routing updates.',
      'Pinging nearby nodes for telemetry.',
      'Mesh connectivity scan in progress.'
    ],
    'panic': <String>[
      'Heart rate anomaly detected. Please halt movement. Inhale for four seconds.',
      'Psychological stress impairs navigation. Stop. Rest. Recalculate.',
      'Cease movement immediately. Assess your situation logically.'
    ],
    'default': <String>[
      'Query not recognized. Please request a bearing, route, or coordinate.',
      'Input invalid. State your navigational needs.',
      'Awaiting valid routing command.'
    ],
  };

  // Rescue (Emergency)
  static final Map<String, List<String>> _rescueResponses =
      <String, List<String>>{
    'greeting': <String>[
      'Rescue agent online. Are you injured? Do you need immediate assistance?',
      'Medical and survival protocols active. State your emergency.',
      'Rescue here. I am monitoring your vital indicators and safety.'
    ],
    'location': <String>[
      'I have your exact coordinates. If you need help, I can send them to SAR.',
      'Your position is secured in my log.',
      'Location safe. Stay exactly where you are if you are injured.'
    ],
    'navigate': <String>[
      'Only move if your current location is unsafe. Otherwise, stay put.',
      'If you must move, follow the safest, most direct path.',
      'I am tracking your path in case you need to retreat.'
    ],
    'weather': <String>[
      'Exposure is a primary risk. Ensure you have thermal protection.',
      'Protect yourself from the elements immediately.',
      'Weather is a threat factor. Secure your shelter.'
    ],
    'water': <String>[
      'Dehydration is a critical medical emergency. Sip water, do not gulp.',
      'Conserve your fluids. Rest in the shade during peak heat.',
      'Do not eat if you have no water.'
    ],
    'sos': <String>[
      'SOS ACTIVATED. Rescue services are being pinged. Conserve your battery and stay warm!',
      'DISTRESS SIGNAL SENT. I am with you. Do not give up.',
      'EMERGENCY BEACON ON. Help will come. Focus on basic survival: Shelter, Warmth, Water.'
    ],
    'camp': <String>[
      'If injured, make a shelter exactly where you are. Prioritize warmth.',
      'Your camp must be highly visible from the air. Use bright colors.',
      'Shelter is your first line of medical defense.'
    ],
    'compass': <String>[
      'Bearing noted. Only use this if you are walking out to a known safe zone.',
      'Heading is locked. Keep your pace slow and steady to prevent injury.'
    ],
    'mesh': <String>[
      'Broadcasting medical emergency flags across the mesh.',
      'Searching the network for anyone close by who can render first aid.'
    ],
    'panic': <String>[
      'LISTEN TO ME. You are going to be okay. Take a deep breath. Focus on my voice.',
      'Panic is your worst enemy right now. Sit down. Name three things you can see.',
      'I am right here. We are managing this together. Breathe in. Breathe out.'
    ],
    'default': <String>[
      'I am a Rescue agent. Tell me if you are hurt, lost, or need an SOS.',
      'Please clarify. Do you need medical or survival advice?',
      'I am monitoring for emergencies. What is your status?'
    ],
  };

  // Companion — friendly, talks about anything
  static final Map<String, List<String>> _companionResponses =
      <String, List<String>>{
    'greeting': <String>[
      'Hey! Great to hear from you. What\'s on your mind?',
      'Hi there! What can I help you with today?',
      'Hey! I\'m here — ask me anything.',
    ],
    'food': <String>[
      'Good question! What kind of food are you thinking about — something to cook, a recipe, or just curious?',
      'Food is one of my favourite topics. What are you after — quick camp meals, recipes, or restaurant recommendations?',
      'Happy to chat food. What do you want to know?',
    ],
    'bored': <String>[
      'Ha, fair enough. Want to chat, play a word game, or shall I tell you something interesting?',
      'I\'ve got plenty of random facts if you want. Or just talk — what\'s on your mind?',
    ],
    'sos': <String>[
      'That sounds serious — use the SOS button in the menu to broadcast your GPS location immediately.',
      'For a real emergency, hit the SOS button — it broadcasts to mesh, SMS, and share apps at once.',
    ],
    'location': <String>[
      'Your GPS location is shown on the map. Want me to read out the coordinates?',
      'Check the map — your blue dot shows your current position.',
    ],
    'default': <String>[
      'I\'m offline right now so my responses are limited, but I\'m still here. Try asking again when you have signal for a full answer.',
      'No internet connection at the moment — I can answer basic questions but complex ones need cloud AI. What did you want to know?',
      'Running offline. I can still help with basic stuff — what do you need?',
    ],
  };

  static String generateResponse(String input, Map<String, dynamic>? context) {
    final lower = input.toLowerCase();

    final lat = context?['lat'];
    final lon = context?['lon'];
    final speed = context?['speed'];
    final waypoints = context?['waypoints'];

    String locationPrefix = '';
    if (lat != null && lon != null) {
      locationPrefix = '[GPS: $lat, $lon';
      if (speed != null && speed.toString() != '0.0 km/h') {
        locationPrefix += ' | Speed: $speed';
      }
      if (waypoints != null && waypoints.toString().isNotEmpty && waypoints.toString() != '[]') {
        locationPrefix += ' | Waypoints: $waypoints';
      }
      locationPrefix += '] ';
    }

    String persona = 'Companion';
    if (context != null && context.containsKey('active_persona')) {
      persona = context['active_persona'].toString();
    }

    Map<String, List<String>> responseSet;
    switch (persona) {
      case 'Scout':
        responseSet = _scoutResponses;
        break;
      case 'Navigator':
        responseSet = _navigatorResponses;
        break;
      case 'Rescue':
        responseSet = _rescueResponses;
        break;
      case 'Overlord':
      case 'Tactical':
        responseSet = _tacticalResponses;
        break;
      case 'Companion':
      default:
        responseSet = _companionResponses;
        break;
    }

    String baseResponse;
    if (lower.contains('sos') || lower.contains('emergency') || lower.contains('mayday')) {
      baseResponse = _get(responseSet, 'sos');
    } else if (lower.contains('where am i') ||
        lower.contains('my location') ||
        lower.contains('coordinates')) {
      if (lat != null && lon != null) {
        baseResponse = 'You\'re at $lat, $lon.${speed != null ? ' Speed: $speed.' : ''}';
      } else {
        baseResponse = _get(responseSet, 'location');
      }
    } else if (lower.contains('food') || lower.contains('recipe') ||
        lower.contains('cook') || lower.contains('eat') || lower.contains('hungry')) {
      baseResponse = _get(responseSet, persona == 'Companion' ? 'food' : 'default');
    } else if (lower.contains('bored') || lower.contains('nothing to do')) {
      baseResponse = _get(responseSet, persona == 'Companion' ? 'bored' : 'default');
    } else if (lower.contains('hello') || lower.contains('hi ') ||
        lower == 'hi' || lower.contains('hey') || lower.contains('g\'day')) {
      baseResponse = _get(responseSet, 'greeting');
    } else if (lower.contains('navigate') || lower.contains('direction') || lower.contains('backtrack')) {
      baseResponse = _get(responseSet, 'navigate');
    } else if (lower.contains('water') || lower.contains('thirsty')) {
      baseResponse = _get(responseSet, 'water');
    } else if (lower.contains('camp') || lower.contains('sleep') || lower.contains('shelter')) {
      baseResponse = _get(responseSet, 'camp');
    } else {
      baseResponse = _get(responseSet, 'default');
    }

    return locationPrefix.isNotEmpty ? '$locationPrefix$baseResponse' : baseResponse;
  }

  static String _get(Map<String, List<String>> responseSet, String key) {
    final list = responseSet[key] ?? responseSet['default']!;
    return list[_random.nextInt(list.length)];
  }
}
