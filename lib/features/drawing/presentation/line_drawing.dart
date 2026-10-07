import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/utils/geo_geometry.dart';
import 'package:bush_track/features/drawing/models/drawing.dart';
import 'package:bush_track/features/drawing/presentation/pen_picker.dart';
import 'package:bush_track/features/drawing/services/line_geometry.dart';
import 'package:bush_track/theme/app_colors.dart';

/// "240 m · NE 47°" for one leg.
String describeSegment(LineSegment s) =>
    '${formatDistance(s.metres)} · ${LineMeasure.compassPoint(s.bearing)} '
    '${s.bearing.round() % 360}°';

/// Saved drawings, and the line being drawn or edited, as map layers.
///
/// Only this file and the dashboard know about flutter_map; the arithmetic is
/// in line_geometry.dart, so a change of map widget rewrites this and nothing
/// under it.
///
/// The draft's point handles and + buttons are not in here: see [LineHandles].
List<Widget> buildDrawingMapLayers({
  required List<Drawing> drawings,
  LineDraft? draft,
  int? editingId,
  bool showLabels = true,
  String draftColour = '#FF6B00',
  double draftWidth = 4,
}) {
  final layers = <Widget>[];

  final saved = drawings
      .where((d) => d.id != editingId && d.points.length >= 2)
      .toList();
  if (saved.isNotEmpty) {
    layers.add(PolylineLayer(polylines: [
      for (final d in saved)
        Polyline(
          points: d.points,
          color: WaypointColors.fromHex(d.colour),
          strokeWidth: d.width,
          borderColor: Colors.black.withValues(alpha: 0.5),
          borderStrokeWidth: 1,
        ),
    ]));
  }

  final points = draft?.points ?? const <LatLng>[];
  if (draft == null || points.isEmpty) return layers;

  if (points.length >= 2) {
    layers.add(PolylineLayer(polylines: [
      Polyline(
        points: points,
        color: WaypointColors.fromHex(draftColour),
        strokeWidth: draftWidth,
        borderColor: Colors.white,
        borderStrokeWidth: 1.5,
      ),
    ]));
  }

  final segments = LineMeasure.segments(points);
  final midpoints = draft.midpoints;
  if (!showLabels || segments.isEmpty) return layers;
  layers.add(MarkerLayer(markers: [
    // The leg's length and bearing, above its midpoint.
    //
    // It used to be centred on the midpoint and allowed to wrap, and a label
    // that wrapped -- a long figure, a large system font -- spread down over
    // the + and took its taps. Now it sits wholly above the point, stays on
    // one line (shrinking rather than wrapping), and ignores touches, so
    // nothing under it can be blocked by it.
    for (var i = 0; i < segments.length; i++)
        Marker(
          point: midpoints[i],
          width: 170,
          height: 36,
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(describeSegment(segments[i]),
                      maxLines: 1,
                      softWrap: false,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            ),
          ),
        ),
  ]));

  return layers;
}

/// Where [p] sits on the map widget, in its own logical pixels.
///
/// The inverse of flutter_map's `MapCamera.offsetToCrs`, which the zone
/// handle already relies on to turn a finger into a position. That turns the
/// offset from the centre with `rotate(θ)` -- which in flutter_map is a turn
/// of -θ -- so this turns the other way. Tested as a round trip at several
/// rotations: a handle drawn a few pixels off its point would be dragged from
/// the wrong place.
Offset mapOffsetOf(MapCamera camera, LatLng p) {
  final d = camera.project(p) - camera.project(camera.center);
  final t = -camera.rotationRad;
  final c = math.cos(t), s = math.sin(t);
  return Offset(
    c * d.x + s * d.y + camera.nonRotatedSize.x / 2,
    c * d.y - s * d.x + camera.nonRotatedSize.y / 2,
  );
}

/// The draft line's points and + buttons, drawn **above** the map rather
/// than as markers inside it.
///
/// As markers they were inside the map's own gesture handling, and on the
/// phone a drag that started on a point moved the whole map instead. Above
/// it, a touch that lands on a handle never reaches the map at all; one that
/// misses every handle falls through to the map as usual, because a Stack
/// that hits nothing hands the touch on to what is under it. Freehand's
/// drawing surface works for the same reason.
///
/// [vertices] and [midpoints] are positions on the map widget, from
/// [mapOffsetOf]; this must be laid out over the map with the same origin.
class LineHandles extends StatelessWidget {
  final List<Offset> vertices;
  final List<Offset> midpoints;
  final void Function(int index, Offset globalPosition) onDragTo;
  final ValueChanged<int> onDragEnd;
  final ValueChanged<int> onRemove;

