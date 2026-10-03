import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/core/models/trail.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/widgets/safe_sheet.dart';
import 'package:bush_track/features/files/providers/files_provider.dart';
import 'package:bush_track/features/files/services/item_move.dart';
import 'package:bush_track/features/geofence/providers/geofence_provider.dart';
import 'package:bush_track/features/map/providers/trail_provider.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/theme/app_colors.dart';

/// Pick items out of a list and move them somewhere else.
///
/// Two steps in one sheet -- tick the items, then pick where they go -- rather
/// than a selection mode on the screen behind. A selection mode has to be
/// entered and left, and on a phone in one hand that is two more ways to get
/// stuck.
///
/// [currentFileId] is the list being moved out of: a project's id, or null for
/// the Unsorted view. It decides which destinations are offered.
Future<void> showMoveItemsSheet(
  BuildContext context, {
  required int? currentFileId,
  required List<Waypoint> pins,
  required List<Geofence> zones,
  required List<Trail> trails,
}) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MoveItemsSheet(
        currentFileId: currentFileId,
        pins: pins,
        zones: zones,
        trails: trails,
      ),
    );

class _MoveItemsSheet extends ConsumerStatefulWidget {
  const _MoveItemsSheet({
    required this.currentFileId,
    required this.pins,
    required this.zones,
    required this.trails,
  });

  final int? currentFileId;
  final List<Waypoint> pins;
  final List<Geofence> zones;
  final List<Trail> trails;

  @override
  ConsumerState<_MoveItemsSheet> createState() => _MoveItemsSheetState();
}

class _MoveItemsSheetState extends ConsumerState<_MoveItemsSheet> {
  final _pins = <int>{};
  final _zones = <int>{};
  final _trails = <int>{};
  bool _moving = false;

  int get _count => _pins.length + _zones.length + _trails.length;

  bool get _everythingPicked =>
      _pins.length == widget.pins.where((p) => p.id != null).length &&
      _zones.length == widget.zones.where((z) => z.id != null).length &&
      _trails.length == widget.trails.where((t) => t.id != null).length;

  void _pickAll(bool on) => setState(() {
        _pins.clear();
        _zones.clear();
        _trails.clear();
        if (!on) return;
        _pins.addAll(widget.pins.map((p) => p.id).whereType<int>());
        _zones.addAll(widget.zones.map((z) => z.id).whereType<int>());
        _trails.addAll(widget.trails.map((t) => t.id).whereType<int>());
      });

  Future<void> _move(MoveDestination to) async {
    if (_count == 0 || _moving) return;
    setState(() => _moving = true);

    final target = to.targetFileId;
    // Sequential rather than in parallel: each of these writes a row and
    // refreshes a provider, and a Future.wait over thirty of them makes the
    // list rebuild thirty times while half the writes are still in flight.
    for (final id in _pins) {
      await ref.read(locationProvider.notifier).setWaypointFile(id, target);
    }
    for (final id in _zones) {
      final match = widget.zones.where((z) => z.id == id);
      if (match.isEmpty) continue;
      await ref.read(geofenceProvider.notifier).updateZone(
            match.first.copyWith(fileId: target, clearFile: target == null),
          );
    }
    for (final id in _trails) {
      await ref.read(trailProvider.notifier).setTrailFile(id, target);
    }

    if (!mounted) return;
    final moved = _count;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(describeMove(moved, to.name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = destinationsFor(
      ref.watch(filesProvider).files,
      currentFileId: widget.currentFileId,
    );

    final hasItems =
        widget.pins.isNotEmpty || widget.zones.isNotEmpty || widget.trails.isNotEmpty;

    return SafeSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetGrip(),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('MOVE ITEMS',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
              const Spacer(),
              if (hasItems)
                TextButton(
                  onPressed: () => _pickAll(!_everythingPicked),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                  child: Text(_everythingPicked ? 'NONE' : 'ALL',
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          if (!hasItems)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('Nothing here to move.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            )
          else ...[
            Text('Tick what to move, then choose where.',
                style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                    fontSize: 11)),
            const SizedBox(height: 6),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in widget.pins)
                    if (p.id != null)
                      _row(
                        picked: _pins.contains(p.id),
                        onChanged: (on) => setState(() => on
                            ? _pins.add(p.id!)
                            : _pins.remove(p.id)),
                        icon: Icons.location_on,
                        tint: WaypointColors.fromHex(p.color),
                        label: p.label ?? 'Pin',
                      ),
                  for (final z in widget.zones)
                    if (z.id != null)
                      _row(
                        picked: _zones.contains(z.id),
                        onChanged: (on) => setState(() => on
                            ? _zones.add(z.id!)
                            : _zones.remove(z.id)),
                        icon: z.isPolygon
                            ? Icons.pentagon_outlined
                            : Icons.circle_outlined,
                        tint: Color(z.category.colorValue),
                        label: z.name,
                      ),
                  for (final t in widget.trails)
                    if (t.id != null)
                      _row(
                        picked: _trails.contains(t.id),
                        onChanged: (on) => setState(() => on
                            ? _trails.add(t.id!)
                            : _trails.remove(t.id)),
                        icon: Icons.route_rounded,
                        tint: WaypointColors.fromHex(t.color),
                        label: t.name ?? 'Trail',
                      ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (destinations.isEmpty)
              const Text(
                'There is nowhere else to put these yet. Make another '
                'project first.',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 12, height: 1.35),
              )
            else ...[
              Text('MOVE $_count TO',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              // Each destination is its own button, so the move is one tap
              // once the ticking is done rather than a dropdown and a confirm.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in destinations)
                    _destinationChip(d, enabled: _count > 0 && !_moving),
                ],
              ),
            ],
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row({
    required bool picked,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color tint,
    required String label,
  }) =>
      CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        activeColor: AppColors.accent,
        checkColor: Colors.black,
        value: picked,
        onChanged: (on) => onChanged(on == true),
        title: Row(children: [
          Icon(icon, size: 15, color: tint),
          const SizedBox(width: 7),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ]),
      );

  Widget _destinationChip(MoveDestination d, {required bool enabled}) {
    final tint = d.colour == null
        ? AppColors.accent
        : WaypointColors.fromHex(d.colour);

    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: InkWell(
        onTap: enabled ? () => _move(d) : null,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: tint.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  d.isUnsorted
                      ? Icons.inbox_rounded
                      : Icons.folder_rounded,
                  size: 14,
                  color: tint),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(d.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
