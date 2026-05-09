import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:exif/exif.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';

/// Photo Geotagging Service
/// Adds photos to waypoints with GPS metadata
/// Matches Avenza Maps photo waypoint feature
class PhotoGeotaggingService {
  static final PhotoGeotaggingService _instance = PhotoGeotaggingService._internal();
  factory PhotoGeotaggingService() => _instance;
  PhotoGeotaggingService._internal();

  final ImagePicker _picker = ImagePicker();
  String? _photosDirectory;
  String? _thumbnailsDirectory;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _photosDirectory = '${appDir.path}/waypoint_photos';
      _thumbnailsDirectory = '${appDir.path}/waypoint_thumbnails';

      // Create directories
      await Directory(_photosDirectory!).create(recursive: true);
      await Directory(_thumbnailsDirectory!).create(recursive: true);

      _isInitialized = true;
      print('✅ PhotoGeotaggingService initialized');
    } catch (e) {
      print('❌ PhotoGeotaggingService initialization failed: $e');
    }
  }

  /// Take a photo with camera and geotag it
  Future<GeotaggedPhoto?> takePhoto({
    required LatLng location,
    double? altitude,
    String? notes,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048, // Limit size for storage
        maxHeight: 2048,
        imageQuality: 85, // Good quality, reasonable size
      );

      if (photo == null) return null;

      return await _processPhoto(
        File(photo.path),
        location: location,
        altitude: altitude,
        notes: notes,
      );
    } catch (e) {
      print('❌ Error taking photo: $e');
      return null;
    }
  }

  /// Pick photo from gallery and geotag it
  Future<GeotaggedPhoto?> pickPhotoFromGallery({
    required LatLng location,
    double? altitude,
    String? notes,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (photo == null) return null;

      return await _processPhoto(
        File(photo.path),
        location: location,
        altitude: altitude,
        notes: notes,
      );
    } catch (e) {
      print('❌ Error picking photo: $e');
      return null;
    }
  }

  /// Process and save a geotagged photo
  Future<GeotaggedPhoto> _processPhoto(
    File sourceFile, {
    required LatLng location,
    double? altitude,
    String? notes,
  }) async {
    final timestamp = DateTime.now();
    final filename = 'wp_${timestamp.millisecondsSinceEpoch}.jpg';
    final photoPath = path.join(_photosDirectory!, filename);
    final thumbnailPath = path.join(_thumbnailsDirectory!, 'thumb_$filename');

    // Read original image
    final bytes = await sourceFile.readAsBytes();
    final original = img.decodeImage(bytes);

    if (original == null) {
      throw Exception('Could not decode image');
    }

    // Create thumbnail (200x200)
    final thumbnail = img.copyResize(original, width: 200);
    await File(thumbnailPath).writeAsBytes(img.encodeJpg(thumbnail, quality: 70));

    // Add GPS metadata to EXIF
    final exifBytes = await _addGpsExif(bytes, location, altitude);

    // Save full photo with EXIF
    await File(photoPath).writeAsBytes(exifBytes);

    return GeotaggedPhoto(
      filePath: photoPath,
      thumbnailPath: thumbnailPath,
      location: location,
      altitude: altitude,
      timestamp: timestamp,
      notes: notes,
    );
  }

  /// Add GPS EXIF data to image bytes
  Future<Uint8List> _addGpsExif(
    Uint8List imageBytes,
    LatLng location,
    double? altitude,
  ) async {
    // For web, EXIF manipulation is limited
    // On mobile platforms, we'd use native EXIF libraries
    // For now, return original bytes (metadata stored in waypoint instead)
    return imageBytes;
  }

  /// Extract GPS location from photo EXIF
  Future<LatLng?> extractGpsFromPhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final exifData = await readExifFromBytes(bytes);

      if (exifData.isEmpty) return null;

      // Extract GPS coordinates from EXIF
      final gpsLatitude = exifData['GPS GPSLatitude'];
      final gpsLatitudeRef = exifData['GPS GPSLatitudeRef'];
      final gpsLongitude = exifData['GPS GPSLongitude'];
      final gpsLongitudeRef = exifData['GPS GPSLongitudeRef'];

      if (gpsLatitude != null && gpsLongitude != null) {
        final lat = _convertExifCoord(gpsLatitude.values, gpsLatitudeRef.toString());
        final lon = _convertExifCoord(gpsLongitude.values, gpsLongitudeRef.toString());

        if (lat != null && lon != null) {
          return LatLng(lat, lon);
        }
      }

      return null;
    } catch (e) {
      print('⚠️ Could not extract GPS from photo: $e');
      return null;
    }
  }

  /// Convert EXIF coordinate format to decimal degrees
  double? _convertExifCoord(IfdValues coord, String ref) {
    try {
      // Parse EXIF rational format: "[deg/1, min/1, sec/100]"
      final parts = coord.toString().replaceAll('[', '').replaceAll(']', '').split(', ');
      if (parts.length != 3) return null;

      double parseRational(String rational) {
        final split = rational.split('/');
        if (split.length == 2) {
          return double.parse(split[0]) / double.parse(split[1]);
        }
        return double.parse(rational);
      }

      final degrees = parseRational(parts[0]);
      final minutes = parseRational(parts[1]);
      final seconds = parseRational(parts[2]);

      var decimal = degrees + minutes / 60 + seconds / 3600;
      if (ref == 'S' || ref == 'W') {
        decimal = -decimal;
      }

      return decimal;
    } catch (e) {
      return null;
    }
  }

  /// Attach photo to existing waypoint
  Future<bool> attachPhotoToWaypoint(
    Waypoint waypoint,
    GeotaggedPhoto photo,
  ) async {
    try {
      // Update waypoint with photo
      final photos = waypoint.photoPaths ?? [];
      photos.add(photo.filePath);
      waypoint.photoPaths = photos;

      // Set thumbnail if first photo
      if (waypoint.thumbnailPath == null) {
        waypoint.thumbnailPath = photo.thumbnailPath;
      }

      return true;
    } catch (e) {
      print('❌ Error attaching photo to waypoint: $e');
      return false;
    }
  }

  /// Delete a photo
  Future<bool> deletePhoto(String photoPath, Waypoint waypoint) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
      }

      // Delete thumbnail
      final thumbPath = waypoint.photoPaths?.firstWhere(
        (p) => p == photoPath.replaceFirst('/waypoint_photos/', '/waypoint_thumbnails/thumb_'),
        orElse: () => '',
      );
      if (thumbPath != null && thumbPath.isNotEmpty) {
        final thumbFile = File(thumbPath);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      }

      // Remove from waypoint
      waypoint.photoPaths?.remove(photoPath);

      // Update thumbnail if needed
      if (waypoint.thumbnailPath == photoPath) {
        waypoint.thumbnailPath = waypoint.photoPaths?.isNotEmpty == true
            ? waypoint.photoPaths!.first
            : null;
      }

      return true;
    } catch (e) {
      print('❌ Error deleting photo: $e');
      return false;
    }
  }

  /// Get all photos for a waypoint
  List<File> getWaypointPhotos(Waypoint waypoint) {
    if (waypoint.photoPaths == null || waypoint.photoPaths!.isEmpty) {
      return [];
    }

    return waypoint.photoPaths!
        .where((path) => File(path).existsSync())
        .map((path) => File(path))
        .toList();
  }

  /// Show photo gallery for waypoint
  void showPhotoGallery(BuildContext context, Waypoint waypoint, int initialIndex) {
    if (waypoint.photoPaths == null || waypoint.photoPaths!.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => PhotoGalleryDialog(
        photoPaths: waypoint.photoPaths!,
        initialIndex: initialIndex,
        waypoint: waypoint,
        onDelete: (path) => deletePhoto(path, waypoint),
      ),
    );
  }

  /// Get storage usage for photos
  Future<PhotoStorageInfo> getStorageInfo() async {
    if (!_isInitialized) await initialize();

    int photoCount = 0;
    int thumbnailCount = 0;
    int totalBytes = 0;

    // Count photos
    final photoDir = Directory(_photosDirectory!);
    if (await photoDir.exists()) {
      await for (final file in photoDir.list(recursive: true)) {
        if (file is File) {
          photoCount++;
          final stat = await file.stat();
          totalBytes += stat.size;
        }
      }
    }

    // Count thumbnails
    final thumbDir = Directory(_thumbnailsDirectory!);
    if (await thumbDir.exists()) {
      await for (final file in thumbDir.list(recursive: true)) {
        if (file is File) {
          thumbnailCount++;
          final stat = await file.stat();
          totalBytes += stat.size;
        }
      }
    }

    return PhotoStorageInfo(
      photoCount: photoCount,
      thumbnailCount: thumbnailCount,
      totalBytes: totalBytes,
    );
  }
}

