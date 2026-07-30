import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:bush_track/core/utils/web_helpers.dart';

class StreetViewScreen extends ConsumerStatefulWidget {
  final LatLng? initialPosition;

  const StreetViewScreen({super.key, this.initialPosition});

  @override
  ConsumerState<StreetViewScreen> createState() => _StreetViewScreenState();
}

class _StreetViewScreenState extends ConsumerState<StreetViewScreen> {
  late LatLng _position;
  late final String _viewId;
  bool _frameLoaded = false;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition ?? const LatLng(-25.3444, 131.0369);

    if (widget.initialPosition == null) {
      final locationState = ref.read(locationProvider);
      if (locationState.stats.currentLat != null) {
        _position = LatLng(
          locationState.stats.currentLat!,
          locationState.stats.currentLon!,
        );
      }
    }

    _viewId = 'mapillary_${DateTime.now().millisecondsSinceEpoch}';
    _registerMapillaryView();

    // On mobile there's no iframe — mark as loaded immediately so no spinner
    if (!kIsWeb) {
      _frameLoaded = true;
    } else {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _frameLoaded = true);
      });
    }
  }

  void _registerMapillaryView() {
    if (!kIsWeb) return;
    final url =
        'https://www.mapillary.com/embed?lat=${_position.latitude}&lng=${_position.longitude}&z=17&menu=false';
    registerWebView(_viewId, url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Mapillary iframe embed (web only)
          if (kIsWeb)
            Positioned.fill(
              child: HtmlElementView(viewType: _viewId),
            ),
          if (!kIsWeb)
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.panorama, size: 64, color: AppColors.primaryOrange),
                    const SizedBox(height: 16),
                    const Text('Street view is web-only.\nTap below to open in browser.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _openInBrowser,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open Mapillary'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                    ),
                  ],
                ),
              ),
            ),

          // Loading overlay
          if (!_frameLoaded)
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryOrange, width: 2),
                      ),
                      child: const Icon(Icons.panorama, size: 48, color: AppColors.primaryOrange),
                    ),
                    const SizedBox(height: 16),
                    const Text('Loading Mapillary...', style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(color: AppColors.primaryOrange),
                  ],
                ),
              ),
            ),

          // Top controls overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildButton(Icons.arrow_back, () => Navigator.pop(context)),
                  const Spacer(),
                  _buildButton(Icons.open_in_new, _openInBrowser),
                ],
              ),
            ),
          ),

          // Bottom info bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.primaryOrange, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${_position.latitude.toStringAsFixed(5)}, ${_position.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF1DB954), width: 1),
                    ),
                    child: const Text(
                      'MAPILLARY',
                      style: TextStyle(color: Color(0xFF1DB954), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  void _openInBrowser() async {
    final url = Uri.parse(
        'https://www.mapillary.com/app/?lat=${_position.latitude}&lng=${_position.longitude}&z=17');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error opening Mapillary: $e');
    }
  }
}
