import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/features/map/services/photo_geotagging_service.dart';
import 'package:bush_track/core/config/api_config.dart';
import 'package:url_launcher/url_launcher.dart';

class StreetViewScreen extends ConsumerStatefulWidget {
  final LatLng? initialPosition;
  
  const StreetViewScreen({super.key, this.initialPosition});

  @override
  ConsumerState<StreetViewScreen> createState() => _StreetViewScreenState();
}

class _StreetViewScreenState extends ConsumerState<StreetViewScreen> {
  late LatLng _position;
  double _heading = 0;
  double _pitch = 0;
  int _zoom = 1;
  bool _isFullscreen = false;
  final PhotoGeotaggingService _photoService = PhotoGeotaggingService();
  
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
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildStreetView(),
          _buildControls(),
          _buildInfoOverlay(),
        ],
      ),
    );
  }
  
  Widget _buildStreetView() {
    final apiKey = ApiConfig.googleMapsKey;
    
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // Google Maps Satellite View URL
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.panelLight,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryOrange,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.map,
                            size: 50,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Google Maps Satellite View',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_position.latitude.toStringAsFixed(6)}, ${_position.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _openInGoogleMaps,
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open Full Google Maps'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Coordinates overlay
                  Positioned(
                    top: 40,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.primaryOrange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_position.latitude.toStringAsFixed(6)}, ${_position.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.statusGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'SATELLITE',
                              style: TextStyle(color: AppColors.statusGreen, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Map mode selector
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.panelMatte,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMapModeButton(Icons.map, 'Map', () {}),
                _buildMapModeButton(Icons.satellite, 'Satellite', () {}),
                _buildMapModeButton(Icons.terrain, 'Terrain', () {}),
                _buildMapModeButton(Icons.layers, 'Hybrid', () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMapModeButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.panelLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
  
  Widget _buildControls() {
    return SafeArea(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.panelMatte.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildControlButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.pop(context),
                  tooltip: 'Back to map',
                ),
                const Spacer(),
                _buildControlButton(
                  icon: Icons.fullscreen,
                  onTap: () => setState(() => _isFullscreen = !_isFullscreen),
                  tooltip: 'Toggle fullscreen',
                ),
                const SizedBox(width: 8),
                _buildControlButton(
                  icon: Icons.my_location,
                  onTap: _goToCurrentLocation,
                  tooltip: 'Go to my location',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.panelLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
  
  Widget _buildInfoOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Navigation Controls',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDirectionButton(Icons.rotate_left, 'Turn Left', () => _heading -= 45),
                _buildDirectionButton(Icons.arrow_upward, 'Look Forward', () => _pitch = 0),
                _buildDirectionButton(Icons.rotate_right, 'Turn Right', () => _heading += 45),
                _buildDirectionButton(Icons.arrow_downward, 'Look Down', () => _pitch = -30),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildZoomButton(Icons.remove, 'Zoom Out', () {
                  setState(() => _zoom = (_zoom - 1).clamp(1, 4));
                }),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.panelLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Zoom: $_zoom',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 16),
                _buildZoomButton(Icons.add, 'Zoom In', () {
                  setState(() => _zoom = (_zoom + 1).clamp(1, 4));
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDirectionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        onTap();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label: ${_heading.toInt()}°'), duration: const Duration(seconds: 1)),
        );
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.panelLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
  
  Widget _buildZoomButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryOrange,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
  
  void _goToCurrentLocation() {
    final locationState = ref.read(locationProvider);
    if (locationState.stats.currentLat != null) {
      setState(() {
        _position = LatLng(
          locationState.stats.currentLat!,
          locationState.stats.currentLon!,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moved to your current location')),
      );
    }
  }
  
  void _openInGoogleMaps() async {
    final apiKey = ApiConfig.googleMapsKey;
    
    // Open Google Maps with satellite view centered on location
    final mapUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${_position.latitude},${_position.longitude}'
    );
    
    // Open Street View directly
    final streetViewUrl = Uri.parse(
      'https://www.google.com/maps/streetview/?cbp=11,${_heading.toInt()},${_pitch.toInt()},0,0&cbll=${_position.latitude},${_position.longitude}&key=$apiKey'
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.map, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Opening Google Maps at ${_position.latitude.toStringAsFixed(4)}, ${_position.longitude.toStringAsFixed(4)}'),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryOrange,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OPEN',
          textColor: Colors.white,
          onPressed: () async {
            if (await canLaunchUrl(mapUrl)) {
              await launchUrl(mapUrl, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ),
    );
    
    // Try to open automatically
    try {
      await launchUrl(mapUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error opening maps: $e');
    }
  }
}