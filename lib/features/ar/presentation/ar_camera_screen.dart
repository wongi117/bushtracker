import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/services/heading/heading_provider.dart';
import 'package:bush_track/features/ai/presentation/identify_result_sheet.dart';
import 'package:bush_track/features/ai/services/vision_service.dart';
import 'package:bush_track/features/ar/presentation/distant_pin_sheet.dart';
import 'package:bush_track/features/ar/presentation/photo_pin_sheet.dart';
import 'package:bush_track/features/ar/services/ar_compass_service.dart';
import 'package:bush_track/features/ar/presentation/ar_pin_sheet.dart';
import 'package:bush_track/features/ar/services/ar_projection.dart';
import 'package:bush_track/features/ar/services/ar_targets.dart';
import 'package:bush_track/features/map/providers/marker_visibility_provider.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/features/tracking/providers/track_target_provider.dart';
import 'package:bush_track/theme/app_colors.dart';

/// Print the computed AR geometry to the log while testing.
///
/// Build with --dart-define=DEBUG_AR=true to check heading, pitch and where
/// each pin lands, without shipping the noise to everyone.
const bool kDebugAr =
    bool.fromEnvironment('DEBUG_AR', defaultValue: false);

class ARCameraScreen extends ConsumerStatefulWidget {
  const ARCameraScreen({super.key});

  @override
  ConsumerState<ARCameraScreen> createState() => _ARCameraScreenState();
}

