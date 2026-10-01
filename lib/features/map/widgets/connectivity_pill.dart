import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bush_track/core/services/connectivity_service.dart';
import 'package:bush_track/theme/app_colors.dart';

/// What the pill should show, worked out without a widget or a network.
///
/// Separated because the notifier runs a real connectivity check on
/// construction, so a widget test cannot pin it to "offline" — the live check
/// resolves mid-pump and overwrites it. The decision is the part worth
/// testing; the widget around it is a row with an icon in it.
@immutable
class ConnectivityDisplay {
  const ConnectivityDisplay({
    required this.icon,
    required this.colour,
    this.label,
  });

  final IconData icon;
  final Color colour;

  /// Null means say nothing — the quiet, normal, online case.
  final String? label;

  static ConnectivityDisplay from(ConnectivityState state, int pending) {
    if (state.connectionType == 'checking') {
      // Saying OFFLINE before anything has been checked is a lie that lasts a
      // second and undermines the badge for the rest of the session.
      return const ConnectivityDisplay(
          icon: Icons.cloud_queue, colour: AppColors.textMuted);
    }
    if (!state.isConnected) {
      return ConnectivityDisplay(
        icon: Icons.cloud_off,
        colour: AppColors.statusRed,
        label: pending > 0 ? 'OFFLINE · $pending QUEUED' : 'OFFLINE',
      );
    }
    if (pending > 0) {
      return ConnectivityDisplay(
        icon: Icons.sync,
        colour: AppColors.primaryOrange,
        label: 'SYNCING $pending',
      );
    }
    // Quiet in the normal case: a badge that shouts when all is well teaches
    // people to ignore it, and then it is no use when it matters.
    return const ConnectivityDisplay(
        icon: Icons.cloud_done, colour: Color(0xFF05CB63));
  }
}

/// Online, offline, or syncing — always on screen.
///
/// Required by the offline-first brief, and it earns its space for a reason
/// worth stating: in this app "it didn't work" and "it hasn't sent yet" look
/// identical from the outside. Someone who has just pressed SOS, or shared a
/// project, or taken a photo, needs to know which of those they are looking at
/// without opening a menu.
///
/// Deliberately quiet when online — a small dot — and loud when not. A status
/// badge that shouts in the normal case teaches people to ignore it, and then
/// it is no use in the case that matters.
class ConnectivityPill extends ConsumerWidget {
  const ConnectivityPill({super.key, this.pendingCount = 0});

  /// Items waiting in the outbox. Shown here because "offline" and "offline
  /// with three things queued" are different situations.
  final int pendingCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display =
        ConnectivityDisplay.from(ref.watch(connectivityProvider), pendingCount);
    final colour = display.colour;
    final icon = display.icon;
    final label = display.label;

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: label == null ? 6 : 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.panelMatte.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colour.withValues(alpha: 0.7)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: colour, size: 13),
        if (label != null) ...[
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: colour,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4)),
        ],
      ]),
    );
  }
}
