import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/services/heading/heading_reading.dart';
import 'package:bush_track/features/files/providers/files_provider.dart';
import 'package:bush_track/theme/app_colors.dart';

class DistantPinDetails {
  const DistantPinDetails({
    required this.name,
    this.notes,
    this.colorHex = WaypointColors.emberOrange,
    this.icon = WaypointIcon.pin,
  });

  final String name;
  final String? notes;
  final String colorHex;
  final String icon;
}

/// Name a pin dropped somewhere you are looking at but not standing on.
///
/// It leads with how far away and which way, because that is the part worth
/// checking: the position came from where the camera was pointed and how the
/// phone was tilted, so a wildly wrong distance is the tell that the compass
/// needs calibrating or the aim was above the ground.
Future<DistantPinDetails?> showDistantPinSheet(
  BuildContext context, {
  required double distanceM,
  required double bearingDeg,
  required LatLng position,
}) {
  return showModalBottomSheet<DistantPinDetails>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _DistantPinSheet(
      distanceM: distanceM,
      bearingDeg: bearingDeg,
      position: position,
    ),
  );
}

class _DistantPinSheet extends ConsumerStatefulWidget {
  const _DistantPinSheet({
    required this.distanceM,
    required this.bearingDeg,
    required this.position,
  });

  final double distanceM;
  final double bearingDeg;
  final LatLng position;

  @override
  ConsumerState<_DistantPinSheet> createState() => _DistantPinSheetState();
}

class _DistantPinSheetState extends ConsumerState<_DistantPinSheet> {
  final _name = TextEditingController();
  final _notes = TextEditingController();

  static const List<({String label, String icon, String colour})> _kinds = [
    (label: 'Point', icon: 'pin', colour: '#FF6B35'),
    (label: 'Camp', icon: 'camp', colour: '#00FF88'),
    (label: 'Water', icon: 'water', colour: '#00E5FF'),
    (label: 'Hazard', icon: 'hazard', colour: '#FF2D55'),
  ];
  int _kind = 0;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final openFile = ref.watch(filesProvider).activeFile;
    final cardinal = HeadingReading(
      degrees: widget.bearingDeg,
      quality: HeadingQuality.good,
      source: HeadingSourceKind.sensors,
    ).cardinal;

    final away = widget.distanceM >= 1000
        ? '${(widget.distanceM / 1000).toStringAsFixed(2)} km'
        : '${widget.distanceM.round()} m';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.panelMatte,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        // 18 plus the system navigation bar. viewInsets above handles the
        // keyboard; viewPadding here handles the bar, and a sheet that only
        // did the first drew its buttons underneath the second.
        padding: EdgeInsets.fromLTRB(
            18, 10, 18, 18 + MediaQuery.of(context).viewPadding.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.panelHighlight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('PIN OUT THERE',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.straighten,
                    size: 15, color: AppColors.accentLight),
                const SizedBox(width: 6),
                Text('$away away, $cardinal',
                    style: const TextStyle(
                        color: AppColors.accentLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 2),
              Text(
                '${widget.position.latitude.toStringAsFixed(5)}, '
                '${widget.position.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              if (openFile != null) ...[
                const SizedBox(height: 4),
                Text('Filing under ${openFile.name}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: _field('Name', 'Big gum, creek crossing, gate'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: _field('Description', 'What it is, why it matters'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < _kinds.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _kind = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _kind == i
                              ? WaypointColors.fromHex(_kinds[i].colour)
                                  .withValues(alpha: 0.25)
                              : AppColors.panelLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _kind == i
                                  ? WaypointColors.fromHex(_kinds[i].colour)
                                  : AppColors.panelHighlight,
                              width: _kind == i ? 2 : 1),
                        ),
                        child: Text(_kinds[i].label,
                            style: TextStyle(
                                color: _kind == i
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.push_pin, size: 18),
                      label: const Text('DROP PIN',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      onPressed: () {
                        final name = _name.text.trim();
                        final notes = _notes.text.trim();
                        Navigator.pop(
                          context,
                          DistantPinDetails(
                            name: name.isEmpty ? _kinds[_kind].label : name,
                            notes: notes.isEmpty ? null : notes,
                            colorHex: _kinds[_kind].colour,
                            icon: _kinds[_kind].icon,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _field(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.panelLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      );
}