class _ARCameraScreenState extends ConsumerState<ARCameraScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the beam pulse and the ground rings.
  late final AnimationController _beam;
  CameraController? _controller;
  bool _cameraReady = false;

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
    // The beam keeps running regardless of platform so the overlay is alive
    // even where the camera itself is not.
    _beam = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _hold = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _dropDistantPin();
      });
    _beam.addListener(() {
      if (mounted) setState(() {});
    });

    // Camera plugin is unreliable on web, and build() shows a "not available"
    // screen there — but the heading now comes from the shared provider, so
    // there is nothing sensor-related left to set up here.
    if (kIsWeb) return;
    _arService = ref.read(arCompassServiceProvider);
    _initCamera();
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
    _controller?.dispose();
    for (final image in _wpImages.values) {
      image.dispose();
    }
    _beam.dispose();
    _hold.dispose();
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

  bool _identifying = false;
  final _vision = VisionService();

  /// Where a finger is being held to drop a distant pin, and how far through
  /// the three seconds it is.
  Offset? _holdAt;
  late final AnimationController _hold;

  /// Heading and tilt as of the moment the hold started.
  ///
  /// Frozen deliberately: the pin belongs where the camera was pointed when
  /// you pressed, not wherever your hand has drifted to three seconds later.
  double _holdHeading = 0;
  double _holdPitch = 0;
  double _holdRoll = 0;

  /// Where each pin landed on the last frame.
  ///
  /// Worked out once per build and handed to both the painter and the tap
  /// handler. Working it out twice is how they come to disagree, and a label
  /// drawn in one place but tappable in another reads as a tap being ignored.
  List<ArTarget> _targets = const [];

  /// Last lens bearing worth having. Null until one is measured.
  ///
  /// The stream sends `waiting` before the first fix and can drop back to
  /// `unavailable`, and taking zero degrees in those moments drew the entire
  /// scene as though the phone faced north — every marker in the wrong place,
  /// all of them jumping the instant a real bearing arrived. Holding the last
  /// real reading keeps the overlay still, and `hasHeading` in build says
  /// whether there is anything worth drawing yet.
  HeadingReading? _liveHeading;

  void _retake() {
    setState(() => _capturedBytes = null);
  }

  /// Work out where every pin lands this frame.
  ///
  /// Called from build. Stores the result for [_onArTap] as well as handing it
  /// to the painter, so what is drawn and what is tappable cannot drift apart.
  List<ArTarget> _buildTargets({
    required List<Waypoint> waypoints,
    required LatLng here,
    required Size size,
    required double headingDeg,
    required double pitchRad,
    required double rollRad,
  }) {
    final targets = buildArTargets(
      waypoints: waypoints,
      currentLocation: here,
      projection: ArProjection(
        size: size,
        headingDeg: headingDeg,
        pitchRad: pitchRad,
        rollRad: rollRad,
      ),
      size: size,
      beamHeightM: _ARCameraPainter.beamHeightM,
      minBeamPixels: _ARCameraPainter.minBeamPixels,
    );
    _targets = targets;
    return targets;
  }

  /// A tap through the camera: which pin did that mean?
  Future<void> _onArTap(Offset at) async {
    if (_capturedBytes != null) return; // reviewing a photo, not looking live
    final hit = hitTest(_targets, at);
    if (hit == null) return;

    HapticFeedback.selectionClick();
    await showArPinSheet(
      context,
      target: hit,
      onShowOnMap: () => Navigator.of(context)
        ..pop() // the sheet
        ..pop(), // the AR screen, back to the map
    );
  }

  /// Start the three-second hold that drops a pin out where you are looking.
  void _beginHold(Offset at, double heading, double pitch, double roll) {
    if (_capturedBytes != null) return; // reviewing a photo, not looking live
    setState(() {
      _holdAt = at;
      _holdHeading = heading;
      _holdPitch = pitch;
      _holdRoll = roll;
    });
    _hold.forward(from: 0);
  }

  void _cancelHold() {
    if (_holdAt == null) return;
    _hold.stop();
    setState(() => _holdAt = null);
  }

  /// Drop a pin on the patch of ground the finger was over.
  ///
  /// The whole point is not having to walk there: look at a tree two hundred
  /// metres off, hold on it, and the pin lands on that spot rather than on
  /// top of you.
  Future<void> _dropDistantPin() async {
    final at = _holdAt;
    setState(() => _holdAt = null);
    if (at == null || !mounted) return;

    final stats = ref.read(locationProvider).stats;
    if (stats.currentLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No GPS fix yet — a distant pin needs to know where '
            'you are standing first.'),
        backgroundColor: AppColors.statusRed,
      ));
      return;
    }

    final size = MediaQuery.of(context).size;
    final projection = ArProjection(
      size: size,
      headingDeg: _holdHeading,
      pitchRad: _holdPitch,
      rollRad: _holdRoll,
    );

    final ground = projection.groundAt(at);
    if (ground == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('That is on or above the horizon — aim a bit lower, at '
            'the ground you mean.'),
        backgroundColor: AppColors.primaryOrange,
      ));
      return;
    }

    final here = LatLng(stats.currentLat!, stats.currentLon!);
    final there = const Distance()
        .offset(here, ground.distanceM, ground.bearingDeg);

    HapticFeedback.mediumImpact();

    if (kDebugAr) {
      debugPrint('🎯 AR drop: screen=$at heading=${_holdHeading.toStringAsFixed(1)} '
          'bearing=${ground.bearingDeg.toStringAsFixed(1)} '
          'dist=${ground.distanceM.toStringAsFixed(0)}m '
          '=> ${there.latitude.toStringAsFixed(6)}, ${there.longitude.toStringAsFixed(6)}');
    }

    final details = await showDistantPinSheet(
      context,
      distanceM: ground.distanceM,
      bearingDeg: ground.bearingDeg,
      position: there,
    );
    if (details == null || !mounted) return;

    await ref.read(locationProvider.notifier).addManualWaypoint(
          there.latitude,
          there.longitude,
          details.name,
          notes: details.notes,
          color: details.colorHex,
          icon: details.icon,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Dropped "${details.name}" '
          '${ground.distanceM.round()} m away'),
      backgroundColor: AppColors.statusGreen,
    ));
  }

  /// Send the captured photo away to be identified, then offer to carry on
  /// talking to the assistant about what came back.
  Future<void> _identify(IdentifyMode mode) async {
    if (_capturedBytes == null || _identifying) return;
    setState(() => _identifying = true);

    try {
      // Same compression as the pin path: a 1200px JPEG is plenty for
      // identification and keeps the upload small on a weak connection.
      final decoded = img.decodeImage(_capturedBytes!);
      var bytes = _capturedBytes!;
      if (decoded != null) {
        final resized = img.copyResize(decoded,
            width: decoded.width > 1200 ? 1200 : decoded.width);
        bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 80));
      }

      final result = await _vision.identify(
        mode: mode,
        jpegBase64: base64Encode(bytes),
      );

      if (!mounted) return;
      setState(() => _identifying = false);

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Could not identify — this needs a signal. The photo is still '
              'here, try again when you have bars.'),
          backgroundColor: AppColors.statusRed,
          duration: Duration(seconds: 4),
        ));
        return;
      }

      final wantsToTalk = await showIdentifyResult(context, result);
      if (!wantsToTalk || !mounted) return;

      // Hand the result back to the map screen, which opens the chat with it.
      // Sending it from here would reach the assistant but not the chat's own
      // message list, so the reply would land nowhere the user can see.
      Navigator.pop(context, result.toPrompt());
    } catch (e) {
      debugPrint('Identify error: $e');
      if (mounted) setState(() => _identifying = false);
    }
  }

  Future<void> _savePin() async {
    if (_capturedBytes == null || _saving) return;

    // Compress first so the sheet previews exactly what gets stored.
    final decoded = img.decodeImage(_capturedBytes!);
    var compressed = _capturedBytes!;
    if (decoded != null) {
      final resized = img.copyResize(decoded,
          width: decoded.width > 1200 ? 1200 : decoded.width);
      compressed = Uint8List.fromList(img.encodeJpg(resized, quality: 80));
    }

    final stats = ref.read(locationProvider).stats;
    final lat = stats.currentLat;
    final lon = stats.currentLon;

    final details = await showPhotoPinSheet(
      context,
      photo: compressed,
      positionLabel: lat == null
          ? 'No GPS fix — position not recorded'
          : '${lat.toStringAsFixed(5)}, ${lon!.toStringAsFixed(5)}',
      accuracyLabel:
          lat == null ? null : 'to within ${stats.currentAccuracyM.round()} m',
    );
    if (details == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final base64Uri = 'data:image/jpeg;base64,${base64Encode(compressed)}';

      // One step, and it hands back the pin it made.
      //
      // This used to create a nameless pin and then search the list for it by
      // matching the label it had just written — which would have picked the
      // wrong pin the moment two shared a name.
      await ref.read(locationProvider.notifier).addPhotoWaypoint(
            lat: lat ?? 0.0,
            lon: lon ?? 0.0,
            photoPath: base64Uri,
            thumbnailPath: base64Uri,
            label: details.name,
            notes: details.notes,
            type: WaypointType.pinage,
            color: '#7B2FFF',
            icon: 'pinage',
            fileId: details.fileId,
            useOpenFile: false,
          );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved "${details.name}"'),
        backgroundColor: const Color(0xFF7B2FFF),
      ));
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
            // Respect the same show/hide choice the map uses, so the camera
            // shows the project you are working on and not four days of other
            // work in the same paddock.
            if (!ref
                .watch(markerVisibilityProvider)
                .showsPin(id: wp.id, fileId: wp.fileId)) {
              return false;
            }
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

    // Shared tilt-compensated compass (see core/services/heading).
    //
    // The lens bearing, not `degrees`. `degrees` is where the top edge points,
    // which is what a compass rose wants and is degenerate exactly here: held
    // up to look through the camera, the top edge points at the sky. Anchoring
    // markers to it is why they travelled along with the camera rather than
    // staying on their feature.
    final headingReading = ref.watch(headingProvider).valueOrNull;
    if (headingReading != null && headingReading.hasCameraBearing) {
      _liveHeading = headingReading;
    }
    final held = _liveHeading;
    final hasHeading = held?.cameraDegrees != null;
    final compassHeading = held?.cameraDegrees ?? 0.0;
    final pitchRad = held?.pitchRad ?? 0.0;
    final rollRad = held?.rollRad ?? 0.0;

    // Where every pin lands this frame, for the painter and for taps alike.
    final screen = MediaQuery.of(context).size;
    if (hasHeading && currentLat != null && currentLon != null) {
      _buildTargets(
        waypoints: visibleWaypoints,
        here: LatLng(currentLat, currentLon),
        size: screen,
        headingDeg: compassHeading,
        pitchRad: pitchRad,
        rollRad: rollRad,
      );
    } else {
      _targets = const [];
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

          // ── Hold anywhere on the view to drop a pin out there
          if (_capturedBytes == null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (d) => _onArTap(d.localPosition),
                onLongPressDown: (d) => _beginHold(
                    d.localPosition, compassHeading, pitchRad, rollRad),
                onLongPressCancel: _cancelHold,
                onLongPressUp: _cancelHold,
                // Moving the finger means aiming somewhere else, so start the
                // three seconds again rather than dropping a pin on the spot
                // it happened to begin at.
                onLongPressMoveUpdate: (d) {
                  final start = _holdAt;
                  if (start == null) return;
                  if ((d.localPosition - start).distance > 28) {
                    _beginHold(
                        d.localPosition, compassHeading, pitchRad, rollRad);
                  }
                },
              ),
            ),

          // ── The hold, drawn where the finger is
          if (_holdAt != null)
            Positioned(
              left: _holdAt!.dx - 46,
              top: _holdAt!.dy - 46,
              child: IgnorePointer(
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _hold.value,
                        strokeWidth: 4,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent),
                      ),
                      Icon(Icons.push_pin,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 26),
                    ],
                  ),
                ),
              ),
            ),

          // ── AR pin overlays (live mode only)
          //
          // The projection and the targets are built here, not in the painter,
          // so the tap handler above is matching against the same geometry
          // that gets drawn.
          // Nothing is drawn until there is a real bearing: without one the
          // only choice is to guess north, which puts every marker somewhere
          // it is not and then jumps them all when the compass wakes up.
          if (_capturedBytes == null &&
              hasHeading &&
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
                  targets: _targets,
                  currentLocation: LatLng(currentLat, currentLon),
                  compassHeading: compassHeading,
                  arService: _arService,
                  wpImages: Map.unmodifiable(_wpImages),
                  beamPhase: _beam.value,
                  target: ref.watch(trackTargetProvider),
                  pitchRad: pitchRad,
                  rollRad: rollRad,
                  debugGeometry: kDebugAr,
                ),
              ),
            ),

          // No compass, no overlay. This used to fall back to zero degrees,
          // which drew every marker as though you were facing north: they then
          // sat wherever they happened to land and did not move when you
          // turned, so the only way to tell was that one of them lined up with
          // the real thing once you were pointed at it. An empty screen with a
          // reason on it is far better than a confident wrong answer.
          if (!hasHeading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 74,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.statusRed.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.explore_off, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Waiting for the compass — hold the phone up and wave '
                      'it in a figure-8. Pins stay hidden until it knows '
                      'which way the camera is pointed.',
                      style: TextStyle(
                          color: Colors.white, fontSize: 12, height: 1.3),
                    ),
                  ),
                ]),
              ),
            ),

          // Where a marker lands is only as good as the heading. Near a
          // vehicle body or a UHF the field is distorted and everything can
          // be tens of degrees out — worth saying so rather than quietly
          // drawing pins in the wrong place.
          if (hasHeading && headingReading != null && headingReading.needsCalibration)
            Positioned(
              top: MediaQuery.of(context).padding.top + 74,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.statusRed.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.explore_off, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Compass needs calibrating — wave the phone in a '
                      'figure-8, and step away from the vehicle',
                      style: TextStyle(
                          color: Colors.white, fontSize: 12, height: 1.3),
                    ),
                  ),
                ]),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _identifyButton(
                  IdentifyMode.rock, Icons.terrain, 'IDENTIFY ROCK'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _identifyButton(
                  IdentifyMode.plant, Icons.local_florist, 'IDENTIFY PLANT'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildSaveRow(),
      ],
    );
  }

  Widget _identifyButton(IdentifyMode mode, IconData icon, String label) {
    return GestureDetector(
      onTap: _identifying ? null : () => _identify(mode),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _identifying ? 0.06 : 0.14),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_identifying)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent),
              )
            else
              Icon(icon, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            Text(
              _identifying ? 'LOOKING...' : label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveRow() {
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
  /// Where each pin landed, worked out by the screen so that what is drawn and
  /// what can be tapped are the same thing.
  final List<ArTarget> targets;
  final LatLng currentLocation;
  final double compassHeading;
  final ARCompassService arService;
  final Map<int, ui.Image> wpImages;

  /// 0-1, loops. Drives the ring expansion and the beam shimmer.
  final double beamPhase;

  /// What is being tracked, if anything, so the way there can be drawn on
  /// the ground rather than only described in a panel.
  final TrackTarget? target;

  /// Camera tilt and roll, so the horizon sits where it really is.
  final double pitchRad;
  final double rollRad;

  /// Prints the computed geometry to the log while testing.
  final bool debugGeometry;

  _ARCameraPainter({
    required this.targets,
    required this.currentLocation,
    required this.compassHeading,
    required this.arService,
    required this.wpImages,
    required this.beamPhase,
    this.target,
    this.pitchRad = 0,
    this.rollRad = 0,
    this.debugGeometry = false,
  });

  /// How tall a beam stands in the world, in metres.
  ///
  /// Real height rather than a screen size, so a beam behaves like an object
  /// in the scene: towering when you are next to it, a sliver on the horizon
  /// from kilometres away.
  static const double beamHeightM = 60;

  /// Floors so a distant marker stays findable instead of shrinking to
  /// nothing. Honest geometry, with a minimum you can actually see.
  static const double _minBeamHalfWidth = 5;
  static const double minBeamPixels = 80;

  @override
  void paint(Canvas canvas, Size size) {
    final projection = ArProjection(
      size: size,
      headingDeg: compassHeading,
      pitchRad: pitchRad,
      rollRad: rollRad,
    );

    // Roll used to be handled by spinning the whole canvas, which turned the
    // artwork as well as the positions: beams leaned over, labels went
    // sideways, and because the sign was inverted they leaned the same way as
    // the phone instead of against it — twice the tilt rather than none. Now
    // the roll lives inside the projection, so it moves where a marker sits
    // without touching how it is drawn. Each beam stays upright on screen
    // with its base glued to its own patch of ground.
    _drawGroundTrack(canvas, size, projection);

    // Already farthest first, so nearer pins render on top.
    for (final target in targets) {
      final wp = target.waypoint;
      final bearing = target.bearingDeg;
      final distance = target.distanceM;
      final base = target.base;
      final beamPixels = target.beamPixels;
      final colour = WaypointColors.fromHex(wp.color);

      if (debugGeometry) {
        debugPrint('🎯 AR ${wp.label ?? 'pin'}: '
            'bearing=${bearing.toStringAsFixed(1)} '
            'rel=${(projection.relativeBearing(bearing) * 180 / math.pi).toStringAsFixed(1)} '
            'dist=${distance.toStringAsFixed(0)}m '
            'base=${base.dx.toStringAsFixed(0)},${base.dy.toStringAsFixed(0)} '
            'beam=${beamPixels.toStringAsFixed(0)}px '
            'horizon=${projection.horizonY.toStringAsFixed(0)}');
      }

      _drawBeam(canvas, projection,
          base: base,
          beamPixels: beamPixels,
          distance: distance,
          colour: colour);
      _drawLabel(canvas, size, wp, base, beamPixels, distance, colour);
    }
  }

  /// A column of light standing on the pin's real position.
  ///
  /// [base] is where that patch of ground lands on the image, roll and all,
  /// and [beamPixels] how tall the column is from there. The column itself is
  /// drawn upright on screen: a real beam of light would lean when you tilt
  /// the handset, but a leaning beam reads as a bug and puts the label on its
  /// side, and what matters for finding the thing is that the base sits on it.
  void _drawBeam(
    Canvas canvas,
    ArProjection projection, {
    required Offset base,
    required double beamPixels,
    required double distance,
    required Color colour,
  }) {
    // Width comes from how big the thing really is and how far away it is —
    // the same beam, seen from further back.
    final halfWidth =
        math.max(projection.apparentWidth(3, distance) / 2, _minBeamHalfWidth);
    final x = base.dx;
    final groundY = base.dy;
    final topY = groundY - beamPixels;

    final rect =
        Rect.fromLTRB(x - halfWidth * 2.2, topY, x + halfWidth * 2.2, groundY);
    if (!rect.isFinite || rect.height <= 0) return;

    canvas.saveLayer(rect.inflate(24), Paint());

    final crossSection = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x - halfWidth * 2.2, 0),
        Offset(x + halfWidth * 2.2, 0),
        [
          colour.withValues(alpha: 0.0),
          colour.withValues(alpha: 0.28),
          colour.withValues(alpha: 0.85),
          Color.lerp(colour, Colors.white, 0.75)!,
          colour.withValues(alpha: 0.85),
          colour.withValues(alpha: 0.28),
          colour.withValues(alpha: 0.0),
        ],
        const [0.0, 0.22, 0.4, 0.5, 0.6, 0.78, 1.0],
      );
    canvas.drawRect(rect, crossSection);

    // Fade towards the top so the column has no hard edge.
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset(0, topY),
          Offset(0, groundY),
          [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.7),
            Colors.white,
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    canvas.restore();

    // Glow where the column meets the ground.
    canvas.drawOval(
      Rect.fromCenter(
          center: base, width: halfWidth * 5, height: halfWidth * 1.5),
      Paint()
        ..color = colour.withValues(alpha: 0.35)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 14),
    );

    // Rings spreading out across the ground at the pin's feet, not yours.
    for (var i = 0; i < 3; i++) {
      final phase = (beamPhase + i / 3) % 1.0;
      final spread = 0.35 + phase * 1.5;
      final fade = (1 - phase).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: base,
          width: halfWidth * 4.4 * spread,
          height: halfWidth * 1.3 * spread,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * fade
          ..color = colour.withValues(alpha: 0.75 * fade),
      );
    }

    // A marker at the top of the column so it is findable against the sky.
    final pulse = 0.85 + 0.15 * math.sin(beamPhase * math.pi * 2);
    canvas.drawCircle(
      Offset(x, topY),
      math.max(halfWidth * 0.62, 4) * pulse,
      Paint()
        ..color = colour.withValues(alpha: 0.55)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      Offset(x, topY),
      math.max(halfWidth * 0.32, 2.5) * pulse,
      Paint()..color = Color.lerp(colour, Colors.white, 0.6)!,
    );
  }

  /// Name, distance and photo, sitting just above the beam.
  ///
  /// Always the right way up, whatever the phone is doing. A label is there to
  /// be read, and the thing that has to be accurate is the beam's foot.
  void _drawLabel(
    Canvas canvas,
    Size size,
    Waypoint wp,
    Offset base,
    double beamPixels,
    double distance,
    Color colour,
  ) {
    final photoImg = (wp.id != null) ? wpImages[wp.id!] : null;
    const photoSize = 64.0;
    const pH = 10.0;
    const pV = 8.0;
    const photoGap = 6.0;

    final distText = distance >= 1000
        ? '${(distance / 1000).toStringAsFixed(1)} km'
        : '${distance.toStringAsFixed(0)} m';

    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(
          text: '${wp.label ?? 'Pin'}\n',
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
    final bH =
        pV + (photoImg != null ? (photoSize + photoGap) : 0) + tp.height + pV;

    final x = base.dx;
    final beamTop = base.dy - beamPixels;

    // Above the top of the beam, kept on screen so a pin high overhead or
    // below the frame still has a readable label.
    final top = (beamTop - bH - 10).clamp(4.0, size.height - bH - 4);

    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - bW / 2, top, bW, bH),
      const Radius.circular(12),
    );

    canvas.drawRRect(
        bubbleRect,
        Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF0D0F1E).withValues(alpha: 0.88));
    canvas.drawRRect(
        bubbleRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = colour.withValues(alpha: 0.9));

    var textY = top + pV;
    if (photoImg != null) {
      final photoRect =
          Rect.fromLTWH(x - photoSize / 2, top + pV, photoSize, photoSize);
      canvas.save();
      canvas.clipRRect(
          RRect.fromRectAndRadius(photoRect, const Radius.circular(8)));
      canvas.drawImageRect(
        photoImg,
        Rect.fromLTWH(
            0, 0, photoImg.width.toDouble(), photoImg.height.toDouble()),
        photoRect,
        Paint(),
      );
      canvas.restore();
      textY += photoSize + photoGap;
    }
    tp.paint(canvas, Offset(x - tp.width / 2, textY));

    // Connector from the label down to the top of the beam.
    canvas.drawLine(
      Offset(x, top + bH),
      Offset(x, math.max(top + bH, beamTop)),
      Paint()
        ..strokeWidth = 2
        ..color = colour.withValues(alpha: 0.85),
    );
  }

  /// The way to whatever is being tracked, drawn along the ground.
  ///
  /// Each step is a real point between here and there, projected the same way
  /// as everything else — so the path lies on the ground and runs out to the
  /// destination rather than being a fixed shape near the bottom of the
  /// screen.
  void _drawGroundTrack(Canvas canvas, Size size, ArProjection projection) {
    final t = target;
    if (t == null) return;

    final bearing = arService.calculateBearing(currentLocation, t.position);
    final distance = arService.calculateDistance(currentLocation, t.position);

    if (!projection.isInView(bearing)) {
      _drawOffScreenArrow(
          canvas, size, projection.relativeBearing(bearing), t.colour);
      return;
    }

    // Steps spaced along the real ground, close together near you where
    // perspective spreads them out, wider further away.
    const steps = 14;
    final points = <Offset>[];
    for (var i = 1; i <= steps; i++) {
      final f = i / steps;
      // Squared so samples bunch towards the far end, matching how the
      // ground compresses towards the horizon.
      final along = distance * f * f;
      if (along < 2) continue;
      points.add(projection.project(bearing, along));
    }
    if (points.length < 2) return;

    // The path itself.
    final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = t.colour.withValues(alpha: 0.5),
    );

    // Chevrons flowing along it, sized by how far away each one is.
    for (var i = 0; i < steps; i++) {
      final f = ((i / steps) + beamPhase / steps) % 1.0;
      final along = math.max(distance * f * f, 2.0);
      final at = projection.project(bearing, along);
      final x = at.dx;
      final y = at.dy;
      // A chevron three metres across on the ground.
      final halfW = math.max(projection.apparentWidth(3, along) / 2, 3);
      final depth = halfW * 0.5;
      final fade = (1 - f * 0.7).clamp(0.0, 1.0);

      final chevron = ui.Path()
        ..moveTo(x - halfW, y)
        ..lineTo(x, y - depth)
        ..lineTo(x + halfW, y)
        ..lineTo(x, y - depth * 0.35)
        ..close();

      canvas.drawPath(
          chevron, Paint()..color = t.colour.withValues(alpha: 0.8 * fade));
    }

    if (debugGeometry) {
      debugPrint('🎯 AR track "${t.name}": bearing=${bearing.toStringAsFixed(1)} '
          'dist=${distance.toStringAsFixed(0)}m '
          'heading=${compassHeading.toStringAsFixed(1)} '
          'pitch=${(pitchRad * 180 / math.pi).toStringAsFixed(1)} '
          'roll=${(rollRad * 180 / math.pi).toStringAsFixed(1)} '
          'horizon=${projection.horizonY.toStringAsFixed(0)}');
    }
  }

  /// A chevron pinned to the screen edge when the target is out of frame.
  void _drawOffScreenArrow(
      Canvas canvas, Size size, double relRad, Color colour) {
    final onRight = relRad > 0;
    final x = onRight ? size.width - 46.0 : 46.0;
    final y = size.height * 0.55;
    final dir = onRight ? 1.0 : -1.0;

    final path = ui.Path()
      ..moveTo(x - 16 * dir, y - 26)
      ..lineTo(x + 16 * dir, y)
      ..lineTo(x - 16 * dir, y + 26)
      ..lineTo(x - 4 * dir, y)
      ..close();

    canvas.drawPath(path, Paint()..color = colour.withValues(alpha: 0.85));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _ARCameraPainter old) =>
      old.targets.length != targets.length ||
      old.compassHeading != compassHeading ||
      old.pitchRad != pitchRad ||
      old.rollRad != rollRad ||
      old.wpImages.length != wpImages.length ||
      old.beamPhase != beamPhase ||
      old.target != target;
}
