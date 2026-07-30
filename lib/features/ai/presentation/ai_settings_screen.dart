import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/core/config/api_config.dart';
import 'package:bush_track/features/ai/services/openrouter_service.dart';
import 'package:bush_track/features/ai/services/google_ai_service.dart';
import 'package:bush_track/core/services/unified_voice_service.dart';

class AISettingsScreen extends ConsumerStatefulWidget {
  const AISettingsScreen({super.key});

  @override
  ConsumerState<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends ConsumerState<AISettingsScreen> {
  Map<String, String> _tierStatus = {};
  bool _isLoading = true;
  String _lastTestedTier = '';
  double _voiceSpeed = 1.1;

  // Live selections — mirror the statics
  String _provider = OpenRouterService.selectedProvider;
  String _claudeModel = OpenRouterService.selectedClaudeModel;
  String _groqModel = OpenRouterService.selectedModel;
  String _geminiModel = GoogleAIService.selectedModel;

  @override
  void initState() {
    super.initState();
    _testConnections();
  }

  // ── Connection test ──────────────────────────────────────────────────────

  Future<void> _testConnections() async {
    setState(() { _isLoading = true; _tierStatus = {}; });
    final status = <String, String>{};

    // Groq
    final groqKeySet = ApiConfig.groqKey.isNotEmpty;
    status['Groq API Key'] = groqKeySet ? '✅ Configured' : '❌ Missing';
    if (groqKeySet) {
      try {
        final r = await http.get(Uri.parse('https://api.groq.com'))
            .timeout(const Duration(seconds: 6));
        status['Groq Endpoint'] = r.statusCode < 500 ? '✅ Reachable' : '❌ HTTP ${r.statusCode}';
      } catch (_) {
        status['Groq Endpoint'] = '❌ Unreachable';
      }
    }

    // Gemini
    final gemKeySet = ApiConfig.geminiKey.isNotEmpty;
    status['Gemini API Key'] = gemKeySet ? '✅ Configured' : '❌ Missing';
    if (gemKeySet) {
      try {
        // Lightweight ping — just the models list endpoint
        final r = await http.get(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=${ApiConfig.geminiKey}'),
        ).timeout(const Duration(seconds: 6));
        status['Gemini Endpoint'] = r.statusCode == 200 ? '✅ Reachable' : '❌ HTTP ${r.statusCode}';
      } catch (_) {
        status['Gemini Endpoint'] = '❌ Unreachable';
      }
    }

    status['Offline Mode'] = '✅ Always available';

    setState(() { _tierStatus = status; _isLoading = false; });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _applyProvider(String p) {
    setState(() => _provider = p);
    OpenRouterService.selectedProvider = p;
  }

  void _applyClaudeModel(String m) {
    setState(() => _claudeModel = m);
    OpenRouterService.selectedClaudeModel = m;
  }

  void _applyGroqModel(String m) {
    setState(() => _groqModel = m);
    OpenRouterService.selectedModel = m;
  }

  void _applyGeminiModel(String m) {
    setState(() => _geminiModel = m);
    GoogleAIService.selectedModel = m;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.smart_toy, color: AppColors.accent, size: 20),
          SizedBox(width: 8),
          Text('AI SETTINGS'),
        ]),
        backgroundColor: AppColors.panelMatte,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _testConnections,
            tooltip: 'Re-test connections',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statusCard(),
          const SizedBox(height: 20),
          _providerCard(),
          const SizedBox(height: 20),
          _modelCard(),
          const SizedBox(height: 20),
          _voiceCard(),
          const SizedBox(height: 20),
          _testButtons(),
          const SizedBox(height: 8),
          if (_lastTestedTier.isNotEmpty) _lastUsedBadge(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Status card ──────────────────────────────────────────────────────────

  Widget _statusCard() {
    return _card(
      title: 'API Status',
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: AppColors.primaryOrange, strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Testing connections…', style: TextStyle(color: Colors.white70)),
              ]),
            )
          : Column(
              children: _tierStatus.entries.map((e) {
                final ok = e.value.contains('✅');
                final warn = e.value.contains('❌');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Icon(
                      ok ? Icons.check_circle : warn ? Icons.cancel : Icons.warning_rounded,
                      color: ok ? AppColors.statusGreen : warn ? AppColors.statusRed : AppColors.statusYellow,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.key, style: const TextStyle(color: Colors.white, fontSize: 13))),
                    Text(
                      e.value.replaceAll('✅ ', '').replaceAll('❌ ', '').replaceAll('⚠️ ', ''),
                      style: TextStyle(
                        fontSize: 11,
                        color: ok ? AppColors.statusGreen : warn ? AppColors.statusRed : AppColors.statusYellow,
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
    );
  }

  // ── Provider picker ──────────────────────────────────────────────────────

  Widget _providerCard() {
    return _card(
      title: 'AI Provider',
      subtitle: 'Auto tries Claude → Groq → Gemini → Offline.',
      child: Column(children: [
        _providerOption('auto', Icons.auto_awesome, 'Auto (Recommended)',
            'Claude → Groq → Gemini → Offline fallback chain'),
        _providerOption('claude', Icons.psychology, 'Claude (Anthropic)',
            'Sonnet / Haiku — smartest reasoning'),
        _providerOption('groq', Icons.bolt, 'Groq Only',
            'Llama 3.3 70B — fastest, free tier'),
        _providerOption('gemini', Icons.stars, 'Gemini Only',
            'Google Gemini — multimodal, reliable'),
        _providerOption('offline', Icons.signal_wifi_off, 'Offline Only',
            'Rule-based responses — no internet needed'),
      ]),
    );
  }

  Widget _providerOption(String value, IconData icon, String title, String sub) {
    final sel = _provider == value;
    return GestureDetector(
      onTap: () => _applyProvider(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: sel ? AppColors.primaryOrange.withValues(alpha: 0.15) : AppColors.panelLight,
          borderRadius: BorderRadius.circular(12),
          border: sel ? Border.all(color: AppColors.primaryOrange, width: 1.5) : null,
        ),
        child: Row(children: [
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: sel ? AppColors.primaryOrange : Colors.white38, size: 18),
          const SizedBox(width: 10),
          Icon(icon, color: sel ? AppColors.primaryOrange : Colors.white38, size: 17),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
                color: sel ? AppColors.primaryOrange : Colors.white,
                fontWeight: FontWeight.w600, fontSize: 13)),
            Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ])),
        ]),
      ),
    );
  }

  // ── Model picker ─────────────────────────────────────────────────────────

  Widget _modelCard() {
    final showGroq = _provider == 'auto' || _provider == 'groq';
    final showGemini = _provider == 'auto' || _provider == 'gemini';

    if (_provider == 'offline') {
      return _card(
        title: 'Model',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('Offline mode uses rule-based responses — no model selection.',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ),
      );
    }

    return _card(
      title: 'Model Selection',
      subtitle: 'Pick the specific model to use for each provider.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_provider == 'auto' || _provider == 'claude') ...[
            _sectionLabel('CLAUDE (ANTHROPIC)', const Color(0xFFCC785C)),
            ...OpenRouterService.availableModels['claude']!.map((m) =>
              _modelOption(
                id: m['id']!,
                name: m['name']!,
                desc: m['desc']!,
                selected: _claudeModel == m['id'],
                accent: const Color(0xFFCC785C),
                onTap: () => _applyClaudeModel(m['id']!),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (showGroq) ...[
            _sectionLabel('GROQ', const Color(0xFF00E5FF)),
            ...OpenRouterService.availableModels['groq']!.map((m) =>
              _modelOption(
                id: m['id']!,
                name: m['name']!,
                desc: m['desc']!,
                selected: _groqModel == m['id'],
                accent: const Color(0xFF00E5FF),
                onTap: () => _applyGroqModel(m['id']!),
              ),
            ),
            if (showGemini) const SizedBox(height: 16),
          ],
          if (showGemini) ...[
            _sectionLabel('GEMINI', const Color(0xFF4FC3F7)),
            ...OpenRouterService.availableModels['gemini']!.map((m) =>
              _modelOption(
                id: m['id']!,
                name: m['name']!,
                desc: m['desc']!,
                selected: _geminiModel == m['id'],
                accent: const Color(0xFF4FC3F7),
                onTap: () => _applyGeminiModel(m['id']!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 1.5)),
    );
  }

  Widget _modelOption({
    required String id,
    required String name,
    required String desc,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.07),
            width: 1.2,
          ),
        ),
        child: Row(children: [
          Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? accent : Colors.white24, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(
                color: selected ? accent : Colors.white,
                fontWeight: FontWeight.w600, fontSize: 13)),
            Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ])),
          if (selected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('ACTIVE', style: TextStyle(
                  color: accent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
        ]),
      ),
    );
  }

  // ── Voice card ───────────────────────────────────────────────────────────

  Widget _voiceCard() {
    return _card(
      title: 'Voice Speed',
      subtitle: 'Controls how fast Future Gen AI speaks responses aloud.',
      child: Column(children: [
        Slider(
          value: _voiceSpeed, min: 0.8, max: 1.4, divisions: 6,
          activeColor: AppColors.primaryOrange,
          label: _speedLabel(_voiceSpeed),
          onChanged: (v) => setState(() => _voiceSpeed = v),
          onChangeEnd: _applyVoiceSpeed,
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Slow', style: TextStyle(color: Colors.white38, fontSize: 11)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_speedLabel(_voiceSpeed),
                style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const Text('Fast', style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ]),
    );
  }

  // ── Test buttons ─────────────────────────────────────────────────────────

  Widget _testButtons() {
    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange, padding: const EdgeInsets.all(14)),
          icon: const Icon(Icons.mic, size: 18),
          label: const Text('Test Voice'),
          onPressed: _testVoice,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purplePrimary, padding: const EdgeInsets.all(14)),
          icon: const Icon(Icons.smart_toy, size: 18),
          label: const Text('Test AI'),
          onPressed: _testAIResponse,
        ),
      ),
    ]);
  }

  Widget _lastUsedBadge() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.statusGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.statusGreen.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle, color: AppColors.statusGreen, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text('AI responded via: $_lastTestedTier',
            style: const TextStyle(color: AppColors.statusGreen, fontSize: 13))),
      ]),
    );
  }

  // ── Shared card container ────────────────────────────────────────────────

  Widget _card({required String title, String? subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(
            color: AppColors.goldPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _speedLabel(double s) {
    if (s <= 0.9) return 'Slow';
    if (s <= 1.05) return 'Normal';
    if (s <= 1.2) return 'Fast';
    return 'Very Fast';
  }

  Future<void> _applyVoiceSpeed(double s) async {
    await UnifiedVoiceService().setSpeechRate(_speedLabel(s));
  }

  Future<void> _testVoice() async {
    await UnifiedVoiceService().speak(
        'Future Gen AI online. Voice test successful. Speed is ${_speedLabel(_voiceSpeed)}.');
  }

  Future<void> _testAIResponse() async {
    final service = OpenRouterService();
    final response = await service.getAiResponse(
        'Hello! Give me a one-sentence overview of what you can help with in the bush.');
    await UnifiedVoiceService().speak(response);
    setState(() => _lastTestedTier = service.lastUsedTier);
  }
}

