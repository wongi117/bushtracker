import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class IncidentReport {
  final String id;
  final String type;
  final String description;
  final LatLng location;
  final DateTime timestamp;
  final String reportedBy;
  final bool isResolved;

  IncidentReport({
    required this.id,
    required this.type,
    required this.description,
    required this.location,
    required this.timestamp,
    required this.reportedBy,
    this.isResolved = false,
  });
}

class IncidentReportingService {
  final Ref ref;
  final List<IncidentReport> _localReports = [];
  
  // Incident types
  static const String roadClosed = 'road_closed';
  static const String flooded = 'flooded';
  static const String fallenTree = 'fallen_tree';
  static const String rockSlide = 'rock_slide';
  static const String fuelAvailable = 'fuel_available';
  static const String waterAvailable = 'water_available';
  static const String campSpot = 'camp_spot';
  static const String wildlife = 'wildlife';
  static const String powerLines = 'power_lines';
  static const String mineSite = 'mine_site';
  static const String bushfire = 'bushfire';

  IncidentReportingService(this.ref);

  Future<void> reportIncident({
    required String type,
    required String description,
    required LatLng location,
    required String reporterId,
  }) async {
    final report = IncidentReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      description: description,
      location: location,
      timestamp: DateTime.now(),
      reportedBy: reporterId,
    );
    
    // Add to local reports
    _localReports.add(report);
    
    // Broadcast via mesh network
    await _broadcastViaMesh(report);
    
    // In a real implementation, we would also send to a community server when online
    // await _sendToCommunityServer(report);
  }

  Future<void> _broadcastViaMesh(IncidentReport report) async {
    // Create a mesh packet for the incident report
    // final packet = {
    //   'id': report.id,
    //   'type': 'incident_report',
    //   'incident_type': report.type,
    //   'description': report.description,
    //   'lat': report.location.latitude,
    //   'lon': report.location.longitude,
    //   'timestamp': report.timestamp.millisecondsSinceEpoch,
    //   'reporter': report.reportedBy,
    // };
    
    // Send via mesh provider
    // Note: We would need to modify the mesh provider to handle incident reports
    // For now, we'll just log that we would send it
    // debugPrint('Would broadcast incident report via mesh: \$packet');
  }

  List<IncidentReport> getReportsNearLocation(LatLng location, {double radiusKm = 50}) {
    return _localReports.where((report) {
      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        report.location.latitude,
        report.location.longitude,
      );
      return distance <= radiusKm * 1000; // Convert km to meters
    }).toList();
  }

  List<IncidentReport> getLocalReports() {
    return List.from(_localReports);
  }
  
  void clearResolvedReports() {
    _localReports.removeWhere((report) => report.isResolved);
  }
}

// Provider for the incident reporting service
final incidentReportingServiceProvider = Provider((ref) {
  return IncidentReportingService(ref);
});