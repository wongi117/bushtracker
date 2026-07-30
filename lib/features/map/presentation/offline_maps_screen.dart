import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/features/map/services/offline_map_manager.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/theme/app_colors.dart';

// ─── Zoom presets ─────────────────────────────────────────────────────────────

class _ZoomPreset {
  final String label;
  final String subtitle;
  final int minZoom;
  final int maxZoom;
  const _ZoomPreset(this.label, this.subtitle, this.minZoom, this.maxZoom);
}

const _presets = [
  _ZoomPreset('Overview', 'Country/State', 6, 12),
  _ZoomPreset('Navigation', 'City/Roads', 12, 16),
  _ZoomPreset('Trail', 'Trail/Property', 15, 19),
  _ZoomPreset('Max Detail', 'Street level', 8, 20),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class OfflineMapsScreen extends ConsumerStatefulWidget {
  const OfflineMapsScreen({super.key});

  @override
  ConsumerState<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends ConsumerState<OfflineMapsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _manager = OfflineMapManager();
  final _mapController = MapController();

  int _presetIndex = 1;
  MapStyle _style = MapStyle.streets;
  String _regionName = '';
  bool _downloading = false;
  LatLngBounds? _selectedBounds;
  SizeEstimate? _estimate;
  StreamSubscription<DownloadProgress>? _progressSub;
  final Map<String, DownloadProgress> _progress = {};
  int _totalStorageBytes = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _manager.initialize().then((_) {
      _refreshStorage();
      if (mounted) setState(() {});
    });
    _progressSub = _manager.downloadProgress.listen((p) {
      if (!mounted) return;
      setState(() => _progress[p.regionId] = p);
      if (p.status == DownloadStatus.completed || p.status == DownloadStatus.failed) {
        _refreshStorage();
      }
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refreshStorage() async {
    final bytes = await _manager.totalStorageBytes();
    if (mounted) setState(() => _totalStorageBytes = bytes);
  }

  void _onMapReady() {
    _updateBoundsFromCamera();
  }

  void _updateBoundsFromCamera() {
    try {
      final bounds = _mapController.camera.visibleBounds;
      setState(() {
        _selectedBounds = bounds;
        _recalcEstimate();
      });
    } catch (_) {}
  }

  void _recalcEstimate() {
    if (_selectedBounds == null) return;
    final p = _presets[_presetIndex];
    setState(() {
      _estimate = _manager.estimate(_selectedBounds!, p.minZoom, p.maxZoom, _style);
    });
  }

  Future<void> _startDownload() async {
    if (_selectedBounds == null) return;
    final name = _regionName.trim().isNotEmpty
        ? _regionName.trim()
        : 'Region ${_manager.regions.length + 1}';
    final p = _presets[_presetIndex];

    setState(() => _downloading = true);
    await _manager.startDownload(
      name: name,
      bounds: _selectedBounds!,
      minZoom: p.minZoom,
      maxZoom: p.maxZoom,
      style: _style,
    );
    if (mounted) {
      setState(() => _downloading = false);
      _tabs.animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(locationProvider);
    final center = loc.stats.currentLat != null
        ? LatLng(loc.stats.currentLat!, loc.stats.currentLon!)
        : const LatLng(0, 20);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Offline Maps',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primaryOrange,
          labelColor: AppColors.primaryOrange,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(icon: Icon(Icons.download), text: 'Download'),
            Tab(icon: Icon(Icons.map), text: 'My Maps'),
          ],
        ),
      ),
      body: kIsWeb ? _buildWebUnsupported() : TabBarView(
        controller: _tabs,
        children: [
          _buildDownloadTab(center),
          _buildMyMapsTab(),
        ],
      ),
    );
  }

  Widget _buildWebUnsupported() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smartphone, size: 72, color: AppColors.primaryOrange),
            const SizedBox(height: 20),
            Text('Mobile App Required',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Offline map downloads require the native app.\nInstall BushTrack on your Samsung to download areas for use without internet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.android, color: AppColors.primaryOrange, size: 18),
                  const SizedBox(width: 10),
                  Text('Get the BushTrack APK to enable downloads',
                      style: GoogleFonts.outfit(color: AppColors.primaryOrange, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Download Tab ─────────────────────────────────────────────────────────────

  Widget _buildDownloadTab(LatLng center) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMapPreview(center),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionLabel('MAP STYLE'),
                const SizedBox(height: 8),
                _buildStyleSelector(),
                const SizedBox(height: 20),
                _sectionLabel('ZOOM LEVEL PRESET'),
                const SizedBox(height: 8),
                _buildZoomPresets(),
                const SizedBox(height: 20),
                _sectionLabel('MAP NAME (OPTIONAL)'),
                const SizedBox(height: 8),
                _buildNameField(),
                const SizedBox(height: 20),
                _buildEstimateCard(),
                const SizedBox(height: 16),
                _buildDownloadButton(),
                const SizedBox(height: 8),
                Text(
                  'The selected area visible on the map above will be downloaded.\nMove/zoom the map to set the region.',
                  style: GoogleFonts.outfit(color: Colors.white30, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview(LatLng center) {
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 10,
              maxZoom: 20,
              minZoom: 3,
              onMapReady: _onMapReady,
              onPositionChanged: (_, __) => _updateBoundsFromCamera(),
            ),
            children: [
              TileLayer(
                urlTemplate: _style.urlTemplate,
                maxZoom: 20,
              ),
              // Download region overlay
              if (_selectedBounds != null)
                PolygonLayer(polygons: [
                  Polygon(
                    points: [
                      _selectedBounds!.northWest,
                      _selectedBounds!.northEast,
                      _selectedBounds!.southEast,
                      _selectedBounds!.southWest,
                    ],
                    color: AppColors.primaryOrange.withValues(alpha: 0.15),
                    borderColor: AppColors.primaryOrange,
                    borderStrokeWidth: 2,
                    isFilled: true,
                  ),
                ]),
            ],
          ),
          // Corner label
          Positioned(
            top: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Download area', style: GoogleFonts.outfit(color: AppColors.primaryOrange, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MapStyle.values.map((s) {
        final selected = s == _style;
        return GestureDetector(
          onTap: () => setState(() { _style = s; _recalcEstimate(); }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryOrange.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? AppColors.primaryOrange : Colors.white24,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_styleIcon(s), size: 14, color: selected ? AppColors.primaryOrange : Colors.white54),
                const SizedBox(width: 6),
                Text(s.label, style: GoogleFonts.outfit(
                  color: selected ? AppColors.primaryOrange : Colors.white70,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildZoomPresets() {
    return Column(
      children: List.generate(_presets.length, (i) {
        final p = _presets[i];
        final selected = i == _presetIndex;
        return GestureDetector(
          onTap: () => setState(() { _presetIndex = i; _recalcEstimate(); }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryOrange.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.primaryOrange : Colors.white12,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.primaryOrange : Colors.transparent,
                    border: Border.all(color: selected ? AppColors.primaryOrange : Colors.white38, width: 2),
                  ),
                  child: selected ? const Icon(Icons.check, size: 12, color: Colors.black) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.label, style: GoogleFonts.outfit(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w600, fontSize: 13,
                      )),
                      Text(
                        '${p.subtitle}  •  zoom ${p.minZoom}–${p.maxZoom}',
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNameField() {
    return TextField(
      style: GoogleFonts.outfit(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'e.g. Kakadu National Park',
        hintStyle: GoogleFonts.outfit(color: Colors.white30),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryOrange),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: (v) => _regionName = v,
    );
  }

  Widget _buildEstimateCard() {
    if (_estimate == null) {
      return const SizedBox.shrink();
    }
    final tooLarge = _estimate!.tileCount > 50000;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tooLarge
            ? Colors.orange.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: tooLarge ? Colors.orange.withValues(alpha: 0.5) : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statCell('Tiles', '${_estimate!.tileCount}', Colors.cyanAccent),
              _statCell('Est. Size', _estimate!.formattedSize, AppColors.primaryOrange),
              _statCell('Zoom', '${_presets[_presetIndex].minZoom}–${_presets[_presetIndex].maxZoom}', Colors.greenAccent),
            ],
          ),
          if (tooLarge) ...[
            const SizedBox(height: 10),
            Text(
              '⚠️ Large download — consider a smaller area or fewer zoom levels.',
              style: GoogleFonts.outfit(color: Colors.orange, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadButton() {
    return ElevatedButton.icon(
      onPressed: _downloading || _estimate == null ? null : _startDownload,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryOrange,
        disabledBackgroundColor: Colors.white12,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: _downloading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.download, color: Colors.white),
      label: Text(
        _downloading ? 'Starting...' : 'Download Map',
        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }

  // ─── My Maps Tab ──────────────────────────────────────────────────────────────

  Widget _buildMyMapsTab() {
    final regions = _manager.regions;
    final storageMB = _totalStorageBytes / (1024 * 1024);

    return Column(
      children: [
        _buildStorageHeader(storageMB),
        if (regions.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_outlined, size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text('No offline maps yet',
                      style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Download a region in the Download tab',
                      style: GoogleFonts.outfit(color: Colors.white24, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: regions.length,
              itemBuilder: (ctx, i) => _buildRegionCard(regions[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildStorageHeader(double usedMB) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Storage Used', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
                Text(
                  usedMB < 1024
                      ? '${usedMB.toStringAsFixed(1)} MB'
                      : '${(usedMB / 1024).toStringAsFixed(2)} GB',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
          ),
          Text('${_manager.regions.length} maps',
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRegionCard(OfflineMapRegion region) {
    final prog = _progress[region.id];
    final status = prog?.status ?? region.status;
    final downloaded = prog?.downloaded ?? region.downloadedTiles;
    final total = region.totalTiles;
    final frac = total > 0 ? downloaded / total : 0.0;
    final isActive = status == DownloadStatus.downloading;
    final isPaused = status == DownloadStatus.paused;
    final isDone = status == DownloadStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppColors.primaryOrange.withValues(alpha: 0.5)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusDot(status),
              const SizedBox(width: 10),
              Expanded(
                child: Text(region.name,
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              _buildRegionActions(region, status),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              _chip(Icons.layers, region.style.label),
              _chip(Icons.zoom_in, 'z${region.minZoom}–${region.maxZoom}'),
              _chip(Icons.grid_4x4, '${region.totalTiles} tiles'),
              if (isDone) _chip(Icons.save, region.formattedSize),
            ],
          ),
          if (!isDone) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: frac,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(
                    isActive ? AppColors.primaryOrange : Colors.white38),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isActive
                  ? 'Downloading… $downloaded / $total tiles'
                  : isPaused
                      ? 'Paused — $downloaded / $total tiles'
                      : '${status.name} — $downloaded / $total tiles',
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRegionActions(OfflineMapRegion region, DownloadStatus status) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == DownloadStatus.downloading)
          _iconBtn(Icons.pause, Colors.orange, () {
            _manager.pauseDownload(region.id);
            setState(() {});
          }),
        if (status == DownloadStatus.paused)
          _iconBtn(Icons.play_arrow, Colors.greenAccent, () {
            _manager.resumeDownload(region.id);
            setState(() {});
          }),
        _iconBtn(Icons.delete_outline, Colors.redAccent, () => _confirmDelete(region)),
      ],
    );
  }

  Future<void> _confirmDelete(OfflineMapRegion region) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text('Delete "${region.name}"?',
            style: GoogleFonts.outfit(color: Colors.white)),
        content: Text('This will remove all downloaded tiles for this region.',
            style: GoogleFonts.outfit(color: Colors.white54)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('CANCEL', style: GoogleFonts.outfit(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('DELETE', style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _manager.deleteRegion(region.id);
      await _refreshStorage();
      if (mounted) setState(() {});
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(text,
      style: GoogleFonts.outfit(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2));

  Widget _statCell(String label, String value, Color color) => Column(
    children: [
      Text(value, style: GoogleFonts.outfit(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
      Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
    ],
  );

  Widget _statusDot(DownloadStatus s) {
    final color = s == DownloadStatus.completed
        ? Colors.greenAccent
        : s == DownloadStatus.downloading
            ? AppColors.primaryOrange
            : s == DownloadStatus.paused
                ? Colors.orange
                : s == DownloadStatus.failed
                    ? Colors.red
                    : Colors.white24;
    return Container(width: 8, height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }

  Widget _chip(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: Colors.white38),
      const SizedBox(width: 4),
      Text(text, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
    ],
  );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(icon, color: color, size: 20),
    ),
  );

  IconData _styleIcon(MapStyle s) {
    switch (s) {
      case MapStyle.streets:   return Icons.map;
      case MapStyle.satellite: return Icons.satellite_alt;
      case MapStyle.topo:      return Icons.terrain;
      case MapStyle.outdoor:   return Icons.hiking;
      case MapStyle.dark:      return Icons.dark_mode;
    }
  }
}
