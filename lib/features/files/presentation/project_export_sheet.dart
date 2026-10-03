import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/core/models/photo_paths_codec.dart';
import 'package:bush_track/core/models/trail.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/services/gpx_service.dart';
import 'package:bush_track/core/services/photo_file_store.dart';
import 'package:bush_track/core/services/project_export.dart';
import 'package:bush_track/core/widgets/safe_sheet.dart';
import 'package:bush_track/theme/app_colors.dart';

/// Get a project off the phone.
///
/// Shared rather than written to the app's documents directory. A file in there
/// is unreachable on Android -- no file manager can see it -- so "exported"
/// would mean "saved somewhere you cannot get to it", which is what the older
/// GPX export does. Sharing hands it to email, Drive or a message, which is how
/// data actually leaves a field phone.
Future<void> showProjectExportSheet(
  BuildContext context, {
  required FieldFile file,
  required List<Waypoint> pins,
  required List<Geofence> zones,
  required List<Trail> trails,
  VoidCallback? onShareSummary,
}) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProjectExportSheet(
        file: file,
        pins: pins,
        zones: zones,
        trails: trails,
        onShareSummary: onShareSummary,
      ),
    );

class _ProjectExportSheet extends ConsumerStatefulWidget {
  const _ProjectExportSheet({
    required this.file,
    required this.pins,
    required this.zones,
    required this.trails,
    this.onShareSummary,
  });

  final FieldFile file;
  final List<Waypoint> pins;
  final List<Geofence> zones;
  final List<Trail> trails;

  /// Shares a readable plain-text summary.
  ///
  /// Kept alongside the file formats rather than replaced by them: a summary
  /// pasted into the body of a message is a different job from an attachment,
  /// and this is what the share button did before. Dropping it as a side
  /// effect of adding export would be a quiet regression.
  final VoidCallback? onShareSummary;

  @override
  ConsumerState<_ProjectExportSheet> createState() =>
      _ProjectExportSheetState();
}

class _ProjectExportSheetState extends ConsumerState<_ProjectExportSheet> {
  String? _busy;
  String? _error;

  /// Every photo reference held by the pins being exported.
  List<String> get _photoRefs => [
        for (final p in widget.pins)
          ...?PhotoPathsCodec.decode(p.photoPaths),
      ];

  Future<Directory> _stagingDir() async {
    // The temp directory, not documents: these files exist to be handed to
    // another app and are rubbish afterwards. Writing them into documents
    // would grow the app's storage with every export and never clean up.
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/export');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _exportData(ExportFormat format) async {
    setState(() {
      _busy = format.label;
      _error = null;
    });

    try {
      final content = switch (format) {
        ExportFormat.geoJson => ProjectExport.geoJson(
            projectName: widget.file.name,
            pins: widget.pins,
            zones: widget.zones,
            trails: widget.trails,
          ),
        // Reusing GPXService rather than writing a second XML writer. It takes
        // waypoints only, so zones go in as their centre points for GPX -- the
        // format has no polygon at all, which the picker says out loud.
        ExportFormat.gpx => GPXService.exportWaypoints(_pinsWithZonePoints()),
        ExportFormat.kml => GPXService.exportWaypointsKML(_pinsWithZonePoints()),
      };

      final dir = await _stagingDir();
      final name = ProjectExport.fileName(widget.file.name, format);
      final out = File('${dir.path}/$name');
      await out.writeAsBytes(utf8.encode(content));

      // Checked, rather than trusted. The older export helper swallows every
      // write error and still reports success, which on a full phone means
      // being told the data is safe when nothing was written.
      if (!await out.exists() || await out.length() == 0) {
        throw const FileSystemException('the file came out empty');
      }

      await _share(out, 'Project ${widget.file.name}');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
      return;
    } finally {
      if (mounted) setState(() => _busy = null);
    }

    if (mounted) Navigator.pop(context);
  }

  /// Zones as waypoints, for the formats that cannot hold an area.
  ///
  /// Their shape is lost -- that is what [ExportFormat.keepsZoneShape] is
  /// warning about -- but a boundary's centre and name is still better than
  /// the boundary being left out of the file with nothing said.
  List<Waypoint> _pinsWithZonePoints() => [
        ...widget.pins,
        for (final z in widget.zones)
          Waypoint(
            label: '${z.name} (boundary centre)',
            latitude: z.latitude,
            longitude: z.longitude,
            notes: 'Boundary, ${z.radiusMeters.round()} m nominal radius. '
                'Shape not supported by this format.',
            isPin: true,
          ),
      ];

