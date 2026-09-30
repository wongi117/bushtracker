import 'package:flutter/material.dart';

import 'package:bush_track/theme/app_colors.dart';

/// A map pin falling from the sky, landing, and sending out a ripple.
///
/// The app takes a while to get going on a phone — engine start, database,
/// sensors, then map tiles over whatever signal is available. A blank screen
/// for that long reads as a broken app, so this gives the wait something to
/// be, and the pin is the app's own furniture rather than a generic spinner.
class PinDropLoader extends StatefulWidget {
  const PinDropLoader({super.key, this.size = 140});

  final double size;

  @override
  State<PinDropLoader> createState() => _PinDropLoaderState();
}

class _PinDropLoaderState extends State<PinDropLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Vertical travel, 0 = high above, 1 = landed.
  late final Animation<double> _fall;

  /// Squash on impact, then recover.
  late final Animation<double> _squash;

  /// The ring that spreads out from where it lands.
  late final Animation<double> _ripple;

  late final Animation<double> _shadow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();

    // Accelerate downward like something actually falling, rather than
    // easing in and out as if it were being lowered.
    _fall = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.42, curve: Curves.easeInQuad),
    );

    _squash = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0), weight: 42),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 8),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 30),
      TweenSequenceItem(tween: ConstantTween(0), weight: 20),
    ]).animate(_controller);

    _ripple = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.92, curve: Curves.easeOutCubic),
    );

    // The shadow tightens and darkens as the pin approaches the ground.
    _shadow = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.42, curve: Curves.easeInQuad),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final drop = _fall.value;
          final squash = _squash.value;
          final ripple = _ripple.value;
          final shadow = _shadow.value;

          // Squashing must not change where the tip sits, so the pin is
          // scaled about its bottom edge.
          final scaleX = 1 + squash * 0.28;
          final scaleY = 1 - squash * 0.24;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Ripple on landing.
              if (ripple > 0 && ripple < 1)
                Positioned(
                  bottom: size * 0.14,
                  child: Opacity(
                    opacity: (1 - ripple).clamp(0.0, 1.0) * 0.55,
                    child: Container(
                      width: size * (0.15 + ripple * 0.72),
                      height: size * (0.05 + ripple * 0.24),
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.all(
                            Radius.elliptical(size, size * 0.3)),
                        border: Border.all(
                          color: AppColors.accent
                              .withValues(alpha: 1 - ripple),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),

              // Ground shadow — small and faint when high, wide when close.
              Positioned(
                bottom: size * 0.15,
                child: Container(
                  width: size * (0.10 + shadow * 0.26),
                  height: size * (0.03 + shadow * 0.055),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18 + shadow * 0.3),
                    borderRadius: BorderRadius.all(
                        Radius.elliptical(size, size * 0.1)),
                  ),
                ),
              ),

              // The pin itself.
              Positioned(
                bottom: size * 0.17 + (1 - drop) * size * 0.72,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
                  child: Icon(
                    Icons.location_on,
                    size: size * 0.46,
                    color: AppColors.accent,
                    shadows: const [
                      Shadow(color: AppColors.accentGlow, blurRadius: 18),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
