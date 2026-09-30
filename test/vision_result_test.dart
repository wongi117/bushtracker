// Camera identification is safety-critical: a plant wrongly shown as benign
// could get someone poisoned. These pin down how a model's reply is read.
import 'package:bush_track/features/ai/services/vision_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reading a reply', () {
    test('a full result comes through intact', () {
      final result = IdentifyResult.fromJson({
        'mode': 'plant',
        'name': 'Solanum centrale',
        'alsoKnownAs': 'Bush tomato, kutjera',
        'confidence': 'medium',
        'summary': 'A small shrub of the arid interior.',
        'safety': 'caution',
        'safetyNote': 'Several Solanum species in the same country are toxic.',
        'notes': ['Check the fruit colour', 'Compare the leaf shape'],
        'provider': 'Claude Sonnet 5',
      });

      expect(result.mode, IdentifyMode.plant);
      expect(result.name, 'Solanum centrale');
      expect(result.confidence, IdentifyConfidence.medium);
      expect(result.safety, IdentifySafety.caution);
      expect(result.notes, hasLength(2));
      expect(result.isUnclear, isFalse);
    });

    test('an unusable photo is reported as unclear, not guessed at', () {
      final result = IdentifyResult.fromJson({
        'mode': 'rock',
        'name': 'Unclear',
        'confidence': 'low',
        'safety': 'not-applicable',
      });

      expect(result.isUnclear, isTrue);
      expect(result.confidence, IdentifyConfidence.low);
    });

    test('a missing name is unclear rather than blank', () {
      expect(IdentifyResult.fromJson({'mode': 'rock'}).name, 'Unclear');
      expect(IdentifyResult.fromJson({'mode': 'rock', 'name': '  '}).name,
          'Unclear');
    });

    test('an unrecognised confidence falls to low, never to high', () {
      for (final value in ['certain', 'very high', '', null, 'HIGH']) {
        final result =
            IdentifyResult.fromJson({'mode': 'rock', 'confidence': value});
        expect(result.confidence, IdentifyConfidence.low,
            reason: 'confidence "$value" must not be trusted upward');
      }
    });
  });

  group('safety mapping', () {
    IdentifySafety safetyOf(String? raw) =>
        IdentifyResult.fromJson({'mode': 'plant', 'safety': raw}).safety;

    test('known verdicts map across', () {
      expect(safetyOf('toxic'), IdentifySafety.toxic);
      expect(safetyOf('irritant'), IdentifySafety.irritant);
      expect(safetyOf('caution'), IdentifySafety.caution);
      expect(safetyOf('hazard'), IdentifySafety.hazard);
      expect(safetyOf('not-applicable'), IdentifySafety.notApplicable);
    });

    test('anything unexpected becomes unknown, never permissive', () {
      // A model inventing "safe" or "edible" must not produce a value the UI
      // would treat as reassuring. There is deliberately no safe option.
      for (final raw in ['safe', 'edible', 'fine', 'ok', '', null, 'SAFE']) {
        expect(safetyOf(raw), IdentifySafety.unknown,
            reason: '"$raw" must not read as safe');
      }
    });

    test('the dangerous verdicts are the ones flagged as warnings', () {
      expect(IdentifySafety.toxic.isWarning, isTrue);
      expect(IdentifySafety.irritant.isWarning, isTrue);
      expect(IdentifySafety.hazard.isWarning, isTrue);
      expect(IdentifySafety.unknown.isWarning, isFalse);
      expect(IdentifySafety.notApplicable.isWarning, isFalse);
    });
  });

  group('handing the result to the assistant', () {
    test('the prompt carries what was found so the chat can continue', () {
      final prompt = IdentifyResult.fromJson({
        'mode': 'rock',
        'name': 'Banded iron formation',
        'confidence': 'high',
        'summary': 'Alternating iron oxide and chert bands.',
        'safety': 'hazard',
        'safetyNote': 'Sharp fracture edges.',
        'notes': ['Common through the Yilgarn'],
      }).toPrompt();

      expect(prompt, contains('Banded iron formation'));
      expect(prompt, contains('high'));
      expect(prompt, contains('Sharp fracture edges'));
      expect(prompt, contains('Common through the Yilgarn'));
    });
  });
}
