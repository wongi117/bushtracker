import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mesh_gradient/mesh_gradient.dart';
import 'dart:math';

import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bush_track/features/settings/providers/vehicle_profile_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(vsync: this, duration: const Duration(seconds: 15))
          ..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _startMapDownload() {
    setState(() {
      _isDownloading = true;
    });

    // Simulate tactical download
    Future.delayed(const Duration(milliseconds: 500), () {
      _simulateDownload();
    });
  }

  void _simulateDownload() {
    if (!mounted) return;

    setState(() {
      _downloadProgress += 0.05;
    });

    if (_downloadProgress < 1.0) {
      Future.delayed(const Duration(milliseconds: 100), _simulateDownload);
    } else {
      // Done downloading
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _finishOnboarding();
      });
    }
  }

  void _finishOnboarding() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const DashboardScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Dynamic Mesh Gradient Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return MeshGradient(
                  points: [
                    MeshGradientPoint(
                      position: Offset(
                          -0.2 + sin(_animController.value * pi * 2) * 0.3,
                          -0.2 + cos(_animController.value * pi * 2) * 0.3),
                      color: AppColors.background,
                    ),
                    MeshGradientPoint(
                      position: Offset(
                          1.2 - cos(_animController.value * pi * 2) * 0.3,
                          -0.2 + sin(_animController.value * pi * 2) * 0.3),
                      color: const Color(0xFF1A1A24),
                    ),
                    MeshGradientPoint(
                      position: const Offset(0.5, 1.2),
                      color: AppColors.primaryOrange.withValues(alpha: 0.15),
                    ),
                    MeshGradientPoint(
                      position: const Offset(0.5, 0.5),
                      color: Colors.black.withValues(alpha: 0.9),
                    ),
                  ],
                  options: MeshGradientOptions(blend: 3.5),
                );
              },
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32.0, vertical: 24.0),
                  child: Row(
                    children: List.generate(3, (index) {
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: _currentPage >= index
                                ? AppColors.primaryOrange
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: _currentPage == index
                                ? [
                                    BoxShadow(
                                        color: AppColors.primaryOrange
                                            .withValues(alpha: 0.5),
                                        blurRadius: 8)
                                  ]
                                : [],
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Content Carousel
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics:
                        const NeverScrollableScrollPhysics(), // Prevent manual swipe
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: [
                      _buildWelcomePage(),
                      _buildVehicleProfilePage(),
                      _buildRegionDownloadPage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.primaryOrange.withValues(alpha: 0.3),
                  width: 2),
            ),
            child: const Icon(Icons.compass_calibration_outlined,
                color: AppColors.primaryOrange, size: 52),
          ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
          const SizedBox(height: 28),
          const Text(
            'FUTURE GEN AI\nOS INITIALIZED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.2,
              letterSpacing: 2.0,
            ),
          ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
          const SizedBox(height: 16),
          const Text(
            'Welcome to BushTrack. You are now equipped with the most advanced offline survival and navigation system on the planet.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 800.ms),
          const SizedBox(height: 28),
          _buildFeatureRow(Icons.map_outlined, 'Zero-Signal Navigation')
              .animate()
              .fadeIn(delay: 1200.ms),
          const SizedBox(height: 14),
          _buildFeatureRow(Icons.wifi_tethering, 'P2P Mesh Network SOS')
              .animate()
              .fadeIn(delay: 1400.ms),
          const SizedBox(height: 14),
          _buildFeatureRow(
                  Icons.support_agent_rounded, 'On-Device AI Specialists')
              .animate()
              .fadeIn(delay: 1600.ms),
          const SizedBox(height: 32),
          _buildPrimaryButton('INITIALIZE PROTOCOL', _nextPage)
              .animate()
              .fadeIn(delay: 2000.ms),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryOrange, size: 24),
        const SizedBox(width: 16),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleProfilePage() {
    final vehicleState = ref.watch(vehicleProfileProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MISSION\nPROFILE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.2,
              letterSpacing: 2.0,
            ),
          ).animate().fadeIn().slideX(begin: -0.1),
          const SizedBox(height: 12),
          const Text(
            'Select your primary mode of transport. This calibrates AI routing, speed warnings, and trail preferences.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              // 3 columns on narrow phones, 2 on tablets/wide screens
              final crossCount = constraints.maxWidth < 360 ? 2 : constraints.maxWidth > 500 ? 4 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  mainAxisExtent: 100,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: VehicleProfile.profiles.length,
                itemBuilder: (context, index) {
                  final profile = VehicleProfile.profiles[index];
                  final isSelected = vehicleState.selectedType == profile.type;

                  return GestureDetector(
                    onTap: () {
                      ref
                          .read(vehicleProfileProvider.notifier)
                          .setVehicleType(profile.type);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryOrange.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryOrange.withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.08),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: AppColors.primaryOrange
                                        .withValues(alpha: 0.25),
                                    blurRadius: 16)
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(profile.icon,
                              style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 6),
                          Text(
                            profile.name.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primaryOrange
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryOrange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('SELECTED',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold)),
                            )
                          ]
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: 300 + (index * 80)))
                      .scale(curve: Curves.easeOutBack);
                },
              );
            },
          ),
          const SizedBox(height: 28),
          _buildPrimaryButton('CONFIRM PARAMETERS', _nextPage)
              .animate()
              .fadeIn(delay: 800.ms),
        ],
      ),
    );
  }

  Widget _buildRegionDownloadPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TACTICAL\nCACHE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.2,
              letterSpacing: 2.0,
            ),
          ).animate().fadeIn().slideX(begin: -0.1),
          const SizedBox(height: 14),
          const Text(
            'To guarantee survival in zero-signal environments, BushTrack must cache topographical data for your region.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 40),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: _isDownloading ? _downloadProgress : 0.0,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    color: AppColors.primaryOrange,
                  ),
                ),
                if (!_isDownloading)
                  const Icon(Icons.satellite_alt_rounded,
                      color: Colors.white54, size: 72)
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(_downloadProgress * 100).toInt()}%',
                        style: const TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 36,
                            fontWeight: FontWeight.w900),
                      ),
                      const Text(
                        'DOWNLOADING\nWA GOLDFIELDS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            letterSpacing: 2.0),
                      ),
                    ],
                  ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms).scale(),
          const SizedBox(height: 40),
          if (!_isDownloading) ...[
            _buildPrimaryButton('INITIATE DOWNLOAD (~45MB)', _startMapDownload)
                .animate()
                .fadeIn(delay: 600.ms),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _finishOnboarding,
                child: const Text('SKIP (NOT RECOMMENDED)',
                    style:
                        TextStyle(color: Colors.white54, letterSpacing: 1.0)),
              ),
            ).animate().fadeIn(delay: 800.ms),
          ] else ...[
            Center(
              child: const Text('MAINTAIN CONNECTION...',
                      style: TextStyle(
                          color: AppColors.primaryOrange, letterSpacing: 2.0))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fade(),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: AppColors.primaryOrange.withValues(alpha: 0.5),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }
}
