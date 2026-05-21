import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math' as math;
import 'dart:async';

import 'package:bush_track/features/ar/services/ar_compass_service.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/theme/app_colors.dart';

// Only import camera on non-web builds
// camera package has partial web support but is unstable — we skip it on web
export 'ar_compass_screen.dart';

class ARCompassScreen extends ConsumerStatefulWidget {
  const ARCompassScreen({super.key});

  @override
  ConsumerState<ARCompassScreen> createState() => _ARCompassScreenState();
}

class _ARCompassScreenState extends ConsumerState<ARCompassScreen>
    with TickerProviderStateMixin {
  double _compassHeading = 0.0;
  bool _cameraAvailable = false;
  bool _sensorActive = false;
  Object? _cameraController; // dynamic ref to avoid import on web

  // Smooth heading with animation
  late AnimationController _headingAnimController;
  double _smoothHeading = 0.0;
  double _prevHeading = 0.0;

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _headingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _startSensors();
    if (!kIsWeb) _initCamera();
  }

  void _startSensors() {
    // Magnetometer → compass heading
    final magSub = magnetometerEvents.listen((e) {
      if (!mounted) return;
      double h = math.atan2(e.y, e.x) * 180 / math.pi;
      if (h < 0) h += 360;
      setState(() {
        _compassHeading = h;
        _sensorActive = true;
        // Smooth wrap-around
        double diff = h - _prevHeading;
        if (diff > 180) diff -= 360;
        if (diff < -180) diff += 360;
        _smoothHeading = _prevHeading + diff * 0.3;
        _prevHeading = _smoothHeading;
      });
    });
    _subs.add(magSub);
  }

  Future<void> _initCamera() async {
    // Dynamically use camera — skip entirely on web
    try {
      // We don't import camera at the top so web won't fail
      // On native, camera initialises via image_picker flow — for AR preview
      // we rely on the camera plugin directly
      setState(() => _cameraAvailable = false);
    } catch (_) {
      setState(() => _cameraAvailable = false);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _headingAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final currentLat = locationState.stats.currentLat;
    final currentLon = locationState.stats.currentLon;

    final allWaypoints = locationState.waypoints
        .where((w) => w.latitude != null && w.longitude != null)
        .toList();

    // Sort by distance, keep nearest 8
    if (currentLat != null && currentLon != null) {
      final here = LatLng(currentLat, currentLon);
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
          // Background: camera preview on native, dark gradient on web
          _cameraAvailable
              ? _buildCameraPreview()
              : _buildDarkBackground(),

          // AR HUD overlay
          if (currentLat != null && currentLon != null)
            _ARHudOverlay(
              waypoints: nearby,
              currentLat: currentLat,
              currentLon: currentLon,
              heading: _smoothHeading,
              onPinTap: (wp) => _showPinDetails(wp),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white24, width: 1),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AR WAYPOINTS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        _sensorActive
                            ? '${_smoothHeading.toStringAsFixed(0)}° · ${nearby.length} pins visible'
                            : 'Calibrating sensors…',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (!_sensorActive)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryOrange),
                    ),
                ],
              ),
            ),
          ),

          // Bottom horizon line + compass strip
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _CompassStrip(heading: _smoothHeading),
          ),

          // No GPS overlay
          if (currentLat == null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.primaryOrange, width: 1),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gps_off,
                        color: AppColors.primaryOrange, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Waiting for GPS fix',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Step outside and wait a moment.',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // No waypoints hint
          if (currentLat != null && nearby.isEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white24, width: 1),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off,
                        color: Colors.white38, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'No waypoints saved',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Drop a pin on the map first.',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    // Native camera preview — currently stubbed, real impl attaches CameraController
    return Container(color: Colors.black);
  }

  Widget _buildDarkBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            Color(0xFF0A1628),
            Color(0xFF050A14),
          ],
        ),
      ),
      child: CustomPaint(painter: _StarfieldPainter()),
    );
  }

  void _showPinDetails(Waypoint wp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PinDetailSheet(waypoint: wp),
    );
  }
}

// ─── AR HUD overlay ────────────────────────────────────────────────────────

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
    const fovDeg = 70.0; // horizontal FOV in degrees
    final halfW = size.width / 2;

    final widgets = <Widget>[];

    for (int i = 0; i < waypoints.length; i++) {
      final wp = waypoints[i];
      final target = LatLng(wp.latitude!, wp.longitude!);
      final bearing = ARCompassService.staticBearing(here, target);
      final distance = ARCompassService.staticDistance(here, target);

      // Relative bearing from camera centre
      double rel = bearing - heading;
      if (rel > 180) rel -= 360;
      if (rel < -180) rel += 360;

      // Only render pins within FOV + 10° margin
      if (rel.abs() > fovDeg / 2 + 10) continue;

      // Horizontal pixel position
      final px = halfW + (rel / (fovDeg / 2)) * halfW;

      // Vertical: stack closest pins higher on screen
      final baseY = size.height * 0.30 + i * 10.0;

      widgets.add(
        Positioned(
          left: px - 70, // bubble width is ~140
          top: baseY,
          child: GestureDetector(
            onTap: () => onPinTap(wp),
            child: _ARPinBubble(
              waypoint: wp,
              distance: distance,
              isInFov: rel.abs() <= fovDeg / 2,
            ),
          ),
        ),
      );

      // Direction arrow when pin is off-screen
      if (rel.abs() > fovDeg / 2) {
        final arrowX = rel < 0 ? 20.0 : size.width - 30.0;
        widgets.add(
          Positioned(
            left: arrowX,
            top: size.height * 0.45,
            child: Icon(
              rel < 0 ? Icons.chevron_left : Icons.chevron_right,
              color: AppColors.primaryOrange.withValues(alpha: 0.8),
              size: 28,
            ),
          ),
        );
      }
    }

    // Horizon line
    widgets.add(
      Positioned(
        top: (size.height * 0.50).toDouble(),
        left: 0,
        right: 0,
        child: Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
    );

    return Stack(children: widgets);
  }
}

