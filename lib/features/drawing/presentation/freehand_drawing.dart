import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/utils/geo_geometry.dart';
import 'package:bush_track/features/drawing/services/freehand.dart';
import 'package:bush_track/theme/app_colors.dart';

/// Pen colours: picked to stand out on satellite imagery and on the topo map.
const freehandColours = ['#FF6B00', '#FF1744', '#FFEA00', '#00E5FF', '#FFFFFF'];

/// Thin, medium, thick, in logical pixels.
const freehandWidths = [2.0, 4.0, 7.0];

/// The session's strokes, and the one under the finger, as map layers.
List<Widget> buildFreehandLayers(FreehandSession? session) {
  if (session == null) return const [];
  final colour = WaypointColors.fromHex(session.colour);
  final current = session.current;
  final lines = [
    ...session.strokes,
    if (current != null && current.length >= 2) current,
  ];
  if (lines.isEmpty) return const [];
  return [
    PolylineLayer(polylines: [
      for (final l in lines)
        Polyline(
          points: l,
          color: colour,
          strokeWidth: session.width,
          borderColor: Colors.black.withValues(alpha: 0.5),
          borderStrokeWidth: 1,
        ),
    ]),
  ];
}

class FreehandPanel extends StatelessWidget {
  final FreehandSession session;
  final ValueChanged<bool> onDrawingChanged;
  final ValueChanged<String> onColour;
  final ValueChanged<double> onWidth;
  final VoidCallback onUndo;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  const FreehandPanel({
    super.key,
    required this.session,
    required this.onDrawingChanged,
    required this.onColour,
    required this.onWidth,
    required this.onUndo,
    required this.onCancel,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final n = session.strokes.length;
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
                Expanded(
                  child: Text(
                    n == 0
                        ? (session.drawing
                            ? 'Draw on the map with your finger'
                            : 'Move the map, then switch back to Draw')
                        : '$n ${n == 1 ? 'stroke' : 'strokes'}  ·  '
                            '${formatDistance(session.totalMetres)}',
                    key: const ValueKey('freehand-status'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                // Draw locks the map so a stroke is not read as a pan; Pan
                // gives the map back.
                SegmentedButton<bool>(
                  key: const ValueKey('freehand-mode'),
                  segments: const [
                    ButtonSegment(
                        value: true,
                        icon: Icon(Icons.edit, size: 16),
                        label: Text('Draw')),
                    ButtonSegment(
                        value: false,
                        icon: Icon(Icons.pan_tool_outlined, size: 16),
                        label: Text('Pan')),
                  ],
                  selected: {session.drawing},
                  onSelectionChanged: (s) => onDrawingChanged(s.first),
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    selectedForegroundColor: Colors.black,
                    selectedBackgroundColor: AppColors.primaryOrange,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                for (final c in freehandColours)
                  GestureDetector(
                    key: ValueKey('freehand-colour-$c'),
                    onTap: () => onColour(c),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: WaypointColors.fromHex(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: session.colour == c
                              ? Colors.white
                              : Colors.white24,
                          width: session.colour == c ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                for (final w in freehandWidths)
                  GestureDetector(
                    key: ValueKey('freehand-width-${w.round()}'),
                    onTap: () => onWidth(w),
                    child: Container(
                      width: 34,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: session.width == w
                              ? AppColors.primaryOrange
                              : Colors.transparent,
                        ),
                      ),
                      child: Container(
                          width: 20, height: w, color: Colors.white),
                    ),
                  ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                IconButton(
                  tooltip: 'Undo last stroke',
                  onPressed: session.canUndo ? onUndo : null,
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
                  onPressed: n == 0 ? null : onDone,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange),
                  child: const Text('Done',
                      style: TextStyle(color: Colors.white)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
