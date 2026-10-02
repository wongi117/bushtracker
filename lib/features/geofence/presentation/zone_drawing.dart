import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/core/utils/geo_geometry.dart';
import 'package:bush_track/core/widgets/safe_sheet.dart';
import 'package:bush_track/theme/app_colors.dart';

/// Smallest and largest a circle zone can be.
///
/// 20 m is about the smallest thing worth flagging; 50 km covers a pastoral
/// lease or a whole search area. The old 5 km ceiling was too tight for both
/// ends of that.
const double kZoneMinRadius = 20;
const double kZoneMaxRadius = 50000;

/// Slider position (0-1) for a radius, and back. On a linear scale a 50 km
/// range leaves everything under a kilometre crammed into the first few
/// pixels; on a log scale each drag changes the size by a proportion, so 50 m
/// is as easy to set as 5 km.
double radiusToSliderT(double metres) =>
    (math.log(metres.clamp(kZoneMinRadius, kZoneMaxRadius) / kZoneMinRadius) /
            math.log(kZoneMaxRadius / kZoneMinRadius))
        .clamp(0.0, 1.0);

double sliderTToRadius(double t) =>
    kZoneMinRadius *
    math.pow(kZoneMaxRadius / kZoneMinRadius, t.clamp(0.0, 1.0));

/// A zone being drawn on the map, before it is named and saved.
///
/// Held by the map screen and replaced wholesale on each tap, so the map
/// rebuilds from one value rather than a scatter of mutable fields.
class ZoneDraft {
  /// Set when an existing zone is being resized rather than a new one drawn,
  /// so saving updates that zone instead of adding a second one on top of it.
  final int? editingId;

  final ZoneShape shape;

  /// Corners for a boundary; for a circle, the single centre point once it
  /// has been placed.
  final List<LatLng> points;

  final double radiusMetres;

  const ZoneDraft({
    this.shape = ZoneShape.circle,
    this.points = const [],
    this.radiusMetres = 200,
    this.editingId,
  });

  /// Reopen an existing zone for resizing, with its current size and position.
  factory ZoneDraft.from(Geofence zone) => ZoneDraft(
        shape: zone.isPolygon ? ZoneShape.polygon : ZoneShape.circle,
        points: zone.isPolygon ? zone.points : [zone.centre],
        radiusMetres: zone.radiusMeters,
        editingId: zone.id,
      );

  LatLng? get centre => points.isEmpty ? null : points.first;

  /// Whether there is enough here to save: a placed centre, or three corners
  /// that actually enclose ground.
  bool get isSaveable =>
      shape == ZoneShape.circle ? points.isNotEmpty : points.length >= 3;

  double get areaSqMetres => shape == ZoneShape.circle
      ? 3.141592653589793 * radiusMetres * radiusMetres
      : polygonAreaSqMetres(points);

  ZoneDraft copyWith({
    ZoneShape? shape,
    List<LatLng>? points,
    double? radiusMetres,
  }) =>
      ZoneDraft(
        shape: shape ?? this.shape,
        points: points ?? this.points,
        radiusMetres: radiusMetres ?? this.radiusMetres,
        editingId: editingId,
      );

  /// Handle a tap on the map: a circle keeps only the latest centre, a
  /// boundary adds another corner.
  ZoneDraft withTap(LatLng point) => shape == ZoneShape.circle
      ? copyWith(points: [point])
      : copyWith(points: [...points, point]);

  ZoneDraft undoLastPoint() => points.isEmpty
      ? this
      : copyWith(points: points.sublist(0, points.length - 1));

  /// Switching shape throws away points that do not carry over, so the map
  /// never shows a half-converted shape.
  ZoneDraft withShape(ZoneShape next) =>
      next == shape ? this : copyWith(shape: next, points: const []);
}

