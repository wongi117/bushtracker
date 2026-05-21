import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:bush_track/core/config/api_config.dart';
import 'package:bush_track/core/utils/coordinate_utils.dart';
import 'package:bush_track/theme/app_colors.dart';

/// Widget to display coordinates in multiple formats
/// Matches Avenza Maps and professional GPS apps
class CoordinateDisplay extends StatelessWidget {
  final LatLng position;
  final CoordinateFormat format;
  final bool showAllFormats;
  final VoidCallback? onFormatChanged;
  
  const CoordinateDisplay({
    super.key,
    required this.position,
    this.format = CoordinateFormat.decimalDegrees,
    this.showAllFormats = false,
    this.onFormatChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (showAllFormats) {
      return _buildAllFormatsView();
    }
    return _buildSingleFormatView();
  }
  
  Widget _buildSingleFormatView() {
    final formatted = _formatCoordinate(position, format);
    
    return GestureDetector(
      onTap: onFormatChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              color: AppColors.primaryOrange,
              size: 16,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getFormatLabel(format),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatted,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            if (onFormatChanged != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.swap_horiz,
                color: Colors.white54,
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildAllFormatsView() {
    final formats = [
      (CoordinateFormat.decimalDegrees, '📊 Decimal Degrees'),
      (CoordinateFormat.dms, '🧭 DMS'),
      (CoordinateFormat.utm, '🎯 UTM'),
      (CoordinateFormat.mgrs, '🗺️ MGRS'),
    ];
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryOrange),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              const Row(
                children: [
                  Icon(Icons.gps_fixed, color: AppColors.primaryOrange, size: 16),
                  SizedBox(width: 8),
                  Text(
                    '📍 COORDINATE FORMATS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 8),
          FutureBuilder<String>(
            future: _fetchW3W(position),
            builder: (ctx, snap) {
              final w3w = snap.data ??
                  (snap.connectionState == ConnectionState.waiting
                      ? 'loading...'
                      : 'unavailable');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🔤 What3Words', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(w3w, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace')),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(color: Colors.white12, height: 8),
          ...formats.map((f) {
            final isSelected = format == f.$1;
            return GestureDetector(
              onTap: () => onFormatChanged?.call(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.primaryOrange.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.primaryOrange : Colors.white24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.$2,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatCoordinate(position, f.$1),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
  
  String _formatCoordinate(LatLng pos, CoordinateFormat fmt) {
    switch (fmt) {
      case CoordinateFormat.decimalDegrees:
        final lat = pos.latitude.abs().toStringAsFixed(5);
        final lon = pos.longitude.abs().toStringAsFixed(5);
        final latDir = pos.latitude >= 0 ? 'N' : 'S';
        final lonDir = pos.longitude >= 0 ? 'E' : 'W';
        return '$lat°$latDir, $lon°$lonDir';
        
      case CoordinateFormat.dms:
        final latDms = CoordinateUtils.decimalToDms(pos.latitude, true);
        final lonDms = CoordinateUtils.decimalToDms(pos.longitude, false);
        return '${latDms.toCompactString()}, ${lonDms.toCompactString()}';
        
      case CoordinateFormat.utm:
        final utm = CoordinateUtils.decimalToUtm(pos.latitude, pos.longitude);
        return utm.toCompactString();
        
      case CoordinateFormat.mgrs:
        return CoordinateUtils.decimalToMgrs(pos.latitude, pos.longitude);
    }
  }
  
  static Future<String> _fetchW3W(LatLng pos) async {
    final key = ApiConfig.what3WordsKey;
    if (key.isEmpty) return '///key.not.configured';
    try {
      final resp = await http.get(Uri.parse(
        'https://api.what3words.com/v3/convert-to-3wa?coordinates=${pos.latitude},${pos.longitude}&key=$key',
      )).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return '///${data['words']}';
      }
    } catch (_) {}
    return '///unavailable';
  }

  String _getFormatLabel(CoordinateFormat fmt) {
    switch (fmt) {
      case CoordinateFormat.decimalDegrees:
        return 'LAT/LON';
      case CoordinateFormat.dms:
        return 'DMS';
      case CoordinateFormat.utm:
        return 'UTM';
      case CoordinateFormat.mgrs:
        return 'MGRS';
    }
  }
}

/// Bottom sheet to select coordinate format
class CoordinateFormatSelector extends StatelessWidget {
  final CoordinateFormat currentFormat;
  final Function(CoordinateFormat) onFormatSelected;
  
  const CoordinateFormatSelector({
    super.key,
    required this.currentFormat,
    required this.onFormatSelected,
  });

  @override
  Widget build(BuildContext context) {
    final formats = [
      (CoordinateFormat.decimalDegrees, '📊 Decimal Degrees', '25.3444° S, 131.0369° E', 'Most common format'),
      (CoordinateFormat.dms, '🧭 DMS (Degrees, Minutes, Seconds)', '25°20\'39.84"S, 131°02\'12.84"E', 'Traditional navigation'),
      (CoordinateFormat.utm, '🎯 UTM (Universal Transverse Mercator)', '52J 281234E 7194321N', 'Military & surveyors'),
      (CoordinateFormat.mgrs, '🗺️ MGRS (Military Grid Reference)', '52J PU 12345 43210', 'NATO military standard'),
    ];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📍 COORDINATE FORMAT',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Select the format used for displaying coordinates',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ...formats.map((f) {
            final isSelected = currentFormat == f.$1;
            return GestureDetector(
              onTap: () {
                onFormatSelected(f.$1);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryOrange.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primaryOrange : Colors.white24,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.primaryOrange : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? AppColors.primaryOrange : Colors.white54,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.black, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.$2,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            f.$3,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            f.$4,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
