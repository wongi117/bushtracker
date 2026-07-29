import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/places/providers/places_provider.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/features/places/services/places_service.dart';

class PlacesSearchScreen extends ConsumerStatefulWidget {
  const PlacesSearchScreen({super.key});

  @override
  ConsumerState<PlacesSearchScreen> createState() => _PlacesSearchScreenState();
}

class _PlacesSearchScreenState extends ConsumerState<PlacesSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<PlaceCategory> _categories = PlaceCategory.values;
  PlaceCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    // Search for nearby places when screen opens
    _searchNearbyPlaces();
  }

  void _searchNearbyPlaces() {
    final locationState = ref.read(locationProvider);
    if (locationState.stats.currentLat != null && locationState.stats.currentLon != null) {
      final location = LatLng(
        locationState.stats.currentLat!,
        locationState.stats.currentLon!,
      );
      ref.read(placesProvider.notifier).searchNearbyPlaces(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final placesState = ref.watch(placesProvider);
    final locationState = ref.watch(locationProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('📍 NEARBY PLACES'),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '🔍 Search places...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                  onPressed: () => _searchController.clear(),
                ),
                filled: true,
                fillColor: AppColors.panelMatte,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (value) {
                final locationState = ref.read(locationProvider);
                final proximity = locationState.stats.currentLat != null && locationState.stats.currentLon != null
                    ? LatLng(locationState.stats.currentLat!, locationState.stats.currentLon!)
                    : null;
                if (value.trim().isNotEmpty) {
                  ref.read(placesProvider.notifier).searchPlaces(value.trim(), proximity: proximity);
                }
              },
            ),
          ),
          
          // Category filters
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip(null, 'All', isSelected: _selectedCategory == null),
                const SizedBox(width: 8),
                ..._categories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildCategoryChip(
                      category,
                      category.displayName,
                      isSelected: _selectedCategory == category,
                    ),
                  );
                }),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Results
          Expanded(
            child: placesState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
                : placesState.error != null
                    ? Center(
                        child: Text(
                          placesState.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : placesState.places.isEmpty
                        ? const Center(
                            child: Text(
                              'No places found',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: placesState.places.length,
                            itemBuilder: (context, index) {
                              final place = placesState.places[index];
                              return _buildPlaceCard(place, locationState);
                            },
                          ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategoryChip(PlaceCategory? category, String label, {required bool isSelected}) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textSecondary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryOrange,
      backgroundColor: AppColors.panelMatte,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? category : null;
        });
      },
    );
  }
  
  Widget _buildPlaceCard(Place place, LocationState locationState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: place.category.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            place.category.icon,
            color: place.category.color,
          ),
        ),
        title: Text(
          place.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${(place.distance / 1000).toStringAsFixed(1)} km away',
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              place.openingHours,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.navigation, color: AppColors.primaryOrange),
          onPressed: () {
            // In a real implementation, this would start navigation to the place
          },
        ),
      ),
    );
  }
}
