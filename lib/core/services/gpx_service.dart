import 'package:flutter/material.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/models/trail.dart';
import 'package:latlong2/latlong.dart';

class GPXService {
  static String exportWaypoints(List<Waypoint> waypoints) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="BushTrack">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>BushTrack Waypoints</name>');
    buffer.writeln('    <time>${DateTime.now().toIso8601String()}</time>');
    buffer.writeln('  </metadata>');

    for (final waypoint in waypoints) {
      if (waypoint.latitude != null && waypoint.longitude != null) {
        buffer.writeln(
            '  <wpt lat="${waypoint.latitude}" lon="${waypoint.longitude}">');
        if (waypoint.altitude != null) {
          buffer.writeln('    <ele>${waypoint.altitude}</ele>');
        }
        buffer.writeln(
            '    <name>${_escapeXml(waypoint.label ?? 'Waypoint')}</name>');
        if (waypoint.notes != null && waypoint.notes!.isNotEmpty) {
          buffer.writeln('    <desc>${_escapeXml(waypoint.notes!)}</desc>');
        }
        if (waypoint.timestamp != null) {
          buffer.writeln(
              '    <time>${waypoint.timestamp!.toIso8601String()}</time>');
        }
        buffer.writeln('  </wpt>');
      }
    }

    buffer.writeln('</gpx>');
    return buffer.toString();
  }

  static String exportTrail(Trail trail) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="BushTrack">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>${_escapeXml(trail.name ?? 'Trail')}</name>');
    buffer.writeln('    <time>${DateTime.now().toIso8601String()}</time>');
    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>${_escapeXml(trail.name ?? 'Trail')}</name>');
    buffer.writeln('    <trkseg>');

    final points = trail.getWaypoints();
    for (final point in points) {
      buffer.writeln(
          '      <trkpt lat="${point.latitude}" lon="${point.longitude}">');
      buffer.writeln('      </trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');
    return buffer.toString();
  }

  static List<Waypoint> parseGPX(String gpxContent) {
    final waypoints = <Waypoint>[];

    try {
      final waypointRegex = RegExp(
        r'<wpt lat="([^"]+)" lon="([^"]+)">(.*?)</wpt>',
        dotAll: true,
      );

      for (final match in waypointRegex.allMatches(gpxContent)) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lon = double.tryParse(match.group(2) ?? '');
        final content = match.group(3) ?? '';

        if (lat != null && lon != null) {
          String? name;
          String? description;
          double? elevation;
          DateTime? time;

          final nameMatch = RegExp(r'<name>(.*?)</name>').firstMatch(content);
          if (nameMatch != null) name = _unescapeXml(nameMatch.group(1) ?? '');

          final descMatch = RegExp(r'<desc>(.*?)</desc>').firstMatch(content);
          if (descMatch != null)
            description = _unescapeXml(descMatch.group(1) ?? '');

          final eleMatch = RegExp(r'<ele>(.*?)</ele>').firstMatch(content);
          if (eleMatch != null)
            elevation = double.tryParse(eleMatch.group(1) ?? '');

          final timeMatch = RegExp(r'<time>(.*?)</time>').firstMatch(content);
          if (timeMatch != null)
            time = DateTime.tryParse(timeMatch.group(1) ?? '');

          waypoints.add(Waypoint(
            latitude: lat,
            longitude: lon,
            label: name ?? 'Imported Waypoint',
            notes: description,
            altitude: elevation,
            timestamp: time ?? DateTime.now(),
            type: WaypointType.manual,
            isPin: true,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error parsing GPX: $e');
    }

    return waypoints;
  }

  static List<LatLng> parseTrack(String gpxContent) {
    final points = <LatLng>[];

    try {
      final trackpointRegex = RegExp(
        r'<trkpt lat="([^"]+)" lon="([^"]+)"',
        dotAll: true,
      );

      for (final match in trackpointRegex.allMatches(gpxContent)) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lon = double.tryParse(match.group(2) ?? '');

        if (lat != null && lon != null) {
          points.add(LatLng(lat, lon));
        }
      }
    } catch (e) {
      debugPrint('Error parsing track: $e');
    }

    return points;
  }

  // ── KML Export ────────────────────────────────────────────────────────────

  static String exportWaypointsKML(List<Waypoint> waypoints) {
    final buf = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<kml xmlns="http://www.opengis.net/kml/2.2">')
      ..writeln('  <Document>')
      ..writeln('    <name>BushTrack Waypoints</name>');

    for (final w in waypoints) {
      if (w.latitude == null || w.longitude == null) continue;
      final name = _escapeXml(w.label ?? 'Waypoint');
      final desc = _escapeXml(w.notes ?? '');
      final alt = w.altitude ?? 0;
      buf
        ..writeln('    <Placemark>')
        ..writeln('      <name>$name</name>')
        ..writeln('      <description>$desc</description>')
        ..writeln('      <Point>')
        ..writeln(
            '        <coordinates>${w.longitude},${w.latitude},$alt</coordinates>')
        ..writeln('      </Point>')
        ..writeln('    </Placemark>');
    }

    buf
      ..writeln('  </Document>')
      ..writeln('</kml>');
    return buf.toString();
  }

  static String exportTrailKML(Trail trail) {
    final buf = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<kml xmlns="http://www.opengis.net/kml/2.2">')
      ..writeln('  <Document>')
      ..writeln('    <name>${_escapeXml(trail.name ?? 'Trail')}</name>')
      ..writeln('    <Placemark>')
      ..writeln('      <name>${_escapeXml(trail.name ?? 'Trail')}</name>')
      ..writeln('      <LineString>')
      ..writeln('        <tessellate>1</tessellate>')
      ..writeln('        <coordinates>');

    for (final pt in trail.getWaypoints()) {
      buf.writeln('          ${pt.longitude},${pt.latitude},0');
    }

    buf
      ..writeln('        </coordinates>')
      ..writeln('      </LineString>')
      ..writeln('    </Placemark>')
      ..writeln('  </Document>')
      ..writeln('</kml>');
    return buf.toString();
  }

  // ── KML Import ────────────────────────────────────────────────────────────

  static List<Waypoint> parseKML(String kmlContent) {
    final waypoints = <Waypoint>[];
    try {
      final placemarkRx = RegExp(
        r'<Placemark>(.*?)</Placemark>',
        dotAll: true,
      );
      for (final pm in placemarkRx.allMatches(kmlContent)) {
        final body = pm.group(1) ?? '';
        final nameM = RegExp(r'<name>(.*?)</name>').firstMatch(body);
        final descM = RegExp(r'<description>(.*?)</description>').firstMatch(body);
        final coordM = RegExp(r'<coordinates>\s*(.*?)\s*</coordinates>',
                dotAll: true)
            .firstMatch(body);
        if (coordM == null) continue;

        final coordStr = coordM.group(1)!.trim().split(RegExp(r'\s+')).first;
        final parts = coordStr.split(',');
        if (parts.length < 2) continue;

        final lon = double.tryParse(parts[0]);
        final lat = double.tryParse(parts[1]);
        final alt = parts.length >= 3 ? double.tryParse(parts[2]) : null;
        if (lat == null || lon == null) continue;

        waypoints.add(Waypoint(
          latitude: lat,
          longitude: lon,
          altitude: alt,
          label: nameM != null ? _unescapeXml(nameM.group(1)!) : 'KML Import',
          notes: descM != null ? _unescapeXml(descM.group(1)!) : null,
          timestamp: DateTime.now(),
          type: WaypointType.manual,
          isPin: true,
        ));
      }
    } catch (e) {
      debugPrint('Error parsing KML: $e');
    }
    return waypoints;
  }

  static List<LatLng> parseKMLTrack(String kmlContent) {
    final points = <LatLng>[];
    try {
      final coordsRx = RegExp(
        r'<coordinates>\s*(.*?)\s*</coordinates>',
        dotAll: true,
      );
      for (final m in coordsRx.allMatches(kmlContent)) {
        for (final entry in (m.group(1) ?? '').trim().split(RegExp(r'\s+'))) {
          final parts = entry.split(',');
          if (parts.length < 2) continue;
          final lon = double.tryParse(parts[0]);
          final lat = double.tryParse(parts[1]);
          if (lat != null && lon != null) points.add(LatLng(lat, lon));
        }
      }
    } catch (e) {
      debugPrint('Error parsing KML track: $e');
    }
    return points;
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _unescapeXml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}
