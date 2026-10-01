import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// Multi-Provider AI Configuration
class ApiConfig {
  static const String mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');
  static const String maptilerKey = String.fromEnvironment('MAPTILER_KEY');
  static const String openRouterKey = String.fromEnvironment('OPENROUTER_KEY');
  static const String openAIKey = String.fromEnvironment('OPENAI_KEY');
  static const String anthropicKey = String.fromEnvironment('ANTHROPIC_KEY');
  static const String geminiKey = String.fromEnvironment('GEMINI_API_KEY',
      defaultValue: String.fromEnvironment('GEMINI_KEY'));
  static const String googleProjectName = 'projects/147600682787';
  static const String googleProjectNumber = '147600682787';
  static const String googleModelName = 'gemini-2.5-flash';
  static const String groqKey = String.fromEnvironment('GROQ_KEY');
  static const String minimaxKey = String.fromEnvironment('MINIMAX_KEY');
  static const String moonshotKey = String.fromEnvironment('MOONSHOT_KEY');
  static const String xaiKey = String.fromEnvironment('XAI_KEY');
  static const String ollamaKey = String.fromEnvironment('OLLAMA_KEY');
  static const String googleMapsKey = String.fromEnvironment('GOOGLE_MAPS_KEY');
  static const String hereApiKey = String.fromEnvironment('HERE_API_KEY');
  static const String openCageKey = String.fromEnvironment('OPENCAGE_KEY');
  static const String what3WordsKey = String.fromEnvironment('W3W_KEY');

  // ── Map and imagery providers ─────────────────────────────────────────────
  //
  // No defaults, deliberately. The Supabase publishable key above carries a
  // committed default because it is safe by design once RLS is on; these are
  // not in that category — a Mapbox token is billable and a Mapillary token
  // has no row-level security behind it — so they come from a git-ignored
  // config/pinage.json via --dart-define-from-file and are absent from the
  // repository entirely.
  //
  // Absent is a working state, not a broken one: with no Mapbox token the map
  // stays on MapTiler, and with no Mapillary token the street-imagery layer
  // hides itself. That is what keeps the provider switch from being a flag day.
  //
  // A SECRET token (sk.) must never appear here or anywhere in the repo. It is
  // only for downloading the Mapbox SDK at build time and belongs in the
  // user-level ~/.gradle/gradle.properties — note that android/gradle.properties
  // IS tracked, so it is the wrong file.
  static const String mapboxPublicToken =
      String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');

  static const String mapillaryToken =
      String.fromEnvironment('MAPILLARY_TOKEN');

  /// True when Mapbox can be used at all. False falls back to MapTiler.
  static bool get hasMapbox => mapboxPublicToken.startsWith('pk.');

  /// True when street-level imagery can be fetched. The layer is hidden
  /// otherwise rather than failing on tap.
  static bool get hasMapillary => mapillaryToken.startsWith('MLY|');