  /// Called with the index the new vertex will take: a + on leg i asks for
  /// i + 1.
  final ValueChanged<int> onInsert;

  const LineHandles({
    super.key,
    required this.vertices,
    required this.midpoints,
    required this.onDragTo,
    required this.onDragEnd,
    required this.onRemove,
    required this.onInsert,
  });

  /// Bigger than it looks: the dot is 14 px, the target a fingertip.
  static const double _vertexTarget = 40;
  static const double _plusTarget = 32;

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      for (var i = 0; i < midpoints.length; i++)
        Positioned(
          left: midpoints[i].dx - _plusTarget / 2,
          top: midpoints[i].dy - _plusTarget / 2,
          width: _plusTarget,
          height: _plusTarget,
          child: GestureDetector(
            key: ValueKey('line-midpoint-$i'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onInsert(i + 1),
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppColors.primaryOrange, width: 1.5),
                ),
                child: const Icon(Icons.add, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      for (var i = 0; i < vertices.length; i++)
        Positioned(
          left: vertices[i].dx - _vertexTarget / 2,
          top: vertices[i].dy - _vertexTarget / 2,
          width: _vertexTarget,
          height: _vertexTarget,
          child: GestureDetector(
            key: ValueKey('line-vertex-$i'),
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => onDragTo(i, d.globalPosition),
            onPanEnd: (_) => onDragEnd(i),
            onLongPress: () => onRemove(i),
            child: Center(
              child: Container(
                width: i == 0 ? 18 : 14,
                height: i == 0 ? 18 : 14,
                decoration: BoxDecoration(
                  color: i == 0 ? Colors.white : AppColors.primaryOrange,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: i == 0 ? AppColors.primaryOrange : Colors.white,
                      width: 2),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// The controls while a line is drawn: running total, every leg, undo, done.
class LineDrawPanel extends StatelessWidget {
  final List<LatLng> points;
  final bool canUndo;
  final bool editing;

  /// What the last tap snapped to, said out loud so a snap is never a
  /// surprise.
  final String? snappedTo;

  final VoidCallback onUndo;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  final String colour;
  final double width;
  final ValueChanged<String> onColour;
  final ValueChanged<double> onWidth;

  const LineDrawPanel({
    super.key,
    required this.points,
    required this.canUndo,
    required this.onUndo,
    required this.onCancel,
    required this.onDone,
    required this.colour,
    required this.width,
    required this.onColour,
    required this.onWidth,
    this.editing = false,
    this.snappedTo,
  });

  @override
  Widget build(BuildContext context) {
    final segments = LineMeasure.segments(points);
    final total = LineMeasure.totalMetres(points);
    final canSave = points.length >= 2;

    return Material(
      color: const Color(0xF20F0F1A),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        // viewPadding: the buttons sat under the navigation bar otherwise.
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.timeline, color: AppColors.primaryOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    points.isEmpty
                        ? 'Tap the map to start the line'
                        : '${formatDistance(total)}  ·  '
                            '${segments.length} ${segments.length == 1 ? 'leg' : 'legs'}',
                    key: const ValueKey('line-total'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
              if (snappedTo != null) ...[
                const SizedBox(height: 4),
                Text('Snapped to $snappedTo',
                    style: const TextStyle(
                        color: AppColors.primaryOrange, fontSize: 12)),
              ],
              if (segments.isNotEmpty) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 110),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: segments.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        SizedBox(
                          width: 26,
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ),
                        Expanded(
                          child: Text(describeSegment(segments[i]),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              PenPicker(
                colour: colour,
                width: width,
                onColour: onColour,
                onWidth: onWidth,
              ),
              const SizedBox(height: 8),
              Text(
                'Drag a point to move it · long-press to remove · tap + to add',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
              ),
              const SizedBox(height: 10),
              Row(children: [
                IconButton(
                  tooltip: 'Undo',
                  onPressed: canUndo ? onUndo : null,
                  icon: const Icon(Icons.undo),
                  color: Colors.white,
                  disabledColor: Colors.white24,
                ),
                const Spacer(),
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white60)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: canSave ? onDone : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange),
                  child: Text(editing ? 'Save' : 'Done',
                      style: const TextStyle(color: Colors.white)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
