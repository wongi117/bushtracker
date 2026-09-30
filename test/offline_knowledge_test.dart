// The offline assistant is what answers when there is no signal, which is
// exactly when a wrong answer matters most. These check that the questions
// people actually ask reach the right topic.
import 'package:bush_track/features/ai/services/offline_knowledge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matching a question to a topic', () {
    void expectsTopic(String question, String topic) {
      final match = matchFieldAnswer(question);
      expect(match, isNotNull, reason: '"$question" matched nothing');
      expect(match!.topic, topic, reason: '"$question" went to the wrong topic');
    }

    test('emergencies reach their topic', () {
      expectsTopic('my mate got bitten by a snake', 'Snake bite');
      expectsTopic('snake bite what do i do', 'Snake bite');
      expectsTopic('he is confused and stopped sweating', 'Heat and dehydration');
      expectsTopic("I'm lost and don't know which way to go", 'Lost');
      expectsTopic('the car broke down out here', 'Vehicle breakdown');
      expectsTopic('he is bleeding badly', 'Bleeding');
    });

    test('everyday questions reach their topic', () {
      expectsTopic('how much water do I need a day', 'Water');
      expectsTopic('how do I find north without gps', 'Navigation without GPS');
      expectsTopic('where should I set up camp', 'Shelter');
      expectsTopic('how do I make the battery last', 'Phone and battery');
      expectsTopic('can I eat these berries', 'Food and foraging');
      expectsTopic('there is water over the road', 'Flooded creek crossings');
    });

    test('a more specific phrase beats a single shared word', () {
      // "bite" alone appears in several topics; "snake bite" must win.
      expect(matchFieldAnswer('snake bite')!.topic, 'Snake bite');
      // "redback" is unambiguous even though "bite" is generic.
      expect(matchFieldAnswer('redback bite on my hand')!.topic,
          'Spiders, scorpions and insects');
    });

    test('an unrelated question matches nothing rather than guessing', () {
      expect(matchFieldAnswer('what is the capital of France'), isNull);
      expect(matchFieldAnswer('tell me a joke'), isNull);
    });
  });

  group('safety content', () {
    FieldAnswer topic(String name) =>
        kFieldKnowledge.firstWhere((e) => e.topic == name);

    test('snake bite gives the Australian advice, not the folklore', () {
      final text = topic('Snake bite').answer.toLowerCase();
      expect(text, contains('pressure immobilisation'));
      expect(text, contains('do not cut'));
      expect(text, contains('do not suck'));
      expect(text, contains('do not use a tourniquet'));
      expect(text, contains('still'));
    });

    test('burns say twenty minutes of water and nothing else on it', () {
      final text = topic('Burns').answer.toLowerCase();
      expect(text, contains('20 minutes'));
      expect(text, contains('not ice'));
      expect(text, contains('not butter'));
    });

    test('breakdown advice is to stay with the vehicle', () {
      expect(topic('Vehicle breakdown').answer.toLowerCase(),
          contains('stay with the vehicle'));
    });

    test('foraging refuses to guess at unfamiliar plants', () {
      expect(topic('Food and foraging').answer.toLowerCase(),
          contains('do not experiment'));
    });

    test('every topic has real content, not a one-liner', () {
      for (final entry in kFieldKnowledge) {
        expect(entry.answer.length, greaterThan(200),
            reason: '${entry.topic} is too thin to be useful offline');
        expect(entry.keywords, isNotEmpty, reason: '${entry.topic} is unreachable');
      }
    });
  });

  group('the offline answer itself', () {
    test('an unmatched question offers what it does know', () {
      final answer = buildOfflineAnswer('what is the capital of France');
      expect(answer, contains("I'm offline"));
      expect(answer, contains('Snake bite'));
    });

    test('the position is appended when it is known', () {
      final answer = buildOfflineAnswer(
        'how much water do I need',
        {'latitude': -28.8833, 'longitude': 121.3333},
      );
      expect(answer, contains('4-6 litres'));
      expect(answer, contains('-28.88330'));
      expect(answer, contains('121.33330'));
    });

    test('no position means no made-up position', () {
      final answer = buildOfflineAnswer('how much water do I need');
      expect(answer, isNot(contains('Your position right now')));
    });
  });
}
