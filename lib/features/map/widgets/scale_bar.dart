import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Scale bar widget that shows map scale
class ScaleBar extends StatelessWidget {
  final double zoom;
  final double latitude;
  final bool isMetric;

  const ScaleBar({
    super.key,
    required this.zoom,
    required this.latitude,
    this.isMetric = true,
  });

  @override
  Widget build(BuildContext context) {
    final scaleInfo = _calculateScale();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scale line
          Container(
            width: scaleInfo.pixels,
            height: 4,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white, width: 2),
                left: BorderSide(color: Colors.white, width: 2),
                right: BorderSide(color: Colors.white, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Distance label
          Text(
            scaleInfo.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  _ScaleInfo _calculateScale() {
    // Earth circumference at equator
    const earthCircumference = 40075016.686; // meters
    
    // Mercator projection scale factor at given latitude
    final latRad = latitude * math.pi / 180;
    final scaleFactor = math.cos(latRad);
    
    // Calculate ground resolution (meters per pixel)
    // At zoom 0, entire world is 256 pixels
    final groundResolution = 
        (earthCircumference * scaleFactor) / (256 * math.pow(2, zoom));
    
    // Target width for scale bar (in pixels)
    const targetWidth = 100;
    
    // Calculate distance at target width
    final distance = groundResolution * targetWidth;
    
    // Round to nice number
    final roundedDistance = _roundDistance(distance).toDouble();
    
    // Calculate actual width for rounded distance
    final actualWidth = roundedDistance / groundResolution;
    
    String label;
    if (isMetric) {
      if (roundedDistance >= 1000) {
        label = '${(roundedDistance / 1000).toStringAsFixed(1)} km';
      } else {
        label = '${roundedDistance.toInt()} m';
      }
    } else {
      final feet = roundedDistance * 3.28084;
      if (feet >= 5280) {
        label = '${(feet / 5280).toStringAsFixed(1)} mi';
      } else {
        label = '${feet.toInt()} ft';
      }
    }
    
    return _ScaleInfo(
      pixels: actualWidth.clamp(30, 150),
      label: label,
    );
  }

  double _roundDistance(double distance) {
    // Round to nice numbers: 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, etc.
    final log10 = math.log(distance) / math.ln10;
    final floor = log10.floor();
    final pow10 = math.pow(10, floor);
    final firstDigit = (distance / pow10).floor();
    
    double rounded;
    if (firstDigit < 2) {
      rounded = pow10.toDouble();
    } else if (firstDigit < 5) {
      rounded = (2 * pow10).toDouble();
    } else {
      rounded = (5 * pow10).toDouble();
    }
    
    return rounded;
  }
}

class _ScaleInfo {
  final double pixels;
  final String label;

  _ScaleInfo({required this.pixels, required this.label});
}
