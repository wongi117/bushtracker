import 'dart:async';
import 'package:flutter/services.dart';
import 'mesh_transport.dart';

// Communicates with MeshPlugin.swift via Flutter method/event channels.
class IosMeshTransport implements IMeshTransport {
  static const _method = MethodChannel('bushtrack/mesh');
  static const _events = EventChannel('bushtrack/mesh/events');

  StreamSubscription<dynamic>? _eventSub;
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
    _onPeerConnected = onPeerConnected;
    _onPeerDisconnected = onPeerDisconnected;
    _onBytesReceived = onBytesReceived;
    _eventSub = _events.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (_) {},
    );
    await _method.invokeMethod<void>('start', {'userName': userName});
  }

  void _handleEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String?;
    final peerId = (event['peerId'] as String?) ?? '';
    switch (type) {
      case 'peerConnected':
        _onPeerConnected?.call(peerId);
      case 'peerDisconnected':
        _onPeerDisconnected?.call(peerId);
      case 'bytesReceived':
        final raw = event['bytes'];
        if (raw is Uint8List) {
          _onBytesReceived?.call(peerId, raw);
        } else if (raw is List) {
          _onBytesReceived?.call(peerId, Uint8List.fromList(raw.cast<int>()));
        }
    }
  }

  @override
  Future<void> stop() async {
    await _eventSub?.cancel();
    _eventSub = null;
    await _method.invokeMethod<void>('stop');
  }

  @override
  Future<void> sendBytes(String peerId, Uint8List bytes) async {
    await _method.invokeMethod<void>('sendBytes', {
      'peerId': peerId,
      'bytes': bytes,
    });
  }
}
