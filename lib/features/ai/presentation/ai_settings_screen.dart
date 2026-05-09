import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/ai/services/openrouter_service.dart';
import 'package:bush_track/core/services/unified_voice_service.dart';

class AISettingsScreen extends ConsumerStatefulWidget {
  const AISettingsScreen({super.key});

  @override
  ConsumerState<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends ConsumerState<AISettingsScreen> {
  String _aiStatus = 'Testing...';
  Map<String, String> _tierStatus = {};
  bool _isLoading = true;
  String _preferredTier = 'auto';
  double _voiceSpeed = 1.1;

  @override
  void initState() {
    super.initState();
    _testAI();
  }

  Future<void> _testAI() async {
    final service = OpenRouterService();
    await service.initializeOnDeviceAI();
    
    setState(() {
      _tierStatus = {};
      _isLoading = false;
      _aiStatus = 'Multi-tier AI ready';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('🤖 AI SETTINGS'),
        backgroundColor: AppColors.panelMatte,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Status', style: TextStyle(color: AppColors.goldPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_isLoading)
                  const Row(children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.primaryOrange, strokeWidth: 2)), SizedBox(width: 12), Text('Testing AI connections...', style: TextStyle(color: Colors.white70))])
                else
                  ..._tierStatus.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(e.value.contains('✅') ? Icons.check_circle : Icons.cancel, color: e.value.contains('✅') ? AppColors.statusGreen : AppColors.statusRed, size: 18),
                      const SizedBox(width: 8),
                      Text(e.key, style: const TextStyle(color: Colors.white)),
                      const Spacer(),
                      Text(e.value, style: TextStyle(color: e.value.contains('✅') ? AppColors.statusGreen : AppColors.statusRed)),
                    ]),
                  )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // AI Provider Selection
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Preferred AI Provider', style: TextStyle(color: AppColors.goldPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Auto mode automatically selects the best available AI based on connectivity.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 16),
                _buildTierOption('auto', '🌐 Auto (Recommended)', 'Automatically selects best available AI'),
                _buildTierOption('cloud', '☁️ Cloud AI Only', 'Uses OpenRouter (requires internet)'),
                _buildTierOption('local', '🖥️ Local AI Only', 'Uses Ollama on device'),
                _buildTierOption('offline', '📋 Offline Mode', 'Rule-based only (always works)'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Voice Settings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Voice Settings', style: TextStyle(color: AppColors.goldPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('Voice Speed', style: TextStyle(color: Colors.white)),
                Slider(
                  value: _voiceSpeed,
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  activeColor: AppColors.primaryOrange,
                  label: _getSpeedLabel(_voiceSpeed),
                  onChanged: (v) => setState(() => _voiceSpeed = v),
                  onChangeEnd: (v) => _applyVoiceSpeed(v),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Slow', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(_getSpeedLabel(_voiceSpeed), style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
                  const Text('Fast', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Test Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, padding: const EdgeInsets.all(16)),
                  icon: const Icon(Icons.mic),
                  label: const Text('Test Voice'),
                  onPressed: _testVoice,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.purplePrimary, padding: const EdgeInsets.all(16)),
                  icon: const Icon(Icons.smart_toy),
                  label: const Text('Test AI'),
                  onPressed: _testAIResponse,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierOption(String value, String title, String subtitle) {
    final isSelected = _preferredTier == value;
    return GestureDetector(
      onTap: () => setState(() => _preferredTier = value),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.2) : AppColors.panelLight,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: AppColors.primaryOrange, width: 2) : null,
        ),
        child: Row(children: [
          Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? AppColors.primaryOrange : Colors.white54),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: isSelected ? AppColors.primaryOrange : Colors.white, fontWeight: FontWeight.w600)),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }

  String _getSpeedLabel(double speed) {
    if (speed <= 0.9) return 'Slow';
    if (speed <= 1.05) return 'Normal';
    if (speed <= 1.2) return 'Fast';
    return 'Very Fast';
  }

  Future<void> _applyVoiceSpeed(double speed) async {
    final label = _getSpeedLabel(speed);
    await voiceService.setSpeechRate(label);
  }

  Future<void> _testVoice() async {
    await voiceService.speak('Antigravity online. Voice test successful.');
  }

  Future<void> _testAIResponse() async {
    setState(() => _aiStatus = 'Testing...');
    final service = OpenRouterService();
    final response = await service.getAiResponse('Hello, what can you help me with?');
    await voiceService.speak(response);
    setState(() => _aiStatus = service.lastUsedTier);
  }
}