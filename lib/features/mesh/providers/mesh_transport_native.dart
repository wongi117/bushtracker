import 'dart:io';
import 'mesh_transport.dart';
import 'mesh_transport_android.dart';
import 'mesh_transport_ios.dart';

// ignore: non_constant_identifier_names
IMeshTransport createTransport() {
  if (Platform.isIOS || Platform.isMacOS) return IosMeshTransport();
  return AndroidMeshTransport();
}
