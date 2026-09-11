import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/features/ai/providers/ai_assistant_provider.dart';
import 'package:bush_track/features/navigation/providers/navigation_provider.dart';
import 'package:bush_track/features/map/providers/trail_provider.dart';
import 'package:bush_track/features/geofence/providers/geofence_provider.dart';
import 'package:geolocator/geolocator.dart';

class AiMonitorService {
  final Ref ref;
  Timer? _monitoringTimer;
  Timer? _trailVoiceTimer;
  Position? _lastPosition;
  bool _isMonitoring = false;
  bool _offRouteAlertSent = false;
  bool _sunsetAlertSent = false;

  AiMonitorService(this.ref);

  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _monitoringTimer =
        Timer.periodic(const Duration(minutes: 5), (_) => _check());
    _trailVoiceTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _checkTrailVoice());
  }

  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _trailVoiceTimer?.cancel();
    _isMonitoring = false;
  }

  /// Speaks and clears any pending trail or geofence voice announcements.
  Future<void> _checkTrailVoice() async {
    try {
      final aiNotifier = ref.read(aiAssistantProvider.notifier);

      // Trail voice guide
      final trailNotifier = ref.read(trailProvider.notifier);
      final trailAnnouncement = ref.read(trailProvider).pendingVoiceAnnouncement;
      if (trailAnnouncement != null && trailAnnouncement.isNotEmpty) {
        trailNotifier.clearVoiceAnnouncement();
        await aiNotifier.speak(trailAnnouncement);
      }

      // Geofence entry/exit alerts
      final geofenceNotifier = ref.read(geofenceProvider.notifier);
      final geofenceAnnouncement =
          ref.read(geofenceProvider).pendingVoiceAnnouncement;
      if (geofenceAnnouncement != null && geofenceAnnouncement.isNotEmpty) {
        geofenceNotifier.clearVoiceAnnouncement();
        await aiNotifier.speak(geofenceAnnouncement);
      }
    } catch (e) {
      debugPrint('AiMonitorService voice poll error: $e');
    }
  }

  Future<void> _check() async {
    try {
      final locationState = ref.read(locationProvider);
      final aiNotifier = ref.read(aiAssistantProvider.notifier);
      final navState = ref.read(navigationProvider);

      final lat = locationState.stats.currentLat;
      final lon = locationState.stats.currentLon;
      final speed = locationState.stats.currentSpeedMs;

      // ── Movement tracking ──────────────────────────────────────────────────
      if (lat != null && lon != null) {
        final current = Position(
          latitude: lat,
          longitude: lon,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: speed,
          speedAccuracy: 0,
          floor: null,
          isMocked: false,
        );

        _lastPosition = current;
      }

      // Deadman switch lives in AIControlNotifier only. This was a second copy
      // that ignored arming, sent the SOS instantly, and told the user they
      // could cancel a countdown that did not exist. With two copies, four
      // hours of stillness fired both.

      // ── Off-route voice alert (picked up from navigation state) ───────────
      if (navState.isActive && navState.isOffRoute) {
        final navNotifier = ref.read(navigationProvider.notifier);
        if (navNotifier.offRouteFlagged && !_offRouteAlertSent) {
          _offRouteAlertSent = true;
          final dist = navState.offRouteDistanceM.toStringAsFixed(0);
          await aiNotifier.speak(
            'Off route. You are $dist metres from the track. '
            'Recalculate or turn around.',
          );
          // Allow re-alert after 60 seconds
          Future.delayed(
              const Duration(seconds: 60), () => _offRouteAlertSent = false);
        }
      } else {
        _offRouteAlertSent = false;
      }

      // Battery saver lives in AIControlNotifier. This copy only spoke — it
      // never changed the GPS rate — and repeated every 5 minutes under 20%.

      // ── Sunset alert ───────────────────────────────────────────────────────
      if (lat != null && lon != null) {
        final hoursLeft = _hoursUntilSunset(lat, lon);
        if (hoursLeft != null && hoursLeft > 0 && hoursLeft <= 1.0 &&
            !_sunsetAlertSent) {
          _sunsetAlertSent = true;
          final mins = (hoursLeft * 60).round();
          await aiNotifier.speak(
            'Sunset in $mins minutes. Find a campsite in the next 30 minutes '
            'before you lose light.',
          );
          // Only alert once per sunset window; reset at midnight
          Future.delayed(
              const Duration(hours: 6), () => _sunsetAlertSent = false);
        }
      }

      // ── Stopped movement alert ─────────────────────────────────────────────
      if (speed == 0 &&
          _lastPosition != null &&
          (_lastPosition?.speed ?? 0) > 1.0) {
        await aiNotifier.speak('You have stopped. Marking rest point.');
      }
    } catch (e) {
      debugPrint('AiMonitorService error: $e');
    }
  }



  /// Solar noon / sunset calculation using Spencer's equation.
  /// Returns hours until sunset from the current local time, or null if past sunset.
  double? _hoursUntilSunset(double lat, double lon) {
    try {
      final now = DateTime.now().toLocal();
      final dayOfYear =
          now.difference(DateTime(now.year, 1, 1)).inDays + 1;
      final b = (360.0 / 365.0 * (dayOfYear - 81)) * pi / 180;
      final eqTime =
          9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b); // minutes
      final decl = 23.45 *
          sin((360.0 / 365.0 * (dayOfYear - 81)) * pi / 180) *
          pi /
          180;
      final cosH = -tan(lat * pi / 180) * tan(decl);
      if (cosH < -1 || cosH > 1) return null; // Polar day/night
      final hourAngle = acos(cosH) * 180 / pi;
      final solarNoonMin = 720 - 4 * lon - eqTime;
      final sunsetMin = solarNoonMin + 4 * hourAngle;
      final sunsetHour = (sunsetMin / 60).floor();
      final sunsetMinute = (sunsetMin % 60).round();
      final sunset = DateTime(
          now.year, now.month, now.day, sunsetHour, sunsetMinute);
      final diff = sunset.difference(now);
      return diff.inSeconds / 3600.0;
    } catch (_) {
      return null;
    }
  }

  void dispose() => stopMonitoring();
}

final aiMonitorServiceProvider = Provider((ref) {
  final service = AiMonitorService(ref);
  service.startMonitoring();
  ref.onDispose(service.dispose);
  return service;
});
