import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/features/ar/services/ar_compass_service.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/theme/app_colors.dart';

class ARCameraScreen extends ConsumerStatefulWidget {
  const ARCameraScreen({super.key});

  @override
  ConsumerState<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends ConsumerState<ARCameraScreen> {
  CameraController? _controller;
  bool _cameraReady = false;
  double _compassHeading = 0.0;
  StreamSubscription<MagnetometerEvent>? _magSub;

  // Capture state
  Uint8List? _capturedBytes;
  bool _saving = false;

  late ARCompassService _arService;

  // Decoded thumbnails for AR overlay: waypoint.id → ui.Image
  final Map<int, ui.Image> _wpImages = {};
  final Set<int> _loadingIds = {};

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _arService = ref.read(arCompassServiceProvider);
    _initCamera();
    _magSub = magnetometerEvents.listen((e) {
      double h = math.atan2(e.y, e.x) * 180 / math.pi;
      if (h < 0) h += 360;
      if (mounted) setState(() => _compassHeading = h);
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('AR Camera init error: $e');
    }
  }

  @override
  void dispose() {
    _magSub?.cancel();
    _controller?.dispose();
    for (final image in _wpImages.values) {
      image.dispose();
    }
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final xfile = await _controller!.takePicture();
      final bytes = await xfile.readAsBytes();
      if (mounted) setState(() => _capturedBytes = bytes);
    } catch (e) {
      debugPrint('Capture error: $e');
    }
  }

  void _retake() {
    setState(() => _capturedBytes = null);
  }

