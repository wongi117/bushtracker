import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:bush_track/core/config/api_config.dart';

/// What the camera was pointed at.
enum IdentifyMode {
  rock('rock', 'Rock & mineral'),
  plant('plant', 'Plant');

  const IdentifyMode(this.id, this.label);
  final String id;
  final String label;
}

/// How much weight to put on the answer.
enum IdentifyConfidence { high, medium, low }

/// The safety verdict. There is deliberately no "safe" value for plants:
/// a photo is not enough to eat something on.
enum IdentifySafety {
  toxic,
  irritant,
  caution,
  hazard,
  unknown,
  notApplicable;

  static IdentifySafety fromId(String? raw) => switch (raw) {
        'toxic' => IdentifySafety.toxic,
        'irritant' => IdentifySafety.irritant,
        'caution' => IdentifySafety.caution,
        'hazard' => IdentifySafety.hazard,
        'not-applicable' => IdentifySafety.notApplicable,
        _ => IdentifySafety.unknown,
      };

  /// Anything that should stop someone in their tracks.
  bool get isWarning =>
      this == IdentifySafety.toxic ||
      this == IdentifySafety.irritant ||
      this == IdentifySafety.hazard;
}

class IdentifyResult {
  const IdentifyResult({
    required this.mode,
    required this.name,
    required this.confidence,
    required this.safety,
    this.alsoKnownAs = '',
    this.summary = '',
    this.safetyNote = '',
    this.notes = const [],
    this.provider = '',
  });

  final IdentifyMode mode;
  final String name;
  final String alsoKnownAs;
  final IdentifyConfidence confidence;
  final String summary;
  final IdentifySafety safety;
  final String safetyNote;
  final List<String> notes;
  final String provider;

  /// True when the model could not make anything of the photo.
  bool get isUnclear => name.trim().toLowerCase() == 'unclear';

  factory IdentifyResult.fromJson(Map<String, dynamic> json) => IdentifyResult(
        mode: json['mode'] == 'plant' ? IdentifyMode.plant : IdentifyMode.rock,
        name: (json['name'] as String?)?.trim().isNotEmpty == true
            ? json['name'] as String
            : 'Unclear',
        alsoKnownAs: json['alsoKnownAs'] as String? ?? '',
        confidence: switch (json['confidence']) {
          'high' => IdentifyConfidence.high,
          'medium' => IdentifyConfidence.medium,
          _ => IdentifyConfidence.low,
        },
        summary: json['summary'] as String? ?? '',
        safety: IdentifySafety.fromId(json['safety'] as String?),
        safetyNote: json['safetyNote'] as String? ?? '',
        notes: (json['notes'] as List?)
                ?.whereType<String>()
                .where((n) => n.trim().isNotEmpty)
                .toList() ??
            const [],
        provider: json['provider'] as String? ?? '',
      );

  /// A plain-text version, for handing the result to the assistant so the
  /// conversation can carry on about it.
  String toPrompt() {
    final buffer = StringBuffer()
      ..writeln('I just photographed something and the identification came '
          'back as:')
      ..writeln('- What: $name${alsoKnownAs.isEmpty ? '' : ' ($alsoKnownAs)'}')
      ..writeln('- Confidence: ${confidence.name}')
      ..writeln('- Type: ${mode.label}');
    if (summary.isNotEmpty) buffer.writeln('- Summary: $summary');
    if (safetyNote.isNotEmpty) buffer.writeln('- Safety: $safetyNote');
    for (final note in notes) {
      buffer.writeln('- $note');
    }
    return buffer.toString();
  }
}

/// Sends a photo away to be identified.
///
/// The request goes through our own /api/vision endpoint so no provider key
/// ever reaches the app. Identification needs a signal — there is no on-device
/// model here, and saying so plainly beats a wrong answer.
class VisionService {
  static String get _url =>
      kIsWeb ? '/api/vision' : '${ApiConfig.proxyBase}/api/vision';

  /// Identifies [jpegBase64], which may be a bare base64 string or a data URI.
  ///
  /// Returns null when identification could not be reached at all, so the
  /// caller can say "no signal" rather than inventing a result.
  Future<IdentifyResult?> identify({
    required IdentifyMode mode,
    required String jpegBase64,
    String? question,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mode': mode.id,
              'image': jpegBase64,
              if (question != null && question.isNotEmpty) 'question': question,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return IdentifyResult.fromJson(decoded);
        }
      }
      debugPrint('Vision failed: ${response.statusCode} '
          '${response.body.substring(0, response.body.length.clamp(0, 200))}');
    } catch (e) {
      debugPrint('Vision error: $e');
    }
    return null;
  }
}