  // ── Supabase ──────────────────────────────────────────────────────────────
  //
  // Project "pinage-maps", ap-southeast-2 (Sydney). Only ever this project:
  // autoplexity-ai is a different product that happens to share an owner, and
  // pointing this app at it would put field data in the wrong database.
  //
  // The publishable key belongs in the client — that is what it is for. It is
  // only safe because RLS is on every table: with RLS off it is a straight
  // read of everyone's data. Overridable by dart-define so a staging project
  // can be pointed at without a code change.
  //
  // The service-role key must NEVER appear in this file, this app, or any
  // build flag. It bypasses RLS entirely. Server-side only, and this app has
  // no server of its own.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wmdfykxwwhulbrjysusi.supabase.co',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_ak6I3r0StL8jhq6AXD_lXw_P-CirTCt',
  );

  /// False when the app has not been pointed at a project, so sign-in can say
  /// so instead of failing with a network error.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// Where our own serverless proxies live.
  ///
  /// On web these are same-origin (/api/...). The phone app has no origin of
  /// its own, so it calls the deployed site — which keeps every provider key
  /// on the server for the phone build too, instead of compiling keys into an
  /// APK anyone can unzip.
  static const String proxyBase = String.fromEnvironment(
    'PROXY_BASE',
    defaultValue: 'https://pinagemaps.com',
  );

  // Groq (Primary Cloud AI — fast free Llama 3.3 70B)
  // On web: route through Vercel serverless proxy to avoid browser CORS blocks.
  // On mobile: call Groq directly.
  static String get groqUrl => kIsWeb
      ? '/api/groq'
      : 'https://api.groq.com/openai/v1/chat/completions';

  // OpenRouter (Legacy fallback)
  static const String openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  // OpenAI (GPT-4 Fallback)
  // Claude (Anthropic)
  // Google Gemini
  static const String geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$googleModelName:generateContent';

  // MiniMax — proxy on web (CORS), direct on mobile
  static String get minimaxUrl => kIsWeb
      ? '/api/minimax'
      : 'https://api.minimax.io/v1/chat/completions';

  // Moonshot AI
  static const String moonshotUrl =
      'https://api.moonshot.cn/v1/chat/completions';

  // xAI (Grok)
  static const String xaiUrl = 'https://api.x.ai/v1/chat/completions';

  // Ollama (Local AI)
  static const String ollamaUrl = 'http://localhost:11434/api/generate';

  // Google Maps
  static String get streetViewUrl => 'https://www.googleapis.com/streetview/v1';
  static String get placesApiUrl =>
      'https://maps.googleapis.com/maps/api/place';
  static String mapboxTilesUrl(String style, String format) =>
      'https://api.mapbox.com/styles/v1/$style/tiles/{z}/{x}/{y}.$format?access_token=$mapboxToken';
  static String mapboxStyleUrl(String style) =>
      'https://api.mapbox.com/styles/v1/$style?access_token=$mapboxToken';
}

/// Multi-Tier AI Manager
class MultiTierAIManager {
  static const String _sysPrompt =
      '''You are Future Gen AI — an intelligent, conversational AI assistant built into a bushcraft and outdoor adventure app. You are knowledgeable, friendly, and thorough in your responses. You can discuss any topic and give complete, helpful answers.''';

  static Future<AIResponse> getResponse(String prompt,
      {Map<String, dynamic>? context}) async {
    // Try cloud
    final cloudResult = await _tryCloudAI(prompt, context);
    if (cloudResult != null) return cloudResult;

    // Try Ollama
    final localResult = await _tryOllama(prompt);
    if (localResult != null) return localResult;

    // Fallback
    return _generateOfflineResponse(prompt, context);
  }

