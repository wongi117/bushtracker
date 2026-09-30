import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common/sqflite.dart';
import 'core/services/database_service.dart';
import 'core/utils/startup_trace.dart';


import 'theme/app_theme.dart';
import 'features/onboarding/presentation/splash_screen.dart';

// Provider for database service (works on all platforms)
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('DatabaseService should be provided in main()');
});

// Provider for raw Database (sqflite) - used by legacy providers
final databaseProvider = Provider<Database>((ref) {
  throw UnimplementedError('Database should be provided in main()');
});

// Isar provider (only available on mobile, null on web)
final isarProvider = Provider<dynamic>((ref) => null);

void main() async {
  StartupTrace.mark('main');
  WidgetsFlutterBinding.ensureInitialized();
  StartupTrace.mark('binding');
  
  // Add comprehensive error handling for Flutter errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('🔴 FLUTTER ERROR: ${details.exceptionAsString()}');
    debugPrint('🔴 STACK: ${details.stack}');
  };

  // Catch async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🔴 PLATFORM ERROR: $error');
    debugPrint('🔴 STACK: $stack');
    return true;
  };

  // Initialize database service (works on all platforms including web)
  final databaseService = DatabaseService();
  await databaseService.initialize();
  StartupTrace.mark('database');

  // Isar is not opened any more.
  //
  // It threw "IllegalArg: Collection id is invalid" on every Android launch,
  // and nothing read it: isarProvider is consumed nowhere outside this file,
  // and every feature persists through DatabaseService (sqflite). So it cost
  // a failed open and the startup time to do it, and gave nothing back.
  // initializeIsar() is still in core/services if it is ever wanted.
  const dynamic isar = null;

  StartupTrace.mark('runApp');
  runApp(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(databaseService),
        if (isar != null) isarProvider.overrideWithValue(isar),
      ],
      child: const BushTrackApp(),
    ),
  );
}

class BushTrackApp extends StatelessWidget {
  const BushTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set custom error widget builder
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'RENDER ERROR',
                  style: TextStyle(color: Colors.red, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exceptionAsString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    };
    
    return MaterialApp(
      title: 'BushTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashGate(),
    );
  }
}
