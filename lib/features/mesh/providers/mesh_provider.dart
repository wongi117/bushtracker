import 'dart:async';
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

  /// The most recent SOS received from another phone. The dashboard listens
  /// for a new id here and raises an alarm — before this, an incoming SOS was
  /// filed away silently and nobody on the receiving phone ever knew.
  final MeshPacket? lastIncomingSos;

  /// True while this phone is broadcasting its own SOS.
  final bool sosActive;

  MeshState({
    this.isAdvertising = false,
    this.isDiscovering = false,
    this.connectedEndpoints = const [],
    this.recentPackets = const [],
    this.peerLocations = const {},
    this.lastIncomingSos,
    this.sosActive = false,
  });

  MeshState copyWith({
    bool? isAdvertising,
    bool? isDiscovering,
    List<String>? connectedEndpoints,
    List<MeshPacket>? recentPackets,
    Map<String, MeshPacket>? peerLocations,
    MeshPacket? lastIncomingSos,
    bool? sosActive,
  }) {
    return MeshState(
      isAdvertising: isAdvertising ?? this.isAdvertising,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      connectedEndpoints: connectedEndpoints ?? this.connectedEndpoints,
      recentPackets: recentPackets ?? this.recentPackets,
      peerLocations: peerLocations ?? this.peerLocations,
      lastIncomingSos: lastIncomingSos ?? this.lastIncomingSos,
      sosActive: sosActive ?? this.sosActive,
    );
  }
}

class MeshNotifier extends StateNotifier<MeshState> {
  final String _userName = "BushTrack-${Random().nextInt(1000)}";
  late final IMeshTransport _transport = createTransport();
  final Set<String> _connectedPeers = {};

  /// Every packet id already handled. A flood relays each packet from several
  /// directions; handling each id once stops relay loops and stops one SOS
  /// alarming the same phone over and over. Insertion-ordered, capped.
  final Set<String> _seenPacketIds = {};

  MeshPacket? _activeSos;
  Timer? _sosRebroadcast;

  MeshNotifier() : super(MeshState());

  @override
  void dispose() {
    _sosRebroadcast?.cancel();
    super.dispose();
  }

  bool _markSeen(String id) {
    final isNew = _seenPacketIds.add(id);
    if (_seenPacketIds.length > 500) _seenPacketIds.remove(_seenPacketIds.first);
    return isNew;
  }

  Future<void> _sendTo(String peerId, MeshPacket packet) async {
    try {
      await _transport.sendBytes(
          peerId, Uint8List.fromList(packet.toJson().codeUnits));
    } catch (e) {
      debugPrint('MeshNotifier: send to $peerId failed: $e');
    }
  }

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
          // Someone walking into range while our SOS is active gets it now.
          final sos = _activeSos;
          if (sos != null) _sendTo(peerId, sos);
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
      if (!_markSeen(packet.id)) return;

      final updatedLocations = Map<String, MeshPacket>.from(state.peerLocations);
      if (packet.packetType == 'location' || packet.packetType == 'sos') {
        updatedLocations[packet.senderId] = packet;
      }

      final isIncomingSos =
          packet.packetType == 'sos' && packet.senderId != _userName;
      state = state.copyWith(
        recentPackets: [packet, ...state.recentPackets].take(50).toList(),
        peerLocations: updatedLocations,
        lastIncomingSos: isIncomingSos ? packet : null,
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

  /// Broadcast an SOS to every BushTrack phone in range, and keep offering it
  /// to phones that come into range for the next 30 minutes.
  ///
  /// The old version had three faults that together meant it almost never
  /// reached anyone: it carried no location, and if the mesh was off it
  /// started discovery and broadcast in the same breath — to zero connected
  /// peers — then gave up. Android only: browsers have no Bluetooth/Wi-Fi
  /// Direct, so on the web build this does nothing.
  Future<void> sendSOS({double? latitude, double? longitude}) async {
    if (kIsWeb) return;
    if (!state.isAdvertising && !state.isDiscovering) {
      await startMesh();
    }
    final packet = MeshPacket(
      id: 'SOS_${_userName}_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _userName,
      packetType: 'sos',
      // ASCII only — packets go over the wire as raw code units.
      payload: 'EMERGENCY: SOS Beacon Activated',
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ttl: 5,
    );
    _markSeen(packet.id);
    _activeSos = packet;
    if (mounted) state = state.copyWith(sosActive: true);
    await broadcastPacket(packet);

    _sosRebroadcast?.cancel();
    final started = DateTime.now();
    _sosRebroadcast = Timer.periodic(const Duration(seconds: 20), (_) {
      if (DateTime.now().difference(started) > const Duration(minutes: 30)) {
        cancelSOS();
        return;
      }
      broadcastPacket(packet);
    });
  }

  /// Stop broadcasting our SOS.
  void cancelSOS() {
    _sosRebroadcast?.cancel();
    _sosRebroadcast = null;
    _activeSos = null;
    if (mounted) state = state.copyWith(sosActive: false);
  }

}
