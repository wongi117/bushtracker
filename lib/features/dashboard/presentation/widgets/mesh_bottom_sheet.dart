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
  final void Function(LatLng)? onWaypointTapped;
  const MeshBottomSheet({super.key, this.onWaypointTapped});

  @override
  ConsumerState<MeshBottomSheet> createState() => _MeshBottomSheetState();
}

class _MeshBottomSheetState extends ConsumerState<MeshBottomSheet>
    with SingleTickerProviderStateMixin {
  String _activeTab = 'System';
  int _sheetState = 0; // 0=collapsed, 1=half, 2=full

  static const double _collapsedHeight = 120.0;

  void _advanceState() => setState(() => _sheetState = (_sheetState + 1) % 3);
  void _expandOne()    { if (_sheetState < 2) setState(() => _sheetState++); }
  void _collapseOne()  { if (_sheetState > 0) setState(() => _sheetState--); }
  bool get _isExpanded => _sheetState > 0;

  @override
  Widget build(BuildContext context) {
    final meshState     = ref.watch(meshProvider);
    final locationState = ref.watch(locationProvider);
    final stats         = locationState.stats;
    final screenHeight  = MediaQuery.of(context).size.height;

    final double height = switch (_sheetState) {
      1 => screenHeight * 0.5,
      2 => screenHeight,
      _ => _collapsedHeight,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.steelGradient,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(BushDS.radiusXL)),
          border: const Border(
            top: BorderSide(color: Color(0xFF2A2A2A)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Drag handle ────────────────────────────────────────────────
            GestureDetector(
              onVerticalDragEnd: (d) {
                if (d.velocity.pixelsPerSecond.dy < -200) {
                  _expandOne();
                } else if (d.velocity.pixelsPerSecond.dy > 200) {
                  _collapseOne();
                }
              },
              onTap: _advanceState,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(BushDS.radiusXL)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pill
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: AppColors.accentGradient,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _sheetState == 0
                              ? Icons.keyboard_arrow_up_rounded
                              : _sheetState == 2
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.swap_vert_rounded,
                          color: AppColors.accent,
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _sheetState == 0
                              ? 'Tap to expand'
                              : _sheetState == 1
                                  ? 'Tap for fullscreen'
                                  : 'Tap to collapse',
                          style: TextStyle(
                            color: AppColors.accent.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Collapsed view ─────────────────────────────────────────────
            if (!_isExpanded)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: BushDS.spMD),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCollapsedStat(
                        Icons.speed, 'SPEED', stats.speedFormatted),
                    Text(
                      stats.coordsDecimal.substring(
                          0,
                          stats.coordsDecimal.length > 24
                              ? 24
                              : stats.coordsDecimal.length),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    _buildCollapsedStat(
                        Icons.cell_tower,
                        'NODES',
                        '${meshState.connectedEndpoints.length}'),
                  ],
                ),
              ),

            // ── Expanded view ──────────────────────────────────────────────
            if (_isExpanded) ...[
              const SizedBox(height: BushDS.spSM),
              _buildTabBar(),
              const SizedBox(height: BushDS.spMD),
              Expanded(
                child: _buildTabContent(stats, meshState, locationState),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Collapsed stat item ────────────────────────────────────────────────────
  Widget _buildCollapsedStat(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 12),
            const SizedBox(width: BushDS.spXS),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: BushDS.fontXS,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0)),
          ],
        ),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BushDS.spMD),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTab(Icons.settings,          'System',    'System'),
          _buildTab(Icons.place,             'Waypoints', 'Waypoints'),
          _buildTab(Icons.smart_toy,         'AI',        'AI'),
          _buildTab(Icons.chat_bubble_outline,'Chat',     'Chat'),
        ],
      ),
    );
  }

  Widget _buildTab(IconData icon, String label, String key) {
    final isActive = _activeTab == key;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = key),
      child: Container(
        constraints: const BoxConstraints(minHeight: BushDS.tapMin),
        padding: const EdgeInsets.symmetric(
            horizontal: BushDS.spSM + 4, vertical: BushDS.spSM),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.steelGradient : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(BushDS.radiusSM),
          border: isActive
              ? Border.all(color: AppColors.accent.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive ? AppColors.accent : AppColors.textSecondary,
                size: 16),
            const SizedBox(width: BushDS.spXS),
            Text(
              label,
              style: TextStyle(
                color:
                    isActive ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: BushDS.fontSM,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab content ────────────────────────────────────────────────────────────
  Widget _buildTabContent(
      TrackStats stats, MeshState meshState, LocationState locationState) {
    return switch (_activeTab) {
      'System'    => _buildSystemTab(stats, meshState),
      'Waypoints' => _buildWaypointsTab(locationState),
      'AI'        => _buildAITab(),
      'Chat'      => const AIChatScreen(),
      _           => _buildSystemTab(stats, meshState),
    };
  }

  // ── System tab ─────────────────────────────────────────────────────────────
  Widget _buildSystemTab(TrackStats stats, MeshState meshState) {
    final meshActive =
        meshState.isAdvertising || meshState.isDiscovering;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BushDS.spMD),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stat row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.speed,     'SPEED',    stats.speedFormatted),
                _buildStatItem(Icons.straighten,'DISTANCE', stats.distanceFormatted),
                _buildStatItem(Icons.timer,     'ELAPSED',  stats.elapsedFormatted),
              ],
            ),
            const SizedBox(height: BushDS.spLG),
            // Coordinates
            _buildSectionLabel(Icons.place, 'COORDINATES'),
            const SizedBox(height: BushDS.spXS),
            Text(stats.coordsDecimal,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: BushDS.spXS),
            Text(stats.gpsAccuracyFormatted,
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: BushDS.fontMD,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: BushDS.spLG),
            // Mesh status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel(Icons.cell_tower, 'MESH'),
                    const SizedBox(height: BushDS.spXS),
                    Text(
                      meshActive
                          ? 'ACTIVE'
                          : kIsWeb
                              ? 'APP ONLY'
                              : 'OFFLINE',
                      style: TextStyle(
                        color: meshActive
                            ? AppColors.statusGreen
                            : kIsWeb
                                ? AppColors.statusBlue
                                : AppColors.textSecondary,
                        fontSize: BushDS.fontLG,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (kIsWeb)
                      const Text(
                        'Mesh needs Android/iOS app',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: BushDS.fontXS),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildSectionLabel(Icons.hub, 'NODES'),
                    const SizedBox(height: BushDS.spXS),
                    Text(
                      '${meshState.connectedEndpoints.length}',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: BushDS.fontLG,
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

  // ── Waypoints tab ──────────────────────────────────────────────────────────
  Widget _buildWaypointsTab(LocationState state) {
    final pins = state.waypoints
        .where((w) => w.isPin == true || w.type == WaypointType.manual)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BushDS.spMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionLabel(Icons.place, 'WAYPOINTS'),
              Text('${pins.length}',
                  style:
                      const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: BushDS.spSM),
          Expanded(
            child: pins.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.place,
                            color: AppColors.textMuted, size: 40),
                        SizedBox(height: BushDS.spSM),
                        Text(
                          'No pins saved yet\nLong-press the map to add one',
                          style: TextStyle(color: AppColors.textSecondary,
                              fontSize: BushDS.fontMD),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: pins.length,
                    itemBuilder: (context, index) {
                      final w = pins[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_getWaypointIcon(w.icon),
                            color: AppColors.accent, size: 22),
                        title: Text(
                          w.label ??
                              'Pin at ${w.timestamp != null ? TimeOfDay.fromDateTime(w.timestamp!).format(context) : 'now'}',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: BushDS.fontLG),
                        ),
                        subtitle: Text(
                          '${w.latitude?.toStringAsFixed(4)}, ${w.longitude?.toStringAsFixed(4)}',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: BushDS.fontSM),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textSecondary, size: 18),
                        onTap: () {
                          if (w.latitude != null && w.longitude != null) {
                            widget.onWaypointTapped
                                ?.call(LatLng(w.latitude!, w.longitude!));
                            if (_isExpanded) _collapseOne();
                          }
                        },
                      );
                    },
                  ),
          ),
          if (state.breadcrumbs.isNotEmpty) ...[
            const SizedBox(height: BushDS.spSM),
            _buildSectionLabel(Icons.timeline, 'BREADCRUMB TRAIL'),
            const SizedBox(height: BushDS.spSM),
            Expanded(
              child: ListView.builder(
                itemCount:
                    state.breadcrumbs.length > 20 ? 20 : state.breadcrumbs.length,
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
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: BushDS.fontMD),
                    ),
                    subtitle: Text(
                      '${breadcrumb.latitude?.toStringAsFixed(4)}, ${breadcrumb.longitude?.toStringAsFixed(4)}',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: BushDS.fontXS),
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

  // ── AI tab ─────────────────────────────────────────────────────────────────
  Widget _buildAITab() {
    return GestureDetector(
      onTap: () => showAIChat(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: BushDS.spMD),
        padding: const EdgeInsets.all(BushDS.spLG),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.12),
              AppColors.panelMatte,
            ],
          ),
          borderRadius: BorderRadius.circular(BushDS.radiusLG),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with metallic glow
            Container(
              padding: const EdgeInsets.all(BushDS.spLG),
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(BushDS.radiusLG),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGlow,
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 40),
            ),
            const SizedBox(height: BushDS.spLG),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.accentGradient.createShader(b),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 20),
                ),
                const SizedBox(width: BushDS.spXS),
                const Text(
                  'FUTURE GEN AI',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: BushDS.spSM),
            Text(
              'Your AI Field Partner',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontSize: BushDS.fontMD,
              ),
            ),
            const SizedBox(height: BushDS.spMD),
            Container(
              constraints:
                  const BoxConstraints(minHeight: BushDS.tapMin),
              padding: const EdgeInsets.symmetric(
                  horizontal: BushDS.spLG, vertical: BushDS.spSM),
              decoration: BoxDecoration(
                gradient: AppColors.steelGradient,
                borderRadius: BorderRadius.circular(BushDS.radiusLG),
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app, color: AppColors.accent, size: 18),
                  SizedBox(width: BushDS.spSM),
                  Text(
                    'Tap to chat',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: BushDS.fontMD),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 12),
            const SizedBox(width: BushDS.spXS),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: BushDS.fontXS,
                    letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(height: BushDS.spXS),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionLabel(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.accent, size: 14),
        const SizedBox(width: BushDS.spXS),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: BushDS.fontXS,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  IconData _getWaypointIcon(String? icon) => switch (icon) {
        'camp'   => Icons.holiday_village,
        'water'  => Icons.water_drop,
        'hazard' => Icons.warning_amber_rounded,
        'fuel'   => Icons.local_gas_station,
        'road'   => Icons.route,
        _        => Icons.place,
      };
}
