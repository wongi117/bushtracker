// The queue holds things that must leave the phone: shares, an SOS, a photo
// upload. Two of its rules come straight from what this app is for, and both
// are tested here hardest — nothing is deleted because sending failed, and
// nothing is sent twice.
import 'package:bush_track/core/services/db_migrations.dart';
import 'package:bush_track/core/services/outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  late Outbox outbox;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await DbMigrations.upgrade(db, from: 3, to: 4);
    outbox = Outbox(db: db);
  });

  group('queueing', () {
    test('an item goes in and comes back out', () async {
      final id = await outbox.add(
          kind: 'share', payload: {'project': 'Kookynie', 'to': 'crew'});

      final pending = await outbox.pending();
      expect(pending, hasLength(1));
      expect(pending.single.id, id);
      expect(pending.single.kind, 'share');
      expect(pending.single.payload['project'], 'Kookynie');
      expect(pending.single.state, OutboxState.queued);
    });

    test('the count is what the status badge shows', () async {
      expect(await outbox.pendingCount(), 0);
      await outbox.add(kind: 'share', payload: {});
      await outbox.add(kind: 'sos', payload: {});
      expect(await outbox.pendingCount(), 2);
    });

    test('oldest first, so an SOS from an hour ago goes before a share now',
        () async {
      final old = DateTime(2026, 10, 1, 8);
      await outbox.add(kind: 'sos', payload: {}, now: old);
      await outbox.add(
          kind: 'share', payload: {}, now: old.add(const Duration(hours: 1)));

      expect((await outbox.pending()).map((i) => i.kind), ['sos', 'share']);
    });

    test('a payload survives the round trip intact', () async {
      await outbox.add(kind: 'photo_upload', payload: {
        'path': 'abc.jpg',
        'lat': -28.8833,
        'tags': ['shaft', 'hazard'],
        'nested': {'a': 1},
      });
      final p = (await outbox.pending()).single.payload;
      expect(p['path'], 'abc.jpg');
      expect(p['lat'], -28.8833);
      expect(p['tags'], ['shaft', 'hazard']);
      expect(p['nested'], {'a': 1});
    });
  });

  group('nothing is sent twice', () {
    test('the same dedupe key returns the existing item', () async {
      final first =
          await outbox.add(kind: 'share', payload: {}, dedupeKey: 'proj-4-crew');
      final second =
          await outbox.add(kind: 'share', payload: {}, dedupeKey: 'proj-4-crew');

      expect(second, first, reason: 'two taps on Share must be one share');
      expect(await outbox.pendingCount(), 1);
    });

    test('different keys are different items', () async {
      await outbox.add(kind: 'share', payload: {}, dedupeKey: 'a');
      await outbox.add(kind: 'share', payload: {}, dedupeKey: 'b');
      expect(await outbox.pendingCount(), 2);
    });

    test('no key means no deduplication', () async {
      // Two photos of the same thing are two photos.
      await outbox.add(kind: 'photo_upload', payload: {});
      await outbox.add(kind: 'photo_upload', payload: {});
      expect(await outbox.pendingCount(), 2);
    });

    test('a failed item does not block re-queueing the same thing', () async {
      outbox.register('share', (_) async => SendOutcome.permanent);
      await outbox.add(kind: 'share', payload: {}, dedupeKey: 'k');
      await outbox.flush();
      expect(await outbox.failed(), hasLength(1));

      // Trying again by hand must create a new attempt, not silently return
      // the dead one.
      final again =
          await outbox.add(kind: 'share', payload: {}, dedupeKey: 'k');
      expect(await outbox.pendingCount(), 1);
      expect((await outbox.pending()).single.id, again);
    });
  });

  group('sending', () {
    test('a sent item is removed', () async {
      outbox.register('share', (_) async => SendOutcome.sent);
      await outbox.add(kind: 'share', payload: {});

      expect(await outbox.flush(), 1);
      expect(await outbox.pendingCount(), 0);
      expect(await outbox.failed(), isEmpty);
    });

    test('the handler is given the item it is sending', () async {
      OutboxItem? seen;
      outbox.register('sos', (item) async {
        seen = item;
        return SendOutcome.sent;
      });
      await outbox.add(kind: 'sos', payload: {'lat': -28.88});

      await outbox.flush();
      expect(seen, isNotNull);
      expect(seen!.payload['lat'], -28.88);
    });

    test('only the matching kind is sent', () async {
      outbox.register('share', (_) async => SendOutcome.sent);
      await outbox.add(kind: 'share', payload: {});
      await outbox.add(kind: 'sos', payload: {});

      expect(await outbox.flush(), 1);
      expect((await outbox.pending()).single.kind, 'sos');
    });

    test('an item with no handler yet is left alone, not failed', () async {
      // 4.4 registers the senders. Anything queued before then must still be
      // there afterwards.
      await outbox.add(kind: 'share', payload: {});
      expect(await outbox.flush(), 0);

      final still = (await outbox.pending()).single;
      expect(still.state, OutboxState.queued);
      expect(still.attempts, 0, reason: 'it was never actually tried');
    });
  });

  group('nothing is lost because sending failed', () {
    test('a retry keeps the item and counts the attempt', () async {
      outbox.register('share', (_) async => SendOutcome.retry);
      await outbox.add(kind: 'share', payload: {});

      await outbox.flush();
      final item = (await outbox.pending()).single;
      expect(item.state, OutboxState.retrying);
      expect(item.attempts, 1);
      expect(item.lastError, isNotNull);
    });

    test('a handler that throws is a retry, not a loss', () async {
      outbox.register('share', (_) async => throw Exception('no route'));
      await outbox.add(kind: 'share', payload: {});

      await outbox.flush();
      final item = (await outbox.pending()).single;
      expect(item.attempts, 1);
      expect(item.lastError, contains('no route'));
    });

    test('running out of attempts marks it failed and KEEPS it', () async {
      // The brief: never lose a photo because the upload failed. The same
      // reasoning holds for an SOS — a queue that drops what it could not
      // send is worse than no queue, because it looks like success.
      final small = Outbox(db: db, maxAttempts: 2);
      small.register('photo_upload', (_) async => SendOutcome.retry);
      await small.add(kind: 'photo_upload', payload: {'path': 'a.jpg'});

      var now = DateTime(2026, 10, 2, 9);
      for (var i = 0; i < 4; i++) {
        await small.flush(now: now);
        now = now.add(const Duration(hours: 2));
      }

      expect(await small.pendingCount(), 0);
      final dead = await small.failed();
      expect(dead, hasLength(1), reason: 'it must still exist');
      expect(dead.single.payload['path'], 'a.jpg',
          reason: 'and still carry its payload');
    });

    test('a permanent rejection is kept too, just not retried', () async {
      outbox.register('share', (_) async => SendOutcome.permanent);
      await outbox.add(kind: 'share', payload: {});

      await outbox.flush();
      expect(await outbox.pendingCount(), 0);
      expect(await outbox.failed(), hasLength(1));
    });

    test('an item is only ever removed on a person\'s say-so', () async {
      outbox.register('share', (_) async => SendOutcome.permanent);
      final id = await outbox.add(kind: 'share', payload: {});
      await outbox.flush();

      expect(await outbox.failed(), hasLength(1));
      await outbox.discard(id);
      expect(await outbox.failed(), isEmpty);
    });

    test('a failed item can be pushed back into the queue', () async {
      var attempt = 0;
      outbox.register('share', (_) async {
        attempt++;
        return attempt == 1 ? SendOutcome.permanent : SendOutcome.sent;
      });
      final id = await outbox.add(kind: 'share', payload: {});

      await outbox.flush();
      expect(await outbox.failed(), hasLength(1));

      await outbox.retry(id);
      final back = (await outbox.pending()).single;
      expect(back.state, OutboxState.queued);
      expect(back.attempts, 0);

      expect(await outbox.flush(), 1);
    });
  });

  group('backoff', () {
    test('it doubles', () async {
      final now = DateTime(2026, 10, 2, 9);
      final first = Outbox.backoffFrom(now, 1).difference(now);
      final second = Outbox.backoffFrom(now, 2).difference(now);
      final third = Outbox.backoffFrom(now, 3).difference(now);

      expect(second.inSeconds, first.inSeconds * 2);
      expect(third.inSeconds, second.inSeconds * 2);
    });

    test('and is capped at an hour', () async {
      // A phone in and out of signal all day would otherwise retry forever
      // and cost battery for nothing; capped so an item waiting since morning
      // still goes promptly once there is a tower.
      final now = DateTime(2026, 10, 2, 9);
      expect(Outbox.backoffFrom(now, 20).difference(now).inSeconds, 3600);
    });

    test('an item inside its backoff is not retried', () async {
      var calls = 0;
      outbox.register('share', (_) async {
        calls++;
        return SendOutcome.retry;
      });
      await outbox.add(kind: 'share', payload: {});

      final now = DateTime(2026, 10, 2, 9);
      await outbox.flush(now: now);
      expect(calls, 1);

      // A second later: still backing off.
      await outbox.flush(now: now.add(const Duration(seconds: 1)));
      expect(calls, 1, reason: 'it should wait out its backoff');

      // An hour later: due again.
      await outbox.flush(now: now.add(const Duration(hours: 1)));
      expect(calls, 2);
    });
  });

  group('bad rows', () {
    test('a payload that will not parse does not take the queue down',
        () async {
      await db.insert(Outbox.table, {
        'kind': 'share',
        'payload': 'not json at all',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'state': 'queued',
      });

      final items = await outbox.pending();
      expect(items, hasLength(1));
      expect(items.single.payload, isEmpty);
      expect(items.single.kind, 'share');
    });

    test('an unknown state reads as queued rather than vanishing', () async {
      await db.insert(Outbox.table, {
        'kind': 'share',
        'payload': '{}',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'state': 'something_else',
      });
      expect((await outbox.pending()).single.state, OutboxState.queued);
    });
  });
}
