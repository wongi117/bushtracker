import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';

class SavedPlacesScreen extends ConsumerStatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  ConsumerState<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends ConsumerState<SavedPlacesScreen> {
  final List<String> _categories = [
    '⭐ Favourites',
    '⛺ My Camp Spots',
    '💧 Water Sources',
    '🛤️ Known Tracks',
  ];
  
  String _selectedCategory = 'Favourites';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⭐ SAVED PLACES'),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Category tabs
          Container(
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.panelMatte,
              border: Border(bottom: BorderSide(color: AppColors.panelLight)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ChoiceChip(
                    label: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primaryOrange,
                    backgroundColor: Colors.transparent,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? category : 'Favourites';
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Places list
          Expanded(
            child: _buildPlacesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryOrange,
        onPressed: _addNewPlace,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
  
  Widget _buildPlacesList() {
    // In a real implementation, this would fetch places from the service
    // For now, we'll show sample data
    
    final samplePlaces = [
      {
        'name': 'Favorite Camp Spot',
        'description': 'Great views, flat ground',
        'location': const LatLng(-25.3444, 131.0369),
        'distance': '2.3km SW',
        'isFavorite': true,
      },
      {
        'name': 'Water Tank',
        'description': 'Reliable water source',
        'location': const LatLng(-25.3400, 131.0400),
        'distance': '5.1km N',
        'isFavorite': false,
      },
      {
        'name': 'Scenic Overlook',
        'description': 'Panoramic views of the outback',
        'location': const LatLng(-25.3350, 131.0450),
        'distance': '8.7km E',
        'isFavorite': true,
      },
    ];
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: samplePlaces.length,
      itemBuilder: (context, index) {
        final place = samplePlaces[index];
        return _buildPlaceCard(place);
      },
    );
  }
  
  Widget _buildPlaceCard(Map<String, dynamic> place) {
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
            color: place['isFavorite'] 
                ? AppColors.primaryOrange.withValues(alpha: 0.2) 
                : AppColors.panelLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            place['isFavorite'] ? Icons.star : Icons.place,
            color: place['isFavorite'] ? AppColors.primaryOrange : AppColors.textSecondary,
          ),
        ),
        title: Text(
          place['name'],
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
              place['description'],
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              place['distance'],
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
  
  void _addNewPlace() {
    // In a real implementation, this would open a form to add a new place
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add new place functionality would open here'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}