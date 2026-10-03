import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/widgets/safe_sheet.dart';
import 'package:bush_track/features/files/providers/files_provider.dart';
import 'package:bush_track/features/map/widgets/color_picker.dart';
import 'package:bush_track/theme/app_colors.dart';

/// Rename a project, give it a colour, or put it away.
///
/// One sheet for all three because they are the same errand -- tidying up a
/// project you already have -- and three separate menu items for it would be
/// three taps deep on a phone held in one hand.
Future<void> showProjectEditSheet(
  BuildContext context,
  FieldFile file,
) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProjectEditSheet(file: file),
    );

class _ProjectEditSheet extends ConsumerStatefulWidget {
  const _ProjectEditSheet({required this.file});

  final FieldFile file;

  @override
  ConsumerState<_ProjectEditSheet> createState() => _ProjectEditSheetState();
}

class _ProjectEditSheetState extends ConsumerState<_ProjectEditSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.file.name);
  late String? _colour = widget.file.colour;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _nameIsUsable => _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_nameIsUsable || _saving) return;
    setState(() => _saving = true);

    // clearColour rather than rebuilding the object: a null colour through
    // copyWith means "leave it alone", and constructing a replacement by hand
    // is how a field gets quietly dropped the next time one is added.
    final next = widget.file.copyWith(
      name: _name.text.trim(),
      colour: _colour,
      clearColour: _colour == null,
    );

    await ref.read(filesProvider.notifier).updateFile(next);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleArchived() async {
    final file = widget.file;
    final restoring = file.isArchived;

    await ref.read(filesProvider.notifier).updateFile(
          restoring
              ? file.copyWith(clearArchived: true)
              : file.copyWith(archivedAt: DateTime.now()),
        );

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(restoring
          ? '${file.name} is back in the list'
          : '${file.name} archived'),
      action: SnackBarAction(
        // An undo, because archiving by accident from a menu is easy and the
        // project drops out of the list immediately, which looks like a
        // delete.
        label: 'UNDO',
        onPressed: () => ref.read(filesProvider.notifier).updateFile(
              restoring
                  ? file.copyWith(archivedAt: DateTime.now())
                  : file.copyWith(clearArchived: true),
            ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;

    return SafeSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetGrip(),
          const SizedBox(height: 14),
          Text(
            file.isArchived ? 'ARCHIVED PROJECT' : 'EDIT PROJECT',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: false,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('Name', 'Kookynie survey'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 20),
          const Text('COLOUR',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(
            _colour == null
                ? 'Default'
                : WaypointColors.names[_colour] ?? 'Custom',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 10),
          // Horizontally scrollable: ten swatches plus the clear one do not fit
          // across a 360 px phone, and a wrapped grid pushes the buttons off
          // the bottom of the sheet.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: CompactColorPicker(
              selectedColor: _colour,
              // The pin palette, not the trail one, so a project and the pins
              // filed under it can be given the same colour.
              palette: WaypointColors.allColors,
              allowNone: true,
              onCleared: () => setState(() => _colour = null),
              onColorSelected: (c) => setState(() => _colour = c),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              TextButton.icon(
                onPressed: _toggleArchived,
                icon: Icon(
                    file.isArchived
                        ? Icons.unarchive_rounded
                        : Icons.archive_rounded,
                    size: 17,
                    color: AppColors.textSecondary),
                label: Text(file.isArchived ? 'Restore' : 'Archive',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: _nameIsUsable && !_saving ? _save : null,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black),
                child: const Text('SAVE',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          if (file.isArchived) ...[
            const SizedBox(height: 10),
            const Text(
              'Archived projects stay on the map and keep everything filed '
              'under them. They are just out of the list.',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      );
}
