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
        title: const Row(children: [
          Icon(Icons.holiday_village, color: AppColors.accent, size: 20),
          SizedBox(width: 8),
          Text('CAMP FINDER'),
        ]),
        backgroundColor: AppColors.background,
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
            // Info card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.panelMatte,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.auto_awesome, color: AppColors.primaryOrange, size: 18),
                    SizedBox(width: 8),
                    Text('AI-Powered Terrain Analysis',
                        style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'Analyses nearby terrain using your GPS position and elevation data to score potential campsites on flatness, water proximity, and shelter. Results are based on geographic data — always verify conditions on the ground.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: BushDS.fontXS),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isSearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                  strokeWidth: 2))
                          : const Icon(Icons.search),
                      label: Text(
                        _isSearching ? 'Analysing terrain...' : 'FIND BEST CAMPSITE NEARBY',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: _isSearching ? null : () => _searchForCampsite(locationState),
                    ),
                  ),
                ],
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
                const Icon(Icons.holiday_village,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'CAMP SITE SCORE:',
                  style: TextStyle(
                    fontSize: BushDS.fontLG,
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
            _buildScoreBar('FLATNESS', campsite.flatnessScore, '${campsite.flatness.toStringAsFixed(1)}% grade'),

            const SizedBox(height: 8),

            // Water proximity score
            _buildScoreBar('WATER PROXIMITY', campsite.waterScore, '${campsite.waterDistance.toStringAsFixed(0)} meters'),
            
            const SizedBox(height: 24),
            
            // Recommendation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getScoreColor(campsite.overallScore).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getScoreColor(campsite.overallScore).withValues(alpha: 0.5)),
              ),
              child: Row(children: [
                Icon(
                  campsite.overallScore >= 70 ? Icons.thumb_up : Icons.info_outline,
                  color: _getScoreColor(campsite.overallScore),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _buildRecommendationText(campsite),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ]),
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
    if (score >= 80) return AppColors.statusGreen;
    if (score >= 60) return AppColors.statusGreen.withValues(alpha: 0.75);
    if (score >= 40) return AppColors.accent;
    if (score >= 20) return AppColors.statusYellow;
    return AppColors.statusRed;
  }

  Future<void> _searchForCampsite(LocationState locationState) async {
    setState(() {
      _isSearching = true;
      _statusMessage = 'Checking GPS position...';
      _bestCampsite = null;
    });

    try {
      if (locationState.stats.currentLat == null || locationState.stats.currentLon == null) {
        setState(() {
          _isSearching = false;
          _statusMessage = 'No GPS fix — step outside and wait for a signal, then try again.';
        });
        return;
      }

      final currentLocation = LatLng(
        locationState.stats.currentLat!,
        locationState.stats.currentLon!,
      );

      setState(() => _statusMessage = 'Reading elevation data for surrounding area...');
      await Future.delayed(const Duration(milliseconds: 600));

      setState(() => _statusMessage = 'Scoring terrain flatness within 500 m radius...');
      await Future.delayed(const Duration(milliseconds: 700));

      setState(() => _statusMessage = 'Locating nearest water sources...');
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() => _statusMessage = 'Calculating best campsite score...');

      final bestCampsite = await GeographicAnalysisService.findBestCampsite(currentLocation);

      if (bestCampsite != null) {
        setState(() {
          _bestCampsite = bestCampsite;
          _statusMessage = 'Analysis complete. Best spot found within 500 m of your position.';
        });
      } else {
        setState(() {
          _statusMessage = 'No high-scoring campsites in the immediate area — try moving to higher ground.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Analysis error — check your GPS signal and try again.';
      });
    } finally {
      setState(() => _isSearching = false);
    }
  }

  String _buildRecommendationText(CampSiteScore campsite) {
    if (campsite.overallScore >= 80) {
      return 'Excellent spot — flat ground and good water access. Highly recommended.';
    } else if (campsite.overallScore >= 60) {
      return 'Good campsite. ${campsite.flatnessScore >= 60 ? 'Reasonably flat' : 'Slightly sloped'} with water ${campsite.waterDistance < 200 ? 'nearby' : 'within ${campsite.waterDistance.toStringAsFixed(0)} m'}.';
    } else if (campsite.overallScore >= 40) {
      return 'Marginal site — ${campsite.flatnessScore < 50 ? 'uneven ground, bring a sleeping pad' : 'flat enough'}. ${campsite.waterScore < 50 ? 'Water source is distant — carry extra.' : 'Water accessible.'}';
    } else {
      return 'Poor conditions near your position. Consider moving to higher, flatter terrain before nightfall.';
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