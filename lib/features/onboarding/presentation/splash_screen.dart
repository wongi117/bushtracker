import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bush_track/features/onboarding/presentation/onboarding_screen.dart';
import 'package:geolocator/geolocator.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _status = "🚀 INITIALIZING ANTIGRAVITY OS...";
  bool _skipRegionDetection = false;
  bool _showSkipButton = false;

  @override
  void initState() {
    super.initState();
    _initApp();
    // Show skip button after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSkipButton = true;
        });
      }
    });
  }

  Future<void> _initApp() async {
    // Stage 1 (0-2s): Initialising Antigravity...
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Stage 2 (2-4s): Acquiring GPS signal...
    setState(() => _status = kIsWeb ? "🌐 BROWSER MODE — Allow location for GPS..." : "📡 ACQUIRING GPS SIGNAL...");
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Stage 3 (4-6s): Detecting survival region...
    setState(() => _status = "🎯 DETECTING SURVIVAL REGION...");
    
    // Try to get last known position first (skip on web - not supported)
    Position? lastKnownPosition;
    if (!kIsWeb) {
      try {
        lastKnownPosition = await Geolocator.getLastKnownPosition();
      } catch (e) {
        debugPrint("Error getting last known position: $e");
      }
      
      // If we have last known position, use it immediately
      if (lastKnownPosition != null) {
        if (mounted) {
          setState(() => _status = "📍 USING LAST KNOWN LOCATION...");
          await Future.delayed(const Duration(milliseconds: 500));
          _finishOnboarding();
          return;
        }
      }
    }
    
    // Wait for fresh GPS with timeout
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Stage 4 (6-8s): Almost ready...
    setState(() => _status = "⏳ ALMOST READY...");
    
    // Set up timeout for GPS (8 seconds total)
    bool timeoutReached = false;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !timeoutReached) {
        setState(() {
          timeoutReached = true;
          _skipRegionDetection = true;
          _status = "⚠️ REGION DETECTION SKIPPED - TAP TO DOWNLOAD MAPS MANUALLY";
        });
      }
    });
    
    // Wait a bit more to see if GPS comes in
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // If we reached timeout, go to map screen
    if (timeoutReached) {
      _finishOnboarding();
      return;
    }
    
    // If we have GPS position by now, proceed normally
    ref.read(locationProvider);
    if (mounted) {
      setState(() => _status = "🗺️ PREPARING OFFLINE TACTICAL MAPS...");
      _finishOnboarding();
    }
  }

  void _showDownloadBottomSheet() {
    if (_skipRegionDetection) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.panelMatte,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "⚠️ MAP CACHE RECOMMENDED",
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "To ensure survival capability in zero-signal areas, I recommend downloading offline 3D terrain tiles for your region (~45MB).",
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "⏭️ SKIP", 
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                    onPressed: () {
                      Navigator.pop(context);
                      // In a real implementation, this would trigger map download
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Map download would start here..."),
                          backgroundColor: AppColors.primaryOrange,
                        ),
                      );
                    },
                    child: const Text(
                      "📥 DOWNLOAD NOW", 
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  void _finishOnboarding() {
    if (!mounted) return;
    
    // Show download bottom sheet BEFORE navigation if region detection was skipped
    if (_skipRegionDetection) {
      _showDownloadBottomSheet();
      // Navigate after a delay to let user see the bottom sheet
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      });
    } else {
      // Normal navigation without bottom sheet
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  void _skipToMap() {
    setState(() {
      _skipRegionDetection = true;
      _status = "REGION DETECTION SKIPPED - TAP TO DOWNLOAD MAPS MANUALLY";
    });
    // Give user feedback and then proceed
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _finishOnboarding();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.compass_calibration, size: 80, color: AppColors.primaryOrange),
            const SizedBox(height: 32),
            const Text(
              "🌿 BUSHTRACK",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 2,
                color: AppColors.primaryOrange,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: AppColors.panelLight,
                color: AppColors.primaryOrange,
              ),
            ),
            const SizedBox(height: 32),
            if (_showSkipButton)
              TextButton(
                onPressed: _skipToMap,
                child: const Text(
                  "🌿 SKIP →",
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