  static Future<AIResponse?> _tryCloudAI(
      String prompt, Map<String, dynamic>? context) async {
    // On web the key lives server-side in the /api/groq proxy, so there is
    // nothing to check here. Requiring a client-side key meant the web build
    // never even tried the cloud and dropped straight to canned replies.
    if (!kIsWeb && ApiConfig.groqKey.isEmpty) return null;
    try {
      String ctxStr = '';
      if (context != null) {
        ctxStr =
            '\n\nContext: ${context.entries.map((e) => '${e.key}: ${e.value}').join(', ')}';
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.groqUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${ApiConfig.groqKey}',
            },
            body: jsonEncode({
              'model': 'llama-3.3-70b-versatile',
              'max_tokens': 1024,
              'temperature': 0.7,
              'messages': [
                {'role': 'system', 'content': _sysPrompt},
                {'role': 'user', 'content': '$prompt$ctxStr'},
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        if (content != null && content.toString().isNotEmpty) {
          return AIResponse(
              text: _voiceOptimize(content.toString()),
              provider: 'Cloud (Groq Llama 3.3 70B)',
              isOffline: false);
        }
      }
    } catch (e) {
      debugPrint('Groq AI failed: $e');
    }
    return null;
  }

  static Future<AIResponse?> _tryOllama(String prompt) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.ollamaUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'llama3',
              'prompt': '$_sysPrompt\n\nUser: $prompt',
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['response'];
        if (content != null && content.toString().isNotEmpty) {
          return AIResponse(
              text: _voiceOptimize(content.toString()),
              provider: 'Local (Ollama)',
              isOffline: false);
        }
      }
    } catch (e) {
      debugPrint('Ollama not available: $e');
    }
    return null;
  }

  static AIResponse _generateOfflineResponse(
      String prompt, Map<String, dynamic>? context) {
    final response = _OfflineAI.generate(prompt, context);
    return AIResponse(
        text: response, provider: 'Offline (Rule-Based)', isOffline: true);
  }

  static String _voiceOptimize(String text) {
    return text
        .replaceAll(RegExp(r'[#*_`]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

/// AI Response wrapper
class AIResponse {
  final String text;
  final String provider;
  final bool isOffline;
  AIResponse(
      {required this.text, required this.provider, required this.isOffline});
}

/// Robust Offline AI
class _OfflineAI {
  static final Random _rnd = Random();

  static final Map<String, List<String>> _responses = <String, List<String>>{
    'greeting': <String>[
      'Future Gen AI online. What do you need?',
      'Systems active. Ready to help.',
      'Future Gen AI at your service.'
    ],
    'location': <String>[
      'Your GPS is locked. Position confirmed.',
      'Coordinates displayed.',
      'Location cached.'
    ],
    'navigate': <String>[
      'Navigation ready. Set destination.',
      'Guide via recorded path.',
      'Say reverse to return.'
    ],
    'weather': <String>[
      'Weather displayed on screen.',
      'Conditions monitored.',
      'Observe sky for changes.'
    ],
    'water': <String>[
      'Water critical: 4-5L daily.',
      'Hydration priority.',
      'Conserve water supply.'
    ],
    'sos': <String>[
      'Emergency! Broadcasting SOS.',
      'SOS active.',
      'Emergency signal sent.'
    ],
    'camp': <String>[
      'Seek flat ground, wind shelter.',
      'Higher ground, away from creeks.',
      'Find natural shelter.'
    ],
    'compass': <String>[
      'Compass active.',
      'Sensors calibrated.',
      'Bearing locked.'
    ],
    'mesh': <String>[
      'Scanning for devices.',
      'Device beaconing.',
      'Mesh sync active.'
    ],
    'panic': <String>[
      'Breathe. You are not alone.',
      'Stay calm. Focus.',
      'I am here.'
    ],
    'default': <String>[
      'Ask navigation, waypoints, SOS.',
      'Ready to help.',
      'I am here.'
    ],
  };

  static String generate(String input, Map<String, dynamic>? ctx) {
    final lower = input.toLowerCase();
    if (lower.contains('help') ||
        lower.contains('emergency') ||
        lower.contains('sos')) {
      return _gt('sos');
    }
    if (lower.contains('scared') ||
        lower.contains('lost') ||
        lower.contains('panic')) {
      return _gt('panic');
    }
    if (lower.contains('navigate') ||
        lower.contains('direction') ||
        lower.contains('backtrack')) {
      return _gt('navigate');
    }
    if (lower.contains('where am i') ||
        lower.contains('location') ||
        lower.contains('coordinates')) {
      return _gt('location');
    }
    if (lower.contains('weather') ||
        lower.contains('rain') ||
        lower.contains('temperature')) {
      return _gt('weather');
    }
    if (lower.contains('water') || lower.contains('thirsty')) {
      return _gt('water');
    }
    if (lower.contains('camp') ||
        lower.contains('sleep') ||
        lower.contains('shelter')) {
      return _gt('camp');
    }
    if (lower.contains('compass') ||
        lower.contains('bearing') ||
        lower.contains('north')) {
      return _gt('compass');
    }
    if (lower.contains('mesh') || lower.contains('network')) return _gt('mesh');
    if (lower.contains('hello') ||
        lower.contains('hi') ||
        lower.contains('hey')) {
      return _gt('greeting');
    }
    return _gt('default');
  }

  static String _gt(String key) {
    final list = _responses[key] ?? _responses['default']!;
    return list[_rnd.nextInt(list.length)];
  }
}
