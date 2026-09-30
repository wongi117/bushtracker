import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:bush_track/core/utils/startup_trace.dart';
import 'package:bush_track/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bush_track/features/onboarding/presentation/widgets/pin_drop_loader.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/theme/app_colors.dart';

/// The map, with the splash painted over the top of it.
///
/// The splash used to be its own route that ran a timer and only THEN pushed
/// the dashboard — so the map, the tiles, the GPS and the mesh all started
/// after the animation finished. The wait was additive: splash, then load.
///
/// Now the dashboard is built from the first frame and everything starts at
/// once. The splash is a lid over that work, lifted as soon as there is
/// something worth showing.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({super.key});

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate> {
  /// Never dismiss before this: a splash that flashes past is worse than none.
  static const _minimumShow = Duration(milliseconds: 1200);

  /// Never hold longer than this, however loading is going. The map is usable
  /// without a fix — it says so — and a lid that never lifts is a hang.
  static const _maximumShow = Duration(seconds: 20);

  bool _covered = true;
  bool _minimumPassed = false;
  Timer? _ceiling;

  @override
  void initState() {
    super.initState();

    // On web the browser prompt needs kicking off here; on native the
    // location provider asks for itself.
    if (kIsWeb) {
      Geolocator.requestPermission().catchError((Object e) {
        debugPrint('Location permission: $e');
        return LocationPermission.denied;
      });
    }

    // Touch the providers now so GPS and the rest begin immediately rather
    // than whenever the dashboard first happens to build them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationProvider);
      StartupTrace.mark('splash_shown');
    });

    Timer(_minimumShow, () {
      _minimumPassed = true;
      _liftIfReady();
    });
    _ceiling = Timer(_maximumShow, () => _lift('timeout'));
  }

  @override
  void dispose() {
    _ceiling?.cancel();
    super.dispose();
  }

  /// Ready means the map can open somewhere meaningful. A position from the
  /// OS cache counts — that is exactly what stops it opening zoomed out on
  /// the whole country.
  bool get _hasPosition => ref.read(locationProvider).stats.currentLat != null;

  void _liftIfReady() {
    if (_minimumPassed && _hasPosition) _lift('ready');
  }

  void _lift(String why) {
    if (!_covered || !mounted) return;
    _ceiling?.cancel();
    StartupTrace.mark('splash_lifted_$why');
    StartupTrace.report();
    setState(() => _covered = false);
  }

  @override
  Widget build(BuildContext context) {
    // Lift the moment a position arrives, once the minimum has passed.
    ref.listen<LocationState>(locationProvider, (_, next) {
      if (next.stats.currentLat != null) _liftIfReady();
    });

    return Stack(
      children: [
        // Built from the first frame, so its tiles, sensors and services load
        // underneath the splash rather than after it.
        const DashboardScreen(),
        if (_covered)
          Positioned.fill(child: _SplashCover(onSkip: () => _lift('skipped'))),
      ],
    );
  }
}

class _SplashCover extends StatefulWidget {
  const _SplashCover({required this.onSkip});

  final VoidCallback onSkip;

  @override
  State<_SplashCover> createState() => _SplashCoverState();
}

class _SplashCoverState extends State<_SplashCover> {
  static const _tips = [
    'Tap the compass at the bottom right to activate it',
    'Long-press the map to drop a pin where you are looking',
    'Open a file and every pin, zone and note is filed under it',
    'Boundaries do not have to be circles — tap out the corners',
    'Hold SOS for three seconds to reach nearby phones',
    'Drag the grip on a circle zone to resize it',
    'Tap a pin to see how far away it is and which way to walk',
  ];

  late final int _firstTip;
  int _tipStep = 0;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();
    _firstTip = DateTime.now().millisecondsSinceEpoch % _tips.length;
    _tipTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted) setState(() => _tipStep++);
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tip = _tips[(_firstTip + _tipStep) % _tips.length];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onSkip,
      child: Material(
        color: AppColors.background,
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                const PinDropLoader(size: 150),
                const SizedBox(height: 28),
                const Text(
                  'PINAGE MAPS',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 7,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 150,
                  height: 2,
                  decoration:
                      const BoxDecoration(gradient: AppColors.accentGradient),
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    child: Text(
                      tip,
                      key: ValueKey(tip),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.accentLight,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Tap to skip',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
