import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/utils/geo_geometry.dart';
import 'package:bush_track/features/files/providers/files_provider.dart';
import 'package:bush_track/features/files/services/project_scope.dart';
import 'package:bush_track/features/geofence/providers/geofence_provider.dart';
import 'package:bush_track/features/map/providers/marker_visibility_provider.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/theme/app_colors.dart';

/// What the picker was asked to do with the thing that was tapped.
class MarkerChoice {
  const MarkerChoice.follow(this.position, this.name)
      : zone = null,
        waypoint = null;
  const MarkerChoice.followPin(this.waypoint)
      : zone = null,
        position = null,
        name = null;
  const MarkerChoice.followZone(this.zone)
      : waypoint = null,
        position = null,
        name = null;

  final Waypoint? waypoint;
  final Geofence? zone;
  final LatLng? position;
  final String? name;
}

/// Choose what to see and what to follow.
///
/// Reached from the camera and from the menu: after a few days of work there
/// are too many pins and zones for all of them to be useful at once, and the
/// one you are walking to is the one that matters.
class MarkerPickerScreen extends ConsumerStatefulWidget {
  const MarkerPickerScreen({super.key});

  @override
  ConsumerState<MarkerPickerScreen> createState() => _MarkerPickerScreenState();
}

class _MarkerPickerScreenState extends ConsumerState<MarkerPickerScreen> {
  @override
  Widget build(BuildContext context) {
    final visibility = ref.watch(markerVisibilityProvider);
    // The project being worked in is not a filter local to this screen — it is
    // the map's and the camera's too. Picking one here changes what is drawn
    // out there, which is the whole point of having projects.
    final scope = visibility.scope;
    final stats = ref.watch(locationProvider).stats;
    final here = stats.currentLat == null
        ? null
        : LatLng(stats.currentLat!, stats.currentLon!);

    var pins = ref
        .watch(locationProvider)
        .waypoints
        .where((w) => w.isPin == true && w.latitude != null)
        .toList();
    var zones = [...ref.watch(geofenceProvider).geofences];

    if (scope.isFiltered) {
      pins = pins.where((w) => scope.isVisible(w.fileId)).toList();
      zones = zones.where((z) => scope.isVisible(z.fileId)).toList();
    }

    // Nearest first: the thing you are next to is the thing you mean.
    if (here != null) {
      const d = Distance();
      pins.sort((a, b) => d(here, LatLng(a.latitude!, a.longitude!))
          .compareTo(d(here, LatLng(b.latitude!, b.longitude!))));
      zones.sort((a, b) =>
          d(here, a.centre).compareTo(d(here, b.centre)));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.panelMatte,
        title: const Row(children: [
          Icon(Icons.visibility, color: AppColors.accent, size: 20),
          SizedBox(width: 8),
          Text('SHOW & FOLLOW', style: TextStyle(color: Colors.white)),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (visibility.isFiltered)
            TextButton(
              onPressed: () =>
                  ref.read(markerVisibilityProvider.notifier).showEverything(),
              child: const Text('SHOW ALL',
                  style: TextStyle(color: AppColors.accent, fontSize: 12)),
            ),
        ],
      ),
      body: Column(
        children: [
          _fileChips(scope),
          if (scope.isFiltered) _scopeNote(scope),
          Expanded(
            child: (pins.isEmpty && zones.isEmpty)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        scope == null
                            ? 'Nothing here yet. Drop a pin or draw a zone and '
                                'it will show up in this list.'
                            : 'This project has nothing in it yet. Pins and '
                                'zones you make while it is open get filed '
                                'here.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (pins.isNotEmpty) _label('PINS'),
                      ...pins.map((p) => _pinRow(p, here, visibility)),
                      if (zones.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _label('ZONES & BOUNDARIES'),
                        ...zones.map((z) => _zoneRow(z, here, visibility)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _fileChips(ProjectScope scope) {
    final files = ref.watch(filesProvider).files;
    if (files.isEmpty) return const SizedBox.shrink();

    final notifier = ref.read(markerVisibilityProvider.notifier);
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          // Widening the view does not change where new work is filed: you are
          // still working in the same project, just looking at everything.
          _chip('All work', !scope.isFiltered, notifier.closeProject),
          ...files.map((f) => _chip(f.name, scope.isSelected(f.id!),
              () => _openProject(f.id!))),
          // Unfiled work is reachable as a project in its own right, or it
          // becomes invisible the moment any scope is on.
          _chip('Unsorted', scope.isSelected(FieldFile.unsortedId),
              () => notifier.toggleProject(FieldFile.unsortedId)),
        ],
      ),
    );
  }

  /// Show a project, and file new work into it.
  ///
  /// Both, because otherwise there is a trap: narrow the map to a project,
  /// drop a pin, and the pin is filed wherever the last project was and
  /// vanishes the instant it is created. Looking at a project is as good a
  /// statement of what you are working on as any.
  Future<void> _openProject(int fileId) async {
    final notifier = ref.read(markerVisibilityProvider.notifier);
    await notifier.toggleProject(fileId);
    // New work is filed into the project only while it is the single one being
    // looked at. With two open there is no answer to "which one", and guessing
    // files a pin somewhere the user did not choose.
    final scope = ref.read(markerVisibilityProvider).scope;
    if (scope.count == 1 && scope.isSelected(fileId)) {
      await ref.read(filesProvider.notifier).setActiveFile(fileId);
    }
  }

  /// Says plainly that the map is narrowed, and how to undo it.
  ///
  /// Without this the other pins are simply gone as far as anyone can tell, and
  /// a filter that looks like lost data is worse than no filter.
  Widget _scopeNote(ProjectScope scope) {
    final named = ref
        .watch(filesProvider)
        .files
        .where((f) => f.id != null && scope.isSelected(f.id!))
        .map((f) => f.name)
        .toList();
    if (scope.isSelected(FieldFile.unsortedId)) named.add('Unsorted');
    final name = named.isEmpty
        ? 'this project'
        : named.length == 1
            ? named.first
            // Listed rather than counted here: there is room for it on this
            // screen, and knowing which ones is the point of the note.
            : named.join(', ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.folder_open_rounded,
            color: AppColors.accent, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Map and camera are showing $name only',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        GestureDetector(
          onTap: ref.read(markerVisibilityProvider.notifier).closeProject,
          child: const Text('SHOW ALL',
              style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : AppColors.panelMatte,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? AppColors.accent : AppColors.panelHighlight),
            ),
            child: Text(text,
                style: TextStyle(
                    color: selected ? Colors.black : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      );

  Widget _pinRow(Waypoint p, LatLng? here, MarkerVisibility vis) {
    final visible = vis.showsPin(id: p.id, fileId: p.fileId);
    final colour = WaypointColors.fromHex(p.color);
    final away = here == null
        ? null
        : formatDistance(const Distance()(
            here, LatLng(p.latitude!, p.longitude!)));

    final facts = <String>[
      if (away != null) '$away away',
      if (p.accuracy != null) '±${p.accuracy!.round()} m fix',
    ];

    return _row(
      visible: visible,
      colour: colour,
      icon: Icons.location_on,
      title: p.label ?? 'Pin',
      subtitle: facts.isEmpty ? 'No position recorded' : facts.join('  ·  '),
      onToggle: () =>
          ref.read(markerVisibilityProvider.notifier).togglePin(p.id!),
      onIsolate: () =>
          ref.read(markerVisibilityProvider.notifier).soloPin(p.id!),
      onFollow: () => Navigator.pop(context, MarkerChoice.followPin(p)),
    );
  }

  Widget _zoneRow(Geofence z, LatLng? here, MarkerVisibility vis) {
    final visible = vis.showsZone(id: z.id, fileId: z.fileId);
    final away = here == null
        ? null
        : formatDistance(z.distanceToEdgeMetres(here));

    return _row(
      visible: visible,
      colour: Color(z.category.colorValue),
      icon: z.isPolygon ? Icons.pentagon_outlined : Icons.circle_outlined,
      title: z.name,
      subtitle: [
        z.category.label,
        formatArea(z.areaSqMetres),
        if (away != null) '$away away',
      ].join('  ·  '),
      onToggle: () =>
          ref.read(markerVisibilityProvider.notifier).toggleZone(z.id!),
      onIsolate: () =>
          ref.read(markerVisibilityProvider.notifier).soloZone(z.id!),
      onFollow: () => Navigator.pop(context, MarkerChoice.followZone(z)),
    );
  }


  Widget _row({
    required bool visible,
    required Color colour,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onToggle,
    required VoidCallback onIsolate,
    required VoidCallback onFollow,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: visible
                ? colour.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Opacity(
        opacity: visible ? 1 : 0.45,
        child: ListTile(
          onTap: onToggle,
          leading: Icon(icon, color: colour, size: 22),
          title: Text(title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: Text(subtitle,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: visible ? 'Hide' : 'Show',
                icon: Icon(visible ? Icons.visibility : Icons.visibility_off,
                    color: visible ? AppColors.accent : AppColors.textMuted,
                    size: 20),
                onPressed: onToggle,
              ),
              IconButton(
                tooltip: 'Show only this',
                icon: const Icon(Icons.filter_center_focus,
                    color: AppColors.textSecondary, size: 20),
                onPressed: onIsolate,
              ),
              IconButton(
                tooltip: 'Follow',
                icon: const Icon(Icons.near_me,
                    color: AppColors.statusGreen, size: 20),
                onPressed: onFollow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
