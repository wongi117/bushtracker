import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bush_track/core/utils/geo_geometry.dart';
import 'package:bush_track/features/ar/services/ar_walls.dart';

/// Zones standing up through the camera (Phase 4.5).
///
/// No-go zones (hazard, heritage, No entry) are a tall translucent wall in the
/// zone's colour with warning stripes and a "NO GO" label; ordinary zones are
/// a knee-high band along the ground with their name. Painted under the pins,
/// so a pin inside a zone is still seen and tapped.
class ArWallPainter extends CustomPainter {
  ArWallPainter(this.walls);

  final ArWalls walls;

  @override
  void paint(Canvas canvas, Size size) {
    if (walls.panels.isEmpty) return;

    // One path per zone, so the stripes are clipped once per zone rather
    // than once per piece: a near wall is a few hundred pieces, and a clip
    // per piece per frame shows up as a stutter.
    final byZone = <Object, (WallStyle, Color, Path)>{};
    for (final p in walls.panels) {
      final key = p.zone.id ?? identityHashCode(p.zone);
      final colour = Color(p.zone.category.colorValue);
      final entry = byZone.putIfAbsent(key, () => (p.style, colour, Path()));
      entry.$3.addPath(p.path, Offset.zero);
    }

    for (final (style, colour, path) in byZone.values) {
      final noGo = style == WallStyle.noGo;
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = colour.withValues(alpha: noGo ? 0.28 : 0.45));

      if (noGo) {
        canvas.save();
        canvas.clipPath(path);
        final b = path.getBounds();
        final stripe = Paint()
          ..color = colour.withValues(alpha: 0.35)
          ..strokeWidth = 10;
        for (var x = b.left - b.height; x < b.right; x += 34) {
          canvas.drawLine(
              Offset(x, b.bottom), Offset(x + b.height, b.top), stripe);
        }
        canvas.restore();
      }
    }

    // Edges last, over the fill: the top edge is what reads as "a wall".
    for (final p in walls.panels) {
      final colour = Color(p.zone.category.colorValue);
      final noGo = p.style == WallStyle.noGo;
      canvas.drawLine(
          p.topA,
          p.topB,
          Paint()
            ..color = colour
            ..strokeWidth = noGo ? 3 : 2);
      canvas.drawLine(
          p.bottomA,
          p.bottomB,
          Paint()
            ..color = colour.withValues(alpha: 0.9)
            ..strokeWidth = noGo ? 2 : 3);
    }

    for (final l in walls.labels) {
      _label(canvas, size, l);
    }
  }

  void _label(Canvas canvas, Size size, WallLabel l) {
    final noGo = l.style == WallStyle.noGo;
    final text = noGo
        ? 'NO GO · ${l.zone.category.label.toUpperCase()} · ${l.zone.name} · '
            '${formatDistance(l.edgeDistanceM)}'
        : '${l.zone.name} · ${formatDistance(l.edgeDistanceM)}';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: noGo ? 14 : 12,
          fontWeight: noGo ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width - 24);

    // Kept on screen: a wall's top can run off the top of the image close up.
    final x = (l.at.dx - tp.width / 2)
        .clamp(12.0, math.max(12.0, size.width - tp.width - 12))
        .toDouble();
    final y = (l.at.dy - tp.height - 14)
        .clamp(90.0, math.max(90.0, size.height - tp.height - 120))
        .toDouble();
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - 8, y - 4, tp.width + 16, tp.height + 8),
      const Radius.circular(8),
    );
    canvas.drawRRect(
        box,
        Paint()
          ..color = noGo
              ? const Color(0xE6B71C1C)
              : Colors.black.withValues(alpha: 0.65));
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(ArWallPainter old) => !identical(old.walls, walls);
}
