import 'dart:typed_data';

abstract class IMeshTransport {
  Future<void> start({
    required String userName,
    required void Function(String peerId) onPeerConnected,
    required void Function(String peerId) onPeerDisconnected,
    required void Function(String peerId, Uint8List bytes) onBytesReceived,
  });
  Future<void> stop();
  Future<void> sendBytes(String peerId, Uint8List bytes);
}
