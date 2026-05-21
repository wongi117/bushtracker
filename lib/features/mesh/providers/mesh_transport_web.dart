import 'dart:typed_data';
import 'mesh_transport.dart';

// ignore: non_constant_identifier_names
IMeshTransport createTransport() => _WebMeshTransport();

class _WebMeshTransport implements IMeshTransport {
  @override
  Future<void> start({
    required String userName,
    required void Function(String) onPeerConnected,
    required void Function(String) onPeerDisconnected,
    required void Function(String, Uint8List) onBytesReceived,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> sendBytes(String peerId, Uint8List bytes) async {}
}
