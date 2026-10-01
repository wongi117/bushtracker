import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/core/models/trail.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/utils/geo_geometry.dart';
import 'package:bush_track/core/utils/web_helpers.dart';
import 'package:bush_track/features/files/providers/files_provider.dart';
import 'package:bush_track/features/geofence/providers/geofence_provider.dart';
import 'package:bush_track/features/files/presentation/files_search_view.dart';
import 'package:bush_track/features/map/providers/marker_visibility_provider.dart';
import 'package:bush_track/features/map/providers/trail_provider.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/theme/app_colors.dart';

/// Every field file: one folder per job, site or trip.
class FilesScreen extends ConsumerWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(filesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.panelMatte,
        title: const Row(children: [
          Icon(Icons.folder_rounded, color: AppColors.accent, size: 20),
          SizedBox(width: 8),
          Text('FILES', style: TextStyle(color: Colors.white)),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text('NEW FILE',
            style: TextStyle(fontWeight: FontWeight.w900)),
        onPressed: () => _createFile(context, ref),
      ),
      // The search bar is always there; it takes over the body as soon as
      // there is something to search for, and gets out of the way again when
      // the field is cleared.
      body: FilesSearchView(
        onShowOnMap: (at) => Navigator.pop(context, at),
        idle: state.files.isEmpty
            ? _buildEmpty()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: state.files.length,
                itemBuilder: (_, i) => _FileTile(
                    file: state.files[i],
                    isOpen: state.files[i].id == state.activeFileId),
              ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_rounded,
                  size: 64,
                  color: AppColors.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              const Text('No files yet',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                'Make a file for a job, a site or a trip. While it is open, '
                'every note, pin and zone you make is filed under it, so you '
                'can come back later and see exactly where you worked.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 13,
                    height: 1.4),
              ),
            ],
          ),
        ),
      );

  static Future<void> _createFile(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final made = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.panelMatte,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NEW FILE',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                const Text(
                  'Everything you make while it is open gets filed here.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: Colors.white),
                  decoration: fieldDecoration(
                      'File name', 'Leonora survey, Tuesday run'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: Colors.white),
                  decoration: fieldDecoration(
                      'What is it for (optional)', 'Who it is for, what you are looking at'),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
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
                        onPressed: () => Navigator.pop(sheetContext, true),
                        child: const Text('CREATE',
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

    if (made != true) return;

    final stats = ref.read(locationProvider).stats;
    final where = stats.currentLat == null
        ? null
        : LatLng(stats.currentLat!, stats.currentLon!);
    final name = nameCtrl.text.trim();

    final file = await ref.read(filesProvider.notifier).createFile(
          // An unnamed file still needs something to find it by.
          name: name.isEmpty ? 'Untitled file' : name,
          description:
              descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          position: where,
        );

    if (file == null || !context.mounted) return;
    final goTo = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => FileDetailScreen(fileId: file.id!)),
    );
    if (goTo != null && context.mounted) Navigator.pop(context, goTo);
  }
}

class _FileTile extends ConsumerWidget {
  const _FileTile({required this.file, required this.isOpen});

