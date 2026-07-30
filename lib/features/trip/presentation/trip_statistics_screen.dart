import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';

class TripStatisticsScreen extends ConsumerWidget {
  const TripStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationProvider);
    final stats = locationState.stats;

    final totalDistance = stats.distanceMeters;
    final totalTime = stats.elapsed;
    final avgSpeed = totalTime.inSeconds > 0
        ? (totalDistance / totalTime.inSeconds * 3.6)
        : 0.0;
    final maxSpeed = stats.currentSpeedMs * 3.6;
    final calories = (totalDistance / 1000 * 60).round();
    final altitude = stats.currentAltitude;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.panelMatte,
        title:
            const Text('📊 Trip Statistics', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(totalDistance, totalTime, avgSpeed),
          const SizedBox(height: 16),
          _buildStatGrid(totalDistance, totalTime, avgSpeed, maxSpeed, calories, altitude),
          const SizedBox(height: 16),
          _buildWaypointCount(locationState.waypoints.length, locationState.breadcrumbs.length),
          const SizedBox(height: 16),
          _buildExportButtons(context, locationState),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double distance, Duration time, double avgSpeed) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5722).withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('This Trip',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(_formatDistance(distance),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniStat('Duration', _formatDuration(time)),
              _buildMiniStat(
                  'Avg Speed', '${avgSpeed.toStringAsFixed(1)} km/h'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatGrid(double distance, Duration time, double avgSpeed,
      double maxSpeed, int calories, double? altitude) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
            'Total Distance', _formatDistance(distance), Icons.straighten),
        _buildStatCard(
            'Total Time', _formatDuration(time), Icons.timer),
        _buildStatCard('Avg Speed',
            '${avgSpeed.toStringAsFixed(1)} km/h', Icons.speed),
        _buildStatCard('Max Speed',
            '${maxSpeed.toStringAsFixed(1)} km/h', Icons.flash_on),
        _buildStatCard(
            'Est. Calories', '$calories kcal', Icons.local_fire_department),
        _buildStatCard(
            'Altitude',
            altitude != null ? '${altitude.toStringAsFixed(0)}m' : '-- m',
            Icons.terrain),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.panelLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.primaryOrange, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWaypointCount(int waypointCount, int breadcrumbCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.panelLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(children: [
              const Icon(Icons.place, color: AppColors.primaryOrange, size: 28),
              const SizedBox(height: 4),
              Text('$waypointCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const Text('Waypoints',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
          Container(width: 1, height: 60, color: AppColors.panelLight),
          Expanded(
            child: Column(children: [
              const Icon(Icons.route, color: Colors.red, size: 28),
              const SizedBox(height: 4),
              Text('$breadcrumbCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const Text('Trail Points',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButtons(BuildContext context, LocationState locationState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Export & Share',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _exportGPX(context, locationState),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                      color: AppColors.panelLight,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Export GPX',
                            style: TextStyle(color: Colors.white)),
                      ]),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _shareTrip(context, locationState),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFF5722), Color(0xFFE64A19)]),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.share, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Share',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ]),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportGPX(BuildContext context, LocationState locationState) async {
    final waypoints = locationState.waypoints;
    final breadcrumbs = locationState.breadcrumbs;

    final gpx = StringBuffer();
    gpx.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    gpx.writeln('<gpx version="1.1" creator="BushTrack" xmlns="http://www.topografix.com/GPX/1/1">');
    gpx.writeln('  <metadata><name>BushTrack Export ${DateTime.now().toLocal().toString().substring(0, 16)}</name></metadata>');

    for (final wp in waypoints) {
      if (wp.latitude != null && wp.longitude != null) {
        gpx.writeln('  <wpt lat="${wp.latitude}" lon="${wp.longitude}">');
        if (wp.altitude != null) gpx.writeln('    <ele>${wp.altitude}</ele>');
        gpx.writeln('    <name>${(wp.label ?? 'Waypoint').replaceAll('&', '&amp;').replaceAll('<', '&lt;')}</name>');
        gpx.writeln('  </wpt>');
      }
    }

    if (breadcrumbs.isNotEmpty) {
      gpx.writeln('  <trk>');
      gpx.writeln('    <name>BushTrack Trail</name>');
      gpx.writeln('    <trkseg>');
      for (final bc in breadcrumbs) {
        if (bc.latitude != null && bc.longitude != null) {
          gpx.writeln('      <trkpt lat="${bc.latitude}" lon="${bc.longitude}">');
          if (bc.altitude != null) gpx.writeln('        <ele>${bc.altitude}</ele>');
          if (bc.timestamp != null) {
            gpx.writeln('        <time>${bc.timestamp!.toUtc().toIso8601String()}</time>');
          }
          gpx.writeln('      </trkpt>');
        }
      }
      gpx.writeln('    </trkseg>');
      gpx.writeln('  </trk>');
    }

    gpx.writeln('</gpx>');

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'bushtrack_${DateTime.now().millisecondsSinceEpoch}.gpx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(gpx.toString());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('GPX saved: $fileName — tap Copy to get the path'),
          backgroundColor: AppColors.statusGreen,
          action: SnackBarAction(
            label: 'Copy Path',
            textColor: Colors.white,
            onPressed: () => Clipboard.setData(ClipboardData(text: file.path)),
          ),
          duration: const Duration(seconds: 6),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Export failed — try Share instead'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _shareTrip(BuildContext context, LocationState locationState) async {
    final stats = locationState.stats;
    final distance = _formatDistance(stats.distanceMeters);
    final time = _formatDuration(stats.elapsed);
    final waypoints = locationState.waypoints.length;
    final alt = stats.currentAltitude != null
        ? '⛰ ${stats.currentAltitude!.toStringAsFixed(0)}m altitude\n'
        : '';

    final text = '🌿 BushTrack Trip Summary\n'
        '📍 Distance: $distance\n'
        '⏱ Time: $time\n'
        '📌 Waypoints: $waypoints\n'
        '$alt'
        '\nTracked with BushTrack — offline GPS for the bush.';

    // Copy to clipboard first, then open SMS so user can paste
    await Clipboard.setData(ClipboardData(text: text));

    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Trip summary copied to clipboard — paste anywhere to share!'),
        backgroundColor: AppColors.primaryOrange,
        duration: Duration(seconds: 3),
      ));
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)}m';
    return '${(meters / 1000).toStringAsFixed(2)}km';
  }

  String _formatDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
