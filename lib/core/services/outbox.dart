import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// Where an outbox item has got to.
enum OutboxState {
  /// Waiting for a connection, or for its backoff to expire.
  queued,

  /// A send is in flight.
  sending,

  /// Tried and failed, and will try again.
  retrying,

  /// Out of attempts. **Still here, deliberately** — see [Outbox].
  failed,
}

/// One thing waiting to leave the phone.
@immutable
class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.dedupeKey,
    this.attempts = 0,
    this.lastError,
    this.state = OutboxState.queued,
    this.nextAttemptAt,
  });

  final int id;

  /// What this is — 'share', 'sos', 'photo_upload', 'connection_request'.
  /// A plain string so 4.4 can add kinds without touching the queue.
  final String kind;

  final Map<String, dynamic> payload;
  final DateTime createdAt;

  /// Stops the same thing queueing twice. Two taps on Share should not send
  /// two shares, and a retry loop must not pile up duplicates.
  final String? dedupeKey;

  final int attempts;
  final String? lastError;
  final OutboxState state;

  /// When it may next be tried. Null means now.
  final DateTime? nextAttemptAt;

  bool get isPending =>
      state == OutboxState.queued || state == OutboxState.retrying;

  bool readyAt(DateTime now) =>
      isPending && (nextAttemptAt == null || !now.isBefore(nextAttemptAt!));

  Map<String, Object?> toRow() => {
        'kind': kind,
        'payload': jsonEncode(payload),
        'created_at': createdAt.millisecondsSinceEpoch,
        'dedupe_key': dedupeKey,
        'attempts': attempts,
        'last_error': lastError,
        'state': state.name,
        'next_attempt_at': nextAttemptAt?.millisecondsSinceEpoch,
      };

  static OutboxItem fromRow(Map<String, Object?> row) {
    Map<String, dynamic> payload = const {};
    final raw = row['payload']?.toString();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // A payload we cannot read must not take the whole queue down with
        // it. It stays in the row and surfaces as an empty map.
      }
    }

    return OutboxItem(
      id: row['id'] as int,
      kind: row['kind']?.toString() ?? 'unknown',
      payload: payload,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (row['created_at'] as int?) ?? 0),
      dedupeKey: row['dedupe_key']?.toString(),
      attempts: (row['attempts'] as int?) ?? 0,
      lastError: row['last_error']?.toString(),
      state: OutboxState.values.firstWhere(
        (s) => s.name == row['state'],
        orElse: () => OutboxState.queued,
      ),
      nextAttemptAt: row['next_attempt_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['next_attempt_at'] as int),
    );
  }
}

/// The result of trying to send one item.
enum SendOutcome {
  /// Gone. The item is removed.
  sent,

  /// Failed, but might work later — no signal, a timeout, a 500.
  retry,

  /// Will never work. Bad data, a deleted target, a rejected request.
  /// The item is marked [OutboxState.failed] and kept.
  permanent,
}

/// A handler for one kind of item. Registered by whatever owns that kind.
typedef OutboxSender = Future<SendOutcome> Function(OutboxItem item);

/// Things that have to leave the phone, held until they can.
///
/// The offline-first brief calls for shares, connection requests, edits and
/// posts made with no signal to send themselves later. This is that queue, and
/// two of its rules exist because of what this app is for:
///
/// **Nothing is ever deleted because sending failed.** An item that runs out of
/// attempts is marked failed and stays visible. "Never lose a photo because the
/// upload failed" is in the brief, and the same reasoning applies to an SOS: a
/// queue that quietly drops what it could not send is worse than no queue,
/// because it looks like success.
///
/// **Nothing is sent twice.** A dedupe key means two taps on Share, or a retry
/// that raced a reconnect, produce one send.
///
/// No senders are registered yet — there is no backend until 4.4. The queue is
/// built first because SOS, photo upload and sharing all need it, and because
/// a queue retrofitted after the things that queue is a queue nobody uses.
class Outbox {
  Outbox({required this.db, this.maxAttempts = 8});

  final DatabaseExecutor db;

  /// After this many tries an item stops retrying and waits for a person.
  /// Eight attempts over the backoff below spans about half a day.
  final int maxAttempts;

  static const String table = 'outbox';

  final Map<String, OutboxSender> _senders = {};

  /// Register a handler for a kind. Called by whatever owns that kind.
  void register(String kind, OutboxSender sender) => _senders[kind] = sender;

  @visibleForTesting
  bool handles(String kind) => _senders.containsKey(kind);

