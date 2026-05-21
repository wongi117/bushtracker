import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:url_launcher/url_launcher.dart';

class SavedPlacesScreen extends ConsumerStatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  ConsumerState<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends ConsumerState<SavedPlacesScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Pins', 'Camp', 'Water', 'Hazard'];

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final waypoints =
        locationState.waypoints.where((wp) => wp.isPin == true).toList();
    final filtered = _applyFilter(waypoints);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SAVED PLACES'),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppColors.primaryOrange, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your pinned waypoints appear here. Drop pins on the map to save locations.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ]),
          ),

          // Category filter chips
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _filters.map((f) {
                final isSelected = _selectedFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f,
                        style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontSize: 12)),
                    selected: isSelected,
                    selectedColor: AppColors.primaryOrange,
                    backgroundColor: AppColors.panelMatte,
                    onSelected: (_) => setState(() => _selectedFilter = f),
                  ),
                );
              }).toList(),
            ),
          ),

          // Places list
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildPlaceCard(filtered[index], locationState),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryOrange,
        icon: const Icon(Icons.info_outline, color: Colors.black),
        label: const Text('Drop pins on map',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Long-press on the map to drop a pin and save a location.'),
              backgroundColor: AppColors.primaryOrange,
              duration: Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  List<Waypoint> _applyFilter(List<Waypoint> waypoints) {
    switch (_selectedFilter) {
      case 'Camp':
        return waypoints
            .where((w) =>
                w.icon == WaypointIcon.camp ||
                (w.label ?? '').toLowerCase().contains('camp'))
            .toList();
      case 'Water':
        return waypoints
            .where((w) =>
                w.icon == WaypointIcon.water ||
                (w.label ?? '').toLowerCase().contains('water') ||
                (w.label ?? '').toLowerCase().contains('tank') ||
                (w.label ?? '').toLowerCase().contains('bore'))
            .toList();
      case 'Hazard':
        return waypoints
            .where((w) =>
                w.icon == WaypointIcon.hazard ||
                (w.label ?? '').toLowerCase().contains('hazard') ||
                (w.label ?? '').toLowerCase().contains('danger'))
            .toList();
      case 'Pins':
        return waypoints
            .where((w) => w.type == WaypointType.manual)
            .toList();
      default:
        return waypoints;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'All'
                  ? 'No saved places yet'
                  : 'No $_selectedFilter places found',
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Long-press on the map to drop a pin and save a location.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceCard(Waypoint waypoint, LocationState locationState) {
    final lat = waypoint.latitude;
    final lon = waypoint.longitude;
    final hasCoords = lat != null && lon != null;

    String distanceText = '';
    if (hasCoords &&
        locationState.stats.currentLat != null &&
        locationState.stats.currentLon != null) {
      final dlat = lat - locationState.stats.currentLat!;
      final dlon = lon - locationState.stats.currentLon!;
      final approxM = ((dlat * dlat + dlon * dlon) * 111000).abs();
      distanceText = approxM > 1000
          ? '${(approxM / 1000).toStringAsFixed(1)} km away'
          : '${approxM.toStringAsFixed(0)} m away';
    }

    final iconColor = _iconColor(waypoint.icon);
    final iconData = WaypointIcon.getIconData(waypoint.icon);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(iconData, color: iconColor, size: 22),
        ),
        title: Text(
          waypoint.label ?? 'Unnamed Pin',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (waypoint.notes != null && waypoint.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(waypoint.notes!,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            if (distanceText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(distanceText,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
            if (hasCoords)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                    '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontFamily: 'monospace')),
              ),
          ],
        ),
        trailing: hasCoords
            ? IconButton(
                icon:
                    const Icon(Icons.navigation, color: AppColors.primaryOrange),
                tooltip: 'Navigate here',
                onPressed: () => _navigateTo(waypoint),
              )
            : null,
      ),
    );
  }

  Color _iconColor(String? icon) {
    switch (icon) {
      case WaypointIcon.camp:
        return Colors.brown;
      case WaypointIcon.water:
        return Colors.blue;
      case WaypointIcon.hazard:
        return Colors.red;
      case WaypointIcon.fuel:
        return Colors.green;
      default:
        return AppColors.primaryOrange;
    }
  }

  Future<void> _navigateTo(Waypoint waypoint) async {
    final lat = waypoint.latitude!;
    final lon = waypoint.longitude!;
    final name = Uri.encodeComponent(waypoint.label ?? 'Waypoint');
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&destination_place_id=$name');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Maps')),
      );
    }
  }
}
