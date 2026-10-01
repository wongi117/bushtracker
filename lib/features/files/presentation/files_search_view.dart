import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/utils/geo_geometry.dart';
import 'package:bush_track/features/files/providers/files_provider.dart';
import 'package:bush_track/features/files/services/field_search.dart';
import 'package:bush_track/features/geofence/providers/geofence_provider.dart';
import 'package:bush_track/features/map/providers/trail_provider.dart';
import 'package:bush_track/features/map/widgets/pinage_viewer.dart';
import 'package:bush_track/features/map/widgets/waypoint_editor.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/theme/app_colors.dart';

/// Search across everything in Files, offline.
///
/// Sits above the file list and takes over the body once there is something to
/// search for. Everything is matched over lists already in memory — no index,
/// no database round trip, no network — because this app is for places with no
/// signal, and a search that needs a server is one that fails where it is
/// needed. See field_search.dart for the scoring.
class FilesSearchView extends ConsumerStatefulWidget {
  const FilesSearchView({
    super.key,
    required this.onShowOnMap,
    required this.idle,
  });

  /// Hand a position back to the map. The Files screen pops a LatLng up to the
  /// dashboard, which moves the map there.
  final void Function(LatLng) onShowOnMap;

  /// What to show when nothing has been typed — the ordinary file list.
  ///
  /// Passed in rather than the Files screen deciding, because whether there is
  /// a query is this widget's state, and reaching into it from outside means
  /// reading state during someone else's build and not rebuilding when it
  /// changes.
  final Widget idle;

  @override
  ConsumerState<FilesSearchView> createState() => FilesSearchViewState();
}

class FilesSearchViewState extends ConsumerState<FilesSearchView> {
  final _controller = TextEditingController();
  String _query = '';

  /// Null means every kind.
  SearchKind? _kind;
  SearchSort _sort = SearchSort.relevance;