/// The map layers for every saved zone, plus whatever is being drawn.
///
/// Zones were previously stored and alerted on but never drawn, so there was
/// no way to see where a boundary actually sat.
List<Widget> buildZoneMapLayers({
  required List<Geofence> zones,
  required Set<int> insideIds,
  ZoneDraft? draft,
  bool showLabels = true,
  ValueChanged<Offset>? onRadiusDragTo,
}) {
  final circles = <CircleMarker>[];
  final polygons = <Polygon>[];

  for (final zone in zones) {
    final base = Color(zone.category.colorValue);
    final inside = zone.id != null && insideIds.contains(zone.id);
    // A zone being stood in is drawn heavier, so "am I in it" is answerable
    // from the map without reading a panel.
    final fill = base.withValues(alpha: inside ? 0.30 : 0.15);
    final stroke = base.withValues(alpha: zone.isActive ? 0.95 : 0.35);
    final strokeWidth = inside ? 3.0 : 2.0;

    if (zone.isPolygon) {
      polygons.add(Polygon(
        points: zone.points,
        color: fill,
        isFilled: true,
        borderColor: stroke,
        borderStrokeWidth: strokeWidth,
        // A muted zone is still drawn, as a dashed outline — it is off, not
        // gone, and it still needs to be visible to be turned back on.
        isDotted: !zone.isActive,
        label: showLabels ? zone.name : null,
        labelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ));
    } else {
      circles.add(CircleMarker(
        point: zone.centre,
        radius: zone.radiusMeters,
        useRadiusInMeter: true,
        color: fill,
        borderColor: stroke,
        borderStrokeWidth: strokeWidth,
      ));
    }
  }

  final layers = <Widget>[
    if (circles.isNotEmpty) CircleLayer(circles: circles),
    if (polygons.isNotEmpty)
      PolygonLayer(polygons: polygons, polygonLabels: showLabels),
  ];

  // Circle zones carry their name on a label marker; CircleMarker has no
  // label of its own.
  if (showLabels) {
    final labelled = zones.where((z) => !z.isPolygon).toList();
    if (labelled.isNotEmpty) {
      layers.add(MarkerLayer(
        markers: labelled
            .map((zone) => Marker(
                  point: zone.centre,
                  width: 140,
                  height: 22,
                  child: _ZoneLabel(
                      text: zone.name, color: Color(zone.category.colorValue)),
                ))
            .toList(),
      ));
    }
  }

  if (draft != null && draft.points.isNotEmpty) {
    layers.addAll(_buildDraftLayers(draft, onRadiusDragTo));
  }

  return layers;
}

List<Widget> _buildDraftLayers(
    ZoneDraft draft, ValueChanged<Offset>? onRadiusDragTo) {
  // White, not AppColors.accent. The accent orange is byte-identical to the
  // "No entry" category — which is also the default — so a zone that saved
  // perfectly well looked exactly like one still being dragged out. Reported
  // as "I picked Heritage and got orange": the orange was an unsaved draft,
  // and had they left the category alone the saved zone would have been orange
  // too.
  //
  // A draft is not a category, so it should not borrow a category's colour.
  // White reads as unfinished and clashes with none of them.
  const draftColor = Colors.white;

  if (draft.shape == ZoneShape.circle) {
    // A grab handle on the edge, due east of the centre, so the circle can be
    // pulled out to size directly on the map instead of only through the
    // slider. Dragging reports the pointer's position; the map screen turns
    // that into a radius, which keeps it correct even when the map is rotated.
    final handlePoint =
        const Distance().offset(draft.centre!, draft.radiusMetres, 90);

    return [
      CircleLayer(circles: [
        CircleMarker(
          point: draft.centre!,
          radius: draft.radiusMetres,
          useRadiusInMeter: true,
          color: draftColor.withValues(alpha: 0.18),
          borderColor: draftColor,
          borderStrokeWidth: 2.5,
        ),
      ]),
      MarkerLayer(markers: [
        Marker(
          point: draft.centre!,
          width: 18,
          height: 18,
          child: const _CornerDot(),
        ),
        if (onRadiusDragTo != null)
          Marker(
            point: handlePoint,
            width: 44,
            height: 44,
            child: _RadiusHandle(onDragTo: onRadiusDragTo),
          ),
      ]),
    ];
  }

  return [
    if (draft.points.length >= 3)
      PolygonLayer(polygons: [
        Polygon(
          points: draft.points,
          color: draftColor.withValues(alpha: 0.18),
          isFilled: true,
          borderColor: draftColor,
          borderStrokeWidth: 2.5,
        ),
      ]),
    // Below three corners there is no shape yet, only a line being walked out.
    if (draft.points.length < 3)
      PolylineLayer(polylines: [
        Polyline(
          points: draft.points,
          color: draftColor,
          strokeWidth: 2.5,
        ),
      ]),
    MarkerLayer(
      markers: draft.points
          .map((p) => Marker(
                point: p,
                width: 18,
                height: 18,
                child: const _CornerDot(),
              ))
          .toList(),
    ),
  ];
}

