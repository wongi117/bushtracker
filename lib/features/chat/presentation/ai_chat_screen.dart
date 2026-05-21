import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/ai/providers/ai_assistant_provider.dart';
import 'package:bush_track/features/ai/services/openrouter_service.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/features/chat/providers/chat_history_provider.dart';
import 'package:bush_track/features/navigation/providers/navigation_provider.dart';
import 'package:bush_track/features/map/providers/map_action_provider.dart';
import 'package:bush_track/features/ai/services/google_ai_service.dart';
import 'package:latlong2/latlong.dart';

class _WebModelChoice {
  final String provider;
  final String modelId;
  final String label;
  const _WebModelChoice(this.provider, this.modelId, this.label);
}

const String _memoryKey = 'fgai_memory';

// ── Groq model selector ──────────────────────────────────────────────────────
const _groqModels = {
  'Llama 3.3 70B': 'llama-3.3-70b-versatile',
  'Llama 3.1 8B (Fast)': 'llama-3.1-8b-instant',
  'Mixtral 8x7B': 'mixtral-8x7b-32768',
  'Gemma 2 9B': 'gemma2-9b-it',
};

final selectedAiModelProvider =
    StateProvider<String>((ref) => 'llama-3.3-70b-versatile');

final forceOfflineProvider = StateProvider<bool>((ref) => false);

// ── Conversation starter data ─────────────────────────────────────────────────
class _Starter {
  final String label;
  final IconData icon;
  final String query;
  const _Starter(this.label, this.icon, this.query);
}

const _conversationStarters = [
  _Starter('Where am I?',         Icons.place,            'Where am I right now? What are my exact coordinates?'),
  _Starter('Nearest water?',      Icons.water_drop,       'Find the nearest water source or dam within 50km'),
  _Starter("Battery status?",     Icons.battery_full,     'What is my current device battery level and power status?'),
  _Starter('Set up camp?',        Icons.holiday_village,  'Find a good campsite nearby with flat terrain and wind protection'),
  _Starter('Where did I come from?', Icons.explore,       'Show me my recent track and where I started from'),
  _Starter('SOS help',            Icons.sos,              'What should I do in an emergency? Activate SOS protocol'),
];

// ── Memory models ─────────────────────────────────────────────────────────────
class UserFacts {
  String? name;
  String? vehicle;
  String? homeBase;
  String? emergencyContact;
  List<String> frequentRoutes = [];
  Map<String, dynamic> savedPreferences = {};

  UserFacts({
    this.name,
    this.vehicle,
    this.homeBase,
    this.emergencyContact,
    this.frequentRoutes = const [],
    this.savedPreferences = const {},
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'vehicle': vehicle,
        'homeBase': homeBase,
        'emergencyContact': emergencyContact,
        'frequentRoutes': frequentRoutes,
        'savedPreferences': savedPreferences,
      };

  factory UserFacts.fromJson(Map<String, dynamic> json) => UserFacts(
        name: json['name'],
        vehicle: json['vehicle'],
        homeBase: json['homeBase'],
        emergencyContact: json['emergencyContact'],
        frequentRoutes: json['frequentRoutes'] != null
            ? List<String>.from(json['frequentRoutes'])
            : [],
        savedPreferences: json['savedPreferences'] ?? {},
      );
}

class ConversationEntry {
  final String role;
  final String content;
  final String timestamp;

