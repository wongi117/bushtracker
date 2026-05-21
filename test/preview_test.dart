// preview_test.dart
//
// Lightweight widget preview tests for Flutter Widget Test Preview extension.
// Each test is self-contained — no GPS, DB, or platform channels needed.
// Click "▶ Preview" above any testWidgets() to see it render live.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Shared test app wrapper ───────────────────────────────────

Widget _app(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF060E06),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE8A020),
          secondary: Color(0xFF2E4A2E),
          surface: Color(0xFF0D1A0D),
        ),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF060E06),
        body: SafeArea(child: child),
      ),
    );

// ── Preview Tests ─────────────────────────────────────────────

void main() {
  group('BushTrack UI Previews', () {

    testWidgets('SOS Button', (tester) async {
      await tester.pumpWidget(_app(
        Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 80,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_rounded, color: Colors.white, size: 20),
                  Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('SOS'), findsOneWidget);
    });

    testWidgets('Tracking Status Badge — active', (tester) async {
      await tester.pumpWidget(_app(
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              border: Border.all(color: Colors.green),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'TRACKING',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('TRACKING'), findsOneWidget);
    });

    testWidgets('Guide Overlay card', (tester) async {
      await tester.pumpWidget(_app(
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1A0D),
                border: Border.all(color: const Color(0xFF2E4A2E)),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BushTrack is active. Recording started at 08:42.',
                    style: TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: const Text('Got it',
                          style: TextStyle(color: Color(0xFFE8A020))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.textContaining('BushTrack is active'), findsOneWidget);
    });

    testWidgets('Compass bearing display', (tester) async {
      await tester.pumpWidget(_app(
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE8A020), width: 2),
                  color: const Color(0xFF0D1A0D),
                ),
                child: const Center(
                  child: Icon(Icons.navigation,
                      color: Color(0xFFE8A020), size: 80),
                ),
              ),
              const SizedBox(height: 24),
              const Text('247°  NW',
                style: TextStyle(
                  color: Color(0xFFE8A020),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text('3.2 km  ·  ~48 min walk',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('247°  NW'), findsOneWidget);
    });

    testWidgets('Bottom nav bar buttons', (tester) async {
      await tester.pumpWidget(_app(
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            color: const Color(0xFF060E06),
            child: Row(
              children: [
                _NavButton(icon: Icons.explore, label: 'Compass', onTap: () {}),
                const SizedBox(width: 12),
                _NavButton(icon: Icons.home, label: 'Start', onTap: () {}),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 80, height: 56,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_rounded, color: Colors.white, size: 20),
                        Text('SOS', style: TextStyle(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w900, letterSpacing: 2)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('Compass'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
    });

    testWidgets('Coordinate tile', (tester) async {
      await tester.pumpWidget(_app(
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1A0D),
              border: Border.all(color: const Color(0xFF2E4A2E)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MY POSITION',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10, letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('-27.98432',
                  style: TextStyle(color: Color(0xFFE8A020),
                      fontSize: 14, fontFamily: 'monospace')),
                const Text('121.45672',
                  style: TextStyle(color: Color(0xFFE8A020),
                      fontSize: 14, fontFamily: 'monospace')),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('MY POSITION'), findsOneWidget);
      expect(find.text('-27.98432'), findsOneWidget);
    });

  });
}

// ── Helper widget ─────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1A0D),
          border: Border.all(color: const Color(0xFF2E4A2E)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFE8A020), size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
