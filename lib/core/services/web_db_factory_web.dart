import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:web/web.dart' as web;

/// Real SQLite in the browser, so pins, zones, trails and notes survive a
/// refresh. Importing this package on Android would not compile, hence the
/// conditional import in database_service.dart.
///
/// Two ways to run it, tried in order: a shared web worker (keeps the DB off
/// the UI thread), then plain main-thread wasm. Some browsers and contexts
/// refuse the worker, and a slower database beats one that forgets.
List<DatabaseFactory> get webDatabaseFactories =>
    [databaseFactoryFfiWeb, databaseFactoryFfiWebNoWebWorker];

/// Leave the storage self-test result where it can be read back without a
/// console — release web builds print nothing, so a silent fallback to
/// in-memory storage is otherwise invisible.
void publishStorageReport(String report) {
  try {
    web.window.localStorage.setItem('bushtrack_storage_report', report);
  } catch (_) {}
}
