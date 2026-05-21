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
  String _status = 'INITIALIZING FUTURE GEN AI OS...';
  bool _skipRegionDetection = false;
  bool _showSkipButton = false;
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initApp();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSkipButton = true);
    });
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() => _status = kIsWeb
        ? 'BROWSER MODE — ALLOW LOCATION FOR GPS...'
        : 'ACQUIRING GPS SIGNAL...');

    // Trigger browser permission dialog early so it appears during loading
    if (kIsWeb) {
      try {
        await Geolocator.requestPermission();
      } catch (e) {
        debugPrint('Permission request: $e');
      }
    }

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() => _status = 'DETECTING SURVIVAL REGION...');

    Position? lastKnownPosition;
    if (!kIsWeb) {
      try {
        lastKnownPosition = await Geolocator.getLastKnownPosition();
      } catch (e) {
        debugPrint('Error getting last known position: $e');
      }
      if (lastKnownPosition != null && mounted) {
        setState(() => _status = 'USING LAST KNOWN LOCATION...');
        await Future.delayed(const Duration(milliseconds: 500));
        _finishOnboarding();
        return;
      }
    }

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() => _status = 'ALMOST READY...');

    bool timeoutReached = false;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !timeoutReached) {
        setState(() {
          timeoutReached = true;
          _skipRegionDetection = true;
          _status = 'REGION DETECTION SKIPPED — TAP TO DOWNLOAD MAPS MANUALLY';
        });
      }
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    if (timeoutReached) {
      _finishOnboarding();
      return;
    }

    ref.read(locationProvider);
    if (mounted) {
      setState(() => _status = 'PREPARING OFFLINE TACTICAL MAPS...');
      _finishOnboarding();
    }
  }

  void _showDownloadBottomSheet() {
    if (!_skipRegionDetection) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.panelMatte,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BushDS.radiusXL)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(BushDS.spMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.accent, size: 22),
                SizedBox(width: BushDS.spSM),
                Text(
                  'MAP CACHE RECOMMENDED',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: BushDS.fontXL,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: BushDS.spMD),
            const Text(
              'To ensure survival capability in zero-signal areas, download offline 3D terrain tiles for your region (~45MB).',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: BushDS.fontMD),
            ),
            const SizedBox(height: BushDS.spLG),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  height: BushDS.tapMin,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.skip_next,
                        color: AppColors.textSecondary, size: 18),
                    label: const Text(
                      'SKIP',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                SizedBox(
                  height: BushDS.tapMin,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: BushDS.spMD),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Map download would start here...'),
                          backgroundColor: AppColors.accent,
                        ),
                      );
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('DOWNLOAD NOW',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _finishOnboarding() {
    if (!mounted) return;
    // Always pre-warm GPS — ensures permission dialog fires before dashboard loads
    ref.read(locationProvider);
    if (_skipRegionDetection) {
      _showDownloadBottomSheet();
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        }
      });
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  void _skipToMap() {
    setState(() {
      _skipRegionDetection = true;
      _status = 'REGION DETECTION SKIPPED — TAP TO DOWNLOAD MAPS MANUALLY';
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _finishOnboarding();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.background, Color(0xFF0F0A05), AppColors.background],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo — metallic sheen animation
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
                    child: const Icon(Icons.explore,
                        size: 80, color: Colors.white),
                  );
                },
              ),
              const SizedBox(height: BushDS.spXL),
              // App name — no emoji, pure type
              const Text(
                'BUSHTRACK',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: BushDS.spSM),
              // Metallic accent line under title
              Container(
                width: 180,
                height: 2,
                decoration: const BoxDecoration(
                  gradient: AppColors.accentGradient,
                ),
              ),
              const SizedBox(height: BushDS.spMD),
              Text(
                _status,
                style: const TextStyle(
                  fontSize: BushDS.fontXS,
                  letterSpacing: 2,
                  color: AppColors.accent,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BushDS.spXL),
              SizedBox(
                width: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BushDS.radiusSM),
                  child: const LinearProgressIndicator(
                    backgroundColor: AppColors.panelLight,
                    color: AppColors.accent,
                    minHeight: 3,
                  ),
                ),
              ),
              const SizedBox(height: BushDS.spXL),
              if (_showSkipButton)
                SizedBox(
                  height: BushDS.tapMin,
                  child: TextButton.icon(
                    onPressed: _skipToMap,
                    icon: const Icon(Icons.eco,
                        color: AppColors.accent, size: 18),
                    label: const Text(
                      'SKIP',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: BushDS.fontLG,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
