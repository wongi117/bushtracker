import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/places/providers/places_provider.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/features/places/services/places_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PlacesSearchScreen extends ConsumerStatefulWidget {
  const PlacesSearchScreen({super.key});

  @override
  ConsumerState<PlacesSearchScreen> createState() => _PlacesSearchScreenState();
}

class _PlacesSearchScreenState extends ConsumerState<PlacesSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  PlaceCategory? _selectedCategory;
  Timer? _debounce;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _loadNearby();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadNearby() {
    final loc = ref.read(locationProvider);
    if (loc.stats.currentLat != null) {
      ref.read(placesProvider.notifier).searchNearbyPlaces(
            LatLng(loc.stats.currentLat!, loc.stats.currentLon!));
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _loadNearby();
      setState(() => _hasSearched = false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () {
      setState(() => _hasSearched = true);
      final loc = ref.read(locationProvider);
      final proximity = loc.stats.currentLat != null
          ? LatLng(loc.stats.currentLat!, loc.stats.currentLon!)
          : null;
      ref.read(placesProvider.notifier).searchPlaces(query.trim(), proximity: proximity);
    });
  }

  @override
  Widget build(BuildContext context) {
    final placesState = ref.watch(placesProvider);
    final locationState = ref.watch(locationProvider);

    final filtered = _selectedCategory == null
        ? placesState.places
        : placesState.places.where((p) => p.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1035),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          onChanged: _onQueryChanged,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search towns, cities, landmarks…',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _onQueryChanged('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: Column(
        children: [
          // Category filter row
          Container(
            color: const Color(0xFF0D1035),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip(null, 'All'),
                  ...PlaceCategory.values.map((c) => _chip(c, c.displayName)),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1E2A5E)),

          // Results
          Expanded(
            child: placesState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primaryOrange))
                : placesState.error != null
                    ? _emptyState(Icons.cloud_off, placesState.error!, isError: true)
                    : filtered.isEmpty
                        ? _emptyState(
                            _hasSearched ? Icons.search_off : Icons.location_on,
                            _hasSearched
                                ? 'No results for "${_searchController.text}"'
                                : locationState.stats.currentLat == null
                                    ? 'GPS not acquired — type a place name above to search globally'
                                    : 'Searching for nearby places…',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) =>
                                _placeRow(filtered[i], locationState),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _chip(PlaceCategory? cat, String label) {
    final selected = _selectedCategory == cat;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = cat),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryOrange
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primaryOrange
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _placeRow(Place place, LocationState locationState) {
    final distKm = place.distance > 0
        ? '${(place.distance / 1000).toStringAsFixed(1)} km away'
        : '';
    return InkWell(
      onTap: () => Navigator.pop(context, place.location),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1A1F3A))),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: place.category.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(place.category.icon, color: place.category.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    [place.openingHours, distKm]
                        .where((s) => s.isNotEmpty)
                        .join('  ·  '),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.near_me_outlined,
                  color: AppColors.primaryOrange, size: 20),
              tooltip: 'Open in Google Maps',
              onPressed: () => _openInMaps(place),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String message, {bool isError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 48,
                color: isError ? Colors.red.withValues(alpha: 0.6) : Colors.white24),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isError ? Colors.red.withValues(alpha: 0.8) : Colors.white38,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Future<void> _openInMaps(Place place) async {
    final lat = place.location.latitude;
    final lon = place.location.longitude;
    final name = Uri.encodeComponent(place.name);
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lon&query_place_id=$name');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
