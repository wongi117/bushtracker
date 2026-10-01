import 'package:flutter/material.dart';

import 'package:bush_track/features/ai/services/vision_service.dart';
import 'package:bush_track/theme/app_colors.dart';

/// Shows what the camera identification came back with.
///
/// Returns true when the user wants to carry on talking to the assistant
/// about it, so a photo is part of the conversation rather than a dead end.
Future<bool> showIdentifyResult(
  BuildContext context,
  IdentifyResult result,
) async {
  final continued = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.panelMatte,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.panelHighlight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(18, 16, 18,
                    24 + MediaQuery.of(context).viewPadding.bottom),
                children: _buildBody(sheetContext, result),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return continued ?? false;
}

List<Widget> _buildBody(BuildContext context, IdentifyResult result) {
  return [
    Row(
      children: [
        Icon(
          result.mode == IdentifyMode.plant
              ? Icons.local_florist
              : Icons.terrain,
          color: AppColors.accent,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(result.mode.label.toUpperCase(),
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const Spacer(),
        _ConfidenceChip(result.confidence),
      ],
    ),
    const SizedBox(height: 10),
    Text(
      result.name,
      style: const TextStyle(
          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
    ),
    if (result.alsoKnownAs.isNotEmpty) ...[
      const SizedBox(height: 2),
      Text(result.alsoKnownAs,
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontStyle: FontStyle.italic)),
    ],

    // The safety banner comes before anything else worth reading.
    if (result.safety.isWarning || result.safety == IdentifySafety.caution) ...[
      const SizedBox(height: 14),
      _SafetyBanner(result: result),
    ],

    if (result.summary.isNotEmpty) ...[
      const SizedBox(height: 16),
      Text(result.summary,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, height: 1.5)),
    ],

    if (result.notes.isNotEmpty) ...[
      const SizedBox(height: 16),
      ...result.notes.map((note) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 8),
                  child: Icon(Icons.circle, size: 5, color: AppColors.accent),
                ),
                Expanded(
                  child: Text(note,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.45)),
                ),
              ],
            ),
          )),
    ],

    // Fixed, not model-generated. A plant identification must never be the
    // last word before someone eats something, however confident the model
    // sounded — lookalikes are what kill people.
    if (result.mode == IdentifyMode.plant) ...[
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.statusRed.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.statusRed.withValues(alpha: 0.5)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.statusRed, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Never eat a plant on a photo identification. Lookalikes are '
                'what catch people out, and some need preparation to be safe. '
                'Confirm with someone who knows the country.',
                style: TextStyle(
                    color: Colors.white, fontSize: 12, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    ],

    const SizedBox(height: 18),
    Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('DONE'),
            onPressed: () => Navigator.pop(context, false),
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
            icon: const Icon(Icons.forum_rounded, size: 18),
            label: const Text('ASK ABOUT THIS',
                style: TextStyle(fontWeight: FontWeight.w900)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ),
      ],
    ),

    if (result.provider.isNotEmpty) ...[
      const SizedBox(height: 12),
      Center(
        child: Text('Identified by ${result.provider} · a photo is not proof',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ),
    ],
  ];
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip(this.confidence);

  final IdentifyConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final (label, colour) = switch (confidence) {
      IdentifyConfidence.high => ('HIGH CONFIDENCE', AppColors.statusGreen),
      IdentifyConfidence.medium => ('FAIR CONFIDENCE', AppColors.statusYellow),
      IdentifyConfidence.low => ('LOW CONFIDENCE', AppColors.statusRed),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colour.withValues(alpha: 0.6)),
      ),
      child: Text(label,
          style: TextStyle(
              color: colour, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({required this.result});

  final IdentifyResult result;

  @override
  Widget build(BuildContext context) {
    final (label, colour, icon) = switch (result.safety) {
      IdentifySafety.toxic =>
        ('POISONOUS', AppColors.statusRed, Icons.dangerous),
      IdentifySafety.irritant =>
        ('IRRITANT', AppColors.accent, Icons.back_hand),
      IdentifySafety.hazard =>
        ('HANDLING HAZARD', AppColors.accent, Icons.report_problem),
      _ => ('TAKE CARE', AppColors.statusYellow, Icons.warning_amber_rounded),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colour, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colour, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: colour,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
                if (result.safetyNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(result.safetyNote,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
