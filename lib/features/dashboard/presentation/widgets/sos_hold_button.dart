import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Always-visible SOS trigger for the main map screen.
///
/// Press and hold for [holdFor]: a white ring fills while you hold, and the
/// SOS screen opens when it completes. Letting go early cancels. A quick tap
/// only explains how to use it — so a bump in a pocket or a stray tap can't
/// start an SOS, which is presumably why SOS was once removed from the main
/// screen altogether.
///
/// Uses raw pointer events rather than a long-press gesture so the hold
/// length is exact and nothing else in the gesture arena can steal it.
class SosHoldButton extends StatefulWidget {
  const SosHoldButton({
    super.key,
    required this.onTriggered,
    this.size = 54,
    this.holdFor = const Duration(seconds: 3),
  });

  final VoidCallback onTriggered;
  final double size;
  final Duration holdFor;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: widget.holdFor)
        ..addStatusListener(_onStatus);

  DateTime? _downAt;

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    HapticFeedback.heavyImpact();
    _hold.reset();
    _downAt = null;
    widget.onTriggered();
  }

  void _down(PointerDownEvent _) {
    _downAt = DateTime.now();
    HapticFeedback.selectionClick();
    _hold.forward(from: 0);
  }

  void _up(PointerUpEvent _) {
    final heldFor = _downAt == null
        ? Duration.zero
        : DateTime.now().difference(_downAt!);
    _downAt = null;
    if (_hold.isAnimating) _hold.reset();
    // A quick tap: say how it works instead of doing nothing.
    if (heldFor < const Duration(milliseconds: 600)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
              'Press and hold SOS for ${widget.holdFor.inSeconds} seconds'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFFD50000),
        ));
    }
  }

  void _cancel(PointerCancelEvent _) {
    _downAt = null;
    if (_hold.isAnimating) _hold.reset();
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      button: true,
      label: 'SOS. Press and hold for ${widget.holdFor.inSeconds} seconds.',
      child: Listener(
        onPointerDown: _down,
        onPointerUp: _up,
        onPointerCancel: _cancel,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFD50000),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.6),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _hold,
                builder: (context, _) => _hold.value == 0
                    ? const SizedBox.shrink()
                    : SizedBox(
                        width: size - 10,
                        height: size - 10,
                        child: CircularProgressIndicator(
                          value: _hold.value,
                          strokeWidth: 4,
                          backgroundColor: Colors.white24,
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
              ),
              const Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
