import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/features/map/widgets/pinage_viewer.dart';
import 'package:bush_track/features/map/widgets/pinage_editor.dart';

/// Callback type for jumping the map to a coordinate.
typedef OnJumpToMap = void Function(LatLng location);

class PhotoGalleryScreen extends ConsumerWidget {
  final OnJumpToMap? onJumpToMap;

  const PhotoGalleryScreen({super.key, this.onJumpToMap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    final photos = locationState.waypoints
        .where((w) => w.hasPhotos || w.isPinage)
        .toList()
      ..sort((a, b) => (b.timestamp ?? DateTime(0))
          .compareTo(a.timestamp ?? DateTime(0)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.panelMatte,
        title: const Row(children: [
          Icon(Icons.photo_library, color: AppColors.accent, size: 20),
          SizedBox(width: 8),
          Text('PHOTO GALLERY', style: TextStyle(color: Colors.white)),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: photos.isEmpty
          ? _buildEmpty()
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: photos.length,
              itemBuilder: (ctx, i) => _PhotoCard(
                waypoint: photos[i],
                onJumpToMap: onJumpToMap != null && photos[i].latitude != null
                    ? () {
                        Navigator.pop(ctx);
                        onJumpToMap!(
                            LatLng(photos[i].latitude!, photos[i].longitude!));
                      }
                    : null,
              ),
            ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('No geotagged photos yet',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Use the camera button on the map to take a geotagged photo.',
              style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

class _PhotoCard extends ConsumerWidget {
  final Waypoint waypoint;
  final VoidCallback? onJumpToMap;

  const _PhotoCard({required this.waypoint, this.onJumpToMap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstPhoto =
        waypoint.photoPaths != null && waypoint.photoPaths!.isNotEmpty
            ? waypoint.photoPaths!.first
            : null;

    return GestureDetector(
      onTap: () => showPinageViewer(
        context,
        waypoint: waypoint,
        onEdit: () => showPinageEditor(
          context,
          position: LatLng(waypoint.latitude!, waypoint.longitude!),
          existing: waypoint,
        ),
        onDelete: () =>
            ref.read(locationProvider.notifier).deleteWaypoint(waypoint.id!),
        onJumpToMap: onJumpToMap,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panelMatte,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.primaryOrange.withValues(alpha: 0.15)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (firstPhoto != null)
                    _imageWidget(firstPhoto)
                  else
                    Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: Colors.white24, size: 40),
                    ),
                  // Map-pin overlay badge
                  if (onJumpToMap != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onJumpToMap,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black45, blurRadius: 6),
                            ],
                          ),
                          child: const Icon(Icons.location_on,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  // Photo count badge
                  if ((waypoint.photoPaths?.length ?? 0) > 1)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${waypoint.photoPaths!.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Caption
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waypoint.label ?? 'Photo Pin',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  if (waypoint.latitude != null)
                    Text(
                      '${waypoint.latitude!.toStringAsFixed(4)}, '
                      '${waypoint.longitude!.toStringAsFixed(4)}',
                      style: TextStyle(
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.7),
                          fontSize: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageWidget(String path) {
    if (path.startsWith('data:')) {
      final comma = path.indexOf(',');
      if (comma != -1) {
        try {
          final bytes = base64Decode(path.substring(comma + 1));
          return Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {}
      }
    }
    if (kIsWeb) {
      return Image.network(path, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image,
              color: Colors.white24, size: 36));
    }
    return Image.file(File(path), fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.white24, size: 36));
  }
}
