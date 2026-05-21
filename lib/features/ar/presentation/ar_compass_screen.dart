import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;
import 'dart:async';

import 'package:bush_track/features/ar/services/ar_compass_service.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/map/services/photo_geotagging_service.dart';
import 'package:bush_track/features/map/presentation/photo_pin_screen.dart';

class ARCompassScreen extends ConsumerStatefulWidget {
  const ARCompassScreen({super.key});

  @override
  ConsumerState<ARCompassScreen> createState() => _ARCompassScreenState();
}

class _ARCompassScreenState extends ConsumerState<ARCompassScreen>
    with TickerProviderStateMixin {
  // Camera
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _cameraError = false;

  // Sensors
  double _smoothHeading = 0.0;
  double _prevHeading = 0.0;
  bool _sensorActive = false;
  final List<StreamSubscription> _subs = [];

  // Photo service
  final PhotoGeotaggingService _photoService = PhotoGeotaggingService();
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _startSensors();
    _initCamera();
    _photoService.initialize();
  }

  // ── Sensors ────────────────────────────────────────────────────────────────

  void _startSensors() {
    final sub = magnetometerEvents.listen((e) {
      if (!mounted) return;
      double h = math.atan2(e.y, e.x) * 180 / math.pi;
      if (h < 0) h += 360;
      double diff = h - _prevHeading;
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;
      setState(() {
        _smoothHeading = _prevHeading + diff * 0.25;
        _prevHeading = _smoothHeading;
        _sensorActive = true;
      });
    });
    _subs.add(sub);
  }

  // ── Camera ─────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    if (kIsWeb) {
      // Web camera via CameraController is unreliable — skip, show dark BG
      setState(() => _cameraError = false);
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = true);
        return;
      }
      // Prefer rear camera
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _cameraController = ctrl;
        _cameraReady = true;
      });
    } catch (e) {
      debugPrint('AR camera init error: $e');
      if (mounted) setState(() => _cameraError = true);
    }
  }

  Future<void> _switchCamera() async {
    if (kIsWeb || _cameraController == null) return;
    try {
      final cameras = await availableCameras();
      if (cameras.length < 2) return;
      final current = _cameraController!.description;
      final next = cameras.firstWhere(
        (c) => c.lensDirection != current.lensDirection,
        orElse: () => cameras.first,
      );
      await _cameraController!.dispose();
      setState(() {
        _cameraReady = false;
        _cameraController = null;
      });
      final ctrl = CameraController(next, ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg);
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _cameraController = ctrl;
        _cameraReady = true;
      });
    } catch (e) {
      debugPrint('AR switch camera error: $e');
    }
  }

  // ── Photo capture & pin drop ───────────────────────────────────────────────

  Future<void> _captureAndDropPin() async {
    final locationState = ref.read(locationProvider);
    final lat = locationState.stats.currentLat;
    final lon = locationState.stats.currentLon;

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No GPS fix yet — move outside and wait a moment'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _capturing = true);

    try {
      GeotaggedPhoto? geoPhoto;
      if (_cameraReady && _cameraController != null && !kIsWeb) {
        // Take photo directly from AR camera preview
        final xfile = await _cameraController!.takePicture();
        geoPhoto = await _photoService.processFile(
          xfile.path,
          location: LatLng(lat, lon),
          altitude: locationState.stats.currentAltitude,
        );
      } else {
        // Web / no camera: launch system camera via image_picker
        geoPhoto = await _photoService.takePhoto(
          location: LatLng(lat, lon),
          altitude: locationState.stats.currentAltitude,
        );
      }

      if (geoPhoto == null) {
        setState(() => _capturing = false);
        return;
      }

      // Navigate to pin detail screen — AR screen stays in stack
      if (mounted) {
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoPinScreen(
              photo: geoPhoto!,
              location: LatLng(lat, lon),
            ),
          ),
        );
        if (saved == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pin dropped!'),
              backgroundColor: Color(0xFF1B5E20),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('AR capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Capture failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final lat = locationState.stats.currentLat;
    final lon = locationState.stats.currentLon;

    final allWaypoints = locationState.waypoints
        .where((w) => w.latitude != null && w.longitude != null)
        .toList();

    // Sort nearest 8
    if (lat != null && lon != null) {
      final here = LatLng(lat, lon);
      allWaypoints.sort((a, b) {
        final da = ARCompassService.staticDistance(
            here, LatLng(a.latitude!, a.longitude!));
        final db = ARCompassService.staticDistance(
            here, LatLng(b.latitude!, b.longitude!));
        return da.compareTo(db);
      });
    }
    final nearby = allWaypoints.take(8).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera / background ─────────────────────────────────────────
          if (_cameraReady && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            _buildBackground(),

          // ── AR waypoint HUD ─────────────────────────────────────────────
          if (lat != null && lon != null)
            _ARHudOverlay(
              waypoints: nearby,
              currentLat: lat,
              currentLon: lon,
              heading: _smoothHeading,
              onPinTap: _showPinDetails,
            ),

          // ── Top gradient + controls ──────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 14,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  _topButton(Icons.close, () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'AR VIEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        _sensorActive
                            ? '${_smoothHeading.toStringAsFixed(0)}°  ·  ${nearby.length} pins'
                            : 'Calibrating…',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Switch camera (native only)
                  if (!kIsWeb && !_cameraError)
                    _topButton(Icons.flip_camera_ios, _switchCamera),
                ],
              ),
            ),
          ),

          // ── Bottom controls ──────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compass strip
                _CompassStrip(heading: _smoothHeading),
                // Shutter row
                Container(
                  height: 110,
                  padding: const EdgeInsets.only(bottom: 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _capturing ? null : _captureAndDropPin,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: _capturing ? 64 : 72,
                          height: _capturing ? 64 : 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.9),
                            border: Border.all(
                                color: AppColors.primaryOrange, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryOrange
                                    .withValues(alpha: 0.4),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: _capturing
                              ? const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: AppColors.primaryOrange,
                                  ),
                                )
                              : const Icon(Icons.camera_alt,
                                  color: Colors.black87, size: 32),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── No GPS message ───────────────────────────────────────────────
          if (lat == null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primaryOrange, width: 1),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gps_off,
                        color: AppColors.primaryOrange, size: 48),
                    SizedBox(height: 16),
                    Text('Waiting for GPS',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Step outside — GPS needed for AR pins',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [Color(0xFF0A1628), Color(0xFF050A14)],
        ),
      ),
      child: CustomPaint(painter: _StarfieldPainter()),
    );
  }

  Widget _topButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  void _showPinDetails(Waypoint wp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PinDetailSheet(waypoint: wp),
    );
  }
}