  ConversationEntry({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() =>
      {'role': role, 'content': content, 'timestamp': timestamp};

  factory ConversationEntry.fromJson(Map<String, dynamic> json) =>
      ConversationEntry(
        role: json['role'],
        content: json['content'],
        timestamp: json['timestamp'],
      );
}

class AntigravityMemory {
  List<ConversationEntry> conversations;
  UserFacts userFacts;

  AntigravityMemory()
      : conversations = [],
        userFacts = UserFacts();

  Map<String, dynamic> toJson() => {
        'conversations': conversations.map((c) => c.toJson()).toList(),
        'userFacts': userFacts.toJson(),
      };

  static AntigravityMemory fromJson(Map<String, dynamic> json) {
    final memory = AntigravityMemory();
    if (json['conversations'] != null) {
      memory.conversations = (json['conversations'] as List)
          .map((c) => ConversationEntry.fromJson(c))
          .toList();
    }
    if (json['userFacts'] != null) {
      memory.userFacts = UserFacts.fromJson(json['userFacts']);
    }
    return memory;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isProcessing = false;
  bool _isListening = false;
  final AntigravityMemory _memory = AntigravityMemory();

  // Reverse-geocoded location name cache
  String _locationName = '';
  double _lastGeoLat = 0;
  double _lastGeoLon = 0;

  @override
  void initState() {
    super.initState();
    _loadMemory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Reverse-geocode via Nominatim; only re-fetches when position moves >500m.
  Future<void> _fetchLocationName(double lat, double lon) async {
    final dlat = (lat - _lastGeoLat).abs();
    final dlon = (lon - _lastGeoLon).abs();
    if (_locationName.isNotEmpty && dlat < 0.005 && dlon < 0.005) return;
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10');
      final resp = await http.get(uri, headers: {
        'User-Agent': 'BushTrack/1.0 (wanmallah1.ds@gmail.com)',
      }).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final parts = <String>[
          addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['suburb'] ?? '',
          addr['county'] ?? addr['state_district'] ?? '',
          addr['state'] ?? '',
          addr['country'] ?? '',
        ].where((s) => s.isNotEmpty).toList();
        _locationName = parts.join(', ');
        _lastGeoLat = lat;
        _lastGeoLon = lon;
      }
    } catch (e) {
      debugPrint('Geocode failed: $e');
    }
  }

  void _loadMemory() {
    SharedPreferences.getInstance().then((prefs) {
      try {
        final raw = prefs.getString(_memoryKey);
        if (raw != null && raw.isNotEmpty) {
          final decoded =
              AntigravityMemory.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          _memory.conversations = decoded.conversations;
          _memory.userFacts = decoded.userFacts;
          debugPrint('Memory loaded: ${_memory.conversations.length} entries');
        }
      } catch (e) {
        debugPrint('Error loading memory: $e');
      }
    });
  }

  void _saveMemory() {
    SharedPreferences.getInstance().then((prefs) {
      try {
        // Keep last 50 conversation turns to avoid storage bloat
        if (_memory.conversations.length > 50) {
          _memory.conversations =
              _memory.conversations.sublist(_memory.conversations.length - 50);
        }
        prefs.setString(_memoryKey, jsonEncode(_memory.toJson()));
      } catch (e) {
        debugPrint('Error saving memory: $e');
      }
    });
  }

  void _extractFacts(String userMessage) {
    final lowerUser = userMessage.toLowerCase();

    for (final pattern in [
      RegExp(r"my name is (.+?)(?:\.|,|$|\s)"),
      RegExp(r"i'm (.+?)(?:\.|,|$|\s)"),
      RegExp(r"call me (.+?)(?:\.|,|$|\s)"),
    ]) {
      final match = pattern.firstMatch(lowerUser);
      if (match?.group(1) case final name? when name.length > 1 && name.length < 30) {
        _memory.userFacts.name = name.trim();
      }
    }

    for (final pattern in [
      RegExp(r"(?:i drive|i ride|i travel in|i use)\s+(?:my\s+)?(.+?)(?:\s+for|\s+to|\.|,|$)"),
      RegExp(r"(?:my car|my ute|my truck|my bike|my vehicle)\s+is\s+(.+?)(?:\.|,|$)"),
    ]) {
      final match = pattern.firstMatch(lowerUser);
      if (match?.group(1) case final v? when v.length > 2) {
        _memory.userFacts.vehicle = v.trim();
      }
    }

    for (final pattern in [
      RegExp(r"(?:home base|home is|from|based in)\s+(.+?)(?:\.|,|$)"),
      RegExp(r"(?:i live in|i'm from)\s+(.+?)(?:\.|,|$)"),
    ]) {
      final match = pattern.firstMatch(lowerUser);
      if (match?.group(1) case final h? when h.length > 2) {
        _memory.userFacts.homeBase = h.trim();
      }
    }

    _saveMemory();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiAssistantProvider);
    final messages = ref.watch(chatHistoryProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.vertical(top: Radius.circular(BushDS.radiusXL)),
      ),
      child: Column(
        children: [
          _buildHeader(aiState),
          if (messages.isEmpty) _buildStarters(),
          Expanded(child: _buildMessageList(messages)),
          _buildInputBar(),
          if (aiState.lastError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  BushDS.spMD, 0, BushDS.spMD, BushDS.spSM),
              child: Text(
                aiState.lastError,
                style: const TextStyle(
                    color: AppColors.statusRed,
                    fontSize: BushDS.fontSM,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(AiState aiState) {
    final forceOffline = ref.watch(forceOfflineProvider);
    final isOffline = forceOffline || aiState.isOfflineMode;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: BushDS.spMD, vertical: BushDS.spSM),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.panelLight)),
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => AppColors.accentGradient.createShader(b),
            child: const Icon(Icons.bolt, color: Colors.white, size: 20),
          ),
          const SizedBox(width: BushDS.spSM),
          const Text(
            'FUTURE GEN AI',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: BushDS.fontXL,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: BushDS.spSM),
          // Status dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOffline ? AppColors.statusYellow : AppColors.statusGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isOffline
                          ? AppColors.statusYellow
                          : AppColors.statusGreen)
                      .withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const Spacer(),
          // Offline toggle pill — tap to switch between online and forced-offline
          GestureDetector(
            onTap: () {
              final next = !ref.read(forceOfflineProvider);
              ref.read(forceOfflineProvider.notifier).state = next;
              ref.read(aiAssistantProvider.notifier).setForceOffline(next);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: BushDS.spSM, vertical: 4),
              decoration: BoxDecoration(
                color: forceOffline
                    ? AppColors.statusYellow.withValues(alpha: 0.15)
                    : AppColors.statusGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: forceOffline
                      ? AppColors.statusYellow.withValues(alpha: 0.6)
                      : AppColors.statusGreen.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    forceOffline ? Icons.wifi_off : Icons.wifi,
                    size: 12,
                    color: forceOffline
                        ? AppColors.statusYellow
                        : AppColors.statusGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    forceOffline ? 'OFFLINE' : 'ONLINE',
                    style: TextStyle(
                      fontSize: BushDS.fontXS,
                      fontWeight: FontWeight.bold,
                      color: forceOffline
                          ? AppColors.statusYellow
                          : AppColors.statusGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: BushDS.spSM),
          _buildModelBadge(),
        ],
      ),
    );
  }

