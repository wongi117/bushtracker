import 'package:flutter/material.dart';
import '../../../core/models/waypoint.dart';
import 'color_picker.dart';

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

  bool get _isPinage => waypoint.isPinage;

  @override
  Widget build(BuildContext context) {
    if (_isPinage) return _buildPinageMarker(context);

    final color = WaypointColors.fromHex(waypoint.color);
    final iconData = WaypointIcon.getIconData(waypoint.icon);
    final orderNumber = waypoint.order;

    return GestureDetector(
      onTap: () => _showMenu(context),
      onLongPress: () => _showMenu(context),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
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
                  border: Border.all(color: Colors.white, width: 2),
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

  /// Amber camera-style marker for pinages.
  Widget _buildPinageMarker(BuildContext context) {
    const amber = Color(0xFFFFB300);
    final photoCount = waypoint.photoCount;

    return GestureDetector(
      onTap: onEdit,   // opens PinageViewer directly — no intermediate menu
      onLongPress: onEdit,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Card-style background
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: amber.withValues(alpha: 0.7), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: amber.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.photo_camera_rounded, color: amber, size: 22),
          ),
          // Photo count badge
          if (photoCount > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: amber,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    photoCount > 9 ? '9+' : photoCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
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

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _WaypointMenuSheet(
        waypoint: waypoint,
        onEdit: () {
          Navigator.pop(ctx);
          onEdit();
        },
        onDelete: () {
          Navigator.pop(ctx);
          onDelete();
        },
        onNavigate: onNavigate == null
            ? null
            : () {
                Navigator.pop(ctx);
                onNavigate!();
              },
        onColorChanged: onColorChanged,
        onIconChanged: onIconChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _WaypointMenuSheet extends StatelessWidget {
  final Waypoint waypoint;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onNavigate;
  final Function(String) onColorChanged;
  final Function(String) onIconChanged;

  const _WaypointMenuSheet({
    required this.waypoint,
    required this.onEdit,
    required this.onDelete,
    required this.onColorChanged,
    required this.onIconChanged,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final color = WaypointColors.fromHex(waypoint.color);
    final iconData = WaypointIcon.getIconData(waypoint.icon);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1035),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header — icon + name + coords
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: color, size: 26),
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
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (waypoint.notes != null && waypoint.notes!.isNotEmpty)
                    Text(
                      waypoint.notes!,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (waypoint.latitude != null)
                    Text(
                      '${waypoint.latitude!.toStringAsFixed(5)}, '
                      '${waypoint.longitude!.toStringAsFixed(5)}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // Action row
          Row(children: [
            _actionBtn(context, Icons.edit_outlined, 'Edit Info',
                const Color(0xFF2196F3), onEdit),
            const SizedBox(width: 10),
            if (onNavigate != null) ...[
              _actionBtn(context, Icons.navigation_outlined, 'Navigate',
                  const Color(0xFF4CAF50), onNavigate!),
              const SizedBox(width: 10),
            ],
            _actionBtn(context, Icons.delete_outline, 'Delete',
                const Color(0xFFFF3B30), () => _confirmDelete(context)),
          ]),
          const SizedBox(height: 20),

          // Colour picker
          const Text('Colour',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          ColorPicker(
            selectedColor: waypoint.color,
            onColorSelected: onColorChanged,
          ),
          const SizedBox(height: 20),

          // Icon picker
          const Text('Icon',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          _iconRow(color),
        ],
      ),
    );
  }

  Widget _actionBtn(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _iconRow(Color currentColor) {
    final icons = [
      (WaypointIcon.pin, Icons.location_on, 'Pin'),
      (WaypointIcon.camp, Icons.local_fire_department, 'Camp'),
      (WaypointIcon.water, Icons.water_drop, 'Water'),
      (WaypointIcon.hazard, Icons.warning_amber, 'Hazard'),
      (WaypointIcon.fuel, Icons.local_gas_station, 'Fuel'),
      (WaypointIcon.road, Icons.add_road, 'Road'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in icons)
            GestureDetector(
              onTap: () => onIconChanged(entry.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: waypoint.icon == entry.$1
                      ? currentColor.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: waypoint.icon == entry.$1
                        ? currentColor
                        : Colors.white.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(entry.$2, color: currentColor, size: 26),
                  const SizedBox(height: 4),
                  Text(entry.$3,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1035),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
        ),
        title: const Text('Delete Waypoint?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Delete "${waypoint.label ?? 'this waypoint'}"? This cannot be undone.',
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close confirm dialog
              onDelete();             // already closes the sheet
            },
            child: const Text('DELETE',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