  /// Put something in the queue.
  ///
  /// Returns the existing id when [dedupeKey] matches something already
  /// pending, so callers can be careless about double taps.
  Future<int> add({
    required String kind,
    required Map<String, dynamic> payload,
    String? dedupeKey,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();

    if (dedupeKey != null) {
      final existing = await db.query(
        table,
        columns: ['id'],
        where: 'dedupe_key = ? AND state != ?',
        whereArgs: [dedupeKey, OutboxState.failed.name],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        debugPrint('Outbox: $kind already queued ($dedupeKey)');
        return existing.single['id'] as int;
      }
    }

    final item = OutboxItem(
      id: 0,
      kind: kind,
      payload: payload,
      createdAt: at,
      dedupeKey: dedupeKey,
    );
    final id = await db.insert(table, item.toRow());
    debugPrint('Outbox: queued $kind (#$id)');
    return id;
  }

  /// Everything still waiting, oldest first.
  ///
  /// Selected as "not failed" rather than by listing the pending states. A
  /// test caught why: a row whose state column holds something unrecognised —
  /// a half-written update, a schema change, a bad migration — was returned by
  /// neither this nor [failed], so it existed in the database and nowhere in
  /// the app. For a queue whose entire purpose is not losing things, an
  /// unknown state has to count as "still here".
  Future<List<OutboxItem>> pending() async {
    final rows = await db.query(
      table,
      where: 'state IS NULL OR state != ?',
      whereArgs: [OutboxState.failed.name],
      orderBy: 'created_at ASC',
    );
    return rows.map(OutboxItem.fromRow).toList();
  }

  /// Items that have given up and need a person to look at them.
  Future<List<OutboxItem>> failed() async {
    final rows = await db.query(table,
        where: 'state = ?',
        whereArgs: [OutboxState.failed.name],
        orderBy: 'created_at ASC');
    return rows.map(OutboxItem.fromRow).toList();
  }

  /// What the status badge shows.
  Future<int> pendingCount() async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) c FROM $table WHERE state IS NULL OR state != ?',
      [OutboxState.failed.name],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Try everything that is due. Returns how many left the phone.
  ///
  /// Safe to call repeatedly — on reconnect, on a timer, on app resume.
  Future<int> flush({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final items = await pending();
    var sent = 0;

    for (final item in items) {
      if (!item.readyAt(at)) continue;

      final sender = _senders[item.kind];
      if (sender == null) {
        // No handler registered for this kind yet. Left alone rather than
        // failed: 4.4 registers the senders, and an item queued before then
        // must still be there afterwards.
        continue;
      }

      await _mark(item.id, OutboxState.sending);
      SendOutcome outcome;
      try {
        outcome = await sender(item);
      } catch (e) {
        debugPrint('Outbox: ${item.kind} #${item.id} threw: $e');
        outcome = SendOutcome.retry;
        await _recordError(item, '$e', at);
        continue;
      }

      switch (outcome) {
        case SendOutcome.sent:
          await db.delete(table, where: 'id = ?', whereArgs: [item.id]);
          sent++;
          debugPrint('Outbox: sent ${item.kind} #${item.id}');
        case SendOutcome.retry:
          await _recordError(item, item.lastError ?? 'send failed', at);
        case SendOutcome.permanent:
          await db.update(
            table,
            {
              'state': OutboxState.failed.name,
              'attempts': item.attempts + 1,
              'last_error': 'rejected — will not retry',
            },
            where: 'id = ?',
            whereArgs: [item.id],
          );
          debugPrint('Outbox: ${item.kind} #${item.id} rejected, kept');
      }
    }

    return sent;
  }

  /// Push a failed item back into the queue, for a retry button.
  Future<void> retry(int id) => db.update(
        table,
        {
          'state': OutboxState.queued.name,
          'attempts': 0,
          'next_attempt_at': null,
          'last_error': null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  /// Remove an item. Only ever on a person's say-so, never as a side effect
  /// of a failure.
  Future<void> discard(int id) =>
      db.delete(table, where: 'id = ?', whereArgs: [id]);

  Future<void> _mark(int id, OutboxState state) => db.update(
        table,
        {'state': state.name},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> _recordError(
      OutboxItem item, String error, DateTime now) async {
    final attempts = item.attempts + 1;
    final done = attempts >= maxAttempts;

    await db.update(
      table,
      {
        'state': done ? OutboxState.failed.name : OutboxState.retrying.name,
        'attempts': attempts,
        'last_error': error,
        'next_attempt_at':
            done ? null : backoffFrom(now, attempts).millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// When to try again: doubling, capped at an hour.
  ///
  /// A phone that comes in and out of signal all day would otherwise retry
  /// continuously and cost battery for nothing. Capped rather than unbounded
  /// so an item that has been waiting since this morning still goes out
  /// promptly once there is a tower.
  @visibleForTesting
  static DateTime backoffFrom(DateTime now, int attempts) {
    final seconds = math.min(30 * math.pow(2, attempts - 1).toInt(), 3600);
    return now.add(Duration(seconds: seconds));
  }
}