  // ── Conversation starters ──────────────────────────────────────────────────
  Widget _buildStarters() {
    return Padding(
      padding: const EdgeInsets.all(BushDS.spMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: AppColors.textSecondary, size: 16),
              SizedBox(width: BushDS.spXS),
              Text('Ask me anything:',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: BushDS.fontXS)),
            ],
          ),
          const SizedBox(height: BushDS.spSM),
          Wrap(
            spacing: BushDS.spSM,
            runSpacing: BushDS.spSM,
            children: _conversationStarters.map((s) {
              return GestureDetector(
                onTap: () => _sendMessage(s.query),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: BushDS.spSM + 4, vertical: BushDS.spSM),
                  constraints: const BoxConstraints(minHeight: BushDS.tapMin),
                  decoration: BoxDecoration(
                    gradient: AppColors.steelGradient,
                    borderRadius: BorderRadius.circular(BushDS.radiusLG),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(s.icon, color: AppColors.accent, size: 16),
                      const SizedBox(width: BushDS.spXS + 2),
                      Text(s.label,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: BushDS.fontXS)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: BushDS.spMD),
          Container(
            padding: const EdgeInsets.all(BushDS.spSM),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(BushDS.radiusMD),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.memory,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: BushDS.spSM),
                Expanded(
                  child: Text(
                    'I remember everything you tell me — name, vehicle, home base.',
                    style: TextStyle(
                        color: AppColors.textPrimary.withValues(alpha: 0.8),
                        fontSize: BushDS.fontXS),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Message list ───────────────────────────────────────────────────────────
  Widget _buildMessageList(List<ChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(BushDS.spMD),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return _buildBubble(msg, msg.role == 'user');
      },
    );
  }

  Widget _buildBubble(ChatMessage msg, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BushDS.spSM),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            // AI avatar — not a tap target, decorative only
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(BushDS.radiusSM),
              ),
              child: const Center(
                child: Text('FG',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: BushDS.fontXS,
                    )),
              ),
            ),
            const SizedBox(width: BushDS.spSM),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: BushDS.spMD, vertical: BushDS.spSM + 4),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                gradient: isUser ? AppColors.accentGradient : null,
                color: isUser ? null : AppColors.panelLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(BushDS.radiusLG),
                  topRight: const Radius.circular(BushDS.radiusLG),
                  bottomLeft:
                      Radius.circular(isUser ? BushDS.radiusLG : BushDS.spXS),
                  bottomRight:
                      Radius.circular(isUser ? BushDS.spXS : BushDS.radiusLG),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg.content,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: BushDS.fontMD,
                          height: 1.4)),
                  if (!isUser && msg.actions.isNotEmpty) ...[
                    const SizedBox(height: BushDS.spSM),
                    Wrap(
                      spacing: BushDS.spSM,
                      runSpacing: BushDS.spSM,
                      children: msg.actions.map((action) {
                        return GestureDetector(
                          onTap: () => _handleAction(action, context),
                          child: Container(
                            constraints: const BoxConstraints(
                                minHeight: BushDS.tapMin),
                            padding: const EdgeInsets.symmetric(
                                horizontal: BushDS.spSM + 6,
                                vertical: BushDS.spSM),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                AppColors.accent.withValues(alpha: 0.4),
                                AppColors.accentDark.withValues(alpha: 0.4),
                              ]),
                              borderRadius:
                                  BorderRadius.circular(BushDS.radiusLG),
                              border: Border.all(color: AppColors.accent),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getActionIcon(action),
                                    color: AppColors.textPrimary, size: 16),
                                const SizedBox(width: BushDS.spXS + 2),
                                Text(action,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: BushDS.fontXS,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input bar ──────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: BushDS.spSM, vertical: BushDS.spSM),
      padding: const EdgeInsets.symmetric(
          horizontal: BushDS.spSM, vertical: BushDS.spXS),
      decoration: BoxDecoration(
        color: AppColors.panelLight,
        borderRadius: BorderRadius.circular(BushDS.radiusLG),
        border: Border.all(
          color: _isListening
              ? AppColors.statusGreen
              : AppColors.panelHighlight,
          width: _isListening ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Mic — 48×48 tap target
          SizedBox(
            width: BushDS.tapMin,
            height: BushDS.tapMin,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                if (_isListening) {
                  ref.read(aiAssistantProvider.notifier).stopListening();
                  setState(() => _isListening = false);
                } else {
                  setState(() => _isListening = true);
                  ref.read(aiAssistantProvider.notifier).startListening();
                }
              },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  key: ValueKey(_isListening),
                  color: _isListening
                      ? AppColors.statusGreen
                      : AppColors.textSecondary,
                  size: 22,
                ),
              ),
            ),
          ),
          // Text input
          Expanded(
            child: TextField(
              controller: _inputController,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: BushDS.fontMD),
              decoration: InputDecoration(
                hintText: _isListening
                    ? 'Listening...'
                    : 'Ask Future Gen AI...',
                hintStyle: TextStyle(
                    color: _isListening
                        ? AppColors.statusGreen
                        : AppColors.textMuted,
                    fontSize: BushDS.fontMD),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: BushDS.spSM),
              ),
              onSubmitted: _sendMessage,
            ),
          ),
          // Send — 48×48 tap target
          SizedBox(
            width: BushDS.tapMin,
            height: BushDS.tapMin,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(BushDS.radiusMD),
                onTap: _isProcessing
                    ? null
                    : () => _sendMessage(_inputController.text),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(BushDS.radiusMD),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGlow,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send,
                            color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Model badge ────────────────────────────────────────────────────────────
  Widget _buildModelBadge() {
    final aiState = ref.watch(aiAssistantProvider);

    if (!kIsWeb) {
      // Mobile: Groq-only picker
      final selectedModel = ref.watch(selectedAiModelProvider);
      final label = _groqModels.entries
          .firstWhere((e) => e.value == selectedModel,
              orElse: () =>
                  const MapEntry('Llama 3.3 70B', 'llama-3.3-70b-versatile'))
          .key;
      return PopupMenuButton<String>(
        color: AppColors.panelMatte,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BushDS.radiusMD)),
        onSelected: (value) {
          ref.read(selectedAiModelProvider.notifier).state = value;
          OpenRouterService.selectedModel = value;
        },
        itemBuilder: (context) => [
          const PopupMenuItem<String>(
            enabled: false,
            child: Text('— MOBILE AI MODEL —',
                style: TextStyle(
                    color: AppColors.statusGreen,
                    fontSize: BushDS.fontXS,
                    fontWeight: FontWeight.bold)),
          ),
          ..._groqModels.entries.map((e) => PopupMenuItem<String>(
                value: e.value,
                child: Row(children: [
                  Icon(Icons.check,
                      color: selectedModel == e.value
                          ? AppColors.accent
                          : Colors.transparent,
                      size: 14),
                  const SizedBox(width: BushDS.spXS + 2),
                  Text(e.key,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: BushDS.fontSM)),
                ]),
              )),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: BushDS.spSM, vertical: BushDS.spXS),
          decoration: BoxDecoration(
            gradient: AppColors.steelGradient,
            borderRadius: BorderRadius.circular(BushDS.radiusSM),
            border: Border.all(
                color: AppColors.statusGreen.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.statusGreen,
                      fontSize: BushDS.fontXS,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: BushDS.spXS),
              const Icon(Icons.arrow_drop_down,
                  color: AppColors.statusGreen, size: 16),
            ],
          ),
        ),
      );
    }

    // ── Web: full provider + model picker ──────────────────────────────────
    final tier = aiState.currentTier;
    String badgeLabel;
    Color badgeColor;

    if (tier.isNotEmpty &&
        tier != 'Unknown' &&
        tier != 'Cloud' &&
        !tier.contains('Offline')) {
      if (tier.contains('Claude')) {
        badgeLabel =
            tier.contains('Haiku') ? 'Claude Haiku' : 'Claude Sonnet';
        badgeColor = const Color(0xFFFF6B35);
      } else if (tier.contains('Groq')) {
        badgeLabel = tier.contains('70B')
            ? 'Llama 70B'
            : tier.contains('8B')
                ? 'Llama 8B'
                : tier.contains('Mixtral')
                    ? 'Mixtral'
                    : 'Groq AI';
        badgeColor = AppColors.statusGreen;
      } else if (tier.contains('Gemini')) {
        badgeLabel =
            tier.contains('2.5') ? 'Gemini 2.5' : 'Gemini';
        badgeColor = AppColors.statusBlue;
      } else {
        badgeLabel = 'AI Active';
        badgeColor = AppColors.statusGreen;
      }
    } else {
      switch (OpenRouterService.selectedProvider) {
        case 'claude':
          badgeLabel = OpenRouterService.selectedClaudeModel.contains('haiku')
              ? 'Claude Haiku'
              : 'Claude Sonnet';
          badgeColor = const Color(0xFFFF6B35);
        case 'groq':
          final m = OpenRouterService.selectedModel;
          badgeLabel = m.contains('70b')
              ? 'Llama 70B'
              : m.contains('8b')
                  ? 'Llama 8B'
                  : m.contains('mixtral')
                      ? 'Mixtral'
                      : 'Groq AI';
          badgeColor = AppColors.statusGreen;
        case 'gemini':
          badgeLabel = GoogleAIService.selectedModel.contains('2.5')
              ? 'Gemini 2.5'
              : 'Gemini';
          badgeColor = AppColors.statusBlue;
        default:
          badgeLabel = 'Auto AI';
          badgeColor = AppColors.accent;
      }
    }

    return PopupMenuButton<_WebModelChoice>(
      color: AppColors.panelMatte,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BushDS.radiusMD)),
      onSelected: (_WebModelChoice choice) {
        OpenRouterService.selectedProvider = choice.provider;
        if (choice.provider == 'claude') {
          OpenRouterService.selectedClaudeModel = choice.modelId;
        } else if (choice.provider == 'gemini') {
          GoogleAIService.selectedModel = choice.modelId;
        } else if (choice.provider == 'groq') {
          OpenRouterService.selectedModel = choice.modelId;
        }
        setState(() {});
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<_WebModelChoice>>[];

        // Auto
        items.add(PopupMenuItem(
          value: const _WebModelChoice('auto', '', 'Auto'),
          child: Row(children: [
            Icon(Icons.auto_awesome,
                color: OpenRouterService.selectedProvider == 'auto'
                    ? AppColors.accent
                    : Colors.transparent,
                size: 14),
            const SizedBox(width: 6),
            const Text('Auto (Best Available)',
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: BushDS.fontSM)),
          ]),
        ));
        items.add(const PopupMenuDivider());

        // Claude
        items.add(const PopupMenuItem(
            enabled: false,
            child: Text('— CLAUDE (ANTHROPIC) —',
                style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: BushDS.fontXS,
                    fontWeight: FontWeight.bold))));
        for (final m in OpenRouterService.availableModels['claude']!) {
          final isActive = OpenRouterService.selectedProvider == 'claude' &&
              OpenRouterService.selectedClaudeModel == m['id'];
          items.add(PopupMenuItem(
            value: _WebModelChoice('claude', m['id']!, m['name']!),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Icon(Icons.check,
                  color: isActive ? AppColors.accent : Colors.transparent,
                  size: 14),
              const SizedBox(width: 6),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m['name']!,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: BushDS.fontSM)),
                    Text(m['desc']!,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
                  ]),
            ]),
          ));
        }
        items.add(const PopupMenuDivider());

        // Groq
        items.add(const PopupMenuItem(
            enabled: false,
            child: Text('— GROQ (LLAMA) —',
                style: TextStyle(
                    color: AppColors.statusGreen,
                    fontSize: BushDS.fontXS,
                    fontWeight: FontWeight.bold))));
        for (final m in OpenRouterService.availableModels['groq']!) {
          final isActive = OpenRouterService.selectedProvider == 'groq' &&
              OpenRouterService.selectedModel == m['id'];
          items.add(PopupMenuItem(
            value: _WebModelChoice('groq', m['id']!, m['name']!),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Icon(Icons.check,
                  color: isActive ? AppColors.accent : Colors.transparent,
                  size: 14),
              const SizedBox(width: 6),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m['name']!,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: BushDS.fontSM)),
                    Text(m['desc']!,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
                  ]),
            ]),
          ));
        }
        items.add(const PopupMenuDivider());

        // Gemini
        items.add(const PopupMenuItem(
            enabled: false,
            child: Text('— GEMINI (GOOGLE) —',
                style: TextStyle(
                    color: AppColors.statusBlue,
                    fontSize: BushDS.fontXS,
                    fontWeight: FontWeight.bold))));
        for (final m in OpenRouterService.availableModels['gemini']!) {
          final isActive = OpenRouterService.selectedProvider == 'gemini' &&
              GoogleAIService.selectedModel == m['id'];
          items.add(PopupMenuItem(
            value: _WebModelChoice('gemini', m['id']!, m['name']!),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Icon(Icons.check,
                  color: isActive ? AppColors.accent : Colors.transparent,
                  size: 14),
              const SizedBox(width: 6),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m['name']!,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: BushDS.fontSM)),
                    Text(m['desc']!,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
                  ]),
            ]),
          ));
        }

        return items;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: BushDS.spSM, vertical: BushDS.spXS),
        decoration: BoxDecoration(
          gradient: AppColors.steelGradient,
          borderRadius: BorderRadius.circular(BushDS.radiusSM),
          border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badgeLabel,
                style: TextStyle(
                    color: badgeColor,
                    fontSize: BushDS.fontXS,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: BushDS.spXS),
            Icon(Icons.arrow_drop_down, color: badgeColor, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  IconData _getActionIcon(String action) {
    switch (action) {
      case 'Drop Pin':       return Icons.add_location_alt;
      case 'Start Navigation':
      case 'Guide Me There': return Icons.navigation;
      case 'Activate SOS':   return Icons.sos;
      default:               return Icons.touch_app;
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isProcessing) return;

    OpenRouterService.selectedModel = ref.read(selectedAiModelProvider);

    final timestamp = DateTime.now();
    ref.read(chatHistoryProvider.notifier).addMessage(ChatMessage(
          role: 'user',
          content: text.trim(),
          timestamp: timestamp,
        ));
    setState(() => _isProcessing = true);
    _inputController.clear();

    final locationState = ref.read(locationProvider);
    final lat   = locationState.stats.currentLat ?? 0;
    final lon   = locationState.stats.currentLon ?? 0;
    final speed = locationState.stats.speedFormatted;

    if (lat != 0 && lon != 0) await _fetchLocationName(lat, lon);

    final allMessages = ref.read(chatHistoryProvider);
    final conversationHistory =
        allMessages.map((m) => {'role': m.role, 'content': m.content}).toList();
    final lastMessages = allMessages.length > 10
        ? allMessages.sublist(allMessages.length - 10)
        : allMessages;

    try {
      await ref.read(aiAssistantProvider.notifier).processTextIntent(
            text,
            conversationHistory: conversationHistory,
            overrideSystemPrompt: _buildSystemPrompt(lat, lon, speed, lastMessages),
          );
      final rawResponse = ref.read(aiAssistantProvider).lastResponse;

      // Parse and strip <CMD:...> map-control commands from the response
      final cmdRegex = RegExp(r'<CMD:([^>]+)>', multiLine: true);
      final cmds = cmdRegex.allMatches(rawResponse).map((m) => m.group(1)!).toList();
      final response = rawResponse.replaceAll(cmdRegex, '').trim();
      for (final cmd in cmds) {
        _executeAICommand(cmd, lat, lon);
      }

      ref.read(chatHistoryProvider.notifier).addMessage(ChatMessage(
            role: 'assistant',
            content: response,
            timestamp: DateTime.now(),
            actions: _extractActions(response),
          ));

      _memory.conversations
        ..add(ConversationEntry(
            role: 'user',
            content: text.trim(),
            timestamp: timestamp.toIso8601String()))
        ..add(ConversationEntry(
            role: 'assistant',
            content: response,
            timestamp: DateTime.now().toIso8601String()));

      _extractFacts(text);
      _saveMemory();
      _scrollToBottom();
    } catch (e) {
      ref.read(chatHistoryProvider.notifier).addMessage(ChatMessage(
            role: 'assistant',
            content: 'Sorry, I encountered an error. Please try again.',
            timestamp: DateTime.now(),
          ));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _buildSystemPrompt(
      double lat, double lon, String speed, List<ChatMessage> lastMessages) {
    final uf = _memory.userFacts;
    final locationState = ref.read(locationProvider);
    final pinWaypoints = locationState.waypoints
        .where((w) => w.isPin == true || w.type == WaypointType.manual)
        .toList();
    final waypointSummary = pinWaypoints.isEmpty
        ? 'No waypoints saved yet'
        : '${pinWaypoints.length} waypoints: ${pinWaypoints.take(5).map((w) => w.label).join(', ')}${pinWaypoints.length > 5 ? '...' : ''}';

    return '''
You are BushAI — the built-in assistant for BushTracker, an offline GPS and navigation app for remote Australia. Built by Dennis — Future Gen AI Pty Ltd.

Talk like a knowledgeable mate who knows the bush — direct, practical, warm, no fluff. Think of yourself as the experienced bloke in the crew who always knows what to do when things get tough out there. You can talk about anything — survival, navigation, vehicles, life, general chat. The outback gets lonely, be good company.

You remember everything in this conversation. Build on what's been said. Never start from scratch.

Current field data (weave in naturally when relevant):
- GPS: $lat, $lon  |  Location: ${_locationName.isNotEmpty ? _locationName : 'resolving...'}  |  Speed: $speed  |  Time: ${DateTime.now().toLocal()}
- Saved waypoints: $waypointSummary
- User name: ${uf.name ?? 'unknown'}  |  Vehicle: ${uf.vehicle ?? 'unknown'}
- Home base: ${uf.homeBase ?? 'unknown'}  |  Emergency contact: ${uf.emergencyContact ?? 'none'}

Keep responses concise — users check their phone quickly in the field. For safety-critical info, be clear and direct. Never refuse to help with something that could keep someone safe in the bush.

MAP CONTROL — when the user asks you to interact with the map, append ONE silent command on the very last line of your response. These are stripped before display — users never see them.
Commands:
  <CMD:MAP_MOVE_USER> — center map on user GPS
  <CMD:MAP_ZOOM_IN> — zoom in one level
  <CMD:MAP_ZOOM_OUT> — zoom out one level
  <CMD:MAP_FIT_WAYPOINTS> — zoom to show all waypoints
  <CMD:MAP_NAV:place name> — start turn-by-turn navigation to a place (e.g. <CMD:MAP_NAV:Alice Springs>)
Only include a command when the user explicitly asks to move the map, zoom, or navigate somewhere.''';
  }

  void _executeAICommand(String cmd, double lat, double lon) {
    if (cmd == 'MAP_MOVE_USER' && lat != 0) {
      ref.read(pendingMapActionProvider.notifier).state =
          MapAction(MapActionType.moveTo, location: LatLng(lat, lon), zoom: 15);
    } else if (cmd == 'MAP_ZOOM_IN') {
      ref.read(pendingMapActionProvider.notifier).state =
          MapAction(MapActionType.zoomIn);
    } else if (cmd == 'MAP_ZOOM_OUT') {
      ref.read(pendingMapActionProvider.notifier).state =
          MapAction(MapActionType.zoomOut);
    } else if (cmd == 'MAP_FIT_WAYPOINTS') {
      ref.read(pendingMapActionProvider.notifier).state =
          MapAction(MapActionType.fitWaypoints);
    } else if (cmd.startsWith('MAP_NAV:')) {
      final dest = cmd.substring('MAP_NAV:'.length).trim();
      if (dest.isNotEmpty) {
        ref.read(navigationProvider.notifier).calculateRoute(dest);
      }
    }
  }

  List<String> _extractActions(String response) {
    final actions = <String>[];
    final lower = response.toLowerCase();
    if (lower.contains('drop a waypoint') || lower.contains('drop pin')) {
      actions.add('Drop Pin');
    }
    if (lower.contains('area scan complete') ||
        (lower.contains('pinned') && lower.contains('nearest')) ||
        lower.contains('guide me there')) {
      actions.add('Guide Me There');
    } else if (lower.contains('navigate') || lower.contains('navigation')) {
      actions.add('Start Navigation');
    }
    if (lower.contains('sos') || lower.contains('emergency')) {
      actions.add('Activate SOS');
    }
    return actions;
  }

  void _handleAction(String action, BuildContext context) {
    switch (action) {
      case 'Drop Pin':
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tap on the map to drop a pin'),
            backgroundColor: AppColors.accent,
          ),
        );
      case 'Guide Me There':
      case 'Start Navigation':
        final places = ref.read(aiAssistantProvider).nearbyPlaces;
        if (places.isNotEmpty) {
          final nearest  = places.first;
          final name     = nearest['name'] as String? ?? 'destination';
          final destLat  = (nearest['lat'] as num).toDouble();
          final destLon  = (nearest['lon'] as num).toDouble();
          ref.read(navigationProvider.notifier).navigateTo(destLat, destLon, name);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Navigating to $name'),
              backgroundColor: AppColors.statusGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ask me to scan the area first'),
              backgroundColor: AppColors.accent,
            ),
          );
        }
      case 'Activate SOS':
        ref.read(aiAssistantProvider.notifier).activateEmergencyProtocol();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.panelMatte,
            title: const Row(children: [
              Icon(Icons.sos, color: AppColors.statusRed, size: 28),
              SizedBox(width: BushDS.spSM),
              Text('SOS Activated',
                  style: TextStyle(color: AppColors.textPrimary)),
            ]),
            content: const Text(
              'Emergency beacon activated. Your location will be broadcast to all nearby mesh nodes.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK',
                    style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ),
        );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

// ── Bottom sheet launcher ─────────────────────────────────────────────────────
void showAIChat(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(BushDS.radiusXL)),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGlow,
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: const AIChatScreen(),
    ),
  );
}