  final FieldFile file;
  final bool isOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pins = ref
        .watch(locationProvider)
        .waypoints
        .where((w) => w.fileId == file.id)
        .length;
    final zones = ref
        .watch(geofenceProvider)
        .geofences
        .where((z) => z.fileId == file.id)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen
              ? AppColors.accent.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.08),
          width: isOpen ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () async {
          // A pin or zone tapped inside a file returns a position; hand it
          // straight back to the map rather than stranding the user two
          // screens deep.
          final goTo = await Navigator.push<LatLng>(
            context,
            MaterialPageRoute(
                builder: (_) => FileDetailScreen(fileId: file.id!)),
          );
          if (goTo != null && context.mounted) Navigator.pop(context, goTo);
        },
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(isOpen ? Icons.folder_open_rounded : Icons.folder_rounded,
              color: AppColors.accent, size: 20),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(file.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            if (isOpen) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('OPEN',
                    style: TextStyle(
                        color: AppColors.accentLight,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '${_formatDate(file.createdAt)}  •  $pins pins  •  $zones zones',
            style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontSize: 11),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Straight to the map, showing this project and nothing else.
            IconButton(
              tooltip: isOpen ? 'Showing this project' : 'Show only this on the map',
              icon: Icon(
                  isOpen ? Icons.visibility : Icons.visibility_outlined,
                  color: isOpen ? AppColors.accent : AppColors.textMuted,
                  size: 20),
              onPressed: () async {
                await ref
                    .read(filesProvider.notifier)
                    .setActiveFile(file.id);
                await ref
                    .read(markerVisibilityProvider.notifier)
                    .openProject(file.id!);
                if (!context.mounted) return;
                // Hand the map somewhere to go, so opening a project that was
                // made a hundred kilometres away does not look empty.
                Navigator.pop(context, file.position);
              },
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// One file: its notes, and the pins and zones collected under it.
class FileDetailScreen extends ConsumerStatefulWidget {
  const FileDetailScreen({super.key, required this.fileId});

  final int fileId;

  @override
  ConsumerState<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends ConsumerState<FileDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Notes live in the database rather than in the list state, so they are
    // fetched when the file is actually opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(filesProvider.notifier).loadNotes(widget.fileId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(filesProvider);
    final matches = state.files.where((f) => f.id == widget.fileId);
    if (matches.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: Text('File not found',
                style: TextStyle(color: AppColors.textSecondary))),
      );
    }
    final file = matches.first;
    final isOpen = state.activeFileId == file.id;
    final notes = state.viewingFileId == file.id ? state.notes : const <FileNote>[];

    final pins = ref
        .watch(locationProvider)
        .waypoints
        .where((w) => w.fileId == file.id)
        .toList();
    final zones = ref
        .watch(geofenceProvider)
        .geofences
        .where((z) => z.fileId == file.id)
        .toList();
    final trails = ref
        .watch(trailProvider)
        .trails
        .where((t) => t.fileId == file.id)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.panelMatte,
        title: Text(file.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_rounded,
                color: AppColors.accent),
            tooltip: 'Add existing pins and zones',
            onPressed: () => _collectInto(file),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share, color: AppColors.accent),
            tooltip: 'Share this file',
            onPressed: () => _share(file, notes, pins, zones),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.statusRed),
            tooltip: 'Delete this file',
            onPressed: () => _confirmDelete(file),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.note_add_rounded),
        label: const Text('ADD NOTE',
            style: TextStyle(fontWeight: FontWeight.w900)),
        onPressed: () => _addNote(file),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (file.description != null && file.description!.isNotEmpty) ...[
            Text(file.description!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: 14),
          ],
          _openSwitch(file, isOpen),
          const SizedBox(height: 18),
          _counts(pins, zones, trails, notes.length),
          const SizedBox(height: 18),
          const Text('NOTES',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          if (notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No notes yet. Tap ADD NOTE to write one — it is saved with '
                'the time and the spot you wrote it.',
                style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 13,
                    height: 1.4),
              ),
            )
          else
            ...notes.map((n) => _noteTile(file, n)),
          if (pins.isNotEmpty) ...[
            const SizedBox(height: 18),
            _sectionLabel('PINS'),
            ...pins.map((p) => _itemTile(
                  icon: Icons.location_on,
                  title: p.label ?? 'Pin',
                  detail: p.latitude == null
                      ? 'No position'
                      : '${p.latitude!.toStringAsFixed(5)}, ${p.longitude!.toStringAsFixed(5)}',
                  goTo: p.latitude == null
                      ? null
                      : LatLng(p.latitude!, p.longitude!),
                )),
          ],
          if (zones.isNotEmpty) ...[
            const SizedBox(height: 18),
            _sectionLabel('ZONES'),
            ...zones.map((z) => _itemTile(
                  icon: z.isPolygon
                      ? Icons.pentagon_outlined
                      : Icons.circle_outlined,
                  colour: Color(z.category.colorValue),
                  title: z.name,
                  detail:
                      '${z.category.label}  •  ${formatArea(z.areaSqMetres)}',
                  goTo: z.centre,
                )),
          ],
          if (trails.isNotEmpty) ...[
            const SizedBox(height: 18),
            _sectionLabel('TRAILS'),
            ...trails.map((t) {
              final points = t.getWaypoints();
              return _itemTile(
                icon: Icons.route,
                title: t.name ?? 'Trail',
                detail: t.totalDistance == null
                    ? '${points.length} points'
                    : '${formatDistance(t.totalDistance!)}  •  ${points.length} points',
                goTo: points.isEmpty ? null : points.first,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      );

  /// One collected thing. Tapping it hands the position back up to the map,
  /// which is two screens away, so the user does not have to find it again.
  Widget _itemTile({
    required IconData icon,
    required String title,
    required String detail,
    LatLng? goTo,
    Color colour = AppColors.accent,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.panelMatte,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: ListTile(
          dense: true,
          onTap: goTo == null ? null : () => Navigator.pop(context, goTo),
          leading: Icon(icon, color: colour, size: 20),
          title: Text(title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          subtitle: Text(detail,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          trailing: goTo == null
              ? null
              : const Icon(Icons.my_location,
                  color: AppColors.textMuted, size: 16),
        ),
      );

  /// Open or close the project.
  ///
  /// Deliberately one switch doing two things, because "working in this
  /// project" is one idea: new pins and zones are filed here, and the map and
  /// camera show this project instead of every pin ever dropped in the same
  /// paddock. Splitting it into two toggles in two places would mean the common
  /// case takes two actions and can be left half done.
  ///
  /// The view can still be widened on its own from Show & Follow without
  /// changing where new work is filed, which is why the subtitle reports the two
  /// separately when they disagree.
  Widget _openSwitch(FieldFile file, bool isOpen) {
    final scoped = ref.watch(markerVisibilityProvider).scopeFileId == file.id;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isOpen
                ? AppColors.accent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.08)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: isOpen,
        activeThumbColor: AppColors.accent,
        title: const Text('Work in this project',
            style: TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Text(
          !isOpen
              ? 'Turn on to file new pins and zones here, and show only this '
                  'project on the map'
              : scoped
                  ? 'New pins and zones are filed here, and the map and camera '
                      'are showing this project only'
                  : 'New pins and zones are filed here. The map is showing all '
                      'work — narrow it again from Show & Follow.',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 11),
        ),
        onChanged: (on) => _setOpen(file, on),
      ),
    );
  }

  Future<void> _setOpen(FieldFile file, bool on) async {
    await ref.read(filesProvider.notifier).setActiveFile(on ? file.id : null);
    final visibility = ref.read(markerVisibilityProvider.notifier);
    if (on) {
      await visibility.openProject(file.id!);
    } else {
      await visibility.closeProject();
    }
  }

  Widget _counts(List<Waypoint> pins, List<Geofence> zones,
          List<Trail> trails, int noteCount) =>
      Row(
        children: [
          _countCard(Icons.description_outlined, '$noteCount',
              noteCount == 1 ? 'note' : 'notes'),
          const SizedBox(width: 8),
          _countCard(Icons.location_on, '${pins.length}',
              pins.length == 1 ? 'pin' : 'pins'),
          const SizedBox(width: 8),
          _countCard(Icons.layers_outlined, '${zones.length}',
              zones.length == 1 ? 'zone' : 'zones'),
          const SizedBox(width: 8),
          _countCard(Icons.route, '${trails.length}',
              trails.length == 1 ? 'trail' : 'trails'),
        ],
      );

  Widget _countCard(IconData icon, String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.panelMatte,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.accent, size: 18),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      );

  Widget _noteTile(FieldFile file, FileNote note) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.panelMatte,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note.body,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.4)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_formatDateTime(note.createdAt)}'
                    '${note.position == null ? '' : '  •  ${note.position!.latitude.toStringAsFixed(5)}, ${note.position!.longitude.toStringAsFixed(5)}'}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
                GestureDetector(
                  onTap: () => ref
                      .read(filesProvider.notifier)
                      .deleteNote(note.id!, file.id!),
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.textMuted, size: 18),
                ),
              ],
            ),
          ],
        ),
      );

  Future<void> _addNote(FieldFile file) async {
    final controller = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.panelMatte,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NOTE IN ${file.name.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                const Text('Saved with the time and where you are now.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: Colors.white),
                  decoration: fieldDecoration('Note',
                      'What you found, what needs doing, who to tell'),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
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
                        onPressed: () => Navigator.pop(sheetContext, true),
                        child: const Text('SAVE NOTE',
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

    if (saved != true) return;
    final body = controller.text.trim();
    if (body.isEmpty) return;

    final stats = ref.read(locationProvider).stats;
    await ref.read(filesProvider.notifier).addNote(
          fileId: file.id!,
          body: body,
          position: stats.currentLat == null
              ? null
              : LatLng(stats.currentLat!, stats.currentLon!),
        );
  }

  Future<void> _share(FieldFile file, List<FileNote> notes,
      List<Waypoint> pins, List<Geofence> zones) async {
    final buffer = StringBuffer()
      ..writeln(file.name)
      ..writeln('Started ${_formatDateTime(file.createdAt)}');
    if (file.position != null) {
      buffer.writeln(
          'At ${file.position!.latitude.toStringAsFixed(5)}, ${file.position!.longitude.toStringAsFixed(5)}');
    }
    if (file.description != null && file.description!.isNotEmpty) {
      buffer.writeln(file.description);
    }

    if (notes.isNotEmpty) {
      buffer.writeln('\nNOTES');
      for (final n in notes) {
        buffer.writeln('- ${_formatDateTime(n.createdAt)}: ${n.body}');
        if (n.position != null) {
          buffer.writeln(
              '  at ${n.position!.latitude.toStringAsFixed(5)}, ${n.position!.longitude.toStringAsFixed(5)}');
        }
      }
    }

    if (pins.isNotEmpty) {
      buffer.writeln('\nPINS');
      for (final p in pins) {
        buffer.writeln(
            '- ${p.label ?? 'Pin'}: ${p.latitude?.toStringAsFixed(5)}, ${p.longitude?.toStringAsFixed(5)}');
      }
    }

    if (zones.isNotEmpty) {
      buffer.writeln('\nZONES');
      for (final z in zones) {
        buffer.writeln(
            '- ${z.name} (${z.category.label}, ${formatArea(z.areaSqMetres)})'
            ' at ${z.latitude.toStringAsFixed(5)}, ${z.longitude.toStringAsFixed(5)}');
      }
    }

    await shareText(file.name, buffer.toString());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('File shared'),
      backgroundColor: AppColors.statusGreen,
    ));
  }

  /// Gather work that already exists into this project.
  ///
  /// Needed because projects usually get made after the fact: you drop pins all
  /// morning and only then decide they belong together. Without this, "add the
  /// pins to it" would mean walking back and dropping them again.
  ///
  /// Shows everything not already in this project, including work filed
  /// elsewhere, with where it currently sits spelled out — moving a pin out of
  /// another project is a real change and should not happen by surprise.
  Future<void> _collectInto(FieldFile file) async {
    final pins = ref
        .read(locationProvider)
        .waypoints
        .where((w) => w.isPin == true && w.id != null && w.fileId != file.id)
        .toList();
    final zones = ref
        .read(geofenceProvider)
        .geofences
        .where((z) => z.id != null && z.fileId != file.id)
        .toList();

    if (pins.isEmpty && zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Everything you have is already in this project.'),
      ));
      return;
    }

    final pickedPins = <int>{};
    final pickedZones = <int>{};

    final files = ref.read(filesProvider).files;
    String whereItIs(int? fileId) {
      if (fileId == null) return 'not in a project';
      final match = files.where((f) => f.id == fileId).toList();
      return match.isEmpty ? 'in another project' : 'in ${match.first.name}';
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.8),
          decoration: const BoxDecoration(
            color: AppColors.panelMatte,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
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
              const SizedBox(height: 14),
              Text('ADD TO ${file.name.toUpperCase()}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.8)),
              const SizedBox(height: 4),
              const Text('Tick what belongs in this project.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in pins)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.accent,
                        checkColor: Colors.black,
                        value: pickedPins.contains(p.id),
                        onChanged: (on) => setSheetState(() => on == true
                            ? pickedPins.add(p.id!)
                            : pickedPins.remove(p.id)),
                        title: Row(children: [
                          Icon(Icons.location_on,
                              size: 15,
                              color: WaypointColors.fromHex(p.color)),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(p.label ?? 'Pin',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          ),
                        ]),
                        subtitle: Text(whereItIs(p.fileId),
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 10)),
                      ),
                    for (final z in zones)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.accent,
                        checkColor: Colors.black,
                        value: pickedZones.contains(z.id),
                        onChanged: (on) => setSheetState(() => on == true
                            ? pickedZones.add(z.id!)
                            : pickedZones.remove(z.id)),
                        title: Row(children: [
                          Icon(
                              z.isPolygon
                                  ? Icons.pentagon_outlined
                                  : Icons.circle_outlined,
                              size: 15,
                              color: Color(z.category.colorValue)),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(z.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          ),
                        ]),
                        subtitle: Text(whereItIs(z.fileId),
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 10)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
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
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: (pickedPins.isEmpty && pickedZones.isEmpty)
                        ? null
                        : () => Navigator.pop(sheetContext, true),
                    child: Text(
                        'ADD ${pickedPins.length + pickedZones.length}',
                        style:
                            const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    for (final id in pickedPins) {
      await ref.read(locationProvider.notifier).setWaypointFile(id, file.id);
    }
    for (final id in pickedZones) {
      final zone = zones.firstWhere((z) => z.id == id);
      await ref
          .read(geofenceProvider.notifier)
          .updateZone(zone.copyWith(fileId: file.id));
    }

    if (!mounted) return;
    final n = pickedPins.length + pickedZones.length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$n ${n == 1 ? 'item' : 'items'} added to ${file.name}'),
    ));
  }

  Future<void> _confirmDelete(FieldFile file) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelMatte,
        title:
            const Text('Delete file', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${file.name}" and its notes?\n\n'
          'Pins and zones you collected stay on the map — they just stop '
          'being filed under it.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.statusRed)),
          ),
        ],
      ),
    );

    if (yes != true) return;
    // Order matters: drop the scope first, or for an instant the map is
    // filtered to a project that no longer exists and shows nothing at all.
    await ref.read(markerVisibilityProvider.notifier).forgetProject(file.id!);
    await ref.read(filesProvider.notifier).deleteFile(file.id!);
    if (mounted) Navigator.pop(context);
  }
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _formatDateTime(DateTime d) =>
    '${_formatDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Shared field styling, so the files sheets match the zone sheets.
InputDecoration fieldDecoration(String label, String hint) => InputDecoration(
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
