import 'package:flutter/material.dart';
import '../../../core/models/waypoint.dart';
import '../../../core/models/trail.dart';

/// Horizontal scrolling color picker for trails and waypoints
class ColorPicker extends StatelessWidget {
  final String? selectedColor;
  final ValueChanged<String> onColorSelected;
  final double circleSize;
  final bool showNames;

  const ColorPicker({
    super.key,
    this.selectedColor,
    required this.onColorSelected,
    this.circleSize = 36,
    this.showNames = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TrailColors.allColors;
    final names = TrailColors.colorNames;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < colors.length; i++) ...[
            GestureDetector(
              onTap: () => onColorSelected(colors[i]),
              child: Container(
                margin: EdgeInsets.only(
                  left: i == 0 ? 0 : 8,
                  right: i == colors.length - 1 ? 0 : 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        color: WaypointColors.fromHex(colors[i]),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == colors[i]
                              ? Colors.white
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: WaypointColors.fromHex(colors[i])
                                .withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: selectedColor == colors[i]
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                    if (showNames) ...[
                      const SizedBox(height: 4),
                      Text(
                        names[i],
                        style: TextStyle(
                          color: selectedColor == colors[i]
                              ? Colors.white
                              : Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact color picker for small spaces
class CompactColorPicker extends StatelessWidget {
  final String? selectedColor;
  final ValueChanged<String> onColorSelected;

  const CompactColorPicker({
    super.key,
    this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TrailColors.allColors;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < colors.length; i++) ...[
            GestureDetector(
              onTap: () => onColorSelected(colors[i]),
              child: Container(
                margin: EdgeInsets.only(
                  left: i == 0 ? 0 : 6,
                  right: i == colors.length - 1 ? 0 : 6,
                ),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: WaypointColors.fromHex(colors[i]),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedColor == colors[i]
                        ? Colors.white
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
