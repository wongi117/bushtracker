import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:bush_track/core/models/mesh_packet.dart';

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
  final Strategy _strategy = Strategy.P2P_CLUSTER;

  MeshNotifier() : super(MeshState());

  Future<void> toggleMesh() async {
    if (state.isAdvertising || state.isDiscovering) {
      await stopMesh();
    } else {
      await startMesh();
    }
  }

  Future<void> startMesh() async {
    try {
      bool a = await Nearby().startAdvertising(
        _userName,
        _strategy,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            state = state.copyWith(
              connectedEndpoints: [...state.connectedEndpoints, id],
            );
          }
        },
        onDisconnected: (id) {
          state = state.copyWith(
            connectedEndpoints: state.connectedEndpoints.where((e) => e != id).toList(),
          );
        },
      );

      bool d = await Nearby().startDiscovery(
        _userName,
        _strategy,
        onEndpointFound: (id, name, serviceId) {
          // Auto-accept connections in mesh mode
          Nearby().requestConnection(
            _userName,
            id,
            onConnectionInitiated: _onConnectionInit,
            onConnectionResult: (id, status) {
              if (status == Status.CONNECTED) {
                state = state.copyWith(
                  connectedEndpoints: [...state.connectedEndpoints, id],
                );
              }
            },
            onDisconnected: (id) {
              state = state.copyWith(
                connectedEndpoints: state.connectedEndpoints.where((e) => e != id).toList(),
              );
            },
          );
        },
        onEndpointLost: (id) {},
      );

      state = state.copyWith(isAdvertising: a, isDiscovering: d);
    } catch (e) {
      // debugPrint("Mesh Start Error: \$e");
    }
  }

  void _onConnectionInit(String id, ConnectionInfo info) {
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES) {
          try {
            final str = String.fromCharCodes(payload.bytes ?? Uint8List(0));
            final packet = MeshPacket.fromJson(str);
            
            Map<String, MeshPacket> updatedPeerLocations = Map.from(state.peerLocations);
            if (packet.packetType == 'location' || packet.packetType == 'sos') {
              updatedPeerLocations[packet.senderId] = packet;
            }

            state = state.copyWith(
              recentPackets: [packet, ...state.recentPackets].take(50).toList(),
              peerLocations: updatedPeerLocations,
            );

            // Mesh forwarding logic (if TTL > 0)
            if (packet.ttl > 0 && packet.senderId != _userName) {
              final forwardedPacket = MeshPacket(
                id: packet.id, // Keep same ID for deduplication in real apps
                senderId: packet.senderId,
                packetType: packet.packetType,
                payload: packet.payload,
                latitude: packet.latitude,
                longitude: packet.longitude,
                ttl: packet.ttl - 1,
                timestamp: packet.timestamp,
              );
              broadcastPacket(forwardedPacket);
            }
          } catch (e) {
            // Invalid packet
          }
        }
      },
      onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {},
    );
  }

  Future<void> stopMesh() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    state = state.copyWith(
      isAdvertising: false,
      isDiscovering: false,
      connectedEndpoints: [],
    );
  }

  Future<void> broadcastPacket(MeshPacket packet) async {
    if (state.connectedEndpoints.isEmpty) return;
    
    final bytes = Uint8List.fromList(packet.toJson().codeUnits);
    for (var endpointId in state.connectedEndpoints) {
      await Nearby().sendBytesPayload(endpointId, bytes);
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
    final packet = MeshPacket(
      id: 'SOS_${_userName}_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _userName,
      packetType: 'sos',
      payload: 'EMERGENCY: SOS Beacon Activated',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ttl: 5, // Higher TTL for emergency
    );
    await broadcastPacket(packet);
  }
}
