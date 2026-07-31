import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:bush_track/core/services/heading/heading_reading.dart';

/// Compass Rose widget that rotates with the live device heading.
class CompassRose extends StatelessWidget {
  final double rotation; // Rotation in radians
  final double size;
  final VoidCallback? onTap;

  /// Drives the status ring: acquiring, magnetic interference, or no compass
  /// at all. Defaults to [HeadingQuality.good] so existing callers are
  /// unaffected.
  final HeadingQuality quality;

  const CompassRose({
    super.key,
    required this.rotation,
    this.size = 60,
    this.onTap,
    this.quality = HeadingQuality.good,
  });

  bool get _isLive =>
      quality == HeadingQuality.good || quality == HeadingQuality.interference;

  Color get _ringColor {
    switch (quality) {
      case HeadingQuality.good:
        return Colors.white24;
      case HeadingQuality.interference:
        return const Color(0xFFFFB020); // amber — reading is being skewed
      case HeadingQuality.waiting:
        return Colors.white12;
      case HeadingQuality.unavailable:
        return const Color(0xFFFF2D55);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: _tooltip,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: _ringColor,
              width: quality == HeadingQuality.good ? 1 : 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: _isLive ? 1.0 : 0.35,
                child: Transform.rotate(
                  angle: -rotation, // Negative because map rotation is clockwise
                  child: CustomPaint(
                    size: Size(size, size),
                    painter: CompassRosePainter(),
                  ),
                ),
              ),
              if (quality == HeadingQuality.unavailable)
                Icon(Icons.touch_app,
                    size: size * 0.3, color: const Color(0xFFFF2D55)),
              if (quality == HeadingQuality.waiting)
                SizedBox(
                  width: size * 0.3,
                  height: size * 0.3,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white38),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _tooltip {
    switch (quality) {
      case HeadingQuality.good:
        return 'Compass live — tap to reset map north';
      case HeadingQuality.interference:
        return 'Magnetic interference — move away from the vehicle, '
            'or wave the phone in a figure-8 to recalibrate';
      case HeadingQuality.waiting:
        return 'Acquiring compass…';
      case HeadingQuality.unavailable:
        return 'No compass — tap to enable device orientation';
    }
  }
}

class CompassRosePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    
    // Draw N indicator (red triangle pointing up)
    final northPath = Path()
      ..moveTo(center.dx, center.dy - radius + 4)
      ..lineTo(center.dx - 6, center.dy)
      ..lineTo(center.dx + 6, center.dy)
      ..close();
    
    canvas.drawPath(
      northPath,
      Paint()..color = const Color(0xFFFF2D55),
    );
    
    // Draw S indicator (white triangle pointing down)
    final southPath = Path()
      ..moveTo(center.dx, center.dy + radius - 4)
      ..lineTo(center.dx - 6, center.dy)
      ..lineTo(center.dx + 6, center.dy)
      ..close();
    
    canvas.drawPath(
      southPath,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    
    // Draw cardinal letters
    final textStyle = TextStyle(
      color: Colors.white70,
      fontSize: size.width * 0.15,
      fontWeight: FontWeight.bold,
    );
    
    // N
    final nSpan = TextSpan(text: 'N', style: textStyle);
    final nPainter = TextPainter(text: nSpan, textDirection: TextDirection.ltr);
    nPainter.layout();
    nPainter.paint(canvas, Offset(center.dx - nPainter.width / 2, center.dy - radius + 8));
    
    // Draw outer ring
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..color = Colors.transparent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white24,
    );
    
    // Draw tick marks
    for (int i = 0; i < 360; i += 30) {
      final angle = i * math.pi / 180;
      final isCardinal = i % 90 == 0;
      final tickLength = isCardinal ? 6 : 3;
      final tickWidth = isCardinal ? 2 : 1;
      
      final start = Offset(
        center.dx + (radius - tickLength - 2) * math.sin(angle),
        center.dy - (radius - tickLength - 2) * math.cos(angle),
      );
      final end = Offset(
        center.dx + (radius - 2) * math.sin(angle),
        center.dy - (radius - 2) * math.cos(angle),
      );
      
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = isCardinal ? Colors.white70 : Colors.white30
          ..strokeWidth = tickWidth.toDouble(),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
