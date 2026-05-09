import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/core/utils/coordinate_utils.dart';
import 'package:bush_track/theme/app_colors.dart';

/// Measurement tool for map - distance, bearing, and area measurement
/// Replaces Avenza Maps and Google Maps measurement features
class MeasurementTool extends StatefulWidget {
  final MapController mapController;
  final VoidCallback? onMeasurementComplete;
  final Function(List<LatLng> points, Measurement measurement)? onPointsChanged;
  
  const MeasurementTool({
    super.key,
    required this.mapController,
    this.onMeasurementComplete,
    this.onPointsChanged,
  });

  @override
  MeasurementToolState createState() => MeasurementToolState();
}

class MeasurementToolState extends State<MeasurementTool> {
  MeasurementMode _mode = MeasurementMode.distance;
  final List<LatLng> _points = [];
  bool _isMeasuring = false;
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Mode selector
        Positioned(
          top: 120,
          left: 20,
          child: _buildModeSelector(),
        ),
        
        // Measurement panel
        if (_isMeasuring)
          Positioned(
            bottom: 200,
            left: 20,
            right: 20,
            child: _buildMeasurementPanel(),
          ),
          
        // Action buttons
        if (_isMeasuring)
          Positioned(
            bottom: 120,
            right: 20,
            child: _buildActionButtons(),
          ),
          
