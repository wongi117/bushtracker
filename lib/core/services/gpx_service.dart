import 'dart:convert';
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
        buffer.writeln('  <wpt lat="${waypoint.latitude}" lon="${waypoint.longitude}">');
        if (waypoint.altitude != null) {
          buffer.writeln('    <ele>${waypoint.altitude}</ele>');
        }
        buffer.writeln('    <name>${_escapeXml(waypoint.label ?? 'Waypoint')}</name>');
        if (waypoint.notes != null && waypoint.notes!.isNotEmpty) {
          buffer.writeln('    <desc>${_escapeXml(waypoint.notes!)}</desc>');
        }
        if (waypoint.timestamp != null) {
          buffer.writeln('    <time>${waypoint.timestamp!.toIso8601String()}</time>');
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
      buffer.writeln('      <trkpt lat="${point.latitude}" lon="${point.longitude}">');
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
          if (descMatch != null) description = _unescapeXml(descMatch.group(1) ?? '');
          
          final eleMatch = RegExp(r'<ele>(.*?)</ele>').firstMatch(content);
          if (eleMatch != null) elevation = double.tryParse(eleMatch.group(1) ?? '');
          
          final timeMatch = RegExp(r'<time>(.*?)</time>').firstMatch(content);
          if (timeMatch != null) time = DateTime.tryParse(timeMatch.group(1) ?? '');
          
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