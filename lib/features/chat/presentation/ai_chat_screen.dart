import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/ai/providers/ai_assistant_provider.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/features/chat/providers/chat_history_provider.dart';

const String _memoryKey = 'antigravity_memory';

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

  factory UserFacts.fromJson(Map<String, dynamic> json) {
    return UserFacts(
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

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp,
      };

  factory ConversationEntry.fromJson(Map<String, dynamic> json) {
    return ConversationEntry(
      role: json['role'],
      content: json['content'],
      timestamp: json['timestamp'],
    );
  }
}

class AntigravityMemory {
  List<ConversationEntry> conversations;
  UserFacts userFacts;

  AntigravityMemory()
      : conversations = [],
        userFacts = UserFacts();

  Map<String, dynamic> toJson() {
    return {
      'conversations': conversations.map((c) => c.toJson()).toList(),
      'userFacts': userFacts.toJson(),
    };
  }

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

final List<Map<String, String>> _conversationStarters = [
  {
    'label': 'Where am I?',
    'icon': '📍',
    'query': 'Where am I right now? What are my exact coordinates?'
  },
  {
    'label': 'Nearest water?',
    'icon': '💧',
    'query': 'Find the nearest water source or dam within 50km'
  },
  {
    'label': "How's my battery?",
    'icon': '🔋',
    'query': 'What is my current device battery level and power status?'
  },
  {
    'label': 'Set up camp?',
    'icon': '⛺',
    'query': 'Find a good campsite nearby with flat terrain and wind protection'
  },
  {
    'label': 'Where did I come from?',
    'icon': '🧭',
    'query': 'Show me my recent track and where I started from'
  },
  {
    'label': 'SOS help',
    'icon': '🆘',
    'query': 'What should I do in an emergency? Activate SOS protocol'
  },
];

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
  final String _streamingResponse = '';

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

  void _loadMemory() {
    try {
      final locationState = ref.read(locationProvider);
      final pinWaypoints = locationState.waypoints
          .where((w) => w.isPin == true || w.type == WaypointType.manual)
          .toList();

      debugPrint(
          'Loaded ${_memory.conversations.length} conversations from memory');
      debugPrint(
          'User facts: name=${_memory.userFacts.name}, vehicle=${_memory.userFacts.vehicle}');
    } catch (e) {
      debugPrint('Error loading memory: $e');
    }
  }

  void _saveMemory() {
    try {
      final memoryJson = _memory.toJson();
      debugPrint('Saving memory to localStorage: ${memoryJson.length} entries');
    } catch (e) {
      debugPrint('Error saving memory: $e');
    }
  }