  Future<void> _savePin() async {
    if (_capturedBytes == null || _saving) return;
    setState(() => _saving = true);
    try {
      // Compress image
      final decoded = img.decodeImage(_capturedBytes!);
      Uint8List compressed = _capturedBytes!;
      if (decoded != null) {
        final resized = img.copyResize(
          decoded,
          width: decoded.width > 1200 ? 1200 : decoded.width,
        );
        compressed = Uint8List.fromList(img.encodeJpg(resized, quality: 80));
      }
      final base64Uri = 'data:image/jpeg;base64,${base64Encode(compressed)}';

      final stats = ref.read(locationProvider).stats;
      final lat = stats.currentLat ?? 0.0;
      final lon = stats.currentLon ?? 0.0;
      final name = 'Photo ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';

      // Save via the same two-step pattern as pinage_editor
      await ref.read(locationProvider.notifier).addManualWaypoint(
        lat, lon, name,
        color: '#7B2FFF',
        icon: 'pinage',
      );

      // Upgrade to pinage type with the photo attached
      final fresh = ref.read(locationProvider).waypoints;
      final matches = fresh
          .where((w) => w.label == name && w.type == WaypointType.manual)
          .toList();
      if (matches.isNotEmpty) {
        final w = matches.last;
        w.type = WaypointType.pinage;
        w.isPin = true;
        w.photoPaths = [base64Uri];
        w.thumbnailPath = base64Uri;
        await ref.read(locationProvider.notifier).updateWaypoint(w);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo pin saved to map'),
            backgroundColor: Color(0xFF7B2FFF),
          ),
        );
      }
    } catch (e) {
      debugPrint('Save pin error: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Fire-and-forget thumbnail loader for AR overlay
  void _preloadWpImages(List<Waypoint> waypoints) {
    for (final wp in waypoints) {
      if (wp.id == null) continue;
      if (_wpImages.containsKey(wp.id) || _loadingIds.contains(wp.id)) continue;
      final first = wp.photoPaths?.isNotEmpty == true ? wp.photoPaths!.first : null;
      if (first == null || !first.startsWith('data:image')) continue;
      _loadingIds.add(wp.id!);
      _decodeImage(wp.id!, first);
    }
  }

  Future<void> _decodeImage(int id, String dataUri) async {
    try {
      final comma = dataUri.indexOf(',');
      final bytes = base64Decode(dataUri.substring(comma + 1));
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 80, targetHeight: 80);
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _wpImages[id] = frame.image);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.view_in_ar, color: AppColors.accent, size: 56),
              ),
              const SizedBox(height: 24),
              const Text(
                'AR Camera',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'The AR Camera uses your device camera to capture geotagged photos and show nearby pins in augmented reality. Available on mobile only.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: AppColors.accent),
                label: const Text('Go Back', style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ),
        ),
      );
    }

    final locationState = ref.watch(locationProvider);
    final currentLat = locationState.stats.currentLat;
    final currentLon = locationState.stats.currentLon;

    final visibleWaypoints = (currentLat != null && currentLon != null)
        ? locationState.waypoints.where((wp) {
            if (wp.latitude == null || wp.longitude == null) return false;
            if (wp.isPin != true &&
                wp.type != WaypointType.pinage &&
                wp.type != WaypointType.manual) {
              return false;
            }
            final dist = _arService.calculateDistance(
              LatLng(currentLat, currentLon),
              LatLng(wp.latitude!, wp.longitude!),
            );
            return dist <= 5000;
          }).toList()
        : <Waypoint>[];

    if (visibleWaypoints.isNotEmpty) {
      _preloadWpImages(visibleWaypoints);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera feed or frozen preview
          if (_capturedBytes != null)
            Image.memory(_capturedBytes!, fit: BoxFit.cover)
          else if (_cameraReady && _controller != null)
            CameraPreview(_controller!)
          else
            const Center(child: CircularProgressIndicator(color: Color(0xFF7B2FFF))),

          // ── AR pin overlays (live mode only)
          if (_capturedBytes == null &&
              currentLat != null &&
              currentLon != null &&
              visibleWaypoints.isNotEmpty)
            IgnorePointer(
              child: CustomPaint(
                size: Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height,
                ),
                painter: _ARCameraPainter(
                  waypoints: visibleWaypoints,
                  currentLocation: LatLng(currentLat, currentLon),
                  compassHeading: _compassHeading,
                  arService: _arService,
                  wpImages: Map.unmodifiable(_wpImages),
                ),
              ),
            ),

          // ── Top: close button + AR mode badge
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
                const Spacer(),
                if (_capturedBytes == null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B2FFF).withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.view_in_ar, color: Colors.white, size: 14),
                        SizedBox(width: 5),
                        Text(
                          'AR MODE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Pin count badge (live mode)
          if (_capturedBytes == null && visibleWaypoints.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${visibleWaypoints.length} pin${visibleWaypoints.length == 1 ? '' : 's'} nearby',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

          // ── Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 48,
                right: 48,
                top: 28,
                bottom: MediaQuery.of(context).padding.bottom + 32,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
              child: _capturedBytes == null
                  ? _buildShutterRow()
                  : _buildConfirmRow(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShutterRow() {
    return Center(
      child: GestureDetector(
        onTap: _capture,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 34),
        ),
      ),
    );
  }

  Widget _buildConfirmRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Retake
        GestureDetector(
          onTap: _retake,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.replay_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 7),
              const Text(
                'RETAKE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),

        // Save Pin
        GestureDetector(
          onTap: _saving ? null : _savePin,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF9B4FFF), Color(0xFF5B1FDF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B2FFF).withValues(alpha: 0.65),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _saving
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.location_pin, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 7),
              const Text(
                'SAVE PIN',
                style: TextStyle(
                  color: Color(0xFF9B4FFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── AR Painter ──────────────────────────────────────────────────────────────

class _ARCameraPainter extends CustomPainter {
  final List<Waypoint> waypoints;
  final LatLng currentLocation;
  final double compassHeading;
  final ARCompassService arService;
  final Map<int, ui.Image> wpImages;

  _ARCameraPainter({
    required this.waypoints,
    required this.currentLocation,
    required this.compassHeading,
    required this.arService,
    required this.wpImages,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const fov = 65.0;
    final centerX = size.width / 2;

    final bgPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final stemPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF7B2FFF);

    // Draw farthest first so nearer pins render on top
    final sorted = List<Waypoint>.from(waypoints)
      ..sort((a, b) {
        final dA = arService.calculateDistance(
            currentLocation, LatLng(a.latitude!, a.longitude!));
        final dB = arService.calculateDistance(
            currentLocation, LatLng(b.latitude!, b.longitude!));
        return dB.compareTo(dA);
      });

    for (final wp in sorted) {
      if (wp.latitude == null || wp.longitude == null) continue;
      final target = LatLng(wp.latitude!, wp.longitude!);
      final bearing = arService.calculateBearing(currentLocation, target);
      final distance = arService.calculateDistance(currentLocation, target);

      double rel = bearing - compassHeading;
      if (rel > 180) rel -= 360;
      if (rel < -180) rel += 360;
      if (rel.abs() > fov / 2) continue;

      final screenX = centerX + (rel / (fov / 2)) * (size.width / 2);
      final normalizedDist = (distance / 5000).clamp(0.0, 1.0);

      final photoImg = (wp.id != null) ? wpImages[wp.id!] : null;
      const photoSize = 64.0;
      const pH = 10.0;
      const pV = 8.0;
      const photoGap = 6.0;

      final label = wp.label ?? 'Pin';
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
      )..layout(maxWidth: 120);

      final contentW = math.max(tp.width, photoImg != null ? photoSize : 0.0);
      final bW = contentW + pH * 2;
      final bH = pV +
          (photoImg != null ? (photoSize + photoGap) : 0) +
          tp.height +
          pV;
      final pinTop = size.height * (0.08 + normalizedDist * 0.38);

      final bubbleRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(screenX - bW / 2, pinTop, bW, bH),
        const Radius.circular(12),
      );

      bgPaint.color = const Color(0xFF0D0F1E).withValues(alpha: 0.88);
      canvas.drawRRect(bubbleRect, bgPaint);
      borderPaint.color = const Color(0xFF7B2FFF).withValues(alpha: 0.9);
      canvas.drawRRect(bubbleRect, borderPaint);

      double textY = pinTop + pV;

      // Draw photo thumbnail with clipped corners
      if (photoImg != null) {
        final photoRect = Rect.fromLTWH(
          screenX - photoSize / 2,
          pinTop + pV,
          photoSize,
          photoSize,
        );
        final clipRRect = RRect.fromRectAndRadius(
          photoRect,
          const Radius.circular(8),
        );
        canvas.save();
        canvas.clipRRect(clipRRect);
        final src = Rect.fromLTWH(
          0,
          0,
          photoImg.width.toDouble(),
          photoImg.height.toDouble(),
        );
        canvas.drawImageRect(photoImg, src, photoRect, Paint());
        canvas.restore();
        textY += photoSize + photoGap;
      }

      tp.paint(canvas, Offset(screenX - tp.width / 2, textY));

      // Stem + pin dot
      final stemTop = Offset(screenX, pinTop + bH);
      final stemBot = Offset(screenX, pinTop + bH + 32);
      canvas.drawLine(stemTop, stemBot, stemPaint);

      bgPaint.color = const Color(0xFF7B2FFF);
      canvas.drawCircle(stemBot, 5, bgPaint);
      bgPaint.color = Colors.white;
      canvas.drawCircle(stemBot, 2, bgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ARCameraPainter old) =>
      old.compassHeading != compassHeading ||
      old.wpImages.length != wpImages.length;
}
