import 'package:isar/isar.dart';

part 'breadcrumb.g.dart';

@Collection()
class Breadcrumb {
  Id? id;

  double? latitude;
  double? longitude;
  double? altitude;
  double? accuracy;
  double? speed;
  DateTime? timestamp;
  String? sessionId;
  
  Breadcrumb({
    this.id,
    this.latitude,
    this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    this.timestamp,
    this.sessionId,
  });

  factory Breadcrumb.fromMap(Map<String, dynamic> map) {
    return Breadcrumb(
      id: map['id'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      altitude: map['altitude']?.toDouble(),
      accuracy: map['accuracy']?.toDouble(),
      speed: map['speed']?.toDouble(),
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : null,
      sessionId: map['session_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
      'timestamp': timestamp?.millisecondsSinceEpoch,
      'session_id': sessionId,
    };
  }
}