        // Start measurement button (when not measuring)
        if (!_isMeasuring)
          Positioned(
            bottom: 120,
            right: 20,
            child: _buildStartButton(),
          ),
      ],
    );
  }
  
  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📏 MEASURE',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          _buildModeButton(
            icon: Icons.straighten,
            label: '📏 Distance',
            isSelected: _mode == MeasurementMode.distance,
            onTap: () => setState(() => _mode = MeasurementMode.distance),
          ),
          const SizedBox(height: 8),
          _buildModeButton(
            icon: Icons.navigation,
            label: '🧭 Bearing',
            isSelected: _mode == MeasurementMode.bearing,
            onTap: () => setState(() => _mode = MeasurementMode.bearing),
          ),
          const SizedBox(height: 8),
          _buildModeButton(
            icon: Icons.square_foot,
            label: '📐 Area',
            isSelected: _mode == MeasurementMode.area,
            onTap: () => setState(() => _mode = MeasurementMode.area),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primaryOrange.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : Colors.white24,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryOrange : Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primaryOrange : Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMeasurementPanel() {
    String title;
    String value = '';
    String subtitle = '';
    
    switch (_mode) {
      case MeasurementMode.distance:
        title = '📏 DISTANCE';
        if (_points.length >= 2) {
          final dist = CoordinateUtils.calculateDistance(_points.first, _points.last);
          value = CoordinateUtils.formatDistance(dist);
          subtitle = 'From point 1 to point ${_points.length}';
        } else {
          value = 'Tap to set points';
        }
        break;
        
      case MeasurementMode.bearing:
        title = '🧭 BEARING';
        if (_points.length >= 2) {
          final bearing = CoordinateUtils.calculateBearing(_points.first, _points.last);
          value = CoordinateUtils.formatBearing(bearing);
          final cardinal = CoordinateUtils.getCardinalDirection(bearing);
          subtitle = 'Heading $cardinal';
        } else {
          value = 'Tap start and end points';
        }
        break;
        
      case MeasurementMode.area:
        title = '📐 AREA';
        if (_points.length >= 3) {
          final area = CoordinateUtils.calculatePolygonArea(_points);
          value = CoordinateUtils.formatArea(area);
          subtitle = '${_points.length} points measured';
        } else {
          value = 'Tap at least 3 points';
          subtitle = 'Tap to draw polygon area';
        }
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryOrange),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              if (_points.isNotEmpty)
                Text(
                  '${_points.length} point${_points.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_points.isNotEmpty)
          FloatingActionButton.small(
            heroTag: 'undo',
            backgroundColor: Colors.orange.withValues(alpha: 0.8),
            onPressed: _undoLastPoint,
            child: const Icon(Icons.undo, color: Colors.white),
          ),
        const SizedBox(height: 8),
        if (_points.isNotEmpty)
          FloatingActionButton.small(
            heroTag: 'clear',
            backgroundColor: Colors.red.withValues(alpha: 0.8),
            onPressed: _clearPoints,
            child: const Icon(Icons.clear, color: Colors.white),
          ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'done',
          backgroundColor: Colors.green,
          onPressed: _completeMeasurement,
          child: const Icon(Icons.check, color: Colors.white),
        ),
      ],
    );
  }
  
  Widget _buildStartButton() {
    return FloatingActionButton.extended(
      heroTag: 'measure',
      backgroundColor: AppColors.primaryOrange,
      onPressed: () {
        setState(() {
          _isMeasuring = true;
          _points.clear();
        });
        // Add tap listener to map
        _addTapHandler();
      },
      icon: const Icon(Icons.straighten),
      label: const Text('📏 MEASURE'),
    );
  }
  
  void _addTapHandler() {
    // The parent widget needs to handle map taps and call handleMapTap
  }
  
  void handleMapTap(LatLng point) {
    if (!_isMeasuring) return;
    
    setState(() {
      _points.add(point);
    });
    
    // Calculate current measurement
    _calculateAndNotify();
    
    // Auto-complete for distance/bearing after 2 points
    if (_mode != MeasurementMode.area && _points.length >= 2) {
      _completeMeasurement();
    }
  }
  
  void _calculateAndNotify() {
    if (_points.length < 2) return;
    
    Measurement? measurement;
    
    switch (_mode) {
      case MeasurementMode.distance:
        if (_points.length >= 2) {
          final dist = CoordinateUtils.calculateDistance(_points.first, _points.last);
          measurement = Measurement(
            type: MeasurementType.distance,
            value: dist,
            point1: _points.first,
            point2: _points.last,
          );
        }
        break;
        
      case MeasurementMode.bearing:
        if (_points.length >= 2) {
          final bearing = CoordinateUtils.calculateBearing(_points.first, _points.last);
          measurement = Measurement(
            type: MeasurementType.bearing,
            value: bearing,
            point1: _points.first,
            point2: _points.last,
          );
        }
        break;
        
      case MeasurementMode.area:
        if (_points.length >= 3) {
          final area = CoordinateUtils.calculatePolygonArea(_points);
          measurement = Measurement(
            type: MeasurementType.area,
            value: area,
            polygon: List.from(_points),
          );
        }
        break;
    }
    
    if (measurement != null) {
      widget.onPointsChanged?.call(_points, measurement);
    }
  }
  
  void _undoLastPoint() {
    if (_points.isNotEmpty) {
      setState(() {
        _points.removeLast();
      });
      _calculateAndNotify();
    }
  }
  
  void _clearPoints() {
    setState(() {
      _points.clear();
    });
  }
  
  void _completeMeasurement() {
    if (_points.isEmpty) return;
    
    Measurement? measurement;
    
    switch (_mode) {
      case MeasurementMode.distance:
        if (_points.length >= 2) {
          final dist = CoordinateUtils.calculateDistance(_points.first, _points.last);
          measurement = Measurement(
            type: MeasurementType.distance,
            value: dist,
            point1: _points.first,
            point2: _points.last,
          );
        }
        break;
        
      case MeasurementMode.bearing:
        if (_points.length >= 2) {
          final bearing = CoordinateUtils.calculateBearing(_points.first, _points.last);
          measurement = Measurement(
            type: MeasurementType.bearing,
            value: bearing,
            point1: _points.first,
            point2: _points.last,
          );
        }
        break;
        
      case MeasurementMode.area:
        if (_points.length >= 3) {
          final area = CoordinateUtils.calculatePolygonArea(_points);
          measurement = Measurement(
            type: MeasurementType.area,
            value: area,
            polygon: List.from(_points),
          );
        }
        break;
    }
    
    if (measurement != null) {
      widget.onMeasurementComplete?.call();
    }
    
    setState(() {
      _isMeasuring = false;
      _points.clear();
    });
  }
  
  // Get markers for current points
  List<Marker> getMeasurementMarkers() {
    return _points.asMap().entries.map((entry) {
      final index = entry.key;
      final point = entry.value;
      
      return Marker(
        point: point,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primaryOrange,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
  
  // Get polylines for measurement
  List<Polyline> getMeasurementPolylines() {
    if (_points.length < 2) return [];
    
    return [
      Polyline(
        points: _points,
        color: AppColors.primaryOrange,
        strokeWidth: 3.0,
      ),
    ];
  }
  
  // Get polygons for area measurement
  List<Polygon> getMeasurementPolygons() {
    if (_mode != MeasurementMode.area || _points.length < 3) return [];
    
    return [
      Polygon(
        points: _points,
        color: AppColors.primaryOrange.withValues(alpha: 0.3),
        borderColor: AppColors.primaryOrange,
        borderStrokeWidth: 2.0,
      ),
    ];
  }
  
  bool get isMeasuring => _isMeasuring;
  MeasurementMode get mode => _mode;
}

enum MeasurementMode {
  distance,
  bearing,
  area,
}