/// Represents a geotagged photo
class GeotaggedPhoto {
  final String filePath;
  final String thumbnailPath;
  final LatLng location;
  final double? altitude;
  final DateTime timestamp;
  final String? notes;

  GeotaggedPhoto({
    required this.filePath,
    required this.thumbnailPath,
    required this.location,
    this.altitude,
    required this.timestamp,
    this.notes,
  });

  File get file => File(filePath);
  File get thumbnailFile => File(thumbnailPath);
}

/// Photo storage statistics
class PhotoStorageInfo {
  final int photoCount;
  final int thumbnailCount;
  final int totalBytes;

  PhotoStorageInfo({
    required this.photoCount,
    required this.thumbnailCount,
    required this.totalBytes,
  });

  String get formattedSize {
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    } else if (totalBytes < 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}

/// Photo gallery dialog
class PhotoGalleryDialog extends StatefulWidget {
  final List<String> photoPaths;
  final int initialIndex;
  final Waypoint waypoint;
  final Function(String)? onDelete;

  const PhotoGalleryDialog({
    super.key,
    required this.photoPaths,
    required this.initialIndex,
    required this.waypoint,
    this.onDelete,
  });

  @override
  State<PhotoGalleryDialog> createState() => _PhotoGalleryDialogState();
}

class _PhotoGalleryDialogState extends State<PhotoGalleryDialog> {
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(
              File(widget.photoPaths[currentIndex]),
              fit: BoxFit.contain,
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${currentIndex + 1} / ${widget.photoPaths.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      if (widget.onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            widget.onDelete!(widget.photoPaths[currentIndex]);
                            if (widget.photoPaths.length > 1) {
                              setState(() {
                                if (currentIndex >= widget.photoPaths.length - 1) {
                                  currentIndex = widget.photoPaths.length - 2;
                                }
                              });
                            } else {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Navigation arrows
          if (widget.photoPaths.length > 1) ...[
            Positioned(
              left: 16,
              top: MediaQuery.of(context).size.height / 2 - 24,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 32),
                onPressed: currentIndex > 0
                    ? () => setState(() => currentIndex--)
                    : null,
              ),
            ),
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height / 2 - 24,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 32),
                onPressed: currentIndex < widget.photoPaths.length - 1
                    ? () => setState(() => currentIndex++)
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
