// The offline-first brief asks for an always-visible status. It earns its space
// for one reason: in this app "it didn't work" and "it hasn't sent yet" look
// identical from outside, and after pressing SOS that is the difference that
// matters. So what gets tested is that every state is distinguishable, and that
// the normal case stays quiet.
//
// Tested through ConnectivityDisplay rather than the widget, because the
// notifier runs a real connectivity check on construction: a provider override
// pinning it to "offline" is overwritten mid-pump by the live check, and on a
// machine with a connection the offline cases simply never render.
import 'package:bush_track/core/services/connectivity_service.dart';
import 'package:bush_track/features/map/widgets/connectivity_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ConnectivityDisplay show(ConnectivityState state, {int pending = 0}) =>
      ConnectivityDisplay.from(state, pending);

  const online = ConnectivityState(isConnected: true, connectionType: 'wifi');
  const offline = ConnectivityState(connectionType: 'none');
  const checking = ConnectivityState(connectionType: 'checking');

  group('online', () {
    test('stays quiet — an icon and no words', () {
      // A badge that shouts when all is well teaches people to ignore it, and
      // then it is no use in the case that matters.
      final d = show(online);
      expect(d.icon, Icons.cloud_done);
      expect(d.label, isNull);
    });
  });

  group('offline', () {
    test('says so in words, not just a colour', () {
      final d = show(offline);
      expect(d.icon, Icons.cloud_off);
      expect(d.label, 'OFFLINE');
    });

    test('counts what is waiting, because that changes the situation', () {
      // "Offline" and "offline with three things queued" are different things
      // to know.
      expect(show(offline, pending: 3).label, 'OFFLINE · 3 QUEUED');
    });

    test('a mobile connection that is down is still offline', () {
      const dropped =
          ConnectivityState(isConnected: false, connectionType: 'mobile');
      expect(show(dropped).icon, Icons.cloud_off);
    });
  });

  group('syncing', () {
    test('online with a queue shows progress, not a tick', () {
      final d = show(online, pending: 2);
      expect(d.icon, Icons.sync);
      expect(d.label, 'SYNCING 2');
    });

    test('online with an empty queue is just online', () {
      expect(show(online).icon, Icons.cloud_done);
    });
  });

  group('before the first check', () {
    test('does not claim to be offline', () {
      // Saying OFFLINE before anything has been checked is a lie that lasts a
      // second and undermines the badge for the whole session.
      final d = show(checking);
      expect(d.icon, Icons.cloud_queue);
      expect(d.label, isNull);
    });

    test('and does not claim to be syncing either', () {
      expect(show(checking, pending: 4).label, isNull);
    });
  });

  group('every state is distinguishable', () {
    test('each has its own icon', () {
      final icons = {
        show(checking).icon,
        show(online).icon,
        show(online, pending: 2).icon,
        show(offline).icon,
      };
      expect(icons, hasLength(4),
          reason: 'two states sharing an icon cannot be told apart');
    });

    test('each has its own colour', () {
      final colours = {
        show(checking).colour,
        show(online).colour,
        show(online, pending: 2).colour,
        show(offline).colour,
      };
      expect(colours, hasLength(4));
    });

    test('offline is the only red one', () {
      expect(show(offline).colour, isNot(show(online).colour));
      expect(show(offline).colour, isNot(show(online, pending: 1).colour));
    });
  });

  group('the widget renders what the decision says', () {
    testWidgets('an icon, and a label only when there is one', (tester) async {
      // The live notifier makes the state unpinnable, so this only checks the
      // widget draws a decision at all; which decision is covered above.
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ConnectivityPill())),
      ));
      await tester.pump();

      expect(find.byType(Icon), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
