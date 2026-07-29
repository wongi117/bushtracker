class MeshPeer {
  int? id;

  String? peerId;
  String? displayName;
  double? lastLatitude;
  double? lastLongitude;
  double? lastAltitude;
  DateTime? lastSeen;
  DateTime? firstSeen;
  String? deviceType;
  int? signalStrength;
  bool? isConnected;
  String? publicKey;

  MeshPeer({
    this.id,
    this.peerId,
    this.displayName,
    this.lastLatitude,
    this.lastLongitude,
    this.lastAltitude,
    this.lastSeen,
    this.firstSeen,
    this.deviceType,
    this.signalStrength,
    this.isConnected,
    this.publicKey,
  });
}
