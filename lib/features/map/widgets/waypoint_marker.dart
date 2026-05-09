import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/waypoint.dart';
import 'color_picker.dart';

/// Waypoint marker with number label and popup menu
class WaypointMarker extends StatelessWidget {
  final Waypoint waypoint;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String color) onColorChanged;
  final Function(String icon) onIconChanged;
  final VoidCallback? onNavigate;
  final VoidCallback? onLongPress;
  final bool isDraggable;

  const WaypointMarker({
    super.key,
    required this.waypoint,
    required this.onEdit,
    required this.onDelete,
    required this.onColorChanged,
    required this.onIconChanged,
    this.onNavigate,
    this.onLongPress,
    this.isDraggable = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = WaypointColors.fromHex(waypoint.color);
    final iconData = WaypointIcon.getIconData(waypoint.icon);
    final orderNumber = waypoint.order;
    
    return GestureDetector(
      onTap: () => _showPopupMenu(context),
      onLongPress: onLongPress,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Pin icon
          Icon(
            iconData,
            color: color,
            size: 44,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          // Number badge
          if (orderNumber != null)
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    orderNumber.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPopupMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  WaypointIcon.getIconData(waypoint.icon),
                  color: WaypointColors.fromHex(waypoint.color),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        waypoint.label ?? 'Waypoint',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (waypoint.notes != null)
                        Text(
                          waypoint.notes!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  Icons.edit,
                  'Edit',
                  Colors.blue,
                  () {
                    // Note: context navigation would need BuildContext passed in
                // For now, just call the callback
                    onEdit();
                  },
                ),
                _buildActionButton(
                  Icons.delete,
                  'Delete',
                  Colors.red,
                  () {
                    // Note: context navigation would need BuildContext passed in
                // For now, just call the callback
                    _showDeleteConfirmation(context);
                  },
                ),
                _buildActionButton(
                  Icons.navigation,
                  'Navigate',
                  Colors.green,
                  () {
                    // Note: context navigation would need BuildContext passed in
                // For now, just call the callback
                    onNavigate?.call();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Color picker
            const Text(
              'Change Colour',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ColorPicker(
              selectedColor: waypoint.color,
              onColorSelected: (color) {
                // Note: context navigation would need BuildContext passed in
                // For now, just call the callback
                onColorChanged(color);
              },
            ),
            const SizedBox(height: 20),
            
            // Icon picker
            const Text(
              'Change Icon',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _buildIconPicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconPicker() {
    final icons = [
      (WaypointIcon.pin, Icons.location_on, 'Pin'),
      (WaypointIcon.camp, Icons.local_fire_department, 'Camp'),
      (WaypointIcon.water, Icons.water_drop, 'Water'),
      (WaypointIcon.hazard, Icons.warning, 'Hazard'),
      (WaypointIcon.fuel, Icons.local_gas_station, 'Fuel'),
      (WaypointIcon.road, Icons.add_road, 'Road'),
    ];
    
    final currentColor = WaypointColors.fromHex(waypoint.color);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var iconData in icons) ...[
            GestureDetector(
              onTap: () {
                onIconChanged(iconData.$1);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: waypoint.icon == iconData.$1
                      ? currentColor.withValues(alpha: 0.3)
                      : const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: waypoint.icon == iconData.$1
                        ? currentColor
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(iconData.$2, color: currentColor, size: 28),
                    const SizedBox(height: 4),
                    Text(
                      iconData.$3,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete Waypoint?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${waypoint.label ?? 'this waypoint'}"?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
