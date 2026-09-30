import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/core/utils/geo_geometry.dart';
import 'package:bush_track/features/geofence/presentation/zone_drawing.dart';
import 'package:bush_track/features/files/providers/files_provider.dart';
import 'package:bush_track/features/geofence/providers/geofence_provider.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/theme/app_colors.dart';

/// Every zone that has been flagged: circles and drawn boundaries.
///
/// Tapping one closes the list and returns it, so the map can fly there —
/// the previous version had no way at all to see where a zone was.
class GeofenceScreen extends ConsumerStatefulWidget {
  const GeofenceScreen({super.key});

  @override
  ConsumerState<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends ConsumerState<GeofenceScreen> {
  @override
  Widget build(BuildContext context) {
    final geofenceState = ref.watch(geofenceProvider);
    final locationState = ref.watch(locationProvider);
    final here = locationState.stats.currentLat == null
        ? null
        : LatLng(locationState.stats.currentLat!,
            locationState.stats.currentLon!);

    // Nearest first when there is a position to measure from — the zone being
    // stood next to is the one being looked for.
    final zones = [...geofenceState.geofences];
    if (here != null) {
      const distance = Distance();
      zones.sort((a, b) =>
          distance(here, a.centre).compareTo(distance(here, b.centre)));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.panelMatte,
        title: const Row(children: [
          Icon(Icons.layers_outlined, color: AppColors.accent, size: 20),
          SizedBox(width: 8),
          Text('ZONES', style: TextStyle(color: Colors.white)),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: AppColors.accent),
            tooltip: 'Quick circle where I am standing',
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: zones.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: zones.length,
              itemBuilder: (_, i) => _buildTile(zones[i], here),
            ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers_outlined,
                  size: 64,
                  color: AppColors.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              const Text(
                'No zones yet',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Use Draw Zone in the menu to tap out a boundary on the map, '
                'or the target button up top for a quick circle where you are '
                'standing.',
                style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _buildTile(Geofence zone, LatLng? here) {
    final isInside = ref.watch(geofenceProvider).insideIds.contains(zone.id);
    final color = Color(zone.category.colorValue);

    final facts = <String>[
      zone.isPolygon
          ? '${zone.points.length} corners'
          : '${zone.radiusMeters.round()} m radius',
      formatArea(zone.areaSqMetres),
      if (here != null && !isInside)
        '${formatDistance(zone.distanceToEdgeMetres(here))} away',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInside
              ? AppColors.statusGreen.withValues(alpha: 0.6)
              : color.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        onTap: () => Navigator.pop(context, ZoneAction(zone)),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Icon(
            zone.isPolygon ? Icons.pentagon_outlined : Icons.circle_outlined,
            color: color,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(zone.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            if (isInside) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.statusGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('INSIDE',
                    style: TextStyle(
                        color: AppColors.statusGreen,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${zone.category.label}  •  ${facts.join('  •  ')}',
              style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  fontSize: 11),
            ),
            if (zone.notes != null && zone.notes!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                zone.notes!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: zone.isActive,
              activeThumbColor: AppColors.accent,
              onChanged: (_) =>
                  ref.read(geofenceProvider.notifier).toggleGeofence(zone.id!),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert,
                  color: AppColors.textSecondary, size: 20),
              onPressed: () => _showZoneActions(zone),
            ),
          ],
        ),
      ),
    );
  }

  void _showZoneActions(Geofence zone) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panelMatte,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.near_me, color: AppColors.statusGreen),
              title: const Text('Track this zone',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Distance and direction until you reach it',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.pop(context, ZoneAction(zone, track: true));
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined, color: AppColors.accent),
              title: const Text('Move to a file',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text(
                  _fileLabel(zone),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _pickFile(zone);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.accent),
              title: const Text('Rename or re-flag',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _editZone(zone);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_full, color: AppColors.accent),
              title: Text(
                  zone.isPolygon ? 'Redraw on map' : 'Resize on map',
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                  zone.isPolygon
                      ? 'Tap out new corners for this zone'
                      : 'Drag its edge to make it bigger or smaller',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.pop(context, ZoneAction(zone, resize: true));
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.statusRed),
              title: const Text('Delete zone',
                  style: TextStyle(color: AppColors.statusRed)),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(zone);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Which file this zone is filed under, for the action sheet subtitle.
  String _fileLabel(Geofence zone) {
    final files = ref.read(filesProvider).files;
    final match = files.where((f) => f.id == zone.fileId);
    return match.isEmpty ? 'Not in a file' : 'In ${match.first.name}';
  }

  /// Move a zone into a field file — or out of one.
  ///
  /// Zones are filed automatically when a file is open as they are drawn, but
  /// one flagged before the file existed needs a way in afterwards.
  Future<void> _pickFile(Geofence zone) async {
    final files = ref.read(filesProvider).files;
    if (files.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No files yet — make one from the folder button first.'),
        backgroundColor: AppColors.primaryOrange,
      ));
      return;
    }

    final chosen = await showModalBottomSheet<int?>(
      context: context,
      backgroundColor: AppColors.panelMatte,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Text('FILE THIS ZONE UNDER',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ),
            ...files.map((f) => ListTile(
                  leading: Icon(
                      zone.fileId == f.id
                          ? Icons.folder_open_rounded
                          : Icons.folder_rounded,
                      color: AppColors.accent),
                  title: Text(f.name,
                      style: const TextStyle(color: Colors.white)),
                  trailing: zone.fileId == f.id
                      ? const Icon(Icons.check, color: AppColors.statusGreen)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, f.id),
                )),
            const Divider(color: AppColors.panelHighlight),
            ListTile(
              leading:
                  const Icon(Icons.folder_off_outlined, color: AppColors.textMuted),
              title: const Text('Not in a file',
                  style: TextStyle(color: AppColors.textSecondary)),
              onTap: () => Navigator.pop(sheetContext, -1),
            ),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    await ref.read(geofenceProvider.notifier).updateZone(
        zone.copyWith(fileId: chosen == -1 ? null : chosen, clearFile: chosen == -1));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(chosen == -1
          ? '${zone.name} removed from its file'
          : '${zone.name} filed'),
      backgroundColor: AppColors.statusGreen,
    ));
  }

  Future<void> _editZone(Geofence zone) async {
    final summary = zone.isPolygon
        ? '${zone.points.length} corners  •  ${formatArea(zone.areaSqMetres)}'
        : '${zone.radiusMeters.round()} m radius  •  ${formatArea(zone.areaSqMetres)}';

    final details = await showZoneDetailsSheet(
      context,
      summary: summary,
      initial: ZoneDetails(
          name: zone.name, category: zone.category, notes: zone.notes),
    );
    if (details == null) return;

    await ref.read(geofenceProvider.notifier).updateZone(zone.copyWith(
          name: details.name,
          category: details.category,
          notes: details.notes,
        ));
  }

  void _showAddDialog(BuildContext context) {
    final locationState = ref.read(locationProvider);
    final lat = locationState.stats.currentLat;
    final lon = locationState.stats.currentLon;

    final nameCtrl = TextEditingController();
    double radius = 200;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          backgroundColor: AppColors.panelMatte,
          title: const Text('Zone where I am standing',
              style: TextStyle(color: Colors.white, fontSize: 17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lat == null)
                const Text(
                  'GPS not available. Enable location first.',
                  style: TextStyle(color: AppColors.statusRed),
                )
              else
                Text(
                  'Location: ${lat.toStringAsFixed(4)}, ${lon!.toStringAsFixed(4)}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle:
                      const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.background.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Radius: ${radius.toInt()} m',
                  style: const TextStyle(color: Colors.white)),
              Slider(
                value: radius,
                min: 50,
                max: 5000,
                divisions: 99,
                activeColor: AppColors.accent,
                onChanged: (v) => setStateDlg(() => radius = v),
              ),
              const Text(
                'For a boundary that is not a circle, use Draw Zone on the map.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: lat == null
                  ? null
                  : () {
                      final name = nameCtrl.text.trim();
                      ref.read(geofenceProvider.notifier).addGeofence(
                            name: name.isEmpty ? 'Zone' : name,
                            latitude: lat,
                            longitude: lon!,
                            radiusMeters: radius,
                          );
                      Navigator.pop(ctx);
                    },
              child:
                  const Text('Save', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Geofence fence) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelMatte,
        title: const Text('Delete zone', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${fence.name}"?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(geofenceProvider.notifier).deleteGeofence(fence.id!);
              Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.statusRed)),
          ),
        ],
      ),
    );
  }
}
