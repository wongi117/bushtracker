import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/ar/services/ar_compass_service.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

// Camera and sensor imports — only used on mobile
import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ARCompassScreen extends ConsumerStatefulWidget {
  const ARCompassScreen({super.key});

  @override
  ConsumerState<ARCompassScreen> createState() => _ARCompassScreenState();
}

class _ARCompassScreenState extends ConsumerState<ARCompassScreen> {
  CameraController? _controller;
  double _compassHeading = 0.0;
  late ARCompassService _arCompassService;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _arCompassService = ref.read(arCompassServiceProvider);
    _initializeCamera();
    _startSensorListening();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _controller = CameraController(
          cameras.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _controller!.initialize();
        if (mounted) setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize camera')),
        );
      }
    }
  }

  void _startSensorListening() {
    accelerometerEvents.listen((AccelerometerEvent event) {
      if (mounted) setState(() {});
    });

    magnetometerEvents.listen((MagnetometerEvent event) {
      if (mounted) {
        double heading = math.atan2(event.y, event.x) * 180 / math.pi;
        if (heading < 0) heading += 360;
        setState(() => _compassHeading = heading);
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('AR COMPASS'),
          backgroundColor: AppColors.panelMatte,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: const Icon(Icons.explore, size: 64, color: AppColors.accent),
                ),
                const SizedBox(height: 24),
                const Text(
                  'AR Compass',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The AR Compass uses your device camera and magnetic sensors to show waypoints in augmented reality.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.smartphone, color: AppColors.accent, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This feature requires the BushTrack mobile app. Camera and compass sensors are not available in a web browser.',
                        style: TextStyle(color: AppColors.accent, fontSize: BushDS.fontSM),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                const Text(
                  'On mobile, point your camera at the landscape and saved waypoints will appear as AR overlays showing their direction and distance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: BushDS.fontSM),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final locationState = ref.watch(locationProvider);
    final currentLat = locationState.stats.currentLat;
    final currentLon = locationState.stats.currentLon;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AR COMPASS'),
        backgroundColor: AppColors.panelMatte,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                if (_isCameraInitialized && _controller != null)
                  CameraPreview(_controller!),
                if (currentLat != null && currentLon != null)
                  _buildAROverlay(currentLat, currentLon),
              ],
            ),
          ),
          Container(
            height: 150,
            padding: const EdgeInsets.all(16),
            child: CustomPaint(
              size: const Size(double.infinity, 150),
              painter: CompassPainter(_compassHeading),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildWaypointsList(currentLat, currentLon),
          ),
        ],
      ),
    );
  }

  Widget _buildAROverlay(double currentLat, double currentLon) {
    final waypoints = ref.watch(locationProvider).waypoints;
    // Show all pinned waypoints within 5 km
    final visibleWaypoints = waypoints.where((wp) {
      if (wp.latitude == null || wp.longitude == null) return false;
      if (wp.isPin != true && wp.type != 'manual') return false;
      final dist = _arCompassService.calculateDistance(
        LatLng(currentLat, currentLon),
        LatLng(wp.latitude!, wp.longitude!),
      );
      return dist <= 5000;
    }).toList();

    if (visibleWaypoints.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<AccelerometerEvent>(
      stream: accelerometerEvents,
      builder: (context, snapshot) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: ARCompassPainter(
            waypoints: visibleWaypoints,
            currentLocation: LatLng(currentLat, currentLon),
            compassHeading: _compassHeading,
            arCompassService: _arCompassService,
          ),
        );
      },
    );
  }

  Widget _buildWaypointsList(double? currentLat, double? currentLon) {
    final waypoints = ref.watch(locationProvider).waypoints;
    final manualWaypoints = waypoints.where((wp) => wp.type == 'manual').toList();

    if (manualWaypoints.isEmpty) {
      return const Center(
        child: Text('No waypoints saved', style: TextStyle(color: Colors.white70)),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: manualWaypoints.length,
        itemBuilder: (context, index) {
          final waypoint = manualWaypoints[index];
          String bearingText = '';
          String distanceText = '';

          if (currentLat != null && currentLon != null &&
              waypoint.latitude != null && waypoint.longitude != null) {
            final currentLocation = LatLng(currentLat, currentLon);
            final targetLocation = LatLng(waypoint.latitude!, waypoint.longitude!);
            final bearing = _arCompassService.calculateBearing(currentLocation, targetLocation);
            final distance = _arCompassService.calculateDistance(currentLocation, targetLocation);
            double relativeBearing = bearing - _compassHeading;
            if (relativeBearing > 180) relativeBearing -= 360;
            if (relativeBearing < -180) relativeBearing += 360;
            bearingText = '${relativeBearing.toStringAsFixed(1)}°';
            distanceText = distance > 1000
                ? '${(distance / 1000).toStringAsFixed(1)}km'
                : '${distance.toStringAsFixed(0)}m';
          }

          return Card(
            color: AppColors.panelLight,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(waypoint.label ?? 'Unnamed Waypoint',
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text('$bearingText • $distanceText',
                  style: const TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.navigation, color: AppColors.accent),
            ),
          );
        },
      ),
    );
  }
}

