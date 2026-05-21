import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/core/services/gpx_service.dart';
import 'package:bush_track/core/utils/web_helpers.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/features/map/providers/trail_provider.dart';

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  bool _busy = false;
  String? _lastMessage;
  bool _lastSuccess = true;

  void _setMsg(String msg, {bool success = true}) =>
      setState(() { _lastMessage = msg; _lastSuccess = success; });

  // ── IMPORT ─────────────────────────────────────────────────────────────────

  Future<void> _importFile() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx', 'kml'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) { _setMsg('Could not read file bytes.', success: false); return; }

      final content = utf8.decode(bytes, allowMalformed: true);
      final ext = (file.extension ?? '').toLowerCase();

      final waypoints = ext == 'kml'
          ? GPXService.parseKML(content)
          : GPXService.parseGPX(content);

      int imported = 0;
      final locationNotifier = ref.read(locationProvider.notifier);
      for (final w in waypoints) {
        if (w.latitude == null || w.longitude == null) continue;
        await locationNotifier.addManualWaypoint(
          w.latitude!,
          w.longitude!,
          w.label ?? 'Imported',
          notes: w.notes,
        );
        imported++;
      }

      final trackPoints = ext == 'kml'
          ? GPXService.parseKMLTrack(content)
          : GPXService.parseTrack(content);

      String trailMsg = '';
      if (trackPoints.length >= 2) {
        final trailNotifier = ref.read(trailProvider.notifier);
        trailNotifier.startCreatingTrail();
        for (final pt in trackPoints) { trailNotifier.addDraftPoint(pt); }
        await trailNotifier.saveDraftTrail(name: 'Imported: ${file.name}');
        trailMsg = '\nTrail imported: ${trackPoints.length} points.';
      }

      if (imported == 0 && trailMsg.isEmpty) {
        _setMsg('No waypoints or tracks found in file.', success: false);
      } else {
        _setMsg('Imported $imported waypoint(s).$trailMsg');
      }
    } catch (e) {
      _setMsg('Import failed: $e', success: false);
    } finally {
      setState(() => _busy = false);
    }
  }

  // ── EXPORT ─────────────────────────────────────────────────────────────────

  Future<void> _export({required bool kml}) async {
    setState(() => _busy = true);
    try {
      final locationState = ref.read(locationProvider);
      final trailState = ref.read(trailProvider);
      final ext = kml ? 'kml' : 'gpx';

      final wpContent = kml
          ? GPXService.exportWaypointsKML(locationState.waypoints)
          : GPXService.exportWaypoints(locationState.waypoints);

      final wpFilename = 'bushtrack_waypoints_${_ts()}.$ext';
      await downloadBytes(wpFilename, utf8.encode(wpContent));

      String trailMsg = '';
      if (trailState.trails.isNotEmpty) {
        final trail = trailState.trails.first;
        final trailContent =
            kml ? GPXService.exportTrailKML(trail) : GPXService.exportTrail(trail);
        final trailFilename = 'bushtrack_trail_${_ts()}.$ext';
        await downloadBytes(trailFilename, utf8.encode(trailContent));
        trailMsg = '\nTrail exported as $trailFilename.';
      }

      _setMsg('Saved $wpFilename.$trailMsg');
    } catch (e) {
      _setMsg('Export failed: $e', success: false);
    } finally {
      setState(() => _busy = false);
    }
  }

  String _ts() => DateTime.now().millisecondsSinceEpoch.toString();

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.panelMatte,
        title: const Row(children: [
          Icon(Icons.import_export, color: AppColors.accent, size: 20),
          SizedBox(width: 8),
          Text('GPX / KML', style: TextStyle(color: Colors.white)),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('Import'),
          const SizedBox(height: 12),
          _tile(
            icon: Icons.upload_file,
            title: 'Import GPX or KML',
            subtitle: 'Pick a .gpx or .kml file — waypoints and tracks are loaded onto the map',
            onTap: _busy ? null : _importFile,
          ),
          const SizedBox(height: 24),
          _sectionTitle('Export'),
          const SizedBox(height: 12),
          _tile(
            icon: Icons.download,
            title: 'Export as GPX',
            subtitle: 'All waypoints in GPS Exchange Format',
            onTap: _busy ? null : () => _export(kml: false),
          ),
          const SizedBox(height: 12),
          _tile(
            icon: Icons.download,
            title: 'Export as KML',
            subtitle: 'All waypoints in Keyhole Markup Language (Google Earth)',
            onTap: _busy ? null : () => _export(kml: true),
          ),
          if (_lastMessage != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_lastSuccess ? AppColors.statusGreen : AppColors.statusRed)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_lastSuccess ? AppColors.statusGreen : AppColors.statusRed)
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Row(children: [
                Icon(
                  _lastSuccess ? Icons.check_circle : Icons.error_outline,
                  color: _lastSuccess ? AppColors.statusGreen : AppColors.statusRed,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(_lastMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 13))),
              ]),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: AppColors.panelMatte,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.2)),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppColors.accent, size: 22),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(subtitle,
              style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 12)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          onTap: onTap,
        ),
      );
}
