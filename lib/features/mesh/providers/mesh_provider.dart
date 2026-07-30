import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/core/models/mesh_packet.dart';
import 'mesh_transport.dart';
import 'mesh_transport_web.dart'
    if (dart.library.io) 'mesh_transport_native.dart';

final meshProvider = StateNotifierProvider<MeshNotifier, MeshState>((ref) {
  return MeshNotifier();
});

class MeshState {
  final bool isAdvertising;
  final bool isDiscovering;
  final List<String> connectedEndpoints;
  final List<MeshPacket> recentPackets;
  final Map<String, MeshPacket> peerLocations;

  MeshState({
    this.isAdvertising = false,
    this.isDiscovering = false,
    this.connectedEndpoints = const [],
    this.recentPackets = const [],
    this.peerLocations = const {},
  });

  MeshState copyWith({
    bool? isAdvertising,
    bool? isDiscovering,
    List<String>? connectedEndpoints,
    List<MeshPacket>? recentPackets,
    Map<String, MeshPacket>? peerLocations,
  }) {
    return MeshState(
      isAdvertising: isAdvertising ?? this.isAdvertising,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      connectedEndpoints: connectedEndpoints ?? this.connectedEndpoints,
      recentPackets: recentPackets ?? this.recentPackets,
      peerLocations: peerLocations ?? this.peerLocations,
    );
  }
}

class MeshNotifier extends StateNotifier<MeshState> {
  final String _userName = "BushTrack-${Random().nextInt(1000)}";
  late final IMeshTransport _transport = createTransport();
  final Set<String> _connectedPeers = {};

  MeshNotifier() : super(MeshState());

  Future<void> toggleMesh() async {
    if (state.isAdvertising || state.isDiscovering) {
      await stopMesh();
    } else {
      await startMesh();
    }
  }

  Future<void> startMesh() async {
    if (kIsWeb) return;
    try {
      await _transport.start(
        userName: _userName,
        onPeerConnected: (peerId) {
          _connectedPeers.add(peerId);
          state = state.copyWith(connectedEndpoints: _connectedPeers.toList());
        },
        onPeerDisconnected: (peerId) {
          _connectedPeers.remove(peerId);
          state = state.copyWith(connectedEndpoints: _connectedPeers.toList());
        },
        onBytesReceived: (_, bytes) => _handleIncomingBytes(bytes),
      );
      state = state.copyWith(isAdvertising: true, isDiscovering: true);
    } catch (e) {
      debugPrint('MeshNotifier.startMesh error: $e');
    }
  }

  void _handleIncomingBytes(Uint8List bytes) {
    try {
      final str = String.fromCharCodes(bytes);
      final packet = MeshPacket.fromJson(str);

      final updatedLocations = Map<String, MeshPacket>.from(state.peerLocations);
      if (packet.packetType == 'location' || packet.packetType == 'sos') {
        updatedLocations[packet.senderId] = packet;
      }

      state = state.copyWith(
        recentPackets: [packet, ...state.recentPackets].take(50).toList(),
        peerLocations: updatedLocations,
      );

      if (packet.ttl > 0 && packet.senderId != _userName) {
        broadcastPacket(MeshPacket(
          id: packet.id,
          senderId: packet.senderId,
          packetType: packet.packetType,
          payload: packet.payload,
          latitude: packet.latitude,
          longitude: packet.longitude,
          ttl: packet.ttl - 1,
          timestamp: packet.timestamp,
        ));
      }
    } catch (_) {}
  }

  Future<void> stopMesh() async {
    if (kIsWeb) return;
    await _transport.stop();
    _connectedPeers.clear();
    state = state.copyWith(
      isAdvertising: false,
      isDiscovering: false,
      connectedEndpoints: [],
    );
  }

  Future<void> broadcastPacket(MeshPacket packet) async {
    if (kIsWeb || _connectedPeers.isEmpty) return;
    final bytes = Uint8List.fromList(packet.toJson().codeUnits);
    for (final peerId in List<String>.from(_connectedPeers)) {
      await _transport.sendBytes(peerId, bytes);
    }
  }

  Future<void> sendMessage(String text) async {
    final packet = MeshPacket(
      id: '${_userName}_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _userName,
      packetType: 'message',
      payload: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ttl: 3,
    );
    await broadcastPacket(packet);
  }

  Future<void> broadcastLocation(double lat, double lon) async {
    final packet = MeshPacket(
      id: 'LOC_${_userName}_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _userName,
      packetType: 'location',
      payload: 'Location Update',
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ttl: 2,
    );
    await broadcastPacket(packet);
  }

  Future<void> sendSOS() async {
    if (kIsWeb) return;
    if (!state.isAdvertising && !state.isDiscovering) {
      await startMesh();
    }
    final packet = MeshPacket(
      id: 'SOS_${_userName}_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _userName,
      packetType: 'sos',
      payload: 'EMERGENCY: SOS Beacon Activated',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ttl: 5,
    );
    await broadcastPacket(packet);
  }
}
