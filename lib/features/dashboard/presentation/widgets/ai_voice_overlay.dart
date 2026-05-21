import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/features/ai/providers/ai_assistant_provider.dart';
import 'package:bush_track/theme/app_colors.dart';

class AiVoiceOverlay extends ConsumerStatefulWidget {
  const AiVoiceOverlay({super.key});

  @override
  ConsumerState<AiVoiceOverlay> createState() => _AiVoiceOverlayState();
}

class _AiVoiceOverlayState extends ConsumerState<AiVoiceOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiAssistantProvider);

    if (!aiState.isListening && !aiState.isSpeaking && !aiState.isProcessing) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AI Tier Indicator Badge
            if (aiState.isProcessing || aiState.isSpeaking)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getTierColor(aiState).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getTierColor(aiState),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getTierIcon(aiState),
                      color: _getTierColor(aiState),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTierLabel(aiState).toUpperCase(),
                      style: TextStyle(
                        color: _getTierColor(aiState),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Main animated icon
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getIconColor(aiState).withValues(alpha: 0.3),
                  boxShadow: [
                    BoxShadow(
                      color: _getIconColor(aiState),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  _getIcon(aiState),
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 40),
            
            // Status text
            Text(
              _getStatusText(aiState),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Current tier subtitle
            if (aiState.isProcessing || aiState.isSpeaking)
              Text(
                aiState.currentTier,
                style: TextStyle(
                  color: _getTierColor(aiState).withValues(alpha: 0.8),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Show recognized text when listening
            if (aiState.isListening && aiState.lastRecognizedText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  '"${aiState.lastRecognizedText}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (aiState.lastError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8),
                child: Text(
                  aiState.lastError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.statusRed,
                    fontSize: BushDS.fontLG,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            
            // Show response preview when speaking (last 100 chars)
            if (aiState.isSpeaking && aiState.lastResponse.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8),
                child: Text(
                  aiState.lastResponse.length > 100 
                      ? '${aiState.lastResponse.substring(0, 100)}...'
                      : aiState.lastResponse,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 14,
                  ),
                ),
              ),
            
            const SizedBox(height: 40),
            
            // Tier status summary (when not processing)
            if (!aiState.isProcessing && aiState.tierStatus.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smart_toy,
                            color: Colors.white.withValues(alpha: 0.6),
                            size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'AI TIERS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: BushDS.fontXS,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...aiState.tierStatus.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: BushDS.fontXS,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            
            const SizedBox(height: 60),
            
            // Close button
            SizedBox(
              width: BushDS.tapMin,
              height: BushDS.tapMin,
              child: IconButton(
                iconSize: 28,
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: () {
                  if (aiState.isListening) {
                    ref.read(aiAssistantProvider.notifier).stopListening();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Get color based on AI tier
  Color _getTierColor(AiState state) {
    if (state.isOfflineMode) {
      if (state.isOnDeviceMode) {
        return AppColors.purplePrimary;
      }
      return AppColors.statusYellow;
    }
    return AppColors.statusGreen;
  }
  
  // Get icon based on AI tier
  IconData _getTierIcon(AiState state) {
    if (state.isOfflineMode) {
      if (state.isOnDeviceMode) {
        return Icons.memory; // On-device chip icon
      }
      return Icons.cloud_off; // Offline
    }
    return Icons.cloud_done; // Cloud
  }
  
  // Get tier label
  String _getTierLabel(AiState state) {
    if (state.isOfflineMode) {
      if (state.isOnDeviceMode) {
        return 'On-Device AI';
      }
      return 'Offline Mode';
    }
    return 'Cloud AI';
  }
  
  // Get icon color based on state
  Color _getIconColor(AiState state) {
    if (state.isProcessing) {
      return AppColors.statusBlue;
    } else if (state.isSpeaking) {
      return AppColors.statusGreen;
    } else {
      return AppColors.accent;
    }
  }
  
  // Get icon based on state
  IconData _getIcon(AiState state) {
    if (state.isProcessing) {
      return Icons.psychology; // Processing/thinking
    } else if (state.isSpeaking) {
      return Icons.speaker_phone; // Speaking
    } else {
      return Icons.mic; // Listening
    }
  }
  
  // Get status text
  String _getStatusText(AiState state) {
    if (state.isProcessing) {
      return 'Future Gen AI is thinking...';
    } else if (state.isSpeaking) {
      return 'A.I. is speaking...';
    } else {
      return 'A.I. is listening...';
    }
  }
}
