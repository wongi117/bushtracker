import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bush_track/features/files/providers/files_provider.dart';
import 'package:bush_track/theme/app_colors.dart';

/// What the photo should be saved as.
class PhotoPinDetails {
  const PhotoPinDetails({
    required this.name,
    this.notes,
    this.fileId,
  });

  final String name;
  final String? notes;

  /// The file to put it in, or null for none.
  final int? fileId;
}

/// Name and describe a photo before it becomes a pin.
///
/// Photos used to save straight to the map as "Photo 14:32" with no
/// description and no say in where they were filed — which is fine at the
/// moment you take it and useless a week later when you are looking for the
/// shaft you photographed.
Future<PhotoPinDetails?> showPhotoPinSheet(
  BuildContext context, {
  required Uint8List photo,
  required String positionLabel,
  String? accuracyLabel,
}) {
  return showModalBottomSheet<PhotoPinDetails>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PhotoPinSheet(
      photo: photo,
      positionLabel: positionLabel,
      accuracyLabel: accuracyLabel,
    ),
  );
}

class _PhotoPinSheet extends ConsumerStatefulWidget {
  const _PhotoPinSheet({
    required this.photo,
    required this.positionLabel,
    this.accuracyLabel,
  });

  final Uint8List photo;
  final String positionLabel;
  final String? accuracyLabel;

  @override
  ConsumerState<_PhotoPinSheet> createState() => _PhotoPinSheetState();
}

class _PhotoPinSheetState extends ConsumerState<_PhotoPinSheet> {
  final _name = TextEditingController();
  final _notes = TextEditingController();

  /// Starts on whichever file is open, which is usually the right answer.
  int? _fileId;
  bool _pickedFile = false;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(filesProvider).files;
    if (!_pickedFile) {
      _fileId = ref.read(filesProvider).activeFileId;
      _pickedFile = true;
    }

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
              const SizedBox(height: 14),

              // The photo itself, so it is obvious which one is being saved.
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  widget.photo,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.accuracyLabel == null
                    ? widget.positionLabel
                    : '${widget.positionLabel}  ·  ${widget.accuracyLabel}',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: _field('Name', 'Old shaft, rock face, damaged gate'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white),
                decoration: _field('Description',
                    'What it is, why it matters, what needs doing'),
              ),

              if (files.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text('FILE',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _fileChip('None', _fileId == null,
                        () => setState(() => _fileId = null)),
                    ...files.map((f) => _fileChip(
                          f.name,
                          _fileId == f.id,
                          () => setState(() => _fileId = f.id),
                        )),
                  ],
                ),
              ],

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
                      label: const Text('SAVE PIN',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      onPressed: () {
                        final name = _name.text.trim();
                        final notes = _notes.text.trim();
                        Navigator.pop(
                          context,
                          PhotoPinDetails(
                            // An unnamed photo still needs something to find
                            // it by in a list.
                            name: name.isEmpty ? 'Photo pin' : name,
                            notes: notes.isEmpty ? null : notes,
                            fileId: _fileId,
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

  Widget _fileChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.25)
                : AppColors.panelLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppColors.accent : AppColors.panelHighlight,
                width: selected ? 2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  selected
                      ? Icons.folder_open_rounded
                      : Icons.folder_rounded,
                  size: 14,
                  color: selected ? AppColors.accent : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

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
