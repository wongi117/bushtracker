// ignore_for_file: constant_identifier_names
// Web stub — nearby_connections is not available on web.
// Provides minimal no-op types so mesh_provider.dart compiles on web.

enum Strategy { P2P_CLUSTER, P2P_POINT_TO_POINT, P2P_STAR }
enum Status { CONNECTED, REJECTED, ERROR }
enum PayloadType { BYTES, FILE, STREAM }

class ConnectionInfo {
  final String endpointName;
  final String authenticationToken;
  final bool isIncomingConnection;
  const ConnectionInfo(this.endpointName, this.authenticationToken, this.isIncomingConnection);
}

class Payload {
  final PayloadType type;
  final List<int>? bytes;
  const Payload({required this.type, this.bytes});
}

class PayloadTransferUpdate {
  final int id;
  final int bytesTransferred;
  final int totalBytes;
  final int status;
  const PayloadTransferUpdate({
    required this.id,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.status,
  });
}

class Nearby {
  static final Nearby _instance = Nearby._();
  factory Nearby() => _instance;
  Nearby._();

  Future<bool> startAdvertising(
    String userNickName,
    Strategy strategy, {
    required void Function(String, ConnectionInfo) onConnectionInitiated,
    required void Function(String, Status) onConnectionResult,
    required void Function(String) onDisconnected,
    String? serviceId,
  }) async => false;

  Future<bool> startDiscovery(
    String userNickName,
    Strategy strategy, {
    required void Function(String, String, String) onEndpointFound,
    required void Function(String?) onEndpointLost,
    String? serviceId,
  }) async => false;

  Future<void> stopAdvertising() async {}
  Future<void> stopDiscovery() async {}
  Future<void> stopAllEndpoints() async {}

  Future<void> requestConnection(
    String userNickName,
    String endpointId, {
    required void Function(String, ConnectionInfo) onConnectionInitiated,
    required void Function(String, Status) onConnectionResult,
    required void Function(String) onDisconnected,
  }) async {}

  Future<void> acceptConnection(
    String endpointId, {
    required void Function(String, Payload) onPayLoadRecieved,
    required void Function(String, PayloadTransferUpdate) onPayloadTransferUpdate,
  }) async {}

  Future<void> sendBytesPayload(String endpointId, List<int> bytes) async {}
}