class CompassPainter extends CustomPainter {
  final double heading;
  CompassPainter(this.heading);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final paint = Paint()..strokeWidth = 2..style = PaintingStyle.stroke;

    paint.color = Colors.white.withValues(alpha: 0.3);
    canvas.drawCircle(center, radius, paint);

    final directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final textPainter = TextPainter(textAlign: TextAlign.center, textDirection: TextDirection.ltr);

    for (int i = 0; i < directions.length; i++) {
      final angle = (i * 45 - heading) * (math.pi / 180);
      final dx = math.cos(angle) * radius;
      final dy = math.sin(angle) * radius;
      paint.color = Colors.white;
      canvas.drawLine(center, center + Offset(dx * 0.8, dy * 0.8), paint);
      textPainter.text = TextSpan(
        text: directions[i],
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        center + Offset(dx * 0.9 - textPainter.width / 2, dy * 0.9 - textPainter.height / 2),
      );
    }

    paint.color = AppColors.accent;
    paint.style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(center.dx, center.dy - radius * 0.7)
      ..lineTo(center.dx - 8, center.dy - radius * 0.5)
      ..lineTo(center.dx + 8, center.dy - radius * 0.5)
      ..close();
    canvas.drawPath(path, paint);

    textPainter.text = TextSpan(
      text: '${heading.toInt()}°',
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy + radius * 0.3 - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ARCompassPainter extends CustomPainter {
  final List<Waypoint> waypoints;
  final LatLng currentLocation;
  final double compassHeading;
  final ARCompassService arCompassService;

  ARCompassPainter({
    required this.waypoints,
    required this.currentLocation,
    required this.compassHeading,
    required this.arCompassService,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const fov = 60.0;
    final centerX = size.width / 2;

    final bgPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final stemPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF7B2FFF);

    // Sort nearest last so they render on top
    final sorted = List<Waypoint>.from(waypoints)
      ..sort((a, b) {
        final dA = arCompassService.calculateDistance(
            currentLocation, LatLng(a.latitude!, a.longitude!));
        final dB = arCompassService.calculateDistance(
            currentLocation, LatLng(b.latitude!, b.longitude!));
        return dB.compareTo(dA);
      });

    for (final waypoint in sorted) {
      if (waypoint.latitude == null || waypoint.longitude == null) continue;
      final target = LatLng(waypoint.latitude!, waypoint.longitude!);
      final bearing = arCompassService.calculateBearing(currentLocation, target);
      final distance = arCompassService.calculateDistance(currentLocation, target);

      double rel = bearing - compassHeading;
      if (rel > 180) rel -= 360;
      if (rel < -180) rel += 360;
      if (rel.abs() > 35) continue; // outside FOV

      final screenX = centerX + (rel / (fov / 2)) * (size.width / 2);
      // Farther pins appear higher on screen
      final normalizedDist = (distance / 5000).clamp(0.0, 1.0);
      final pinTop = size.height * (0.12 + normalizedDist * 0.35);

      final label = waypoint.label ?? 'Pin';
      final distText = distance >= 1000
          ? '${(distance / 1000).toStringAsFixed(1)} km'
          : '${distance.toStringAsFixed(0)} m';

      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(
            text: '$label\n',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: distText,
            style: const TextStyle(color: Color(0xFFB0B8D0), fontSize: 10),
          ),
        ]),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 110);

      const pH = 10.0;
      const pV = 6.0;
      final bW = tp.width + pH * 2;
      final bH = tp.height + pV * 2;
      final bubbleRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(screenX - bW / 2, pinTop, bW, bH),
        const Radius.circular(10),
      );

      bgPaint.color = const Color(0xFF0D0F1E).withValues(alpha: 0.88);
      canvas.drawRRect(bubbleRect, bgPaint);
      borderPaint.color = const Color(0xFF7B2FFF).withValues(alpha: 0.9);
      canvas.drawRRect(bubbleRect, borderPaint);

      tp.paint(canvas, Offset(screenX - tp.width / 2, pinTop + pV));

      // Stem from bubble bottom to pin point
      final stemTop = Offset(screenX, pinTop + bH);
      final stemBot = Offset(screenX, pinTop + bH + 28);
      canvas.drawLine(stemTop, stemBot, stemPaint);

      // Pin dot
      bgPaint.color = const Color(0xFF7B2FFF);
      canvas.drawCircle(stemBot, 5, bgPaint);
      bgPaint.color = Colors.white;
      canvas.drawCircle(stemBot, 2, bgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
