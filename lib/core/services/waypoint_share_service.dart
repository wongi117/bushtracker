import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bush_track/core/models/waypoint.dart';

class WaypointShareService {
  /// Share a waypoint via the native share sheet (mobile) or clipboard (web).
  /// Returns true if sharing succeeded.
  static Future<bool> shareWaypoint(Waypoint waypoint) async {
    if (waypoint.latitude == null || waypoint.longitude == null) return false;

    final label = waypoint.label ?? 'Pin';
    final lat = waypoint.latitude!.toStringAsFixed(6);
    final lon = waypoint.longitude!.toStringAsFixed(6);
    final notes = waypoint.notes?.isNotEmpty == true ? '\nNotes: ${waypoint.notes}' : '';
    final geoLink = 'geo:$lat,$lon?q=$lat,$lon(${Uri.encodeComponent(label)})';
    final webLink = _buildWebLink(waypoint);

    final text = '📍 $label\n'
        'Lat: $lat, Lon: $lon$notes\n\n'
        'Open in maps: $geoLink\n'
        'BushTrack link: $webLink';

    try {
      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: text));
        return true;
      }
      final result = await Share.share(text, subject: 'BushTrack Pin: $label');
      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('WaypointShareService error: $e');
      return false;
    }
  }

  /// Share multiple waypoints as a KML-style summary text.
  static Future<bool> shareWaypoints(List<Waypoint> waypoints) async {
    if (waypoints.isEmpty) return false;
    final lines = waypoints
        .where((w) => w.latitude != null && w.longitude != null)
        .map((w) =>
            '• ${w.label ?? 'Pin'}: ${w.latitude!.toStringAsFixed(5)}, ${w.longitude!.toStringAsFixed(5)}')
        .join('\n');
    final text = 'BushTrack Waypoints (${waypoints.length})\n\n$lines';
    try {
      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: text));
        return true;
      }
      await Share.share(text, subject: 'BushTrack Waypoints');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Build a deep-link URL encoding the waypoint as base64 query param.
  static String _buildWebLink(Waypoint wp) {
    final data = {
      'lat': wp.latitude,
      'lon': wp.longitude,
      'label': wp.label ?? 'Pin',
      if (wp.notes?.isNotEmpty == true) 'notes': wp.notes,
    };
    final encoded = base64Url.encode(utf8.encode(jsonEncode(data)));
    return 'https://bushtrack.app/pin?d=$encoded';
  }
}
