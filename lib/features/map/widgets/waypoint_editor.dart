import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:uuid/uuid.dart';

class WaypointEditorSheet extends ConsumerStatefulWidget {
  final Waypoint? waypoint;
  final LatLng? position;
  final bool isReadOnly;
  
  const WaypointEditorSheet({
    super.key,
    this.waypoint,
    this.position,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<WaypointEditorSheet> createState() => _WaypointEditorSheetState();
}

class _WaypointEditorSheetState extends ConsumerState<WaypointEditorSheet> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  String _selectedCategory = 'custom';
  int _rating = 0;
  bool _isSaving = false;
  
  final List<Map<String, String>> _categories = [
    {'id': 'camp', 'icon': '⛺', 'name': 'Camp'},
    {'id': 'water', 'icon': '💧', 'name': 'Water'},
    {'id': 'hazard', 'icon': '⚠️', 'name': 'Hazard'},
    {'id': 'fuel', 'icon': '⛽', 'name': 'Fuel'},
    {'id': 'road', 'icon': '🛣️', 'name': 'Road'},
    {'id': 'custom', 'icon': '📍', 'name': 'Custom'},
  ];
  
  final Map<String, String> _categoryColors = {
    'camp': '#FF6B35',
    'water': '#00E5FF',
    'hazard': '#FF2D55',
    'fuel': '#FFD700',
    'road': '#7B2FFF',
    'custom': '#00FF88',
  };
  
  final List<String> _colours = [
    '#7B2FFF', '#00E5FF', '#FF6B35', '#00FF88', '#FF2D55', '#FFFFFF',
  ];
  
  String _selectedColour = '#00E5FF';
  String _currentWeather = '28°C, Wind: 12km/h NE';
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.waypoint?.label ?? '');
    _notesController = TextEditingController(text: widget.waypoint?.notes ?? '');
    if (widget.waypoint != null) {
      _selectedCategory = widget.waypoint!.icon ?? 'custom';
      _selectedColour = widget.waypoint!.color ?? _categoryColors[_selectedCategory] ?? '#00E5FF';
      _rating = widget.waypoint!.order ?? 0;
    } else {
      _selectedColour = _categoryColors[_selectedCategory] ?? '#00E5FF';
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
@override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final isEditing = widget.waypoint != null;
    final isReadOnly = widget.isReadOnly || isEditing;
    final lat = widget.waypoint?.latitude ?? widget.position?.latitude ?? 0.0;
    final lon = widget.waypoint?.longitude ?? widget.position?.longitude ?? 0.0;
    final now = DateTime.now();
    
    if (isReadOnly && widget.waypoint != null) {
      return _buildReadOnlyView(context, lat, lon);
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(_getCategoryIcon(_selectedCategory), style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Text(
                      isEditing ? 'Edit Pin' : 'Drop New Pin',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            const Text('📍 Pin Name', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'What is this location?',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: AppColors.panelLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            
            const Text('📝 Notes', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add details... water source here,\ntrack condition, hazard description, camp quality...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: AppColors.panelLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            
            const Text('🏷️ Category', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat['id'];
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedCategory = cat['id']!;
                      _selectedColour = _categoryColors[cat['id']] ?? '#00E5FF';
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? _hexToColor(_categoryColors[cat['id']] ?? '#00E5FF').withValues(alpha: 0.2) : AppColors.panelLight,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: _hexToColor(_categoryColors[cat['id']] ?? '#00E5FF')) : null,
                      ),
                      child: Row(
                        children: [
                          Text(cat['icon']!, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(cat['name']!, style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            
            const Text('⭐ Rating', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      i < _rating ? '⭐' : '☆',
                      style: TextStyle(
                        fontSize: 28,
                        color: i < _rating ? Colors.amber : Colors.white30,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            
            const Text('🎨 Colour', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _colours.map((colour) {
                  final isSelected = _selectedColour == colour;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColour = colour),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _hexToColor(colour),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        boxShadow: isSelected ? [BoxShadow(color: _hexToColor(colour).withValues(alpha: 0.5), blurRadius: 8)] : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.panelLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: AppColors.textSecondary, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        '📅 Saved: ${_formatDate(now)}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.textSecondary, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'Your coords: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.thermostat, color: AppColors.textSecondary, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        '🌡️ $_currentWeather',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.panelLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _isSaving ? null : _saveWaypoint,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : Text(
                                isEditing ? 'Update Pin' : 'Save Pin',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReadOnlyView(BuildContext context, double lat, double lon) {
    final waypoint = widget.waypoint!;
    final categoryInfo = _categories.firstWhere(
      (c) => c['id'] == waypoint.icon,
      orElse: () => {'id': 'custom', 'icon': '📍', 'name': 'Custom'},
    );
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _hexToColor(waypoint.color ?? '#00E5FF').withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          categoryInfo['icon']!,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          waypoint.label ?? 'Unnamed Pin',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          categoryInfo['name']!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (waypoint.notes != null && waypoint.notes!.isNotEmpty) ...[
              const Text('📝 Notes', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.panelLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  waypoint.notes!,
                  style: const TextStyle(color: Colors.white, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            if (waypoint.order != null && waypoint.order! > 0) ...[
              const Text('⭐ Rating', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) {
                  return Text(
                    i < waypoint.order! ? '⭐' : '☆',
                    style: TextStyle(
                      fontSize: 24,
                      color: i < waypoint.order! ? Colors.amber : Colors.white30,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
            ],
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.panelLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: AppColors.textSecondary, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        '📅 Created: ${waypoint.timestamp != null ? _formatDate(waypoint.timestamp!) : 'Unknown'}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.textSecondary, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        '📍 ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      showWaypointEditor(context, waypoint: waypoint);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryOrange),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit, color: AppColors.primaryOrange, size: 18),
                            SizedBox(width: 8),
                            Text('Edit', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelMatte,
        title: const Text('Delete Pin?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete this waypoint. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              if (widget.waypoint?.id != null) {
                ref.read(locationProvider.notifier).deleteWaypoint(widget.waypoint!.id!);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  String _getCategoryIcon(String category) {
    final cat = _categories.firstWhere(
      (c) => c['id'] == category,
      orElse: () => {'id': 'custom', 'icon': '📍'},
    );
    return cat['icon']!;
  }
  
  void _saveWaypoint() async {
    setState(() => _isSaving = true);
    
    final lat = widget.waypoint?.latitude ?? widget.position?.latitude;
    final lon = widget.waypoint?.longitude ?? widget.position?.longitude;
    
    if (lat == null || lon == null) return;
    
    final now = DateTime.now();
    final waypoint = Waypoint(
      id: widget.waypoint?.id ?? DateTime.now().millisecondsSinceEpoch,
      latitude: lat,
      longitude: lon,
      timestamp: now,
      label: _nameController.text.isEmpty ? 'Pin' : _nameController.text,
      notes: _notesController.text,
      type: WaypointType.manual,
      color: _selectedColour,
      icon: _selectedCategory,
      order: _rating,
      isPin: true,
    );
    
    if (widget.waypoint != null) {
      await ref.read(locationProvider.notifier).updateWaypoint(waypoint);
    } else {
      await ref.read(locationProvider.notifier).addManualWaypoint(
        lat,
        lon,
        _nameController.text.isEmpty ? 'Pin' : _nameController.text,
        notes: _notesController.text,
        color: _selectedColour,
        icon: _selectedCategory,
        order: _rating,
      );
    }
    
    await _saveToLocalStorage(waypoint);
    
    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }
  
  Future<void> _saveToLocalStorage(Waypoint waypoint) async {
    try {
      final key = 'bushtrack_waypoints';
      final waypointData = {
        'id': waypoint.id,
        'name': waypoint.label,
        'notes': waypoint.notes,
        'category': waypoint.icon,
        'rating': waypoint.order,
        'lat': waypoint.latitude,
        'lon': waypoint.longitude,
        'colour': waypoint.color,
        'icon': _categories.firstWhere((c) => c['id'] == waypoint.icon, orElse: () => {'icon': '📍'})['icon'],
        'timestamp': waypoint.timestamp?.toIso8601String(),
        'weather': _currentWeather,
        'savedAt': '${waypoint.latitude}, ${waypoint.longitude}',
      };
      debugPrint('Saving waypoint to localStorage: ${jsonEncode(waypointData)}');
    } catch (e) {
      debugPrint('Error saving waypoint: $e');
    }
  }
  
  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
  
  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}, ${hour == 0 ? 12 : hour}:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }
}

// Helper function to show the waypoint editor
void showWaypointEditor(BuildContext context, {Waypoint? waypoint, LatLng? position}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: WaypointEditorSheet(
        waypoint: waypoint,
        position: position,
      ),
    ),
  );
}