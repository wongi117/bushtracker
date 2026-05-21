import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/core/widgets/glass_panel.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/ai/providers/ai_assistant_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'package:mesh_gradient/mesh_gradient.dart';

class AgentManagerScreen extends ConsumerStatefulWidget {
  const AgentManagerScreen({super.key});

  @override
  ConsumerState<AgentManagerScreen> createState() => _AgentManagerScreenState();
}

class _AgentManagerScreenState extends ConsumerState<AgentManagerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final PageController _pageController = PageController(viewportFraction: 0.7);
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiAssistantProvider);
    final isOffline = aiState.isOfflineMode;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Premium Mesh Gradient Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return MeshGradient(
                  points: [
                    MeshGradientPoint(
                      position: Offset(
                          -0.5 + sin(_animController.value * pi * 2),
                          -0.5 + cos(_animController.value * pi * 2)),
                      color: AppColors.panelMatte,
                    ),
                    MeshGradientPoint(
                      position: Offset(
                          1.5 - cos(_animController.value * pi * 2),
                          -0.5 + sin(_animController.value * pi * 2)),
                      color: Colors.black,
                    ),
                    MeshGradientPoint(
                      position: const Offset(0.5, 1.5),
                      color: isOffline
                          ? AppColors.accent.withValues(alpha: 0.3)
                          : AppColors.statusBlue.withValues(alpha: 0.2),
                    ),
                    MeshGradientPoint(
                      position: const Offset(0.5, 0.5),
                      color: Colors.black.withValues(alpha: 0.8),
                    ),
                  ],
                  options: MeshGradientOptions(blend: 3.5),
                );
              },
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, isOffline),
                _buildStatusBanner(aiState),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Select your AI persona. Each agent runs specialized contextual models for your survival.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 16, height: 1.4),
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                const SizedBox(height: 40),

                // 3D Carousel
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: AiPersona.values.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final persona = AiPersona.values[index];
                      final isSelected = aiState.selectedPersona == persona;

                      // Calculate 3D transformation
                      final scale =
                          max(0.8, 1 - (_currentPage - index).abs() * 0.2);
                      final rotationY =
                          (_currentPage - index) * 0.5; // perspective tilt

                      return _build3DAgentCard(
                        context: context,
                        ref: ref,
                        persona: persona,
                        isSelected: isSelected,
                        scale: scale,
                        rotationY: rotationY,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isOffline) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Text(
                'AGENT MANAGER',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
            ],
          ),
          Row(
            children: [
              // Force Offline Toggle
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Force Offline',
                      style: TextStyle(color: Colors.white70, fontSize: BushDS.fontXS)),
                  Switch(
                    value: ref.watch(aiAssistantProvider).forceOffline,
                    onChanged: (val) {
                      ref
                          .read(aiAssistantProvider.notifier)
                          .toggleForceOffline();
                    },
                    activeThumbColor: AppColors.accent,
                    inactiveThumbColor: AppColors.statusBlue,
                    inactiveTrackColor: AppColors.statusBlue.withValues(alpha: 0.3),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // Network Status Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOffline
                      ? AppColors.accent.withValues(alpha: 0.2)
                      : AppColors.statusBlue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                  color: isOffline ? AppColors.accent : AppColors.statusBlue,
                  size: 20,
                ),
              )
                  .animate(
                      onPlay: (controller) => controller.repeat(reverse: true))
                  .fade(begin: 0.7, end: 1.0, duration: 1.seconds),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(AiState aiState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: GlassPanel(
        opacity: 0.15,
        blur: 10,
        borderRadius: 12,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(aiState.statusColor),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              Color(aiState.statusColor).withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SYSTEM CORE: ${aiState.currentTier.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Text(
                aiState.isOfflineMode ? 'LOCAL INFERENCE' : 'CLOUD SYNCED',
                style: TextStyle(
                  color: aiState.isOfflineMode ? AppColors.accent : AppColors.statusBlue,
                  fontSize: BushDS.fontXS,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: -0.1);
  }

  Widget _build3DAgentCard({
    required BuildContext context,
    required WidgetRef ref,
    required AiPersona persona,
    required bool isSelected,
    required double scale,
    required double rotationY,
  }) {
    Color accentColor;
    IconData icon;

    switch (persona) {
      case AiPersona.companion:
        accentColor = const Color(0xFF9C27B0);
        icon = Icons.chat_bubble_rounded;
        break;
      case AiPersona.tactical:
        accentColor = AppColors.statusBlue;
        icon = Icons.hub_rounded;
        break;
      case AiPersona.scout:
        accentColor = AppColors.statusGreen;
        icon = Icons.explore_rounded;
        break;
      case AiPersona.navigator:
        accentColor = AppColors.statusBlue;
        icon = Icons.near_me_rounded;
        break;
      case AiPersona.emergency:
        accentColor = AppColors.statusRed;
        icon = Icons.emergency_rounded;
        break;
    }

    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.002) // perspective
        ..rotateY(rotationY)
        ..scale(scale),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          ref.read(aiAssistantProvider.notifier).setPersona(persona);
          // Optional: haptic feedback here
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    )
                  ]
                : [],
          ),
          child: GlassPanel(
            opacity: isSelected ? 0.2 : 0.05,
            blur: 20,
            borderRadius: 30,
            borderColor: isSelected
                ? accentColor.withValues(alpha: 0.5)
                : Colors.white10,
            borderWidth: isSelected ? 2.0 : 1.0,
            child: Stack(
              children: [
                // Inner glow
                if (isSelected)
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.2),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.5, 1.5),
                            duration: 2.seconds)
                        .fade(),
                  ),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: accentColor.withValues(alpha: 0.4),
                              width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: Icon(icon, color: accentColor, size: 50),
                      ).animate(target: isSelected ? 1 : 0).scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1.1, 1.1),
                          duration: 300.ms,
                          curve: Curves.easeOutBack),
                      const SizedBox(height: 30),
                      Text(
                        persona.label.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? accentColor : Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          shadows: isSelected
                              ? [Shadow(color: accentColor, blurRadius: 10)]
                              : [],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        persona.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: accentColor.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: accentColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .scale(duration: 400.ms, curve: Curves.elasticOut),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
