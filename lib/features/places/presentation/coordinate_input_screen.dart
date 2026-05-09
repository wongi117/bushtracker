import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';

class CoordinateInputScreen extends ConsumerStatefulWidget {
  final Function(LatLng)? onCoordinateEntered;
  
  const CoordinateInputScreen({super.key, this.onCoordinateEntered});

  @override
  ConsumerState<CoordinateInputScreen> createState() => _CoordinateInputScreenState();
}

class _CoordinateInputScreenState extends ConsumerState<CoordinateInputScreen> {
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();
  final TextEditingController _dmsController = TextEditingController();
  final TextEditingController _utmController = TextEditingController();
  
  int _selectedFormat = 0;
  
  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _dmsController.dispose();
    _utmController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.panelMatte,
        title: const Text('📍 Go to Coordinates', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryOrange.withValues(alpha: 0.2),
                  AppColors.deepOrange.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter coordinates in any format:',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _buildFormatSelector(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_selectedFormat == 0) _buildDecimalDegreesInput(),
          if (_selectedFormat == 1) _buildDMSInput(),
          if (_selectedFormat == 2) _buildUTMInput(),
          const SizedBox(height: 24),
          _buildGoButton(),
          const SizedBox(height: 32),
          _buildExamples(),
        ],
      ),
    );
  }
  
  Widget _buildFormatSelector() {
    final formats = ['Decimal', 'DMS', 'UTM'];
    return Row(
      children: List.generate(formats.length, (index) {
        final isSelected = _selectedFormat == index;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedFormat = index),
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryOrange : AppColors.panelLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  formats[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
  
  Widget _buildDecimalDegreesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Decimal Degrees (e.g., -28.887, 121.331)', 
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _latController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Latitude', 'e.g., -28.887'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _lonController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Longitude', 'e.g., 121.331'),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildDMSInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DMS (e.g., 28°53\'13"S 121°19\'51"E)', 
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: _dmsController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Coordinates', '28°53\'13"S 121°19\'51"E'),
        ),
      ],
    );
  }
  
  Widget _buildUTMInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('UTM (e.g., 51K 386421 6803567)', 
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: _utmController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('UTM', '51K 386421 6803567'),
        ),
      ],
    );
  }
  
  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
      filled: true,
      fillColor: AppColors.panelLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
  
  Widget _buildGoButton() {
    return GestureDetector(
      onTap: _navigateToCoordinates,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.navigation, color: Colors.white),
              SizedBox(width: 8),
              Text('Go to Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildExamples() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick examples:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildExampleChip('Uluru', -25.3444, 131.0369),
            _buildExampleChip('Perth', -31.9505, 115.8605),
            _buildExampleChip('Broome', -17.9614, 122.2356),
            _buildExampleChip('Darwin', -12.4637, 130.8438),
          ],
        ),
      ],
    );
  }
  
  Widget _buildExampleChip(String name, double lat, double lon) {
    return GestureDetector(
      onTap: () {
        _latController.text = lat.toString();
        _lonController.text = lon.toString();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.panelLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }
  
  void _navigateToCoordinates() {
    LatLng? coords;
    
    if (_selectedFormat == 0) {
      final lat = double.tryParse(_latController.text);
      final lon = double.tryParse(_lonController.text);
      if (lat != null && lon != null && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
        coords = LatLng(lat, lon);
      }
    } else if (_selectedFormat == 1) {
      coords = _parseDMS(_dmsController.text);
    } else if (_selectedFormat == 2) {
      coords = _parseUTM(_utmController.text);
    }
    
    if (coords != null) {
      widget.onCoordinateEntered?.call(coords);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigating to ${coords.latitude.toStringAsFixed(4)}, ${coords.longitude.toStringAsFixed(4)}'),
          backgroundColor: AppColors.statusGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid coordinates. Please check and try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  LatLng? _parseDMS(String input) {
    try {
      final latMatch = RegExp(r"(\d+)\D+\s*(\d+)\D+\s*([\d.]+)\D+\s*([NS])", caseSensitive: false).firstMatch(input.toUpperCase());
      final lonMatch = RegExp(r"(\d+)\D+\s*(\d+)\D+\s*([\d.]+)\D+\s*([EW])", caseSensitive: false).firstMatch(input.toUpperCase());
      
      if (latMatch != null && lonMatch != null) {
        double lat = double.parse(latMatch.group(1)!) + double.parse(latMatch.group(2)!) / 60 + double.parse(latMatch.group(3)!) / 3600;
        double lon = double.parse(lonMatch.group(1)!) + double.parse(lonMatch.group(2)!) / 60 + double.parse(lonMatch.group(3)!) / 3600;
        
        if (latMatch.group(4)!.toUpperCase() == 'S') lat = -lat;
        if (lonMatch.group(4)!.toUpperCase() == 'W') lon = -lon;
        
        return LatLng(lat, lon);
      }
    } catch (e) {
      debugPrint('DMS parse error: $e');
    }
    return null;
  }
  
  LatLng? _parseUTM(String input) {
    try {
      final parts = input.trim().split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        final zone = parts[0].replaceAll(RegExp(r'[A-Za-z]'), '');
        final easting = double.tryParse(parts[1]);
        final northing = double.tryParse(parts[2]);
        
        debugPrint('UTM: zone=$zone, easting=$easting, northing=$northing');
        return null;
      }
    } catch (e) {
      debugPrint('UTM parse error: $e');
    }
    return null;
  }
}