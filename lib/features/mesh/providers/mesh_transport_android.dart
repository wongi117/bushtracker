import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'mesh_transport.dart';

class AndroidMeshTransport implements IMeshTransport {
  static const Strategy _strategy = Strategy.P2P_CLUSTER;

  String _userName = '';
  void Function(String)? _onPeerConnected;
  void Function(String)? _onPeerDisconnected;
  void Function(String, Uint8List)? _onBytesReceived;

  @override
  Future<void> start({
    required String userName,
    required void Function(String peerId) onPeerConnected,
    required void Function(String peerId) onPeerDisconnected,
    required void Function(String peerId, Uint8List bytes) onBytesReceived,
  }) async {
    _userName = userName;
    _onPeerConnected = onPeerConnected;
    _onPeerDisconnected = onPeerDisconnected;
    _onBytesReceived = onBytesReceived;

    await Nearby().startAdvertising(
      _userName,
      _strategy,
      onConnectionInitiated: _onConnectionInit,
      onConnectionResult: (id, status) {
        if (status == Status.CONNECTED) _onPeerConnected?.call(id);
      },
      onDisconnected: (id) => _onPeerDisconnected?.call(id),
    );

    await Nearby().startDiscovery(
      _userName,
      _strategy,
      onEndpointFound: (id, name, serviceId) {
        Nearby().requestConnection(
          _userName,
          id,
          onConnectionInitiated: _onConnectionInit,
          onConnectionResult: (id, status) {
            if (status == Status.CONNECTED) _onPeerConnected?.call(id);
          },
          onDisconnected: (id) => _onPeerDisconnected?.call(id),
        );
      },
      onEndpointLost: (_) {},
    );
  }

  void _onConnectionInit(String id, ConnectionInfo info) {
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES && payload.bytes != null) {
          _onBytesReceived?.call(endpointId, Uint8List.fromList(payload.bytes!));
        }
      },
      onPayloadTransferUpdate: (_, __) {},
    );
  }

  @override
  Future<void> stop() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
  }

  @override
  Future<void> sendBytes(String peerId, Uint8List bytes) async {
    await Nearby().sendBytesPayload(peerId, bytes);
  }
}
