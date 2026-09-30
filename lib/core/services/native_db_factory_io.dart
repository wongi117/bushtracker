import 'dart:io';

import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show sqfliteFfiInit, databaseFactoryFfi;

/// The right SQLite factory for the platform this is running on.
///
/// Android and iOS must use the sqflite PLUGIN. The app used
/// databaseFactoryFfi everywhere off the web, and on a phone that fails with
/// "unable to open database file (code 14)" — FFI resolves a databases
/// directory the app has no access to. The effect was that nothing saved on
/// Android at all: no pins, no zones, no files, no trails.
///
/// Desktop has no such plugin, so Windows, macOS and Linux do use FFI.
DatabaseFactory? nativeDatabaseFactory() {
  if (Platform.isAndroid || Platform.isIOS) {
    return sqflite.databaseFactory;
  }
  sqfliteFfiInit();
  return databaseFactoryFfi;
}
