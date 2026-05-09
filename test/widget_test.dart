import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Core
import 'package:bush_track/features/onboarding/presentation/splash_screen.dart';
import 'package:bush_track/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bush_track/core/services/database_service.dart';
import 'package:bush_track/main.dart';

// Map & AR
import 'package:bush_track/features/map/presentation/map_3d_screen.dart';
import 'package:bush_track/features/ar/presentation/ar_compass_screen.dart';

// Navigation
import 'package:bush_track/features/navigation/presentation/navigation_screen.dart';
import 'package:bush_track/features/navigation/presentation/route_options_screen.dart';

// Places & AI
import 'package:bush_track/features/places/presentation/places_search_screen.dart';
import 'package:bush_track/features/places/presentation/saved_places_screen.dart';
import 'package:bush_track/features/ai/presentation/camp_finder_screen.dart';

// Chat
import 'package:bush_track/features/chat/presentation/chat_screen.dart';

// Other
import 'package:bush_track/features/elevation/presentation/elevation_profile_screen.dart';
import 'package:bush_track/features/location/presentation/location_sharing_screen.dart';
import 'package:bush_track/features/incidents/presentation/incident_reporting_screen.dart';

void main() {
  late DatabaseService databaseService;

  // Initialize sqflite_ffi for testing
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    databaseService = DatabaseService();
    await databaseService.initialize();
  });

  tearDownAll(() async {
    await databaseService.close();
  });

  // Helper to wrap widgets with necessary providers
  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(databaseService),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Screen Widget Tests', () {
    
    testWidgets('SplashScreen loads without crash', (tester) async {
      await tester.pumpWidget(createTestWidget(const SplashScreen()));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.textContaining('BUSH'), findsOneWidget);
      // Wait for the multi-stage initialization timer to complete
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpWidget(Container()); // Dispose to stop animations
    });

    testWidgets('DashboardScreen loads without crash', (tester) async {
      await tester.pumpWidget(createTestWidget(const DashboardScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DashboardScreen), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('Map3DScreen loads without crash', (tester) async {
      await tester.pumpWidget(createTestWidget(const Map3DScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(Map3DScreen), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('ARCompassScreen loads without crash', (tester) async {
      await tester.pumpWidget(createTestWidget(const ARCompassScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ARCompassScreen), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('NavigationScreen loads without crash', (tester) async {
      await tester.pumpWidget(createTestWidget(const NavigationScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(NavigationScreen), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('RouteOptionsScreen loads without crash', (tester) async {
      await tester.pumpWidget(createTestWidget(const RouteOptionsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(RouteOptionsScreen), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('PlacesSearchScreen loads without crash', (tester) async {
      await tester.pumpWidget(createTestWidget(const PlacesSearchScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(PlacesSearchScreen), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('SavedPlacesScreen loads without crash', (tester) async {
      await tester.pumpWidget(createTestWidget(const SavedPlacesScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SavedPlacesScreen), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('CampFinderScreen loads without crash', (tester) async {
      await tester.pumpWidget(createTestWidget(const CampFinderScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CampFinderScreen), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('ChatScreen loads without crash', (tester) async {
      await tester.pumpWidget(
        createTestWidget(const Scaffold(body: ChatScreen()))
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ChatScreen), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('ElevationProfileScreen loads without crash', (tester) async {
      await tester.pumpWidget(createTestWidget(const ElevationProfileScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ElevationProfileScreen), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('LocationSharingScreen loads without crash', (tester) async {
      await tester.pumpWidget(createTestWidget(const LocationSharingScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(LocationSharingScreen), findsOneWidget);
      await tester.pumpWidget(Container());
    });

    testWidgets('IncidentReportingScreen loads without crash', (tester) async {
      await tester.pumpWidget(createTestWidget(const IncidentReportingScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(IncidentReportingScreen), findsOneWidget);
      await tester.pumpWidget(Container());
    });
  });
}
