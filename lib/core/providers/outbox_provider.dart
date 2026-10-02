import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bush_track/core/services/connectivity_service.dart';
import 'package:bush_track/core/services/database_service.dart';
import 'package:bush_track/core/services/outbox.dart';
import 'package:bush_track/main.dart';

/// The shared queue.
///
/// One instance, because senders register against it: a second Outbox would
/// have an empty handler map and quietly do nothing.
final outboxProvider = Provider<Outbox?>((ref) {
  final db = ref.read(databaseServiceProvider).database;
  if (db == null) return null;
  return Outbox(db: db);
});

/// How many things are waiting, for the status badge.
@immutable
class OutboxStatus {
  const OutboxStatus({this.pending = 0, this.failed = 0, this.flushing = false});

  final int pending;
  final int failed;
  final bool flushing;

  OutboxStatus copyWith({int? pending, int? failed, bool? flushing}) =>
      OutboxStatus(
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
        flushing: flushing ?? this.flushing,
      );
}

/// Watches the queue and empties it when there is a connection.
///
/// Driven by the connectivity provider rather than a bare timer, so the queue
/// goes out the moment signal returns — which on a track means the moment you
/// come over a rise — instead of up to a minute later. A slow timer backs it
/// up for the case where connectivity is reported as present but nothing
/// actually gets through.
class OutboxStatusNotifier extends StateNotifier<OutboxStatus> {
  OutboxStatusNotifier(this._ref) : super(const OutboxStatus()) {
    _watchConnectivity();
    _refresh();
    // The backstop. Long on purpose: the connectivity listener does the real
    // work, and polling a queue that is almost always empty is wasted battery
    // on a phone that may be the only navigation device out there.
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => flush());
  }

  final Ref _ref;
  Timer? _timer;
  ProviderSubscription<ConnectivityState>? _connection;
  bool _busy = false;

  void _watchConnectivity() {
    _connection = _ref.listen<ConnectivityState>(
      connectivityProvider,
      (was, now) {
        // Only the transition matters. Firing on every poll while already
        // online would flush continuously.
        final cameBack = (was?.isConnected ?? false) == false && now.isConnected;
        if (cameBack) {
          debugPrint('Outbox: connection returned, flushing');
          flush();
        }
      },
    );
  }

  /// Recount without sending anything.
  Future<void> _refresh() async {
    final outbox = _ref.read(outboxProvider);
    if (outbox == null) return;
    try {
      final pending = await outbox.pendingCount();
      final failed = (await outbox.failed()).length;
      if (!mounted) return;
      state = state.copyWith(pending: pending, failed: failed);
    } catch (e) {
      debugPrint('Outbox refresh failed: $e');
    }
  }

  /// Try to empty the queue. Safe to call from anywhere, any number of times.
  Future<void> flush() async {
    if (_busy) return;
    final outbox = _ref.read(outboxProvider);
    if (outbox == null) return;
    if (!_ref.read(connectivityProvider).isConnected) {
      await _refresh();
      return;
    }

    _busy = true;
    if (mounted) state = state.copyWith(flushing: true);
    try {
      await outbox.flush();
    } catch (e) {
      debugPrint('Outbox flush failed: $e');
    } finally {
      _busy = false;
      if (mounted) state = state.copyWith(flushing: false);
      await _refresh();
    }
  }

  /// Put something in the queue and update the badge.
  Future<void> add({
    required String kind,
    required Map<String, dynamic> payload,
    String? dedupeKey,
  }) async {
    final outbox = _ref.read(outboxProvider);
    if (outbox == null) return;
    await outbox.add(kind: kind, payload: payload, dedupeKey: dedupeKey);
    await _refresh();
    // If there is signal right now, do not make the user wait for a timer.
    if (_ref.read(connectivityProvider).isConnected) await flush();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connection?.close();
    super.dispose();
  }
}

final outboxStatusProvider =
    StateNotifierProvider<OutboxStatusNotifier, OutboxStatus>(
        (ref) => OutboxStatusNotifier(ref));
