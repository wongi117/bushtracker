import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/features/navigation/providers/navigation_provider.dart';

class RouteOptionsScreen extends ConsumerStatefulWidget {
  const RouteOptionsScreen({super.key});

  @override
  ConsumerState<RouteOptionsScreen> createState() => _RouteOptionsScreenState();
}

class _RouteOptionsScreenState extends ConsumerState<RouteOptionsScreen> {
  final TextEditingController _destController = TextEditingController();
  String? _selectedMode = 'driving';
  bool _isRouting = false;

  final List<_NavMode> _modes = const [
    _NavMode('driving', Icons.directions_car, 'Driving', 'Best for roads & tracks'),
    _NavMode('walking', Icons.directions_walk, 'Walking', 'Foot track & hiking'),
    _NavMode('bicycling', Icons.directions_bike, 'Cycling', 'Bike-friendly routes'),
  ];

  @override
  void dispose() {
    _destController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final hasGPS = locationState.stats.currentLat != null;
    final lat = locationState.stats.currentLat ?? -25.3444;
    final lon = locationState.stats.currentLon ?? 131.0369;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('🧭 Route Navigation'),
        backgroundColor: AppColors.panelMatte,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Your location card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasGPS
                    ? AppColors.statusGreen.withValues(alpha: 0.4)
                    : Colors.orange.withValues(alpha: 0.4),
              ),
            ),
            child: Row(children: [
              Icon(
                hasGPS ? Icons.my_location : Icons.location_searching,
                color: hasGPS ? AppColors.statusGreen : Colors.orange,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    hasGPS ? 'Your Location' : 'Acquiring GPS...',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    hasGPS
                        ? '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}'
                        : 'Step outside for a GPS fix',
                    style: TextStyle(
                      color: hasGPS ? Colors.white54 : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Destination input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Destination',
                  style: TextStyle(
                      color: AppColors.goldPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _destController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Town, landmark, or address...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  suffixIcon: _destController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38),
                          onPressed: () {
                            _destController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.panelLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Travel mode
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Travel Mode',
                  style: TextStyle(
                      color: AppColors.goldPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: _modes.map((mode) {
                  final isSelected = _selectedMode == mode.id;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMode = mode.id),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryOrange.withValues(alpha: 0.2)
                              : AppColors.panelLight,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: AppColors.primaryOrange, width: 2)
                              : null,
                        ),
                        child: Column(children: [
                          Icon(mode.icon,
                              color: isSelected
                                  ? AppColors.primaryOrange
                                  : Colors.white54,
                              size: 22),
                          const SizedBox(height: 4),
                          Text(mode.label,
                              style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primaryOrange
                                      : Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Quick destinations
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Quick Options',
                  style: TextStyle(
                      color: AppColors.goldPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Tap to fill destination',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Nearest town',
                  'Nearest fuel',
                  'Nearest hospital',
                  'Nearest campsite',
                  'Nearest water',
                ].map((q) {
                  return GestureDetector(
                    onTap: () {
                      _destController.text = q;
                      setState(() {});
                    },
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.panelLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primaryOrange.withValues(alpha: 0.3)),
                      ),
                      child: Text(q,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Info box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Navigation opens Google Maps / Apple Maps with your GPS position as the start point.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: const BoxDecoration(
          color: AppColors.panelMatte,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // In-app routing via OSRM
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _destController.text.trim().isEmpty
                      ? AppColors.panelLight
                      : AppColors.statusBlue,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isRouting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.navigation),
                label: Text(
                  _isRouting ? 'Calculating...' : 'Navigate In-App',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: (_destController.text.trim().isEmpty || _isRouting)
                    ? null
                    : () => _navigateInApp(),
              ),
            ),
            const SizedBox(height: 10),
            // External maps fallback
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: AppColors.panelLight),
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open in Google Maps'),
                onPressed: _destController.text.trim().isEmpty
                    ? null
                    : () => _openInMaps(lat, lon),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateInApp() async {
    final dest = _destController.text.trim();
    setState(() => _isRouting = true);
    try {
      await ref.read(navigationProvider.notifier).calculateRoute(dest);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Routing to $dest'),
          backgroundColor: AppColors.statusBlue,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not find route to $dest'),
          backgroundColor: AppColors.statusRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  Future<void> _openInMaps(double fromLat, double fromLon) async {
    final dest = Uri.encodeComponent(_destController.text.trim());
    final mode = _selectedMode ?? 'driving';

    // Try Google Maps first
    final googleUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$fromLat,$fromLon&destination=$dest&travelmode=$mode');

    // Apple Maps fallback
    final appleUri = Uri.parse(
        'https://maps.apple.com/?saddr=$fromLat,$fromLon&daddr=$dest&dirflg=${_appleMode(mode)}');

    // Skip canLaunchUrl — returns false on web for https:// schemes.
    // Try Google Maps; fall back to Apple Maps on failure.
    final launched = await launchUrl(googleUri, mode: LaunchMode.externalApplication);
    if (!launched) {
      final launchedApple = await launchUrl(appleUri, mode: LaunchMode.externalApplication);
      if (!launchedApple && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open Maps'),
          backgroundColor: AppColors.statusRed,
        ));
      }
    }
  }

  String _appleMode(String mode) {
    switch (mode) {
      case 'walking':
        return 'w';
      case 'bicycling':
        return 'b';
      default:
        return 'd';
    }
  }
}

class _NavMode {
  final String id;
  final IconData icon;
  final String label;
  final String subtitle;
  const _NavMode(this.id, this.icon, this.label, this.subtitle);
}
