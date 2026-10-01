import 'package:flutter/material.dart';

import 'package:bush_track/core/services/heading/heading_reading.dart';
import 'package:bush_track/features/streetview/services/mapillary_service.dart';
import 'package:bush_track/theme/app_colors.dart';

/// A Mapillary street-level photo, full screen.
///
/// Shaped like [PinPhotoViewer] — pinch to zoom, close top-left — but
/// deliberately a separate screen rather than a reuse of it. That viewer loads
/// from the local database and offers add and delete; this one loads over the
/// network and offers neither, because the photo is someone else's and the
/// network can vanish mid-load. Sharing the widget would mean threading "where
/// did this come from" through every branch of it.
class StreetPhotoViewer extends StatelessWidget {
  const StreetPhotoViewer({super.key, required this.photo});

  final StreetPhoto photo;

  static Future<void> open(BuildContext context, StreetPhoto photo) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => StreetPhotoViewer(photo: photo),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final url = photo.fullUrl ?? photo.thumbUrl;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: url == null
                  ? _unavailable('No image available for this point')
                  : InteractiveViewer(
                      maxScale: 5,
                      child: Center(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator(
                                          color: AppColors.accent),
                                    ),
                          // Street imagery is the one thing here that needs a
                          // connection, so losing it mid-load has to say so
                          // rather than show a broken-image glyph.
                          errorBuilder: (_, __, ___) => _unavailable(
                              'Could not load this photo — check your '
                              'connection'),
                        ),
                      ),
                    ),
            ),

            Positioned(
              top: 8,
              left: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 19),
                ),
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.streetview,
                          color: AppColors.accentLight, size: 15),
                      const SizedBox(width: 7),
                      Text(_captured(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12.5)),
                      if (photo.compassAngle != null) ...[
                        const SizedBox(width: 10),
                        Text('facing ${_facing()}',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11)),
                      ],
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      '${photo.position.latitude.toStringAsFixed(5)}, '
                      '${photo.position.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10.5),
                    ),
                    const SizedBox(height: 4),
                    // Mapillary's terms require the credit, and it is also
                    // worth being plain that this is not your photo.
                    const Text('Street imagery © Mapillary contributors',
                        style:
                            TextStyle(color: Colors.white24, fontSize: 9.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unavailable(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white24, size: 42),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
      );

  String _captured() {
    final at = photo.capturedAt;
    if (at == null) return 'Street photo';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    // Date only, no time: what matters about street imagery is how old it is,
    // and to the nearest month at that — a road may have changed since.
    return '${months[at.month - 1]} ${at.year}';
  }

  String _facing() {
    final angle = photo.compassAngle;
    if (angle == null) return '';
    return HeadingReading(
      degrees: angle,
      quality: HeadingQuality.good,
      source: HeadingSourceKind.sensors,
    ).cardinal;
  }
}
