import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'color_picker.dart';
import '../../../core/models/trail.dart';

/// Trail creation overlay widget
class TrailCreationOverlay extends StatefulWidget {
  final List<LatLng> draftPoints;
  final VoidCallback onCancel;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final Function(String name, String color, String lineStyle) onSave;

  const TrailCreationOverlay({
    super.key,
    required this.draftPoints,
    required this.onCancel,
    required this.onUndo,
    required this.onClear,
    required this.onSave,
  });

  @override
  State<TrailCreationOverlay> createState() => _TrailCreationOverlayState();
}

class _TrailCreationOverlayState extends State<TrailCreationOverlay> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedColor = TrailColors.electricPurple;
  String _selectedLineStyle = TrailLineStyle.solid;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 120,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.timeline, color: Color(0xFFFF5722), size: 24),
                    SizedBox(width: 8),
                    Text(
                      '🛤️ Create Trail',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: widget.onCancel,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, color: Colors.white70, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Point count
            Text(
              '📍 Points: ${widget.draftPoints.length}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    Icons.undo,
                    '↩️ Undo',
                    widget.draftPoints.isEmpty ? null : widget.onUndo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    Icons.clear_all,
                    '🗑️ Clear',
                    widget.draftPoints.isEmpty ? null : widget.onClear,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
              // Trail name input (only show when points exist)
              if (widget.draftPoints.length >= 2) ...[
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '🏷️ Trail name (optional)',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Color picker
              const Text(
                '🎨 Trail Colour',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              ColorPicker(
                selectedColor: _selectedColor,
                onColorSelected: (color) {
                  setState(() => _selectedColor = color);
                },
              ),
              const SizedBox(height: 16),
              
              // Line style
              const Text(
                '📊 Line Style',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildLineStylePicker(),
              const SizedBox(height: 20),
              
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onSave(
                      _nameController.text.isEmpty
                          ? 'Trail ${DateTime.now().toIso8601String().substring(0, 10)}'
                          : _nameController.text,
                      _selectedColor,
                      _selectedLineStyle,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5722),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                    child: const Text(
                      '💾 Save Trail',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                    child: Text(
                      '👆 Tap on the map to drop points. Add at least 2 points to create a trail.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback? onTap) {
    final isEnabled = onTap != null;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isEnabled
              ? const Color(0xFF2C2C2C)
              : const Color(0xFF2C2C2C).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isEnabled
                  ? Colors.white70
                  : Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isEnabled
                    ? Colors.white70
                    : Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineStylePicker() {
    final styles = [
      (TrailLineStyle.solid, 'Solid', null),
      (TrailLineStyle.dashed, 'Dashed', [15.0, 10.0]),
      (TrailLineStyle.dotted, 'Dotted', [5.0, 5.0]),
    ];

    return Row(
      children: [
        for (var style in styles) ...[
          GestureDetector(
            onTap: () => setState(() => _selectedLineStyle = style.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _selectedLineStyle == style.$1
                    ? const Color(0xFFFF5722).withValues(alpha: 0.2)
                    : const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedLineStyle == style.$1
                      ? const Color(0xFFFF5722)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Line preview
                  Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: _selectedLineStyle == style.$1
                          ? const Color(0xFFFF5722)
                          : Colors.white70,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    style.$2,
                    style: TextStyle(
                      color: _selectedLineStyle == style.$1
                          ? const Color(0xFFFF5722)
                          : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Trail following overlay with navigation guidance
class TrailFollowingOverlay extends StatelessWidget {
  final String? message;
  final double? distanceToNext;
  final double? bearing;
  final int currentPointIndex;
  final int totalPoints;
  final VoidCallback onStop;

  const TrailFollowingOverlay({
    super.key,
    this.message,
    this.distanceToNext,
    this.bearing,
    required this.currentPointIndex,
    required this.totalPoints,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 200,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.navigation, color: Color(0xFF00FF88), size: 24),
                    SizedBox(width: 8),
                    Text(
                      '🧭 Following Trail',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$currentPointIndex/$totalPoints',
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Navigation message
            if (message != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            
            // Distance and bearing
            if (distanceToNext != null && bearing != null)
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      Icons.straighten,
                      '📏 ${(distanceToNext! / 1000).toStringAsFixed(2)} km',
                      'Distance',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      Icons.explore,
                      '🧭 ${bearing!.toInt()}°',
                      'Bearing',
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            
            // Direction arrow
            if (bearing != null)
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                child: Transform.rotate(
                  angle: bearing! * 3.14159 / 180,
                  child: const Icon(
                    Icons.arrow_upward,
                    color: Color(0xFFFF5722),
                    size: 60,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            
            // Stop button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                    child: const Text(
                      '🛑 Stop Following',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFFF5722), size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
