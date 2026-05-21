import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:image/image.dart' as img;
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';

/// Opens the Pinage editor as a bottom sheet.
void showPinageEditor(
  BuildContext context, {
  required LatLng position,
  Waypoint? existing,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0F1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: PinageEditorSheet(position: position, existing: existing),
    ),
  );
}

class PinageEditorSheet extends ConsumerStatefulWidget {
  final LatLng position;
  final Waypoint? existing;

  const PinageEditorSheet({required this.position, this.existing, super.key});

  @override
  ConsumerState<PinageEditorSheet> createState() => _PinageEditorSheetState();
}

class _PinageEditorSheetState extends ConsumerState<PinageEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _storyCtrl;
  final List<String> _media = []; // base64 data URIs
  final ImagePicker _picker = ImagePicker();
  bool _saving = false;
  bool _pickingImages = false;

  @override
  void initState() {
    super.initState();
    final w = widget.existing;
    _nameCtrl = TextEditingController(text: w?.label ?? '');
    _storyCtrl = TextEditingController(text: w?.notes ?? '');
    if (w?.photoPaths != null) _media.addAll(w!.photoPaths!);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _storyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_pickingImages) return;
    setState(() => _pickingImages = true);
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 80);
      if (picked.isEmpty) return;
      for (final xfile in picked) {
        final raw = await xfile.readAsBytes();
        final compressed = await _compress(raw);
        if (compressed != null) {
          setState(() => _media.add('data:image/jpeg;base64,${base64Encode(compressed)}'));
        }
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    } finally {
      setState(() => _pickingImages = false);
    }
  }

  Future<Uint8List?> _compress(Uint8List raw) async {
    try {
      final decoded = img.decodeImage(raw);
      if (decoded == null) return null;
      // Resize to max 900px wide, keeping aspect ratio
      final resized = decoded.width > 900
          ? img.copyResize(decoded, width: 900)
          : decoded;
      return Uint8List.fromList(img.encodeJpg(resized, quality: 72));
    } catch (e) {
      debugPrint('Compress error: $e');
      return null;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final lat = widget.existing?.latitude ?? widget.position.latitude;
    final lon = widget.existing?.longitude ?? widget.position.longitude;
    final name = _nameCtrl.text.trim().isEmpty ? 'Pinage' : _nameCtrl.text.trim();

    final waypoint = Waypoint(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch,
      latitude: lat,
      longitude: lon,
      timestamp: widget.existing?.timestamp ?? DateTime.now(),
      label: name,
      notes: _storyCtrl.text.trim(),
      type: WaypointType.pinage,
      color: '#FFB300',
      icon: 'pinage',
      isPin: true,
      photoPaths: List<String>.from(_media),
    );

    if (widget.existing != null) {
      await ref.read(locationProvider.notifier).updateWaypoint(waypoint);
    } else {
      await ref.read(locationProvider.notifier).addManualWaypoint(
        lat, lon, name,
        notes: _storyCtrl.text.trim(),
        color: '#FFB300',
        icon: 'pinage',
      );
      // Update the newly saved waypoint with media + pinage type
      final updated = ref.read(locationProvider).waypoints
          .where((w) => w.label == name && w.type == WaypointType.manual)
          .toList();
      if (updated.isNotEmpty) {
        final w = updated.last;
        w.type = WaypointType.pinage;
        w.photoPaths = List<String>.from(_media);
        await ref.read(locationProvider.notifier).updateWaypoint(w);
      }
    }

    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.photo_camera_rounded, color: Color(0xFFFFB300), size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              isEditing ? 'Edit Pinage' : 'New Pinage',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white38),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        const Divider(color: Colors.white10, height: 20),

        // ── Scrollable form ──────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).padding.bottom + 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                _label('Name'),
                const SizedBox(height: 8),
                _textField(_nameCtrl, 'What is this spot?', 1),
                const SizedBox(height: 20),

                // Story
                _label('Story'),
                const SizedBox(height: 8),
                _textField(_storyCtrl, 'What happened here? Why did you pin this?\nAdd as much detail as you like…', 5),
                const SizedBox(height: 20),

                // Photos
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _label('Photos  (${_media.length})'),
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (_pickingImages)
                            const SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFB300)),
                            )
                          else
                            const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFFFFB300), size: 15),
                          const SizedBox(width: 6),
                          Text(
                            _pickingImages ? 'Loading…' : 'Add Photos',
                            style: const TextStyle(color: Color(0xFFFFB300), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_media.isEmpty)
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate, color: Colors.white24, size: 32),
                            SizedBox(height: 8),
                            Text('Tap to add photos', style: TextStyle(color: Colors.white24, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _media.length + 1,
                      itemBuilder: (_, i) {
                        if (i == _media.length) {
                          // Add more button
                          return GestureDetector(
                            onTap: _pickImages,
                            child: Container(
                              width: 90,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB300).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.3)),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, color: Color(0xFFFFB300), size: 28),
                                  SizedBox(height: 4),
                                  Text('Add', style: TextStyle(color: Color(0xFFFFB300), fontSize: 10)),
                                ],
                              ),
                            ),
                          );
                        }
                        final src = _media[i];
                        return Stack(
                          children: [
                            Container(
                              width: 90,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white10,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildImageThumbnail(src),
                            ),
                            Positioned(
                              top: 4, right: 14,
                              child: GestureDetector(
                                onTap: () => setState(() => _media.removeAt(i)),
                                child: Container(
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 13),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 24),

                // Coords info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.location_on, color: Colors.white24, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.position.latitude.toStringAsFixed(5)}, ${widget.position.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // Save / Cancel
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(child: Text('Cancel', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFFFB300).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  isEditing ? 'Update Pinage' : 'Save Pinage',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8),
      );

  Widget _textField(TextEditingController ctrl, String hint, int maxLines) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), height: 1.5, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildImageThumbnail(String src) {
    try {
      if (src.startsWith('data:')) {
        final b64 = src.split(',').last;
        return Image.memory(
          base64Decode(b64),
          fit: BoxFit.cover,
          width: 90, height: 110,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white24),
        );
      }
      return const Icon(Icons.image, color: Colors.white24);
    } catch (_) {
      return const Icon(Icons.broken_image, color: Colors.white24);
    }
  }
}
