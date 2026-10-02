import 'package:flutter/material.dart';

import 'package:bush_track/core/services/tile_cache.dart';
import 'package:bush_track/theme/app_colors.dart';

/// The map cache's size, and a way to empty it.
///
/// Worded carefully. This is next to "Offline Map Regions" in settings, and the
/// two are easy to confuse — one of them means imagery still works with no
/// signal and the other does not. Someone who clears this expecting their
/// downloaded regions to survive must be right, and someone who relies on this
/// for a trip out bush must be told plainly that they cannot.
class TileCacheTile extends StatefulWidget {
  const TileCacheTile({super.key});

  @override
  State<TileCacheTile> createState() => _TileCacheTileState();
}

class _TileCacheTileState extends State<TileCacheTile> {
  int? _bytes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    final bytes = await TileCache.instance.currentBytes();
    if (!mounted) return;
    setState(() => _bytes = bytes);
  }

  Future<void> _clear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.panelMatte,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        title: const Text('Clear map cache?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'Frees the space and nothing else. Your downloaded offline regions, '
          'pins, photos and projects are untouched.\n\n'
          'The map will be a little slower, and will re-download tiles, until '
          'it fills again.',
          style:
              TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child:
                const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('CLEAR',
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;

    setState(() => _busy = true);
    await TileCache.instance.clear();
    if (!mounted) return;
    setState(() => _busy = false);
    await _measure();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final used = bytes == null ? '…' : TileCache.humanBytes(bytes);
    final cap = TileCache.humanBytes(TileCache.maxBytes);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelMatte,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: const Icon(Icons.layers_clear,
            color: AppColors.accent, size: 22),
        title: const Text('Map Cache',
            style: TextStyle(color: Colors.white)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$used of $cap used',
                style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 12)),
            const SizedBox(height: 2),
            // The distinction that matters, said out loud rather than left to
            // be inferred from the word "cache".
            Text('Speeds the map up and saves data. Not offline maps — '
                'use Offline Map Regions for that.',
                style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.9),
                    fontSize: 10.5,
                    height: 1.3)),
          ],
        ),
        trailing: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent),
              )
            : TextButton(
                onPressed: (bytes ?? 0) == 0 ? null : _clear,
                child: Text('CLEAR',
                    style: TextStyle(
                        color: (bytes ?? 0) == 0
                            ? AppColors.textMuted
                            : AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
      ),
    );
  }
}