  Future<void> _exportPhotos() async {
    final refs = _photoRefs;
    if (refs.isEmpty) return;

    setState(() {
      _busy = 'Photos';
      _error = null;
    });

    try {
      final store = PhotoFileStore();
      final archive = Archive();
      var added = 0;
      var missing = 0;

      // Deduplicated: two pins can point at the same photo, and a zip with the
      // same name twice in it is a file some tools refuse to open.
      for (final ref in refs.toSet()) {
        final bytes = await store.read(ref);
        if (bytes == null) {
          missing++;
          continue;
        }
        final entryName = ref.split(RegExp(r'[\\/]')).last;
        archive.addFile(
            ArchiveFile(entryName, bytes.length, bytes));
        added++;
      }

      if (added == 0) {
        throw const FileSystemException(
            'none of the photos could be read from disk');
      }

      final zipped = ZipEncoder().encode(archive);
      final dir = await _stagingDir();
      final base = ProjectExport.fileName(widget.file.name, ExportFormat.gpx)
          .replaceAll('.gpx', '');
      final out = File('${dir.path}/${base}_photos.zip');
      await out.writeAsBytes(zipped);

      await _share(
        out,
        missing == 0
            ? '$added photos from ${widget.file.name}'
            // Said rather than hidden: a photo that did not make it into the
            // zip is one somebody will go looking for later.
            : '$added photos from ${widget.file.name} '
                '($missing could not be read)',
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
      return;
    } finally {
      if (mounted) setState(() => _busy = null);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _share(File file, String subject) async {
    try {
      await Share.shareXFiles([XFile(file.path)], subject: subject);
    } catch (e) {
      // The share sheet failing is not the export failing: the file is written
      // and the path is worth telling them.
      debugPrint('Share failed, file is at ${file.path}: $e');
      if (mounted) {
        setState(() => _error = 'Written to ${file.path}, but sharing failed');
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photoRefs.toSet().length;
    final working = _busy != null;

    return SafeSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetGrip(),
          const SizedBox(height: 14),
          Text('EXPORT ${widget.file.name.toUpperCase()}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1)),
          const SizedBox(height: 4),
          Text(
            '${widget.pins.length} pins, ${widget.zones.length} boundaries, '
            '${widget.trails.length} trails',
            style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontSize: 11),
          ),
          const SizedBox(height: 14),
          for (final f in ExportFormat.values)
            _option(
              icon: Icons.description_rounded,
              title: f.label,
              subtitle: f.caveat,
              warn: !f.keepsZoneShape && widget.zones.isNotEmpty,
              onTap: working ? null : () => _exportData(f),
              spinning: _busy == f.label,
            ),
          if (widget.onShareSummary != null)
            _option(
              icon: Icons.subject_rounded,
              title: 'Text summary',
              subtitle: 'Readable list, for the body of a message',
              onTap: working
                  ? null
                  : () {
                      Navigator.pop(context);
                      widget.onShareSummary!();
                    },
            ),
          if (photos > 0)
            _option(
              icon: Icons.photo_library_rounded,
              title: 'Photos',
              subtitle:
                  '$photos ${photos == 1 ? 'photo' : 'photos'} as a zip file',
              onTap: working ? null : _exportPhotos,
              spinning: _busy == 'Photos',
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Export failed: $_error',
                  style: const TextStyle(
                      color: AppColors.statusRed, fontSize: 12, height: 1.35)),
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: working ? null : () => Navigator.pop(context),
              child: const Text('CLOSE',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _option({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool warn = false,
    bool spinning = false,
  }) =>
      Opacity(
        opacity: onTap == null && !spinning ? 0.4 : 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: spinning
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent))
                      : Icon(icon, size: 19, color: AppColors.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              color: warn
                                  ? AppColors.statusYellow
                                  : AppColors.textSecondary
                                      .withValues(alpha: 0.85),
                              fontSize: 11,
                              height: 1.3)),
                    ],
                  ),
                ),
                const Icon(Icons.ios_share,
                    size: 15, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      );
}
