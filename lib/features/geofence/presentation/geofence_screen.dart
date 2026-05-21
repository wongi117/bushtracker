import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/geofence/providers/geofence_provider.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/core/models/geofence.dart';

class GeofenceScreen extends ConsumerStatefulWidget {
  const GeofenceScreen({super.key});

  @override
  ConsumerState<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends ConsumerState<GeofenceScreen> {
  @override
  Widget build(BuildContext context) {
    final geofenceState = ref.watch(geofenceProvider);
    final fences = geofenceState.geofences;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.panelMatte,
        title: const Row(children: [
          Icon(Icons.circle_outlined, color: AppColors.accent, size: 20),
          SizedBox(width: 8),
          Text('GEOFENCES', style: TextStyle(color: Colors.white)),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
            tooltip: 'Add geofence at current location',
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: fences.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: fences.length,
              itemBuilder: (_, i) => _buildTile(fences[i]),
            ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle_outlined,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'No geofences yet',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create a zone around your current location.',
              style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildTile(Geofence fence) {
    final isInside =
        ref.watch(geofenceProvider).insideIds.contains(fence.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInside
              ? AppColors.statusGreen.withValues(alpha: 0.6)
              : AppColors.primaryOrange.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        leading: Icon(
          isInside ? Icons.location_on : Icons.circle_outlined,
          color: isInside ? AppColors.statusGreen : AppColors.textSecondary,
        ),
        title: Text(fence.name,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Text(
          '${fence.radiusMeters.toInt()} m radius  •  '
          '${fence.latitude.toStringAsFixed(4)}, ${fence.longitude.toStringAsFixed(4)}'
          '${isInside ? '  •  INSIDE' : ''}',
          style: TextStyle(
              color: isInside
                  ? AppColors.statusGreen
                  : AppColors.textSecondary.withValues(alpha: 0.7),
              fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: fence.isActive,
              activeThumbColor: AppColors.accent,
              onChanged: (_) =>
                  ref.read(geofenceProvider.notifier).toggleGeofence(fence.id!),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.statusRed, size: 20),
              onPressed: () => _confirmDelete(fence),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final locationState = ref.read(locationProvider);
    final lat = locationState.stats.currentLat;
    final lon = locationState.stats.currentLon;

    final nameCtrl = TextEditingController();
    double radius = 200;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          backgroundColor: AppColors.panelMatte,
          title: const Text('New Geofence',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lat == null)
                const Text(
                  'GPS not available. Enable location first.',
                  style: TextStyle(color: AppColors.statusRed),
                )
              else
                Text(
                  'Location: ${lat.toStringAsFixed(4)}, ${lon!.toStringAsFixed(4)}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle:
                      const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor:
                      AppColors.background.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Radius: ${radius.toInt()} m',
                  style: const TextStyle(color: Colors.white)),
              Slider(
                value: radius,
                min: 50,
                max: 5000,
                divisions: 99,
                activeColor: AppColors.accent,
                onChanged: (v) => setStateDlg(() => radius = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent),
              onPressed: lat == null || nameCtrl.text.trim().isEmpty
                  ? null
                  : () {
                      ref.read(geofenceProvider.notifier).addGeofence(
                            name: nameCtrl.text.trim(),
                            latitude: lat,
                            longitude: lon!,
                            radiusMeters: radius,
                          );
                      Navigator.pop(ctx);
                    },
              child: const Text('Save',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Geofence fence) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelMatte,
        title: const Text('Delete Geofence',
            style: TextStyle(color: Colors.white)),
        content: Text('Delete "${fence.name}"?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(geofenceProvider.notifier)
                  .deleteGeofence(fence.id!);
              Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.statusRed)),
          ),
        ],
      ),
    );
  }
}
