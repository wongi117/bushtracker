import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:bush_track/theme/app_colors.dart';
import 'package:bush_track/features/mesh/providers/mesh_provider.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/features/chat/presentation/ai_chat_screen.dart';
import 'package:bush_track/core/models/waypoint.dart';

class MeshBottomSheet extends ConsumerStatefulWidget {
  /// Optional callback invoked when the user taps a waypoint, so
  /// the parent dashboard can pan the map to that location.
  final void Function(LatLng)? onWaypointTapped;

  const MeshBottomSheet({super.key, this.onWaypointTapped});

  @override
  ConsumerState<MeshBottomSheet> createState() => _MeshBottomSheetState();
}

class _MeshBottomSheetState extends ConsumerState<MeshBottomSheet>
    with SingleTickerProviderStateMixin {
  String _activeTab = 'System';
  bool _isExpanded = false;
  late AnimationController _animController;
  late Animation<double> _heightAnimation;

  static const double _collapsedHeight = 120.0;
  static const double _expandedHeight = 0.45; // 45% of screen

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightAnimation =
        Tween<double>(begin: _collapsedHeight, end: _expandedHeight).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final meshState = ref.watch(meshProvider);
    final locationState = ref.watch(locationProvider);
    final stats = locationState.stats;
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: _heightAnimation,
      builder: (context, child) {
        final height =
            _isExpanded ? screenHeight * _expandedHeight : _collapsedHeight;

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.panelMatte,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Issue #1: Drag handle - swipeable
              GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.velocity.pixelsPerSecond.dy < -200) {
                    _toggleExpanded();
                  } else if (details.velocity.pixelsPerSecond.dy > 200) {
                    if (_isExpanded) _toggleExpanded();
                  }
                },
                onTap: _toggleExpanded,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.panelLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isExpanded
                                ? '⬇️ Swipe down to collapse'
                                : '⬆️ Swipe up for more',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // When collapsed: show only speed + coords
              if (!_isExpanded)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🚀 SPEED',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                          Text(stats.speedFormatted,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            stats.coordsDecimal.substring(
                                0,
                                stats.coordsDecimal.length > 24
                                    ? 24
                                    : stats.coordsDecimal.length),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('📡 NODES',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                          Text('${meshState.connectedEndpoints.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),

              // When expanded: show all tabs and content
              if (_isExpanded) ...[
                const SizedBox(height: 8),
                // Top Navigation Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTab('⚙️ System',
                          isActive: _activeTab == 'System',
                          onTap: () => setState(() => _activeTab = 'System')),
                      _buildTab('📍 Waypoints',
                          isActive: _activeTab == 'Waypoints',
                          onTap: () =>
                              setState(() => _activeTab = 'Waypoints')),
                      _buildTab('🤖 AI',
                          isActive: _activeTab == 'AI',
                          onTap: () => setState(() => _activeTab = 'AI')),
                      _buildTab('💬 Chat',
                          isActive: _activeTab == 'Chat',
                          onTap: () => setState(() => _activeTab = 'Chat')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildTabContent(stats, meshState, locationState),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabContent(
      TrackStats stats, MeshState meshState, LocationState locationState) {
    switch (_activeTab) {
      case 'System':
        return _buildSystemTab(stats, meshState);
      case 'Waypoints':
        return _buildWaypointsTab(locationState);
      case 'AI':
        return _buildAITab();
      case 'Chat':
        // Bug #5 fix: inline AIChatScreen instead of nested modal
        return const AIChatScreen();
      default:
        return _buildSystemTab(stats, meshState);
    }
  }

  Widget _buildAITab() {
    return GestureDetector(
      onTap: () => showAIChat(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.purplePrimary.withValues(alpha: 0.2),
              AppColors.primaryOrange.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.purplePrimary.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Text('🤖', style: TextStyle(fontSize: 40)),
            ),
            const SizedBox(height: 20),
            const Text(
              'ANTIGRAVITY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your AI Field Partner',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.panelLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app,
                      color: AppColors.primaryOrange, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Tap to chat',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemTab(TrackStats stats, MeshState meshState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('🚀 SPEED', stats.speedFormatted),
                _buildStatItem('📏 DISTANCE', stats.distanceFormatted),
                _buildStatItem('⏱️ ELAPSED', stats.elapsedFormatted),
              ],
            ),
            const SizedBox(height: 24),
            // Coordinates
            const Text('📍 COORDINATES',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(stats.coordsDecimal,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(stats.gpsAccuracyFormatted,
                style: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            // Mesh status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📡 MESH',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(
                      meshState.isAdvertising || meshState.isDiscovering
                          ? 'ACTIVE'
                          : kIsWeb
                              ? 'APP ONLY'
                              : 'OFFLINE',
                      style: TextStyle(
                        color:
                            meshState.isAdvertising || meshState.isDiscovering
                                ? AppColors.statusGreen
                                : kIsWeb
                                    ? Colors.blue
                                    : AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (kIsWeb)
                      const Text(
                        'Mesh needs Android/iOS app',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 10),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('📡 NODES',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(
                      '${meshState.connectedEndpoints.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaypointsTab(LocationState state) {
    // Bug #7 fix: only show user-created pins, not auto GPS breadcrumbs
    final pins = state.waypoints
        .where((w) => w.isPin == true || w.type == WaypointType.manual)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('📍 WAYPOINTS',
                  style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              Text('${pins.length}',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: pins.isEmpty
                ? const Center(
                    child: Text(
                    '📍 No pins saved yet — long-press the map to add one',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ))
                : ListView.builder(
                    itemCount: pins.length,
                    itemBuilder: (context, index) {
                      final w = pins[index];
                      final icon = _getWaypointIcon(w.icon);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading:
                            Text(icon, style: const TextStyle(fontSize: 20)),
                        title: Text(
                            w.label ??
                                'Pin at ${w.timestamp != null ? TimeOfDay.fromDateTime(w.timestamp!).format(context) : 'now'}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                        subtitle: Text(
                          '${w.latitude?.toStringAsFixed(4)}, ${w.longitude?.toStringAsFixed(4)}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textSecondary, size: 18),
                        onTap: () {
                          // Bug #6 fix: use callback to pan the map instead of Navigator.pop
                          if (w.latitude != null && w.longitude != null) {
                            widget.onWaypointTapped
                                ?.call(LatLng(w.latitude!, w.longitude!));
                            // Collapse the sheet after tapping
                            if (_isExpanded) _toggleExpanded();
                          }
                        },
                      );
                    },
                  ),
          ),
          if (state.breadcrumbs.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Breadcrumb Trail',
                style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: state.breadcrumbs.length > 20
                    ? 20
                    : state.breadcrumbs.length,
                itemBuilder: (context, index) {
                  final breadcrumb =
                      state.breadcrumbs.reversed.elementAt(index);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.more_horiz,
                        color: AppColors.textSecondary, size: 18),
                    title: Text(
                      'Track point ${state.breadcrumbs.length - index}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Text(
                      '${breadcrumb.latitude?.toStringAsFixed(4)}, ${breadcrumb.longitude?.toStringAsFixed(4)}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

// _buildChatTab removed — Chat tab now renders AIChatScreen inline

  String _getWaypointIcon(String? icon) {
    switch (icon) {
      case 'camp':
        return '⛺';
      case 'water':
        return '💧';
      case 'hazard':
        return '⚠️';
      case 'fuel':
        return '⛽';
      case 'road':
        return '🛣️';
      default:
        return '📍';
    }
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                letterSpacing: 1.2)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTab(String title, {bool isActive = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.panelLight : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
