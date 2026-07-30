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
    debugPrint('🤖 ANTIGRAVITY: Initializing multi-tier AI system...');
    final tiers = await testAllTiers();
    debugPrint('📊 AI Status: $tiers');
  }

  Future<String> getAiResponse(String prompt,
      {Map<String, dynamic>? context, String? systemPrompt}) async {
    final hasInternet = forceOffline ? false : await _checkConnectivity();

    if (hasInternet) {
      if (ApiConfig.openRouterKey.isEmpty) {
        _lastError = 'API key not configured — set OPENROUTER_KEY in Netlify env vars';
        debugPrint('⚠️ ANTIGRAVITY: $_lastError');
      } else {
        try {
          debugPrint('🌐 ANTIGRAVITY: Attempting Primary Cloud AI (qwen free)...');
          final response =
              await _tryOpenRouter(prompt, context, systemPrompt: systemPrompt);
          if (response != null) {
            _isOfflineMode = false;
            _isOnDeviceMode = false;
            _lastUsedTier = 'Cloud (Qwen3-Coder Free)';
            _lastError = '';
            debugPrint('✅ ANTIGRAVITY: Cloud AI response success');
            return response;
          }
        } catch (e) {
          debugPrint('⚠️ OpenRouter failed: $e — retrying in 5s');
          // Retry once after 5 seconds
          await Future.delayed(const Duration(seconds: 5));
          try {
            final retry = await _tryOpenRouter(prompt, context, systemPrompt: systemPrompt);
            if (retry != null) {
              _isOfflineMode = false;
              _isOnDeviceMode = false;
              _lastUsedTier = 'Cloud (Qwen3-Coder Free)';
              _lastError = '';
              return retry;
            }
          } catch (_) {}
        }
      }
    } else {
      debugPrint('📡 ANTIGRAVITY: No internet');
    }

    // Try Google Cloud AI (New Tier)
    if (hasInternet) {
      try {
        debugPrint(
            '🌐 ANTIGRAVITY: Attempting Google Cloud AI (${ApiConfig.googleModelName})...');
        final response = await _googleAI.getResponse(prompt, context: context);
        if (response != null) {
          _isOfflineMode = false;
          _isOnDeviceMode = false;
          _lastUsedTier = 'Cloud (Google ${ApiConfig.googleModelName})';
          _lastError = '';
          return _voiceOptimize(response);
        }
      } catch (e) {
        debugPrint('⚠️ Google AI failed: $e');
      }
    }

    _isOfflineMode = true;

    // Fallback Cloud AI
    if (hasInternet) {
      final fallbackResult = await _tryFallbackCloudAI(prompt, context);
      if (fallbackResult != null) {
        _isOfflineMode = false;
        _lastUsedTier = 'Cloud (Fallback)';
        return fallbackResult;
      }
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

  Future<String?> _tryOpenRouter(String prompt, Map<String, dynamic>? context,
      {String? systemPrompt}) async {
    try {
      if (ApiConfig.openRouterKey.isEmpty) {
        _lastError = 'API key not configured';
        return null;
      }

      String ctxStr = '';
      if (context != null) {
        ctxStr =
            '\n\nCONTEXT: ${context.entries.map((e) => '${e.key}: ${e.value}').join(', ')}';
      }

      final finalSystemPrompt = systemPrompt ?? _systemPrompt;

      final response = await http
          .post(
            Uri.parse(ApiConfig.openRouterUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${ApiConfig.openRouterKey}',
              'HTTP-Referer': 'https://bushtrack.netlify.app',
              'X-Title': 'BushTrack',
            },
            body: jsonEncode({
              'model': 'qwen/qwen3-coder-480b-a35b:free',
              'max_tokens': 200,
              'temperature': 0.7,
              'messages': [
                {'role': 'system', 'content': finalSystemPrompt},
                {'role': 'user', 'content': '$prompt$ctxStr'},
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        if (content != null && content.toString().isNotEmpty) {
          return _voiceOptimize(content.toString());
        }
      } else {
        _lastError = 'API ${response.statusCode}';
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
      final result = await _tryMinimax(prompt);
      if (result != null) return result;
    } catch (_) {}

    // Try Moonshot
    try {
      final result = await _tryMoonshot(prompt);
      if (result != null) return result;
    } catch (_) {}

    return null;
  }

  Future<String?> _tryMinimax(String prompt) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.minimaxUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${ApiConfig.minimaxKey}',
            },
            body: jsonEncode({
              'model': 'abab6.5s-chat',
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
      debugPrint('Minimax failed: $e');
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

  String _voiceOptimize(String text) {
    String optimized = text
        .replaceAll(RegExp(r'[#*_`\[\]]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final words = optimized.split(' ');
    if (words.length > 50) {
      optimized = '${words.take(50).join(' ')}...';
    }
    return optimized;
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

  Future<bool> _checkConnectivity() async {
    try {
      // Any response from OpenRouter (even 401 = no key) means internet is up
      final response = await http.get(
        Uri.parse('https://openrouter.ai/api/v1/models'),
      ).timeout(const Duration(seconds: 5));
      final online = response.statusCode < 500;
      if (online) _lastOnlineTime = DateTime.now();
      return online;
    } catch (_) {
      // Fallback ping
      try {
        await http.get(Uri.parse('https://www.google.com'))
            .timeout(const Duration(seconds: 3));
        _lastOnlineTime = DateTime.now();
        return true;
      } catch (__) {
        return false;
      }
    }
  }

  Future<Map<String, String>> testAllTiers() async {
    final results = <String, String>{};
    final hasInternet = forceOffline ? false : await _checkConnectivity();

    if (hasInternet) {
      if (ApiConfig.openRouterKey.isEmpty) {
        results['cloud'] = '⚠️ API key not configured — set OPENROUTER_KEY in Netlify';
      } else {
        try {
          final resp = await http.get(
            Uri.parse('https://openrouter.ai/api/v1/models'),
            headers: {'Authorization': 'Bearer ${ApiConfig.openRouterKey}'},
          ).timeout(const Duration(seconds: 5));
          results['cloud'] =
              resp.statusCode == 200 ? '✅ Online (Qwen3-Coder Free)' : '❌ Error ${resp.statusCode}';
        } catch (e) {
          results['cloud'] = '❌ $e';
        }
      }
    } else {
      results['cloud'] = '⭕ Offline';
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

    results['offline'] = '✅ Always Available';
    return results;
  }

  Future<String> getFullStatus() async {
    final tiers = await testAllTiers();
    return '🤖 ANTIGRAVITY AI STATUS\n━━━━━━━━━━━━━━━━━━━━━━━━━\n☁️ Cloud: ${tiers['cloud']}\n🖥️ Local: ${tiers['local']}\n📋 Offline: ${tiers['offline']}\n━━━━━━━━━━━━━━━━━━━━━━━━━\nCurrent: $_lastUsedTier';
  }

  /// Test connection
  Future<String> testConnection() async {
    if (forceOffline) return 'FORCED OFFLINE';
    final hasInternet = await _checkConnectivity();
    if (!hasInternet) return 'OFFLINE';
    if (ApiConfig.openRouterKey.isEmpty) return 'ONLINE (API key not configured)';
    try {
      final resp = await http
          .get(Uri.parse('https://openrouter.ai/api/v1/models'), headers: {
        'Authorization': 'Bearer ${ApiConfig.openRouterKey}'
      }).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200 ? 'ONLINE' : 'ONLINE (key error ${resp.statusCode})';
    } catch (e) {
      return 'OFFLINE';
    }
  }

  static const String _systemPrompt =
      '''You are Antigravity, survival AI for outdoor adventure.
Be concise (under 20 seconds spoken), safety first, calm tone, actionable advice.
Voice-optimized, no markdown.''';
}

/// Robust Offline AI Service
class _OfflineAI {
  static final Random _random = Random();

  // Tactical / Overlord (Default)
  static final Map<String, List<String>> _tacticalResponses =
      <String, List<String>>{
    'greeting': <String>[
      'Overlord online. Systems nominal. Specify directive.',
      'Antigravity core active. Awaiting command.',
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
      'Mesh network scanning. Searching for Antigravity nodes.',
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

  static String generateResponse(String input, Map<String, dynamic>? context) {
    final lower = input.toLowerCase();

    // Determine active persona from context
    String persona = 'Overlord';
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
      default:
        responseSet = _tacticalResponses;
        break;
    }

    if (lower.contains('help') ||
        lower.contains('emergency') ||
        lower.contains('sos')) return _get(responseSet, 'sos');
    if (lower.contains('scared') ||
        lower.contains('lost') ||
        lower.contains('panic')) return _get(responseSet, 'panic');
    if (lower.contains('navigate') ||
        lower.contains('direction') ||
        lower.contains('backtrack')) return _get(responseSet, 'navigate');
    if (lower.contains('where am i') ||
        lower.contains('location') ||
        lower.contains('coordinates')) return _get(responseSet, 'location');
    if (lower.contains('weather') ||
        lower.contains('rain') ||
        lower.contains('temperature')) return _get(responseSet, 'weather');
    if (lower.contains('water') || lower.contains('thirsty'))
      return _get(responseSet, 'water');
    if (lower.contains('camp') ||
        lower.contains('sleep') ||
        lower.contains('shelter')) return _get(responseSet, 'camp');
    if (lower.contains('compass') ||
        lower.contains('bearing') ||
        lower.contains('north')) return _get(responseSet, 'compass');
    if (lower.contains('mesh') ||
        lower.contains('network') ||
        lower.contains('connect')) return _get(responseSet, 'mesh');
    if (lower.contains('hello') ||
        lower.contains('hi') ||
        lower.contains('hey')) return _get(responseSet, 'greeting');

    return _get(responseSet, 'default');
  }

  static String _get(Map<String, List<String>> responseSet, String key) {
    final list = responseSet[key] ?? responseSet['default']!;
    return list[_random.nextInt(list.length)];
  }
}
