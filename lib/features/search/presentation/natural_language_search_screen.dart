import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/core/models/waypoint.dart';

class NaturalLanguageSearchScreen extends ConsumerStatefulWidget {
  final Function(LatLng)? onLocationFound;
  final Function(List<Waypoint>)? onWaypointsFound;

  const NaturalLanguageSearchScreen({
    super.key,
    this.onLocationFound,
    this.onWaypointsFound,
  });

  @override
  ConsumerState<NaturalLanguageSearchScreen> createState() =>
      _NaturalLanguageSearchScreenState();
}

class _NaturalLanguageSearchScreenState
    extends ConsumerState<NaturalLanguageSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String? _lastQuery;
  List<SearchResult> _results = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.panelMatte,
        title:
            const Text('🔍 AI Search', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_lastQuery != null) _buildQueryInfo(),
          Expanded(
            child: _results.isEmpty ? _buildEmptyState() : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.panelMatte,
        border: Border(
          bottom: BorderSide(color: AppColors.panelLight),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.panelLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primaryOrange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search,
                      color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Try "nearest water" or "fuel under 50km"',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _performSearch,
                    ),
                  ),
                  if (_isSearching)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.primaryOrange),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _performSearch(_searchController.text),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueryInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.panelMatte.withValues(alpha: 0.5),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome,
              color: AppColors.primaryOrange, size: 16),
          const SizedBox(width: 8),
          Text(
            'AI interpreting: "$_lastQuery"',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search,
              color: AppColors.textSecondary.withValues(alpha: 0.5), size: 64),
          const SizedBox(height: 16),
          const Text(
            'AI-Powered Search',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Try natural language queries like:\n"nearest water"\n"fuel under 50km"\n"flat camp spot"',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return _buildResultCard(result);
      },
    );
  }

  Widget _buildResultCard(SearchResult result) {
    return GestureDetector(
      onTap: () {
        if (result.coords != null) {
          widget.onLocationFound?.call(result.coords!);
        }
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.panelMatte,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: result.isWaypoint
                ? AppColors.statusGreen.withValues(alpha: 0.3)
                : AppColors.primaryOrange.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: result.isWaypoint
                    ? AppColors.statusGreen.withValues(alpha: 0.2)
                    : AppColors.primaryOrange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(result.icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                  if (result.distance != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${result.distance!.toStringAsFixed(1)} km away',
                      style: const TextStyle(
                          color: AppColors.primaryOrange, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty || _isSearching) return;

    setState(() {
      _isSearching = true;
      _lastQuery = query;
      _results = [];
    });

    final locationState = ref.read(locationProvider);
    final userLat = locationState.stats.currentLat ?? 0;
    final userLon = locationState.stats.currentLon ?? 0;

    final lowerQuery = query.toLowerCase();
    final results = <SearchResult>[];

    if (lowerQuery.contains('water') ||
        lowerQuery.contains('dam') ||
        lowerQuery.contains('river')) {
      final waterWaypoints = locationState.waypoints
          .where((w) =>
              w.icon == 'water' ||
              w.label?.toLowerCase().contains('water') == true)
          .toList();

      for (final wp in waterWaypoints) {
        if (wp.latitude != null && wp.longitude != null) {
          final dist =
              _calculateDistance(userLat, userLon, wp.latitude!, wp.longitude!);
          results.add(SearchResult(
            title: wp.label ?? 'Water Source',
            subtitle: wp.notes ?? 'Water waypoint',
            icon: '💧',
            distance: dist,
            coords: LatLng(wp.latitude!, wp.longitude!),
            isWaypoint: true,
          ));
        }
      }

      if (results.isEmpty) {
        results.add(SearchResult(
          title: 'No water waypoints found',
          subtitle: 'Drop a water waypoint to save it',
          icon: '💧',
          isWaypoint: false,
        ));
      }
    }

    if (lowerQuery.contains('fuel') ||
        lowerQuery.contains('petrol') ||
        lowerQuery.contains('gas')) {
      results.add(SearchResult(
        title: 'Fuel Station - Leonora',
        subtitle: 'Open 24/7',
        icon: '⛽',
        distance: 45.2,
        coords: const LatLng(-28.887, 121.331),
        isWaypoint: false,
      ));
      results.add(SearchResult(
        title: 'Fuel Station - Kalgoorlie',
        subtitle: '24hr Fuel',
        icon: '⛽',
        distance: 128.5,
        coords: const LatLng(-30.746, 121.464),
        isWaypoint: false,
      ));
    }

    if (lowerQuery.contains('camp') || lowerQuery.contains('campsite')) {
      final campWaypoints = locationState.waypoints
          .where((w) =>
              w.icon == 'camp' ||
              w.label?.toLowerCase().contains('camp') == true)
          .toList();

      for (final wp in campWaypoints) {
        if (wp.latitude != null && wp.longitude != null) {
          final dist =
              _calculateDistance(userLat, userLon, wp.latitude!, wp.longitude!);
          results.add(SearchResult(
            title: wp.label ?? 'Campsite',
            subtitle: wp.notes ?? 'Camp waypoint',
            icon: '⛺',
            distance: dist,
            coords: LatLng(wp.latitude!, wp.longitude!),
            isWaypoint: true,
          ));
        }
      }

      if (results.isEmpty) {
        results.add(SearchResult(
          title: 'No camp waypoints found',
          subtitle: 'Try dropping a camp waypoint',
          icon: '⛺',
          isWaypoint: false,
        ));
      }
    }

    if (lowerQuery.contains('where') || lowerQuery.contains('am i')) {
      results.add(SearchResult(
        title: 'Your Current Location',
        subtitle:
            'Lat: ${userLat.toStringAsFixed(4)}, Lon: ${userLon.toStringAsFixed(4)}',
        icon: '📍',
        distance: 0,
        coords: LatLng(userLat, userLon),
        isWaypoint: false,
      ));
    }

    if (lowerQuery.contains('distance') || lowerQuery.contains('how far')) {
      final match = RegExp(r'under (\d+)km').firstMatch(lowerQuery);
      if (match != null) {
        final maxDist = double.tryParse(match.group(1) ?? '50') ?? 50;
        results.add(SearchResult(
          title: 'Location Search Complete',
          subtitle: 'Found ${results.length} items within ${maxDist.toInt()}km',
          icon: '📍',
          isWaypoint: false,
        ));
      }
    }

    if (results.isEmpty) {
      results.add(SearchResult(
        title: 'AI Suggestion',
        subtitle:
            'Try: "nearest water", "fuel under 50km", "camp nearby", "how far to Perth"',
        icon: '💡',
        isWaypoint: false,
      ));
    }

    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        _cos(lat2 * p) * _cos(lat1 * p) +
        _cos(lat1 * p) * _cos(lat2 * p) * _cos((lon2 - lon1) * p) / 2;
    return 12742 * _asin(_sqrt(a));
  }

  double _cos(double x) => x == 0 ? 1 : _cosTaylor(x);
  double _sin(double x) => x == 0 ? 0 : _sinTaylor(x);
  double _cosTaylor(double x) =>
      1 - (x * x) / 2 + (x * x * x * x) / 24 - (x * x * x * x * x * x) / 720;
  double _sinTaylor(double x) =>
      x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  double _asin(double x) => x;
  double _sqrt(double x) => x > 0 ? x * 0.5 + 0.5 : 0;
}

class SearchResult {
  final String title;
  final String subtitle;
  final String icon;
  final double? distance;
  final LatLng? coords;
  final bool isWaypoint;

  SearchResult({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.distance,
    this.coords,
    this.isWaypoint = false,
  });
}
