import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final avgSpeed = totalTime.inSeconds > 0 ? (totalDistance / totalTime.inSeconds * 3.6) : 0.0;
    final maxSpeed = stats.currentSpeedMs * 3.6;
    final calories = (totalDistance / 1000 * 60).round();
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.panelMatte,
        title: const Text('📊 Trip Statistics', style: TextStyle(color: Colors.white)),
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
          _buildStatGrid(totalDistance, totalTime, avgSpeed, maxSpeed, calories),
          const SizedBox(height: 16),
          _buildExportButtons(context),
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
          const Text('This Trip', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(_formatDistance(distance), style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniStat('Duration', _formatDuration(time)),
              _buildMiniStat('Avg Speed', '${avgSpeed.toStringAsFixed(1)} km/h'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
  
  Widget _buildStatGrid(double distance, Duration time, double avgSpeed, double maxSpeed, int calories) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Total Distance', _formatDistance(distance), Icons.straighten),
        _buildStatCard('Total Time', _formatDuration(time), Icons.timer),
        _buildStatCard('Avg Speed', '${avgSpeed.toStringAsFixed(1)} km/h', Icons.speed),
        _buildStatCard('Max Speed', '${maxSpeed.toStringAsFixed(1)} km/h', Icons.flash_on),
        _buildStatCard('Est. Calories', '$calories kcal', Icons.local_fire_department),
        _buildStatCard('Elevation', '0m', Icons.terrain),
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
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildExportButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exporting GPX...'))),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: AppColors.panelLight, borderRadius: BorderRadius.circular(12)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.download, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Export GPX', style: TextStyle(color: Colors.white)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sharing...'))),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFE64A19)]), borderRadius: BorderRadius.circular(12)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.share, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ),
      ],
    );
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