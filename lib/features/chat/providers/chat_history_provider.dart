import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/ai/providers/ai_assistant_provider.dart';
import 'package:bush_track/core/models/waypoint.dart';

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
