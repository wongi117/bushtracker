import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/mesh/providers/mesh_provider.dart';
import 'package:bush_track/features/ai/providers/ai_assistant_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = []; // sender, text

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble, color: AppColors.primaryOrange),
                SizedBox(width: 8),
                Text('COMMS & A.I. CHAT', style: TextStyle(color: Colors.white, fontSize: BushDS.fontXL, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender'] == 'Me';
                final isAI = msg['sender'] == 'A.I.';
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primaryOrange.withValues(alpha: 0.2) : AppColors.panelLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isMe ? AppColors.primaryOrange : (isAI ? AppColors.statusGreen : AppColors.textSecondary.withValues(alpha: 0.5)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['sender']!,
                          style: TextStyle(
                            color: isMe ? AppColors.primaryOrange : (isAI ? AppColors.statusGreen : AppColors.textSecondary),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(msg['text']!, style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Message A.I. or crew...',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.panelMatte,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: BushDS.tapMin,
                  height: BushDS.tapMin,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.send, color: AppColors.primaryOrange),
                    onPressed: () {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) {
                        setState(() {
                          _messages.add({'sender': 'Me', 'text': text});
                        });
                        _controller.clear();
                        ref.read(aiAssistantProvider.notifier).processTextIntent(text);
                        ref.read(meshProvider.notifier).sendMessage(text);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
