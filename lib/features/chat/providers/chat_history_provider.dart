import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Chat Message Model ───────────────────────────────────────────────────────
class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final List<String> actions;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.actions = const [],
  });
}

// ─── Persistent Chat History Provider ────────────────────────────────────────
class ChatHistoryNotifier extends StateNotifier<List<ChatMessage>> {
  ChatHistoryNotifier() : super([]);

  void addMessage(ChatMessage message) {
    state = [...state, message];
  }

  void clear() {
    state = [];
  }
}

final chatHistoryProvider =
    StateNotifierProvider<ChatHistoryNotifier, List<ChatMessage>>(
  (ref) => ChatHistoryNotifier(),
);
