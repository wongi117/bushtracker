import 'dart:convert';

class MeshPacket {
  final String id;
  final String senderId;
  final String packetType; // 'message', 'location', 'sos'
  final String payload;
  final double? latitude;
  final double? longitude;
  final int timestamp;
  final int ttl; // Time To Live (max hops)

  MeshPacket({
    required this.id,
    required this.senderId,
    this.packetType = 'message',
    required this.payload,
    this.latitude,
    this.longitude,
    required this.timestamp,
    this.ttl = 3,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'packetType': packetType,
      'payload': payload,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'ttl': ttl,
    };
  }

  factory MeshPacket.fromMap(Map<String, dynamic> map) {
    return MeshPacket(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      packetType: map['packetType'] ?? 'message',
      payload: map['payload'] ?? '',
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      timestamp: map['timestamp'] ?? 0,
      ttl: map['ttl'] ?? 3,
    );
  }

  String toJson() => json.encode(toMap());

  factory MeshPacket.fromJson(String source) => MeshPacket.fromMap(json.decode(source));
}
