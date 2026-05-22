import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bush_track/features/ar/services/ar_compass_service.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/core/models/waypoint.dart';

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
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  @override
  void initState() {
    super.initState();
    _arCompassService = ref.read(arCompassServiceProvider);
    _initializeCamera();
    _startSensorListening();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final camera = cameras.first;
        _controller = CameraController(
          camera,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      // Handle camera initialization error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize camera')),
        );
      }
    }
  }

  void _startSensorListening() {
    _accelSub = accelerometerEvents.listen((AccelerometerEvent event) {
      if (mounted) setState(() {});
    });

    _magSub = magnetometerEvents.listen((MagnetometerEvent event) {
      if (mounted) {
        double heading = math.atan2(event.y, event.x) * 180 / math.pi;
        if (heading < 0) heading += 360;
        setState(() => _compassHeading = heading);
      }
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _magSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final currentLat = locationState.stats.currentLat;
    final currentLon = locationState.stats.currentLon;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AR COMPASS'),
        backgroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Camera preview with AR overlay
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                // Camera preview — fill entire section
                if (_isCameraInitialized && _controller != null)
                  Positioned.fill(child: CameraPreview(_controller!))
                else
                  Container(color: Colors.black),
                // AR overlay
                if (currentLat != null && currentLon != null)
                  Positioned.fill(child: _buildAROverlay(currentLat, currentLon)),
              ],
            ),
          ),

          // Compass visualization — fills 40% of screen height
          Expanded(
            flex: 3,
            child: Container(
              color: const Color(0xFF0A0A1A),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${_compassHeading.toInt()}°  •  ${_headingLabel(_compassHeading)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: CompassPainter(_compassHeading),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Waypoints list
          Expanded(
            flex: 2,
            child: _buildWaypointsList(currentLat, currentLon),
          ),
        ],
      ),
    );
  }

  String _headingLabel(double heading) {
    const dirs = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
                  'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    return dirs[((heading + 11.25) % 360 ~/ 22.5).toInt()];
  }

  Widget _buildAROverlay(double currentLat, double currentLon) {
    final waypoints = ref.watch(locationProvider).waypoints;
    final manualWaypoints = waypoints.where((wp) => wp.type == 'manual').toList();
    
    if (manualWaypoints.isEmpty) {
      return Container();
    }

    return StreamBuilder<AccelerometerEvent>(
      stream: accelerometerEvents,
      builder: (context, snapshot) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: ARCompassPainter(
            waypoints: manualWaypoints,
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
    
    if (waypoints.isEmpty) {
      return const Center(
        child: Text(
          'No waypoints saved',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // Filter to only show manual waypoints
    final manualWaypoints = waypoints.where((wp) => wp.type == 'manual').toList();

    if (manualWaypoints.isEmpty) {
      return const Center(
        child: Text(
          'No waypoints saved',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1B26),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: manualWaypoints.length,
        itemBuilder: (context, index) {
          final waypoint = manualWaypoints[index];
          
          // Calculate bearing and distance if we have current location
          String bearingText = '';
          String distanceText = '';
          
          if (currentLat != null && currentLon != null && 
              waypoint.latitude != null && waypoint.longitude != null) {
            
            final currentLocation = LatLng(currentLat, currentLon);
            final targetLocation = LatLng(waypoint.latitude!, waypoint.longitude!);
            
            final bearing = _arCompassService.calculateBearing(currentLocation, targetLocation);
            final distance = _arCompassService.calculateDistance(currentLocation, targetLocation);
            
            // Calculate relative bearing (difference between compass heading and target bearing)
            double relativeBearing = bearing - _compassHeading;
            if (relativeBearing > 180) relativeBearing -= 360;
            if (relativeBearing < -180) relativeBearing += 360;
            
            bearingText = '${relativeBearing.toStringAsFixed(1)}°';
            distanceText = distance > 1000 
                ? '${(distance/1000).toStringAsFixed(1)}km' 
                : '${distance.toStringAsFixed(0)}m';
          }

          return Card(
            color: const Color(0xFF2A2B3A),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(
                waypoint.label ?? 'Unnamed Waypoint',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '$bearingText • $distanceText',
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: const Icon(Icons.navigation, color: Color(0xFFFF9F1C)),
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
    
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw compass circle
    paint.color = Colors.white.withValues(alpha: 0.3);
    canvas.drawCircle(center, radius, paint);
    
    // Draw direction markers
    final directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    
    for (int i = 0; i < directions.length; i++) {
      final angle = (i * 45 - heading) * (math.pi / 180);
      final dx = math.cos(angle) * radius;
      final dy = math.sin(angle) * radius;
      
      // Draw marker line
      paint.color = Colors.white;
      canvas.drawLine(
        center,
        center + Offset(dx * 0.8, dy * 0.8),
        paint,
      );
      
      // Draw direction label
      final textSpan = TextSpan(
        text: directions[i],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      
      textPainter.text = textSpan;
      textPainter.layout();
      
      final textOffset = center + Offset(
        dx * 0.9 - textPainter.width / 2,
        dy * 0.9 - textPainter.height / 2,
      );
      
      textPainter.paint(canvas, textOffset);
    }
    
    // Draw heading indicator
    paint.color = const Color(0xFFFF9F1C);
    paint.style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(center.dx, center.dy - radius * 0.7)
      ..lineTo(center.dx - 8, center.dy - radius * 0.5)
      ..lineTo(center.dx + 8, center.dy - radius * 0.5)
      ..close();
    canvas.drawPath(path, paint);
    
    // Draw heading text
    final headingText = '${heading.toInt()}°';
    final headingSpan = TextSpan(
      text: headingText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
    
    textPainter.text = headingSpan;
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy + radius * 0.3 - textPainter.height / 2,
      ),
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
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw waypoint indicators
    for (final waypoint in waypoints) {
      if (waypoint.latitude == null || waypoint.longitude == null) continue;
      
      final targetLocation = LatLng(waypoint.latitude!, waypoint.longitude!);
      final bearing = arCompassService.calculateBearing(currentLocation, targetLocation);
      final distance = arCompassService.calculateDistance(currentLocation, targetLocation);
      
      // Calculate relative bearing
      double relativeBearing = bearing - compassHeading;
      if (relativeBearing > 180) relativeBearing -= 360;
      if (relativeBearing < -180) relativeBearing += 360;
      
      // Convert to screen coordinates (assuming horizontal FOV of 60 degrees)
      const fov = 60.0; // degrees
      final screenX = center.dx + (relativeBearing / (fov / 2)) * (size.width / 2);
      
      // Only draw if within screen bounds
      if (screenX >= 0 && screenX <= size.width) {
        // Draw arrow pointing to waypoint
        paint.color = const Color(0xFFFF9F1C);
        final arrowPath = ui.Path()
          ..moveTo(screenX, size.height * 0.2)
          ..lineTo(screenX - 10, size.height * 0.2 + 20)
          ..lineTo(screenX + 10, size.height * 0.2 + 20)
          ..close();
        canvas.drawPath(arrowPath, paint);
        
        // Draw distance text
        final distanceText = distance > 1000 
            ? '${(distance/1000).toStringAsFixed(1)}km' 
            : '${distance.toStringAsFixed(0)}m';
        
        final textPainter = TextPainter(
          text: TextSpan(
            text: distanceText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            screenX - textPainter.width / 2,
            size.height * 0.2 + 25,
          ),
        );
        
        // Draw waypoint name
        final nameText = waypoint.label ?? 'Waypoint';
        final namePainter = TextPainter(
          text: TextSpan(
            text: nameText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        
        namePainter.layout();
        namePainter.paint(
          canvas,
          Offset(
            screenX - namePainter.width / 2,
            size.height * 0.2 + 45,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}