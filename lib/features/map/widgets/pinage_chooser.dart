import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Shown on map long-press. Two cards side-by-side.
/// Swipe left or tap the left card → Normal Pin.
/// Swipe right or tap the right card → Pinage (media-rich pin).
void showPinageChooser(
  BuildContext context, {
  required LatLng position,
  required VoidCallback onNormalPin,
  required VoidCallback onPinage,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _PinageChooserSheet(
      onNormalPin: onNormalPin,
      onPinage: onPinage,
    ),
  );
}

class _PinageChooserSheet extends StatefulWidget {
  final VoidCallback onNormalPin;
  final VoidCallback onPinage;
  const _PinageChooserSheet({required this.onNormalPin, required this.onPinage});

  @override
  State<_PinageChooserSheet> createState() => _PinageChooserSheetState();
}

class _PinageChooserSheetState extends State<_PinageChooserSheet> {
  // 0 = neutral, -1 = left (pin) hovered, 1 = right (pinage) hovered
  int _hover = 0;
  double _dragDelta = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        setState(() => _dragDelta += d.delta.dx);
        if (_dragDelta < -40) {
          Navigator.pop(context);
          widget.onNormalPin();
        } else if (_dragDelta > 40) {
          Navigator.pop(context);
          widget.onPinage();
        }
      },
      onHorizontalDragEnd: (_) => setState(() => _dragDelta = 0),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0F1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'What are you pinning?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Swipe left for a quick pin  ·  Swipe right for a photo story',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // ── Normal Pin ────────────────────────────────────────────
                Expanded(
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hover = -1),
                    onExit: (_) => setState(() => _hover = 0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onNormalPin();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _hover == -1
                              ? const Color(0xFF2196F3).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _hover == -1
                                ? const Color(0xFF2196F3)
                                : Colors.white.withValues(alpha: 0.12),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Color(0xFF2196F3),
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Normal Pin',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Name, notes\n& category',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_back, color: Color(0xFF2196F3), size: 14),
                                SizedBox(width: 4),
                                Text('swipe left', style: TextStyle(color: Color(0xFF2196F3), fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // ── Pinage ────────────────────────────────────────────────
                Expanded(
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hover = 1),
                    onExit: (_) => setState(() => _hover = 0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onPinage();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _hover == 1
                              ? const Color(0xFFFFB300).withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _hover == 1
                                ? const Color(0xFFFFB300)
                                : Colors.white.withValues(alpha: 0.12),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.photo_camera_rounded,
                                color: Color(0xFFFFB300),
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Pinage',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Photos, story\n& memories',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('swipe right', style: TextStyle(color: Color(0xFFFFB300), fontSize: 11)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward, color: Color(0xFFFFB300), size: 14),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