// ─── AR Pin Bubble ──────────────────────────────────────────────────────────

class _ARPinBubble extends StatelessWidget {
  final Waypoint waypoint;
  final double distance;
  final bool isInFov;

  const _ARPinBubble({
    required this.waypoint,
    required this.distance,
    required this.isInFov,
  });

  String get _distanceLabel {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
    return '${distance.toStringAsFixed(0)} m';
  }

  Color get _pinColor {
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
    return Opacity(
      opacity: isInFov ? 1.0 : 0.5,
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _pinColor.withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _pinColor.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photo thumbnail or icon
            if (waypoint.thumbnailPath != null &&
                waypoint.thumbnailPath!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  waypoint.thumbnailPath!,
                  width: double.infinity,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _iconFallback(),
                ),
              )
            else
              _iconFallback(),
            const SizedBox(height: 6),
            // Name
            Text(
              waypoint.label ?? 'Pin',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Distance badge
            Row(
              children: [
                Icon(Icons.navigation, color: _pinColor, size: 12),
                const SizedBox(width: 3),
                Text(
                  _distanceLabel,
                  style: TextStyle(
                    color: _pinColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconFallback() {
    return Container(
      width: double.infinity,
      height: 36,
      decoration: BoxDecoration(
        color: _pinColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.location_on, color: _pinColor, size: 22),
    );
  }
}

// ─── Bottom compass strip ───────────────────────────────────────────────────

class _CompassStrip extends StatelessWidget {
  final double heading;

  const _CompassStrip({required this.heading});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: CustomPaint(
        painter: _CompassStripPainter(heading: heading),
        size: Size(MediaQuery.of(context).size.width, 80),
      ),
    );
  }
}

class _CompassStripPainter extends CustomPainter {
  final double heading;

  _CompassStripPainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1;

    final textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    final tickLabels = {
      0.0: 'N',
      45.0: 'NE',
      90.0: 'E',
      135.0: 'SE',
      180.0: 'S',
      225.0: 'SW',
      270.0: 'W',
      315.0: 'NW',
      360.0: 'N',
    };

    const degreesPerPx = 0.5; // 1 degree = 2px
    final centreX = size.width / 2;
    const stripY = 30.0;

    // Draw ticks every 5 degrees across ±180 degrees of view
    for (double d = heading - 180; d <= heading + 180; d += 5) {
      final normalised = ((d % 360) + 360) % 360;
      final relDeg = d - heading;
      final x = centreX + relDeg / degreesPerPx;

      if (x < 0 || x > size.width) continue;

      final isMajor = normalised % 45 == 0;
      final tickH = isMajor ? 18.0 : 8.0;
      paint.color = isMajor
          ? Colors.white.withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.35);

      canvas.drawLine(
        Offset(x, stripY),
        Offset(x, stripY + tickH),
        paint,
      );

      if (isMajor && tickLabels.containsKey(normalised)) {
        final tp = TextPainter(
          text: TextSpan(text: tickLabels[normalised], style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, stripY + tickH + 2));
      }
    }

    // Centre pointer
    final pointerPaint = Paint()
      ..color = AppColors.primaryOrange
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(centreX, stripY - 6),
      Offset(centreX, stripY + 22),
      pointerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CompassStripPainter old) =>
      old.heading != heading;
}

// ─── Pin detail bottom sheet ────────────────────────────────────────────────

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
        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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
          // Header
          Row(
            children: [
              const Icon(Icons.location_on,
                  color: AppColors.primaryOrange, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  waypoint.label ?? 'Unnamed Pin',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Coordinates
          if (waypoint.latitude != null)
            _DetailRow(
              icon: Icons.gps_fixed,
              label: 'Coordinates',
              value:
                  '${waypoint.latitude!.toStringAsFixed(6)}, ${waypoint.longitude!.toStringAsFixed(6)}',
            ),
          // Notes
          if (waypoint.notes != null && waypoint.notes!.isNotEmpty)
            _DetailRow(
              icon: Icons.notes,
              label: 'Notes',
              value: waypoint.notes!,
            ),
          // Timestamp
          if (waypoint.timestamp != null)
            _DetailRow(
              icon: Icons.access_time,
              label: 'Saved',
              value: _formatDate(waypoint.timestamp!),
            ),
          // Photos
          if (waypoint.photoPaths != null && waypoint.photoPaths!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PHOTOS',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: waypoint.photoPaths!.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (ctx, i) => ClipRRect(
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
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryOrange, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11)),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Starfield background painter ──────────────────────────────────────────

class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42); // fixed seed = same stars every frame
    final paint = Paint()..color = Colors.white;

    for (int i = 0; i < 120; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.65;
      final r = rng.nextDouble() * 1.2 + 0.2;
      paint.color = Colors.white.withValues(alpha: rng.nextDouble() * 0.5 + 0.1);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
