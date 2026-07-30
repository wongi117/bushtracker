import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/features/onboarding/presentation/onboarding_screen.dart';
import 'package:geolocator/geolocator.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initApp();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    // On web, trigger the browser location permission dialog now
    // so it appears while the splash is visible
    if (kIsWeb) {
      try {
        await Geolocator.requestPermission();
      } catch (e) {
        debugPrint('Location permission: $e');
      }
    }
    if (mounted) _goToApp();
  }

  void _goToApp() {
    ref.read(locationProvider); // pre-warm GPS
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _shimmer,
              builder: (_, __) {
                return ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      AppColors.accent,
                      AppColors.accentLight,
                      AppColors.accent,
                    ],
                    stops: [
                      (_shimmer.value - 0.3).clamp(0.0, 1.0),
                      _shimmer.value.clamp(0.0, 1.0),
                      (_shimmer.value + 0.3).clamp(0.0, 1.0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Icon(Icons.explore, size: 80, color: Colors.white),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'PINAGE MAPS',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 160,
              height: 2,
              decoration: const BoxDecoration(
                gradient: AppColors.accentGradient,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