  void _extractFacts(String userMessage) {
    final lowerUser = userMessage.toLowerCase();

    final namePatterns = [
      RegExp(r"my name is (.+?)(?:\.|,|$|\s)"),
      RegExp(r"i'm (.+?)(?:\.|,|$|\s)"),
      RegExp(r"call me (.+?)(?:\.|,|$|\s)"),
      RegExp(r"my name's (.+?)(?:\.|,|$|\s)"),
    ];
    for (final pattern in namePatterns) {
      final match = pattern.firstMatch(lowerUser);
      if (match != null && match.group(1) != null) {
        final name = match.group(1)!.trim();
        if (name.length > 1 && name.length < 30) {
          _memory.userFacts.name = name;
          debugPrint('Extracted name: $name');
        }
      }
    }

    final vehiclePatterns = [
      RegExp(
          r"(?:i drive|i ride|i travel in|i use)\s+(?:my\s+)?(.+?)(?:\s+for|\s+to|\.|,|$)"),
      RegExp(
          r"(?:my car|my ute|my truck|my bike|my vehicle)\s+is\s+(.+?)(?:\.|,|$)"),
      RegExp(r"(?:i have a|i own a)\s+(.+?)(?:\.|,|$)"),
    ];
    for (final pattern in vehiclePatterns) {
      final match = pattern.firstMatch(lowerUser);
      if (match != null && match.group(1) != null) {
        final vehicle = match.group(1)!.trim();
        if (vehicle.length > 2) {
          _memory.userFacts.vehicle = vehicle;
          debugPrint('Extracted vehicle: $vehicle');
        }
      }
    }

    final homePatterns = [
      RegExp(r"(?:home base|home is|from|based in)\s+(.+?)(?:\.|,|$)"),
      RegExp(r"(?:i live in|i'm from)\s+(.+?)(?:\.|,|$)"),
    ];
    for (final pattern in homePatterns) {
      final match = pattern.firstMatch(lowerUser);
      if (match != null && match.group(1) != null) {
        final home = match.group(1)!.trim();
        if (home.length > 2) {
          _memory.userFacts.homeBase = home;
          debugPrint('Extracted homeBase: $home');
        }
      }
    }

    final emergencyPatterns = [
      RegExp(
          r"(?:emergency contact|contact in case of emergency|if something happens contact)\s+(.+?)(?:\.|,|$)"),
      RegExp(r"(?:my emergency contact is|notify)\s+(.+?)(?:\.|,|$)"),
    ];
    for (final pattern in emergencyPatterns) {
      final match = pattern.firstMatch(lowerUser);
      if (match != null && match.group(1) != null) {
        final contact = match.group(1)!.trim();
        if (contact.length > 2) {
          _memory.userFacts.emergencyContact = contact;
          debugPrint('Extracted emergencyContact: $contact');
        }
      }
    }

    if (lowerUser.contains('frequent') ||
        lowerUser.contains('often') ||
        lowerUser.contains('regular')) {
      if (lowerUser.contains('route') ||
          lowerUser.contains('trip') ||
          lowerUser.contains('track')) {
        final routePatterns = [
          RegExp(r"(?:between|from)\s+(.+?)\s+(?:to|and)\s+(.+?)(?:\.|,|$)"),
        ];
        for (final pattern in routePatterns) {
          final match = pattern.firstMatch(lowerUser);
          if (match != null) {
            final route = '${match.group(1)} to ${match.group(2)}';
            if (!_memory.userFacts.frequentRoutes.contains(route)) {
              _memory.userFacts.frequentRoutes.add(route);
              debugPrint('Added frequent route: $route');
            }
          }
        }
      }
    }

    _saveMemory();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final aiState = ref.watch(aiAssistantProvider);
    final messages = ref.watch(chatHistoryProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.panelLight),
              ),
            ),
            child: Row(
              children: [
                const Text('🤖 ', style: TextStyle(fontSize: 20)),
                const Text('🧠 ANTIGRAVITY',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    )),
                const SizedBox(width: 12),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: aiState.isOfflineMode
                        ? Colors.orange
                        : AppColors.statusGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  aiState.isOfflineMode ? 'OFFLINE' : 'ONLINE',
                  style: TextStyle(
                    color: aiState.isOfflineMode
                        ? Colors.orange
                        : AppColors.statusGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          if (messages.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 Ask me anything:',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _conversationStarters.map((q) {
                      return GestureDetector(
                        onTap: () => _sendMessage(q['query']!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.panelLight,
                                AppColors.panelMatte,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.primaryOrange
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(q['icon']!,
                                  style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(q['label']!,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppColors.primaryOrange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb,
                            color: AppColors.primaryOrange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'I remember everything you tell me. Share your name, vehicle, or home base and I\'ll keep track!',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isUser = msg.role == 'user';
                return _buildMessageBubble(msg, isUser);
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.panelLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    _isListening ? AppColors.statusGreen : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_isListening) {
                      ref.read(aiAssistantProvider.notifier).stopListening();
                      setState(() => _isListening = false);
                    } else {
                      setState(() => _isListening = true);
                      ref.read(aiAssistantProvider.notifier).startListening();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isListening
                          ? AppColors.statusGreen.withValues(alpha: 0.2)
                          : AppColors.panelMatte,
                      borderRadius: BorderRadius.circular(22),
                      border: _isListening
                          ? Border.all(color: AppColors.statusGreen, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: _isListening
                          ? const _PulsingMicIcon()
                          : const Text('🎙️', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'Listening...'
                          : '🤖 Ask Antigravity...',
                      hintStyle: TextStyle(
                          color: _isListening
                              ? AppColors.statusGreen
                              : Colors.white30),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (value) => _sendMessage(value),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isProcessing
                      ? null
                      : () => _sendMessage(_inputController.text),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5722).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (aiState.lastError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                aiState.lastError,
                style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('A',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    )),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
                      )
                    : null,
                color: isUser ? null : AppColors.panelLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  if (!isUser && msg.actions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: msg.actions.map((action) {
                          return GestureDetector(
                            onTap: () => _handleAction(action, context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primaryOrange
                                        .withValues(alpha: 0.4),
                                    AppColors.deepOrange.withValues(alpha: 0.4),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: AppColors.primaryOrange),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getActionIcon(action),
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(action,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'Drop Pin':
        return Icons.add_location;
      case 'Start Navigation':
        return Icons.navigation;
      case 'Activate SOS':
        return Icons.sos;
      default:
        return Icons.touch_app;
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isProcessing) return;

    final timestamp = DateTime.now();
    ref.read(chatHistoryProvider.notifier).addMessage(ChatMessage(
          role: 'user',
          content: text.trim(),
          timestamp: timestamp,
        ));
    setState(() => _isProcessing = true);

    _inputController.clear();

    final locationState = ref.read(locationProvider);
    final lat = locationState.stats.currentLat ?? 0;
    final lon = locationState.stats.currentLon ?? 0;
    final speed = locationState.stats.speedFormatted;

    final currentMessages = ref.read(chatHistoryProvider);
    final lastMessages = currentMessages.length > 10
        ? currentMessages.sublist(currentMessages.length - 10)
        : currentMessages;

    final systemPrompt = _buildSystemPrompt(lat, lon, speed, lastMessages);

    try {
      await ref.read(aiAssistantProvider.notifier).processTextIntent(text);
      final response = ref.read(aiAssistantProvider).lastResponse;

      final actions = _extractActions(response);

      ref.read(chatHistoryProvider.notifier).addMessage(ChatMessage(
            role: 'assistant',
            content: response,
            timestamp: DateTime.now(),
            actions: actions,
          ));
      setState(() => _isProcessing = false);

      _memory.conversations.add(ConversationEntry(
        role: 'user',
        content: text.trim(),
        timestamp: timestamp.toIso8601String(),
      ));
      _memory.conversations.add(ConversationEntry(
        role: 'assistant',
        content: response,
        timestamp: DateTime.now().toIso8601String(),
      ));

      _extractFacts(text);
      _saveMemory();
      _scrollToBottom();
    } catch (e) {
      ref.read(chatHistoryProvider.notifier).addMessage(ChatMessage(
            role: 'assistant',
            content: 'Sorry, I encountered an error. Please try again.',
            timestamp: DateTime.now(),
          ));
      setState(() => _isProcessing = false);
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
You are Antigravity, survival AI for BushTrack.
Current location: $lat, $lon
Current time: ${DateTime.now().toIso8601String()}
Speed: $speed
Nearby waypoints: $waypointSummary
Weather: 28°C NE 12km/h

What I know about this user:
Name: ${uf.name ?? 'unknown'}
Vehicle: ${uf.vehicle ?? 'unknown'}
Home base: ${uf.homeBase ?? 'unknown'}
Emergency contact: ${uf.emergencyContact ?? 'none'}
Frequent routes: ${uf.frequentRoutes.isEmpty ? 'none' : uf.frequentRoutes.join(', ')}

Recent conversation:
${lastMessages.map((m) => '${m.role == 'user' ? 'User' : 'AI'}: ${m.content}').join('\n')}

You remember everything the user tells you.
You are concise, field-ready, survival-focused.
You speak like a trusted field partner.
Never forget what the user has told you.
''';
  }

  List<String> _extractActions(String response) {
    final actions = <String>[];
    final lower = response.toLowerCase();

    if (lower.contains('drop a waypoint') || lower.contains('drop pin')) {
      actions.add('Drop Pin');
    }
    if (lower.contains('navigate') || lower.contains('navigation')) {
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
            backgroundColor: AppColors.primaryOrange,
          ),
        );
        break;
      case 'Start Navigation':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Setting navigation target...'),
            backgroundColor: AppColors.statusGreen,
          ),
        );
        break;
      case 'Activate SOS':
        ref.read(aiAssistantProvider.notifier).activateEmergencyProtocol();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.panelMatte,
            title: const Row(
              children: [
                Icon(Icons.sos, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('SOS Activated', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: const Text(
              'Emergency beacon activated. Your location will be broadcast to all nearby mesh nodes.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK',
                    style: TextStyle(color: AppColors.primaryOrange)),
              ),
            ],
          ),
        );
        break;
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

class _PulsingMicIcon extends StatefulWidget {
  const _PulsingMicIcon();

  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: const Text('🎙️', style: TextStyle(fontSize: 20)),
        );
      },
    );
  }
}

// ChatMessage is now defined in chat_history_provider.dart

void showAIChat(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: AppColors.primaryOrange.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: const AIChatScreen(),
    ),
  );
}
