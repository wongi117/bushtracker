import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/incidents/services/incident_reporting_service.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';

class IncidentReportingScreen extends ConsumerStatefulWidget {
  const IncidentReportingScreen({super.key});

  @override
  ConsumerState<IncidentReportingScreen> createState() =>
      _IncidentReportingScreenState();
}

class _IncidentReportingScreenState
    extends ConsumerState<IncidentReportingScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedIncidentType = IncidentReportingService.roadClosed;
  bool _isReporting = false;

  final Map<String, Map<String, dynamic>> _incidentTypes = {
    IncidentReportingService.roadClosed: {
      'label': 'Road Closed',
      'emoji': '🚧',
      'icon': Icons.block,
      'color': Colors.red,
      'description': 'Track or road is physically blocked — gate, barrier, landslide, or washed-out crossing.',
    },
    IncidentReportingService.flooded: {
      'label': 'Flooded',
      'emoji': '🌊',
      'icon': Icons.water_damage,
      'color': Colors.blue,
      'description': 'Water over the track or crossing. Depth unknown — do not attempt without checking.',
    },
    IncidentReportingService.fallenTree: {
      'label': 'Fallen Tree',
      'emoji': '🌳',
      'icon': Icons.eco,
      'color': Colors.brown,
      'description': 'Tree fallen across the track, blocking vehicles or walkers.',
    },
    IncidentReportingService.rockSlide: {
      'label': 'Rock Slide',
      'emoji': '🪨',
      'icon': Icons.landslide,
      'color': Colors.grey,
      'description': 'Rocks or debris on the track from a slide or cliff. Hazard to tyres and undercarriage.',
    },
    IncidentReportingService.fuelAvailable: {
      'label': 'Fuel Available',
      'emoji': '⛽',
      'icon': Icons.local_gas_station,
      'color': Colors.green,
      'description': 'Fuel station or drum cache available at this location. Useful for remote routes.',
    },
    IncidentReportingService.waterAvailable: {
      'label': 'Water Available',
      'emoji': '💧',
      'icon': Icons.water_drop,
      'color': Colors.blue,
      'description': 'Reliable water source — bore, tank, or creek — confirmed at this location.',
    },
    IncidentReportingService.campSpot: {
      'label': 'Camp Spot',
      'emoji': '⛺',
      'icon': Icons.outdoor_grill,
      'color': Colors.brown,
      'description': 'Good campsite here — flat ground, shelter, or existing fire ring.',
    },
    IncidentReportingService.wildlife: {
      'label': 'Wildlife',
      'emoji': '🦘',
      'icon': Icons.pets,
      'color': Colors.orange,
      'description': 'Significant wildlife sighting — snake, large mob, injured animal, or unusual activity.',
    },
    IncidentReportingService.powerLines: {
      'label': 'Power Lines',
      'emoji': '⚡',
      'icon': Icons.flash_on,
      'color': Colors.yellow,
      'description': 'Downed or low-hanging power lines. Extreme danger — keep well clear.',
    },
    IncidentReportingService.mineSite: {
      'label': 'Mine Site',
      'emoji': '⚠️',
      'icon': Icons.warning,
      'color': Colors.red,
      'description': 'Active or historic mine site ahead. Entry may be restricted and hazardous.',
    },
    IncidentReportingService.bushfire: {
      'label': 'Bushfire',
      'emoji': '🔥',
      'icon': Icons.local_fire_department,
      'color': Colors.red,
      'description': 'Active fire or heavy smoke in the area. Report to authorities immediately.',
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
        title: const Text('REPORT INCIDENT'),
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
            // Intro banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mark hazards, resources, and points of interest at your current GPS location so other travellers know what to expect.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            const Text(
              'SELECT INCIDENT TYPE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                itemCount: _incidentTypes.length,
                itemBuilder: (context, index) {
                  final type = _incidentTypes.keys.elementAt(index);
                  final info = _incidentTypes[type]!;
                  final isSelected = _selectedIncidentType == type;
                  final color = info['color'] as Color;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedIncidentType = type),
                    onLongPress: () => _showDescription(info),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.2)
                            : AppColors.panelMatte,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? color : Colors.white12,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(info['emoji'] as String,
                                    style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 4),
                                if (isSelected)
                                  Icon(Icons.check_circle, color: color, size: 14),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              info['label'] as String,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Selected type description
            if (_incidentTypes[_selectedIncidentType] != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.panelMatte,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.help_outline, color: AppColors.primaryOrange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _incidentTypes[_selectedIncidentType]!['description'] as String,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                ]),
              ),

            // Description input
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add details (optional)...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.panelMatte,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
              style: const TextStyle(color: Colors.white),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isReporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                            strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(
                  _isReporting ? 'Reporting...' : 'SUBMIT REPORT',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: _isReporting ? null : _reportIncident,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDescription(Map<String, dynamic> info) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelMatte,
        title: Text('${info['emoji']} ${info['label']}',
            style: const TextStyle(color: Colors.white)),
        content: Text(info['description'] as String,
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.primaryOrange)),
          ),
        ],
      ),
    );
  }

  Future<void> _reportIncident() async {
    setState(() => _isReporting = true);

    try {
      final service = ref.read(incidentReportingServiceProvider);
      final locationState = ref.read(locationProvider);
      final lat = locationState.stats.currentLat;
      final lon = locationState.stats.currentLon;

      if (lat == null || lon == null) {
        throw Exception('No GPS fix — step outside and try again.');
      }

      await service.reportIncident(
        type: _selectedIncidentType,
        description: _descriptionController.text.trim().isEmpty
            ? (_incidentTypes[_selectedIncidentType]!['label'] as String)
            : _descriptionController.text.trim(),
        location: LatLng(lat, lon),
        reporterId: 'BRAVO-3',
      );

      _descriptionController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_incidentTypes[_selectedIncidentType]!['emoji']} Incident reported at your location.'),
            backgroundColor: AppColors.statusGreen,
            duration: const Duration(seconds: 2),
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReporting = false);
    }
  }
}