/// The drag-to-size grip on a circle's edge. Big enough to hit with a thumb,
/// with the visible grip smaller than the touch target.
class _RadiusHandle extends StatelessWidget {
  const _RadiusHandle({required this.onDragTo});

  final ValueChanged<Offset> onDragTo;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDragTo(details.globalPosition),
        child: Center(
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4), blurRadius: 4),
              ],
            ),
            child:
                const Icon(Icons.open_in_full, size: 13, color: Colors.black),
          ),
        ),
      );
}

class _CornerDot extends StatelessWidget {
  const _CornerDot();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      );
}

class _ZoneLabel extends StatelessWidget {
  const _ZoneLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      );
}

/// The controls shown while a zone is being drawn.
class ZoneDrawPanel extends StatelessWidget {
  const ZoneDrawPanel({
    super.key,
    required this.draft,
    required this.onShapeChanged,
    required this.onRadiusChanged,
    required this.onUndo,
    required this.onCancel,
    required this.onSave,
  });

  final ZoneDraft draft;
  final ValueChanged<ZoneShape> onShapeChanged;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onUndo;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final isCircle = draft.shape == ZoneShape.circle;

    return Container(
      padding: EdgeInsets.fromLTRB(
          14, 12, 14, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: AppColors.accent, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.draw, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              const Text('DRAW ZONE',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1)),
              const Spacer(),
              _ShapeToggle(shape: draft.shape, onChanged: onShapeChanged),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isCircle
                ? (draft.points.isEmpty
                    ? 'Tap the map to place the centre.'
                    : 'Drag the grip on the edge to size it, or use the '
                        'slider. Tap the map to move the centre.')
                : (draft.points.length < 3
                    ? 'Tap each corner of the boundary. At least 3.'
                    : 'Keep tapping to add corners, or save it.'),
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12, height: 1.3),
          ),
          if (isCircle && draft.points.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.accent,
                      thumbColor: AppColors.accent,
                      inactiveTrackColor: AppColors.panelHighlight,
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: radiusToSliderT(draft.radiusMetres),
                      onChanged: (t) => onRadiusChanged(sliderTToRadius(t)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(formatDistance(draft.radiusMetres),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
          if (draft.isSaveable) ...[
            const SizedBox(height: 2),
            Text(
              'Covers ${formatArea(draft.areaSqMetres)}'
              '${isCircle ? '' : '  •  ${draft.points.length} corners'}',
              style: const TextStyle(
                  color: AppColors.accentLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (!isCircle && draft.points.isNotEmpty) ...[
                _PanelButton(
                  label: 'UNDO',
                  icon: Icons.undo,
                  onTap: onUndo,
                ),
                const SizedBox(width: 8),
              ],
              _PanelButton(
                label: 'CANCEL',
                icon: Icons.close,
                onTap: onCancel,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PanelButton(
                  label: 'SAVE ZONE',
                  icon: Icons.check,
                  filled: true,
                  onTap: draft.isSaveable ? onSave : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShapeToggle extends StatelessWidget {
  const _ShapeToggle({required this.shape, required this.onChanged});

  final ZoneShape shape;
  final ValueChanged<ZoneShape> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.panelLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _option('Circle', Icons.circle_outlined, ZoneShape.circle),
            _option('Boundary', Icons.pentagon_outlined, ZoneShape.polygon),
          ],
        ),
      );

  Widget _option(String label, IconData icon, ZoneShape value) {
    final selected = shape == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? Colors.black : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.black : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: filled
              ? (enabled ? AppColors.accent : AppColors.panelHighlight)
              : AppColors.panelLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: filled ? Colors.transparent : AppColors.panelHighlight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: filled
                    ? (enabled ? Colors.black : AppColors.textMuted)
                    : Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: filled
                        ? (enabled ? Colors.black : AppColors.textMuted)
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

/// What the zones list wants the map to do with a zone.
class ZoneAction {
  const ZoneAction(this.zone, {this.resize = false, this.track = false});

  final Geofence zone;

  /// True to reopen it for resizing; false to just fly there.
  final bool resize;

  /// True to navigate to it, the same way a pin is tracked.
  final bool track;
}

/// What a zone gets called and why it is flagged.
class ZoneDetails {
  const ZoneDetails({
    required this.name,
    required this.category,
    this.notes,
  });

  final String name;
  final ZoneCategory category;
  final String? notes;
}

/// Asks for the name, category and notes once the shape is drawn.
///
/// Full-height and scrollable, with room left for the keyboard: the app's
/// other sheets used to trap their own content off the bottom of a phone.
Future<ZoneDetails?> showZoneDetailsSheet(
  BuildContext context, {
  required String summary,
  ZoneDetails? initial,
}) {
  final nameController = TextEditingController(text: initial?.name ?? '');
  final notesController = TextEditingController(text: initial?.notes ?? '');
  var category = initial?.category ?? ZoneCategory.exclusion;

  return showModalBottomSheet<ZoneDetails>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      // Was padded for viewInsets only — the keyboard — so SAVE and CANCEL
      // were drawn underneath the Android navigation bar whenever the keyboard
      // was down, and a boundary could not be saved at all. sheetPadding
      // clears both; see safe_sheet.dart for why they combine with max rather
      // than a sum.
      builder: (sheetContext, setSheetState) => Container(
        constraints: BoxConstraints(
          // Leaves the keyboard its room, so the form scrolls rather than
          // pushing its own buttons off the bottom while being typed into.
          maxHeight: (MediaQuery.of(sheetContext).size.height -
                  MediaQuery.of(sheetContext).viewInsets.bottom) *
              0.9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.panelMatte,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        // Two separate jobs, and one without the other leaves the buttons
        // covered.
        //
        // The MARGIN lifts the whole panel clear of the keyboard. Content
        // padding cannot do this: showModalBottomSheet pins the sheet to the
        // bottom of the screen and the keyboard is drawn over the top, so
        // padding only moves the contents around inside a box that is still
        // underneath it. A test caught precisely that — the navigation bar was
        // cleared and SAVE was still behind the keyboard. The background does
        // not paint into the margin, which is right: nothing should be drawn
        // under the keyboard.
        margin: EdgeInsets.only(bottom: sheetLift(sheetContext)),
        // The PADDING then clears whatever of the navigation bar the keyboard
        // is not already covering.
        padding: sheetPadding(sheetContext),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.panelHighlight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('NAME THIS ZONE',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(summary,
                  style: const TextStyle(
                      color: AppColors.accentLight, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('Name', 'Old shaft, creek bend'),
              ),
              const SizedBox(height: 16),
              const Text('WHAT IS IT?',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ZoneCategory.values.map((c) {
                  final selected = c == category;
                  final color = Color(c.colorValue);
                  return GestureDetector(
                    onTap: () => setSheetState(() => category = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: 0.25)
                            : AppColors.panelLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: selected ? color : AppColors.panelHighlight,
                            width: selected ? 2 : 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 7),
                          Text(c.label,
                              style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration(
                    'Notes (optional)', 'What is here, who to tell'),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('CANCEL',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final name = nameController.text.trim();
                        Navigator.pop(
                          sheetContext,
                          ZoneDetails(
                            // An unnamed zone is still worth saving; it just
                            // needs something to show in the list.
                            name: name.isEmpty ? category.label : name,
                            category: category,
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                          ),
                        );
                      },
                      child: const Text('SAVE',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

InputDecoration _fieldDecoration(String label, String hint) => InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      filled: true,
      fillColor: AppColors.panelLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    );