  bool get hasQuery => _query.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hits = hasQuery ? _search() : const <SearchHit>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _controller,
            // Results update on every keystroke; there is nothing to submit.
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search pins, zones, tracks, notes…',
              hintStyle:
                  const TextStyle(color: AppColors.textMuted, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textMuted, size: 20),
              suffixIcon: hasQuery
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.textMuted, size: 18),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.panelLight,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
        ),
        if (!hasQuery) Expanded(child: widget.idle),
        if (hasQuery) ...[
          _kindChips(hits),
          _sortRow(hits.length),
          Expanded(
            child: hits.isEmpty
                ? _nothingFound()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: hits.length,
                    itemBuilder: (_, i) => _resultRow(hits[i]),
                  ),
          ),
        ],
      ],
    );
  }

  // ── Searching ──────────────────────────────────────────────────────────────

  List<SearchHit> _search() {
    final q = _query.trim();
    final hits = <SearchHit>[];

    final waypoints = ref.watch(locationProvider).waypoints;
    for (final w in waypoints) {
      if (w.id == null) continue;
      // Track points are machinery, not something anyone searches for.
      if (w.isPin != true && w.type != WaypointType.manual) continue;

      final scored = FieldSearch.scoreFields(q, {
        'name': w.label,
        'notes': w.notes,
        'weather': w.weatherConditions,
      });
      if (scored.score == 0) continue;

      hits.add(SearchHit(
        kind: w.isPin == true ? SearchKind.pin : SearchKind.waypoint,
        id: w.id!,
        title: w.label ?? 'Pin',
        subtitle: w.notes,
        position: (w.latitude != null && w.longitude != null)
            ? LatLng(w.latitude!, w.longitude!)
            : null,
        colorHex: w.color,
        date: w.timestamp,
        fileId: w.fileId,
        score: scored.score,
        matchedField: scored.field,
      ));
    }

    for (final z in ref.watch(geofenceProvider).geofences) {
      if (z.id == null) continue;
      final scored = FieldSearch.scoreFields(q, {
        'name': z.name,
        'notes': z.notes,
        'category': z.category.label,
      });
      if (scored.score == 0) continue;

      hits.add(SearchHit(
        kind: SearchKind.boundary,
        id: z.id!,
        title: z.name,
        subtitle: z.notes ?? z.category.label,
        position: z.centre,
        date: null,
        fileId: z.fileId,
        score: scored.score,
        matchedField: scored.field,
      ));
    }

    for (final t in ref.watch(trailProvider).trails) {
      if (t.id == null) continue;
      final scored = FieldSearch.scoreFields(q, {
        'name': t.name,
        'description': t.description,
        'difficulty': t.difficulty,
      });
      if (scored.score == 0) continue;

      hits.add(SearchHit(
        kind: SearchKind.track,
        id: t.id!,
        title: t.name ?? 'Track',
        subtitle: t.description,
        colorHex: t.color,
        date: t.createdAt,
        fileId: t.fileId,
        score: scored.score,
        matchedField: scored.field,
      ));
    }

    final filesState = ref.watch(filesProvider);
    for (final f in filesState.files) {
      if (f.id == null) continue;
      final scored = FieldSearch.scoreFields(q, {
        'name': f.name,
        'description': f.description,
      });
      if (scored.score == 0) continue;

      hits.add(SearchHit(
        kind: SearchKind.file,
        id: f.id!,
        title: f.name,
        subtitle: f.description,
        position: f.position,
        date: f.createdAt,
        fileId: f.id,
        score: scored.score,
        matchedField: scored.field,
      ));
    }

    // Notes for whichever file is being looked at are the only ones loaded; the
    // rest are not in memory, so they cannot be searched without a read. Said
    // plainly in the empty state rather than pretended otherwise.
    for (final n in filesState.notes) {
      if (n.id == null) continue;
      final scored = FieldSearch.scoreFields(q, {'note': n.body});
      if (scored.score == 0) continue;

      hits.add(SearchHit(
        kind: SearchKind.note,
        id: n.id!,
        title: n.body.split('\n').first,
        subtitle: 'Note',
        fileId: n.fileId,
        score: scored.score,
        matchedField: scored.field,
      ));
    }

    final filtered =
        _kind == null ? hits : hits.where((h) => h.kind == _kind).toList();

    final stats = ref.watch(locationProvider).stats;
    final here = stats.currentLat == null
        ? null
        : LatLng(stats.currentLat!, stats.currentLon!);

    return FieldSearch.sortHits(filtered, _sort, from: here);
  }

  // ── Chrome ─────────────────────────────────────────────────────────────────

  Widget _kindChips(List<SearchHit> all) {
    // Counted before the kind filter is applied, so the numbers do not vanish
    // the moment one is chosen.
    final counts = <SearchKind, int>{};
    for (final h in all) {
      counts[h.kind] = (counts[h.kind] ?? 0) + 1;
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _chip('All', _kind == null, () => setState(() => _kind = null)),
          for (final k in SearchKind.values)
            if ((counts[k] ?? 0) > 0 || _kind == k)
              _chip('${k.plural} ${counts[k] ?? 0}', _kind == k,
                  () => setState(() => _kind = _kind == k ? null : k)),
        ],
      ),
    );
  }

  Widget _sortRow(int count) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
        child: Row(children: [
          Text('$count result${count == 1 ? '' : 's'}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          const Spacer(),
          const Icon(Icons.sort, color: AppColors.textMuted, size: 15),
          const SizedBox(width: 6),
          DropdownButton<SearchSort>(
            value: _sort,
            isDense: true,
            underline: const SizedBox.shrink(),
            dropdownColor: AppColors.panelMatte,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            onChanged: (v) => setState(() => _sort = v ?? SearchSort.relevance),
            items: const [
              DropdownMenuItem(
                  value: SearchSort.relevance, child: Text('Best match')),
              DropdownMenuItem(value: SearchSort.name, child: Text('Name')),
              DropdownMenuItem(value: SearchSort.date, child: Text('Newest')),
              DropdownMenuItem(
                  value: SearchSort.distance, child: Text('Nearest')),
            ],
          ),
        ]),
      );

  Widget _chip(String text, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : AppColors.panelMatte,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: selected ? AppColors.accent : AppColors.panelHighlight),
            ),
            child: Text(text,
                style: TextStyle(
                    color: selected ? Colors.black : AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      );

  Widget _nothingFound() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off,
                  color: Colors.white12, size: 44),
              const SizedBox(height: 12),
              Text('Nothing matches "${_query.trim()}".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 6),
              const Text(
                'Names, notes and descriptions are searched. Notes inside a '
                'project are searched once that project has been opened.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      );

  Widget _resultRow(SearchHit hit) {
    final colour = hit.colorHex != null
        ? WaypointColors.fromHex(hit.colorHex)
        : AppColors.accent;

    final stats = ref.watch(locationProvider).stats;
    final here = stats.currentLat == null
        ? null
        : LatLng(stats.currentLat!, stats.currentLon!);
    final away = (here != null && hit.position != null)
        ? formatDistance(const Distance()(here, hit.position!))
        : null;

    // Say why a result is in the list when the name does not explain it.
    final because = (hit.matchedField != null && hit.matchedField != 'name')
        ? 'matched ${hit.matchedField}'
        : null;
    final sub = [
      hit.kind.label,
      if (away != null) '$away away',
      if (because != null) because,
    ].join('  ·  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: ListTile(
        dense: true,
        onTap: () => _openDetail(hit),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colour.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_iconFor(hit.kind), color: colour, size: 17),
        ),
        title: Text(hit.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13.5)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sub,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 10.5)),
            if (hit.subtitle != null && hit.subtitle!.trim().isNotEmpty)
              Text(hit.subtitle!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
          ],
        ),
        trailing: hit.position == null
            ? null
            : IconButton(
                tooltip: 'Show on map',
                icon: const Icon(Icons.map_outlined,
                    color: AppColors.accent, size: 19),
                onPressed: () => widget.onShowOnMap(hit.position!),
              ),
      ),
    );
  }

  IconData _iconFor(SearchKind kind) => switch (kind) {
        SearchKind.pin => Icons.location_on,
        SearchKind.waypoint => Icons.place_outlined,
        SearchKind.boundary => Icons.pentagon_outlined,
        SearchKind.track => Icons.route_outlined,
        SearchKind.file => Icons.folder_rounded,
        SearchKind.note => Icons.description_outlined,
      };

  Future<void> _openDetail(SearchHit hit) async {
    switch (hit.kind) {
      case SearchKind.pin:
      case SearchKind.waypoint:
        final waypoints = ref.read(locationProvider).waypoints;
        final match = waypoints.where((w) => w.id == hit.id).toList();
        if (match.isEmpty) return;
        final wp = match.first;
        showPinageViewer(
          context,
          waypoint: wp,
          onEdit: () => showWaypointEditor(context, waypoint: wp),
          onDelete: () =>
              ref.read(locationProvider.notifier).deleteWaypoint(wp.id!),
          onJumpToMap: hit.position == null
              ? null
              : () => widget.onShowOnMap(hit.position!),
        );
      case SearchKind.boundary:
      case SearchKind.track:
      case SearchKind.file:
      case SearchKind.note:
        // These have no sheet of their own yet. The map is the useful thing to
        // do with them, and the row's map button says so too.
        if (hit.position != null) widget.onShowOnMap(hit.position!);
    }
  }
}
