import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/settings/providers/vehicle_profile_provider.dart';
import 'package:bush_track/features/geofence/presentation/geofence_screen.dart';
import 'package:bush_track/features/import_export/presentation/import_export_screen.dart';
import 'package:bush_track/features/gallery/presentation/photo_gallery_screen.dart';
import 'package:bush_track/features/map/presentation/offline_maps_screen.dart';
import 'package:bush_track/features/heritage/presentation/artifact_logger_screen.dart';

IconData _vehicleTypeIcon(VehicleType type) => switch (type) {
      VehicleType.car => Icons.directions_car,
      VehicleType.fourWD => Icons.terrain,
      VehicleType.motorcycle => Icons.two_wheeler,
      VehicleType.walking => Icons.directions_walk,
      VehicleType.cycling => Icons.directions_bike,
      VehicleType.boat => Icons.directions_boat,
      VehicleType.horse => Icons.pets,
    };

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(vehicleProfileProvider);
    final currentProfile = profileState.currentProfile;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.panelMatte,
        title: const Row(children: [
          Icon(Icons.settings, color: AppColors.accent, size: 20),
          SizedBox(width: 8),
          Text('SETTINGS', style: TextStyle(color: Colors.white)),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Vehicle Profile'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: AppColors.accentGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(_vehicleTypeIcon(currentProfile.type),
                            color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentProfile.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Max speed: ${currentProfile.maxSpeed.toInt()} km/h',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.panelLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tips_and_updates, color: AppColors.primaryOrange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ref.read(vehicleProfileProvider.notifier).getRouteAdvice(),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Select your vehicle:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          ...VehicleProfile.profiles.map((profile) {
            final isSelected = profileState.selectedType == profile.type && profileState.customProfile == null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => ref.read(vehicleProfileProvider.notifier).setVehicleType(profile.type),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.2) : AppColors.panelMatte,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected ? Border.all(color: AppColors.primaryOrange) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(_vehicleTypeIcon(profile.type),
                          color: isSelected ? AppColors.accent : AppColors.textMuted,
                          size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          profile.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: AppColors.primaryOrange, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          _buildSectionTitle('Offline Maps'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primaryOrange.withValues(alpha: 0.2)),
            ),
            child: ListTile(
              leading: const Icon(Icons.download_for_offline,
                  color: AppColors.accent, size: 22),
              title: const Text('Offline Map Regions',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text('Download maps for zero-signal use',
                  style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12)),
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const OfflineMapsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Safety'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primaryOrange.withValues(alpha: 0.2)),
            ),
            child: ListTile(
              leading: const Icon(Icons.circle_outlined,
                  color: AppColors.accent, size: 22),
              title: const Text('Geofences',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text('Entry & exit voice alerts',
                  style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12)),
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const GeofenceScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primaryOrange.withValues(alpha: 0.2)),
            ),
            child: ListTile(
              leading: const Icon(Icons.photo_library,
                  color: AppColors.accent, size: 22),
              title: const Text('Photo Gallery',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text('View geotagged photos — tap pin to jump to map',
                  style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12)),
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PhotoGalleryScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primaryOrange.withValues(alpha: 0.2)),
            ),
            child: ListTile(
              leading: const Icon(Icons.import_export,
                  color: AppColors.accent, size: 22),
              title: const Text('GPX / KML Import & Export',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text('Import or export waypoints and trails',
                  style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12)),
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ImportExportScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Enterprise'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.panelMatte,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primaryOrange.withValues(alpha: 0.2)),
            ),
            child: ListTile(
              leading: const Icon(Icons.history_edu,
                  color: AppColors.accent, size: 22),
              title: const Text('Heritage Artifact Logger',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text('Log, photograph & GPS-pin heritage artifacts',
                  style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12)),
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ArtifactLoggerScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Privacy'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.statusGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.statusGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.privacy_tip, color: AppColors.statusGreen, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Privacy First',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'BushTrack never collects your data. All tracking stays on your device. No account required.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}