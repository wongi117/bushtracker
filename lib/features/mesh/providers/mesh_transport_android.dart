import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import 'mesh_transport.dart';

class AndroidMeshTransport implements IMeshTransport {
  static const Strategy _strategy = Strategy.P2P_CLUSTER;

  /// Asks for everything Nearby Connections needs, and reports whether it can
  /// actually run.
  ///
  /// permission_handler reports the bluetooth trio as granted on Android
  /// versions that do not have them, so the same check works either way.
  /// nearbyWifiDevices is requested but not required: Nearby falls back to
  /// bluetooth without it, at shorter range.
  static Future<bool> ensurePermissions() async {
    try {
      final results = await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.nearbyWifiDevices,
      ].request();

      bool granted(Permission p) => results[p]?.isGranted ?? false;

      final ok = granted(Permission.location) &&
          granted(Permission.bluetoothScan) &&
          granted(Permission.bluetoothAdvertise) &&
          granted(Permission.bluetoothConnect);

      debugPrint('Mesh permissions granted=$ok '
          '${results.map((k, v) => MapEntry(k.toString(), v.toString()))}');
      return ok;
    } catch (e) {
      debugPrint('Mesh permission request failed: $e');
      return false;
    }
  }

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

    // nearby_connections v4 removed its permission helpers, and without these
    // granted startAdvertising fails quietly — the phone looks like it is on
    // the mesh while being invisible to every other phone. Which is the worst
    // possible failure for a safety feature.
    if (!await ensurePermissions()) {
      throw StateError('Mesh permissions denied');
    }

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