// ─── AR HUD overlay ─────────────────────────────────────────────────────────

class _ARHudOverlay extends StatelessWidget {
  final List<Waypoint> waypoints;
  final double currentLat;
  final double currentLon;
  final double heading;
  final void Function(Waypoint) onPinTap;

  const _ARHudOverlay({
    required this.waypoints,
    required this.currentLat,
    required this.currentLon,
    required this.heading,
    required this.onPinTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final here = LatLng(currentLat, currentLon);
    const fovDeg = 70.0;
    final halfW = size.width / 2;

    final widgets = <Widget>[];

    // Horizon line
    widgets.add(
      Positioned(
        top: size.height * 0.48,
        left: 0,
        right: 0,
        child: Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
    );

    for (int i = 0; i < waypoints.length; i++) {
      final wp = waypoints[i];
      final target = LatLng(wp.latitude!, wp.longitude!);
      final bearing = ARCompassService.staticBearing(here, target);
      final distance = ARCompassService.staticDistance(here, target);

      double rel = bearing - heading;
      if (rel > 180) rel -= 360;
      if (rel < -180) rel += 360;

      // Off-screen arrows
      if (rel.abs() > fovDeg / 2 + 5) {
        final arrowX = rel < 0 ? 16.0 : size.width - 44.0;
        widgets.add(
          Positioned(
            left: arrowX,
            top: size.height * 0.42,
            child: _OffscreenArrow(
              direction: rel < 0 ? -1 : 1,
              label: distance >= 1000
                  ? '${(distance / 1000).toStringAsFixed(1)}km'
                  : '${distance.toStringAsFixed(0)}m',
            ),
          ),
        );
        continue;
      }

      final px = halfW + (rel / (fovDeg / 2)) * halfW;
      // Stagger vertically so overlapping pins don't stack
      final baseY = size.height * 0.22 + (i % 3) * 20.0;

      widgets.add(
        Positioned(
          left: (px - 70).clamp(4.0, size.width - 144.0),
          top: baseY,
          child: GestureDetector(
            onTap: () => onPinTap(wp),
            child: _ARPinBubble(waypoint: wp, distance: distance),
          ),
        ),
      );

      // Vertical drop line from bubble to horizon
      widgets.add(
        Positioned(
          left: px - 0.5,
          top: baseY + 90,
          child: Container(
            width: 1,
            height: (size.height * 0.48 - baseY - 90).clamp(0.0, 200.0),
            color: _pinColor(wp).withValues(alpha: 0.3),
          ),
        ),
      );
    }

    return Stack(children: widgets);
  }

  Color _pinColor(Waypoint wp) {
    final c = wp.color;
    if (c != null && c.isNotEmpty) {
      try {
        return Color(int.parse(c.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return AppColors.primaryOrange;
  }
}

// ─── Off-screen arrow indicator ─────────────────────────────────────────────

class _OffscreenArrow extends StatelessWidget {
  final int direction; // -1 = left, 1 = right
  final String label;

  const _OffscreenArrow({required this.direction, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          direction < 0 ? Icons.chevron_left : Icons.chevron_right,
          color: AppColors.primaryOrange.withValues(alpha: 0.85),
          size: 28,
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primaryOrange,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ─── AR Pin Bubble ───────────────────────────────────────────────────────────

class _ARPinBubble extends StatelessWidget {
  final Waypoint waypoint;
  final double distance;

  const _ARPinBubble({required this.waypoint, required this.distance});

  String get _dist {
    if (distance >= 1000) return '${(distance / 1000).toStringAsFixed(1)} km';
    return '${distance.toStringAsFixed(0)} m';
  }

  Color get _color {
    final c = waypoint.color;
    if (c != null && c.isNotEmpty) {
      try {
        return Color(int.parse(c.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return AppColors.primaryOrange;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.85), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _color.withValues(alpha: 0.25),
              blurRadius: 12,
              spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thumbnail or icon row
          if (waypoint.thumbnailPath != null &&
              waypoint.thumbnailPath!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                waypoint.thumbnailPath!,
                width: double.infinity,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _iconBox(),
              ),
            )
          else
            _iconBox(),
          const SizedBox(height: 5),
          Text(
            waypoint.label ?? 'Pin',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.navigation, color: _color, size: 11),
              const SizedBox(width: 3),
              Text(_dist,
                  style: TextStyle(
                      color: _color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      width: double.infinity,
      height: 34,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.location_on, color: _color, size: 20),
    );
  }
}

// ─── Compass strip ───────────────────────────────────────────────────────────

class _CompassStrip extends StatelessWidget {
  final double heading;
  const _CompassStrip({required this.heading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: CustomPaint(
        painter: _CompassStripPainter(heading: heading),
      ),
    );
  }
}

class _CompassStripPainter extends CustomPainter {
  final double heading;
  _CompassStripPainter({required this.heading});

  static final _labels = <double, String>{
    0.0: 'N', 45.0: 'NE', 90.0: 'E', 135.0: 'SE',
    180.0: 'S', 225.0: 'SW', 270.0: 'W', 315.0: 'NW',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 1;
    const tickY = 14.0;
    final centreX = size.width / 2;
    const pxPerDeg = 2.0;

    for (double d = heading - 100; d <= heading + 100; d += 5) {
      final norm = ((d % 360) + 360) % 360;
      final rel = d - heading;
      final x = centreX + rel * pxPerDeg;
      if (x < 0 || x > size.width) continue;

      final isMajor = norm % 45 == 0;
      paint.color = isMajor
          ? Colors.white.withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.3);
      canvas.drawLine(
        Offset(x, tickY),
        Offset(x, tickY + (isMajor ? 16.0 : 7.0)),
        paint,
      );

      if (isMajor && _labels.containsKey(norm)) {
        final tp = TextPainter(
          text: TextSpan(
            text: _labels[norm],
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, tickY + 18));
      }
    }

    // Centre pointer
    final ptr = Paint()
      ..color = AppColors.primaryOrange
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(centreX, tickY - 4), Offset(centreX, tickY + 18), ptr);
  }

  @override
  bool shouldRepaint(covariant _CompassStripPainter old) =>
      old.heading != heading;
}

// ─── Pin detail bottom sheet ─────────────────────────────────────────────────

class _PinDetailSheet extends StatelessWidget {
  final Waypoint waypoint;
  const _PinDetailSheet({required this.waypoint});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1624),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: AppColors.primaryOrange.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on,
                  color: AppColors.primaryOrange, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  waypoint.label ?? 'Unnamed Pin',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child:
                    const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (waypoint.latitude != null)
            _Row(Icons.gps_fixed, 'Coords',
                '${waypoint.latitude!.toStringAsFixed(6)}, ${waypoint.longitude!.toStringAsFixed(6)}'),
          if (waypoint.notes != null && waypoint.notes!.isNotEmpty)
            _Row(Icons.notes, 'Notes', waypoint.notes!),
          if (waypoint.timestamp != null)
            _Row(Icons.access_time, 'Saved', _fmt(waypoint.timestamp!)),
          if (waypoint.photoPaths != null &&
              waypoint.photoPaths!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('PHOTOS',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1.2)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: waypoint.photoPaths!.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    waypoint.photoPaths![i],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.white10,
                      child: const Icon(Icons.broken_image,
                          color: Colors.white38),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryOrange, size: 15),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11)),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Starfield BG ────────────────────────────────────────────────────────────

class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint();
    for (int i = 0; i < 140; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.2 + 0.2;
      paint.color =
          Colors.white.withValues(alpha: rng.nextDouble() * 0.45 + 0.08);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
