import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:bush_track/core/utils/geo_geometry.dart';
import 'package:bush_track/features/ar/services/ar_walls.dart';

/// Zones standing up through the camera (Phase 4.5).
///
/// A no-go zone (hazard, heritage, No entry) is a solid translucent wall in
/// the zone's colour, rising from the ground, with bold diagonal stripes that
/// keep their real size, a thick bright top and base, a tint on the ground in
/// front of it and its name pinned to its face. Within 50 m it is drawn
/// stronger and pulses slowly. An ordinary zone is the same wall, knee high,
/// in its own colour, without stripes.
///
/// Painted under the pins, so a pin inside a zone is still seen and tapped.
class ArWallPainter extends CustomPainter {
  ArWallPainter(this.walls, {this.pulse = 0});

  final ArWalls walls;

  /// 0 to 1, repeating: the slow pulse on a near wall.
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (walls.panels.isEmpty) return;
    // 0 -> 1 -> 0 over one cycle, eased.
    final wave = 0.5 - 0.5 * math.cos(2 * math.pi * pulse);

    // Near or not is decided per zone: a wall pulses as a whole.
    final nearZones = <Object>{
      for (final p in walls.panels)
        if (p.isNear) _key(p),
    };

    // 1. The ground in front of the wall, under everything.
    for (final p in walls.panels) {
      final g = p.glow;
      if (g == null) continue;
      final colour = Color(p.zone.category.colorValue);
      final from = Offset.lerp(g[0], g[1], 0.5)!;
      final to = Offset.lerp(g[2], g[3], 0.5)!;
      if ((to - from).distance < 1) continue;
      canvas.drawPath(
        _poly(g),
        Paint()
          ..shader = ui.Gradient.linear(from, to, [
            colour.withValues(alpha: 0.35),
            colour.withValues(alpha: 0),
          ]),
      );
    }

    // 2. The face. One path per zone, so overlapping seams do not double up.
    final faces = <Object, (WallStyle, Color, Path)>{};
    for (final p in walls.panels) {
      final entry = faces.putIfAbsent(_key(p),
          () => (p.style, Color(p.zone.category.colorValue), Path()));
      entry.$3.addPath(p.path, Offset.zero);
    }
    for (final MapEntry(:key, value: (style, colour, path)) in faces.entries) {
      final noGo = style == WallStyle.noGo;
      final near = nearZones.contains(key);
      final alpha = noGo ? (near ? 0.45 + 0.12 * wave : 0.40) : 0.45;
      canvas.drawPath(path, Paint()..color = colour.withValues(alpha: alpha));
    }

    // 3. Stripes: white bands over the zone's colour read as a warning on
    // any background the camera shows.
    for (final p in walls.panels) {
      if (p.stripes.isEmpty) continue;
      final near = nearZones.contains(_key(p));
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: near ? 0.45 + 0.15 * wave : 0.42);
      for (final s in p.stripes) {
        canvas.drawPath(_poly(s), paint);
      }
    }

    // 4. Edges: the top is what reads as a wall, the base is where it meets
    // the ground. Thick and bright for no-go.
    for (final p in walls.panels) {
      final colour = Color(p.zone.category.colorValue);
      final noGo = p.style == WallStyle.noGo;
      final edge = Paint()
        ..color = colour
        ..strokeWidth = noGo ? 5 : 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p.topA, p.topB, edge);
      canvas.drawLine(p.bottomA, p.bottomB, edge);
      if (noGo) {
        final core = Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..strokeWidth = 1.5;
        canvas.drawLine(p.topA, p.topB, core);
        canvas.drawLine(p.bottomA, p.bottomB, core);
      }
    }

    // 5. Names, on the wall.
    for (final l in walls.labels) {
      _label(canvas, size, l, wave);
    }
  }

  static Object _key(WallPanel p) => p.zone.id ?? identityHashCode(p.zone);

  static Path _poly(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  /// Centred on the point pinned to the wall face, always square to the
  /// camera, sized by distance within a readable range.
  void _label(Canvas canvas, Size size, WallLabel l, double wave) {
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
          fontSize: noGo ? l.fontSize : math.min(l.fontSize, 14),
          fontWeight: noGo ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size.width - 32);

    // Kept on screen: close up, the wall's middle can be off the edge.
    final x = (l.at.dx - tp.width / 2)
        .clamp(16.0, math.max(16.0, size.width - tp.width - 16))
        .toDouble();
    final y = (l.at.dy - tp.height / 2)
        .clamp(90.0, math.max(90.0, size.height - tp.height - 120))
        .toDouble();
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - 10, y - 6, tp.width + 20, tp.height + 12),
      const Radius.circular(8),
    );
    final fill = noGo
        ? Color.fromRGBO(183, 28, 28, l.isNear ? 0.85 + 0.1 * wave : 0.9)
        : Colors.black.withValues(alpha: 0.65);
    canvas.drawRRect(box, Paint()..color = fill);
    if (noGo) {
      canvas.drawRRect(
          box,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white);
    }
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(ArWallPainter old) =>
      !identical(old.walls, walls) || old.pulse != pulse;
}
