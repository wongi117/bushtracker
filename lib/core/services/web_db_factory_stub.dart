import 'package:sqflite_common/sqflite.dart';

/// Off the web there is no browser database; native opens the FFI factory
/// directly. See web_db_factory_web.dart for the web implementation.
List<DatabaseFactory> get webDatabaseFactories => const [];

/// No-op off the web: the phone build has a real file and a real console.
void publishStorageReport(String report) {}
