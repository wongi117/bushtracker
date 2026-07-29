import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/ai/services/geographic_analysis_service.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'dart:math' as math;

class CampFinderScreen extends ConsumerStatefulWidget {
  const CampFinderScreen({super.key});

  @override
  ConsumerState<CampFinderScreen> createState() => _CampFinderScreenState();
}

class _CampFinderScreenState extends ConsumerState<CampFinderScreen> {
  bool _isSearching = false;
  CampSiteScore? _bestCampsite;
  String _statusMessage = 'Ready to search for campsites';

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('⛺ CAMP FINDER'),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search controls
            Card(
              color: AppColors.panelMatte,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      '🔍 Find the best campsite near your current location',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isSearching ? null : () => _searchForCampsite(locationState),
                      child: _isSearching
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('🔍 SEARCHING...'),
                              ],
                            )
                          : const Text(
                              '⛺ FIND CAMPSITE',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Status message
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.panelLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Results
            if (_bestCampsite != null)
              Expanded(
                child: _buildCampsiteResult(_bestCampsite!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampsiteResult(CampSiteScore campsite) {
    final locationState = ref.watch(locationProvider);
    final currentLat = locationState.stats.currentLat;
    final currentLon = locationState.stats.currentLon;
    
    String directionInfo = '';
    String distanceInfo = '';
    
    if (currentLat != null && currentLon != null) {
      final currentLocation = LatLng(currentLat, currentLon);
      final direction = _calculateBearing(currentLocation, campsite.location);
      final cardinalDirection = _getCardinalDirection(direction);
      final distance = GeographicAnalysisService.calculateDistance(currentLocation, campsite.location);
      
      directionInfo = cardinalDirection;
      distanceInfo = '${distance.toStringAsFixed(0)} meters';
    }
    
    return Card(
      color: AppColors.panelMatte,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall score
            Row(
              children: [
                const Text(
                  '🏕️ CAMP SITE SCORE:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getScoreColor(campsite.overallScore),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    campsite.overallScore.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Direction and distance
            if (directionInfo.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.navigation, color: AppColors.primaryOrange),
                  const SizedBox(width: 8),
                  Text(
                    '$distanceInfo to the $directionInfo',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 16),
            
            // Flatness score
            _buildScoreBar('⚖️ FLATNESS', campsite.flatnessScore, '${campsite.flatness.toStringAsFixed(1)}% grade'),
            
            const SizedBox(height: 8),
            
            // Water proximity score
            _buildScoreBar('💧 WATER PROXIMITY', campsite.waterScore, '${campsite.waterDistance.toStringAsFixed(0)} meters'),
            
            const SizedBox(height: 24),
            
            // Recommendation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryOrange),
              ),
              child: const Text(
                'This location offers a good balance of flat ground and convenient access to water.',
                style: TextStyle(
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBar(String label, double score, String detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${score.toStringAsFixed(0)}/100',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: score / 100,
          backgroundColor: AppColors.panelLight,
          valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(score)),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return AppColors.primaryOrange;
    if (score >= 20) return Colors.orange;
    return Colors.red;
  }

  Future<void> _searchForCampsite(LocationState locationState) async {
    setState(() {
      _isSearching = true;
      _statusMessage = 'Analyzing terrain and water sources...';
      _bestCampsite = null;
    });
    
    try {
      // Check if we have a valid location
      if (locationState.stats.currentLat == null || locationState.stats.currentLon == null) {
        setState(() {
          _isSearching = false;
          _statusMessage = 'Unable to determine your location. Please check GPS.';
        });
        return;
      }
      
      final currentLocation = LatLng(
        locationState.stats.currentLat!,
        locationState.stats.currentLon!,
      );
      
      setState(() {
        _statusMessage = 'Scanning area for potential campsites...';
      });
      
      // Simulate some processing time
      await Future.delayed(const Duration(seconds: 2));
      
      final bestCampsite = await GeographicAnalysisService.findBestCampsite(currentLocation);
      
      if (bestCampsite != null) {
        setState(() {
          _bestCampsite = bestCampsite;
          _statusMessage = 'Found a suitable campsite!';
        });
      } else {
        setState(() {
          _statusMessage = 'No suitable campsites found in the vicinity.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error searching for campsites. Please try again.';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  /// Calculate bearing between two points
  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lon1 = _toRadians(from.longitude);
    final lat2 = _toRadians(to.latitude);
    final lon2 = _toRadians(to.longitude);
    
    final dLon = lon2 - lon1;
    
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final bearing = math.atan2(y, x);
    
    // Convert from radians to degrees
    var degrees = _toDegrees(bearing);
    
    // Normalize to 0-360 range
    degrees = (degrees + 360) % 360;
    
    return degrees;
  }

  /// Convert degrees to cardinal direction
  String _getCardinalDirection(double degrees) {
    const directions = ['north', 'northeast', 'east', 'southeast', 'south', 'southwest', 'west', 'northwest'];
    int index = ((degrees + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  /// Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Convert radians to degrees
  double _toDegrees(double radians) {
    return radians * (180 / math.pi);
  }
}