import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/incidents/services/incident_reporting_service.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';

class IncidentReportingScreen extends ConsumerStatefulWidget {
  const IncidentReportingScreen({super.key});

  @override
  ConsumerState<IncidentReportingScreen> createState() => _IncidentReportingScreenState();
}

class _IncidentReportingScreenState extends ConsumerState<IncidentReportingScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedIncidentType = IncidentReportingService.roadClosed;
  bool _isReporting = false;

  // Incident type options with icons and colors
  final Map<String, Map<String, dynamic>> _incidentTypes = {
    IncidentReportingService.roadClosed: {
      'label': '🚧 Road Closed',
      'icon': Icons.block,
      'color': Colors.red,
    },
    IncidentReportingService.flooded: {
      'label': '🌊 Flooded',
      'icon': Icons.water_damage,
      'color': Colors.blue,
    },
    IncidentReportingService.fallenTree: {
      'label': '🌳 Fallen Tree',
      'icon': Icons.eco,
      'color': Colors.brown,
    },
    IncidentReportingService.rockSlide: {
      'label': '🪨 Rock Slide',
      'icon': Icons.landslide,
      'color': Colors.grey,
    },
    IncidentReportingService.fuelAvailable: {
      'label': '⛽ Fuel Available',
      'icon': Icons.local_gas_station,
      'color': Colors.green,
    },
    IncidentReportingService.waterAvailable: {
      'label': '💧 Water Available',
      'icon': Icons.water_drop,
      'color': Colors.blue,
    },
    IncidentReportingService.campSpot: {
      'label': '⛺ Camp Spot',
      'icon': Icons.outdoor_grill,
      'color': Colors.brown,
    },
    IncidentReportingService.wildlife: {
      'label': '🦘 Wildlife',
      'icon': Icons.pets,
      'color': Colors.orange,
    },
    IncidentReportingService.powerLines: {
      'label': '⚡ Power Lines',
      'icon': Icons.flash_on,
      'color': Colors.yellow,
    },
    IncidentReportingService.mineSite: {
      'label': '⚠️ Mine Site',
      'icon': Icons.warning,
      'color': Colors.red,
    },
    IncidentReportingService.bushfire: {
      'label': '🔥 Bushfire',
      'icon': Icons.local_fire_department,
      'color': Colors.red,
    },
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚠️ REPORT INCIDENT'),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Incident type selection
            const Text(
              '📋 SELECT INCIDENT TYPE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _incidentTypes.length,
                itemBuilder: (context, index) {
                  final type = _incidentTypes.keys.elementAt(index);
                  final info = _incidentTypes[type]!;
                  final isSelected = _selectedIncidentType == type;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIncidentType = type;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.panelLight : AppColors.panelMatte,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? info['color'] as Color : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            info['icon'] as IconData,
                            size: 32,
                            color: isSelected ? info['color'] as Color : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            info['label'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Description input
            const Text(
              '📝 DESCRIPTION',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe the incident...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.panelMatte,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            
            const SizedBox(height: 24),
            
            // Report button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isReporting ? null : _reportIncident,
              child: _isReporting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      '🚨 REPORT INCIDENT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _reportIncident() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a description'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setState(() {
      _isReporting = true;
    });
    
    try {
      final incidentReportingService = ref.read(incidentReportingServiceProvider);
      final locationState = ref.read(locationProvider);
      
      final lat = locationState.stats.currentLat;
      final lon = locationState.stats.currentLon;
      
      if (lat == null || lon == null) {
        throw Exception('Unable to get current location');
      }
      
      await incidentReportingService.reportIncident(
        type: _selectedIncidentType,
        description: _descriptionController.text.trim(),
        location: LatLng(lat, lon),
        reporterId: 'BRAVO-3', // In a real implementation, this would be the user's ID
      );
      
      // Clear the form
      _descriptionController.clear();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident reported successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Close the screen after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to report incident: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReporting = false;
        });
      }
    }
  }
}