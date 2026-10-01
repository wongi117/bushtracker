// Search has to work with no signal, tolerate a typo, and put the obvious
// answer at the top. These cover the scoring and the ordering; the screen that
// shows them is thin over this.
import 'package:bush_track/features/files/services/field_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('scoring one field', () {
    test('an exact match beats everything', () {
      expect(FieldSearch.scoreText('shaft', 'shaft'),
          greaterThan(FieldSearch.scoreText('shaft', 'old shaft')));
    });

    test('the start of a name beats the middle of it', () {
      final atStart = FieldSearch.scoreText('old', 'old shaft');
      final inMiddle = FieldSearch.scoreText('shaft', 'old shaft north');
      expect(atStart, greaterThan(inMiddle));
    });

    test('a whole word beats part of one', () {
      final whole = FieldSearch.scoreText('shaft', 'old shaft');
      final part = FieldSearch.scoreText('haf', 'old shaft');
      expect(whole, greaterThan(part));
      expect(part, greaterThan(0));
    });

    test('case does not matter', () {
      expect(FieldSearch.scoreText('SHAFT', 'old shaft'),
          FieldSearch.scoreText('shaft', 'OLD SHAFT'));
    });

    test('no match scores nothing', () {
      expect(FieldSearch.scoreText('windmill', 'old shaft'), 0);
    });

    test('an empty query matches nothing rather than everything', () {
      expect(FieldSearch.scoreText('', 'old shaft'), 0);
      expect(FieldSearch.scoreText('   ', 'old shaft'), 0);
    });

    test('a null field is not a match', () {
      expect(FieldSearch.scoreText('shaft', null), 0);
    });

    test('surrounding whitespace is ignored', () {
      expect(FieldSearch.scoreText('  shaft  ', 'shaft'), 100);
    });
  });

  group('tolerating a typo', () {
    test('one letter out still finds it', () {
      expect(FieldSearch.scoreText('shatf', 'old shaft'), greaterThan(0));
      expect(FieldSearch.scoreText('wndmill', 'windmill paddock'),
          greaterThan(0));
    });

    test('but scores below a clean match, so the right one ranks first', () {
      final clean = FieldSearch.scoreText('shaft', 'old shaft');
      final typo = FieldSearch.scoreText('shatf', 'old shaft');
      expect(typo, lessThan(clean));
      expect(typo, greaterThan(0));
    });

    test('short words are not fuzzy-matched', () {
      // Two letters out of four matches almost anything, which turns a search
      // for "dam" into a list of everything.
      expect(FieldSearch.scoreText('dam', 'dim'), 0);
      expect(FieldSearch.scoreText('gate', 'gats'), greaterThan(0));
    });

    test('two letters out needs a longer word to count', () {
      expect(FieldSearch.scoreText('shatf', 'shaft'), greaterThan(0));
      // Six letters or more before two mistakes are forgiven.
      expect(FieldSearch.scoreText('windmil', 'windmill'), greaterThan(0));
    });

    test('a completely different word of the same length is not a match', () {
      expect(FieldSearch.scoreText('creek', 'gorge'), 0);
    });
  });

  group('scoring across fields', () {
    test('the best field wins and is named', () {
      final out = FieldSearch.scoreFields('water', {
        'name': 'Old shaft',
        'notes': 'water 200m east',
      });
      expect(out.score, greaterThan(0));
      expect(out.field, 'notes');
    });

    test('a hit on the name outranks a hit in the notes', () {
      final byName = FieldSearch.scoreFields('shaft', {
        'name': 'Shaft',
        'notes': 'nothing here',
      });
      final byNotes = FieldSearch.scoreFields('shaft', {
        'name': 'Nothing',
        'notes': 'near the old shaft somewhere',
      });
      expect(byName.score, greaterThan(byNotes.score));
    });

    test('nothing matching scores zero and names no field', () {
      final out = FieldSearch.scoreFields('helicopter', {
        'name': 'Old shaft',
        'notes': 'water east',
      });
      expect(out.score, 0);
      expect(out.field, isNull);
    });
  });

  group('ordering', () {
    final here = LatLng(-28.8833, 121.3333);

    List<SearchHit> hits() => [
          SearchHit(
            kind: SearchKind.pin,
            id: 1,
            title: 'Zebra rock',
            score: 45,
            date: DateTime.utc(2026, 1, 1),
            position: const Distance().offset(here, 5000, 90),
          ),
          SearchHit(
            kind: SearchKind.boundary,
            id: 2,
            title: 'Alpha zone',
            score: 80,
            date: DateTime.utc(2026, 6, 1),
            position: const Distance().offset(here, 200, 90),
          ),
          SearchHit(
            kind: SearchKind.track,
            id: 3,
            title: 'Middle run',
            score: 65,
            date: DateTime.utc(2026, 3, 1),
            position: const Distance().offset(here, 1200, 90),
          ),
        ];

    test('relevance puts the best match first', () {
      final out = FieldSearch.sortHits(hits(), SearchSort.relevance);
      expect(out.map((h) => h.id), [2, 3, 1]);
    });

    test('name sorts alphabetically, ignoring case', () {
      final out = FieldSearch.sortHits(hits(), SearchSort.name);
      expect(out.map((h) => h.title), ['Alpha zone', 'Middle run', 'Zebra rock']);
    });

    test('date puts the newest first', () {
      final out = FieldSearch.sortHits(hits(), SearchSort.date);
      expect(out.map((h) => h.id), [2, 3, 1]);
    });

    test('distance puts the nearest first', () {
      final out = FieldSearch.sortHits(hits(), SearchSort.distance, from: here);
      expect(out.map((h) => h.id), [2, 3, 1]);
    });

    test('distance with no fix falls back to relevance, not to nothing', () {
      final out = FieldSearch.sortHits(hits(), SearchSort.distance);
      expect(out.map((h) => h.id), [2, 3, 1]);
    });

    test('things with no position go last in a distance sort', () {
      final list = [
        ...hits(),
        const SearchHit(
            kind: SearchKind.note, id: 9, title: 'A note', score: 70),
      ];
      final out = FieldSearch.sortHits(list, SearchSort.distance, from: here);
      expect(out.last.id, 9);
    });

    test('undated things go last in a date sort', () {
      final list = [
        ...hits(),
        const SearchHit(
            kind: SearchKind.note, id: 9, title: 'A note', score: 99),
      ];
      final out = FieldSearch.sortHits(list, SearchSort.date);
      expect(out.last.id, 9);
    });

    test('equal scores break by name, so the list does not shuffle', () {
      final list = [
        const SearchHit(kind: SearchKind.pin, id: 1, title: 'Beta', score: 50),
        const SearchHit(kind: SearchKind.pin, id: 2, title: 'Alpha', score: 50),
      ];
      final once = FieldSearch.sortHits(list, SearchSort.relevance);
      final twice = FieldSearch.sortHits(list, SearchSort.relevance);
      expect(once.map((h) => h.id), [2, 1]);
      expect(twice.map((h) => h.id), once.map((h) => h.id));
    });

    test('sorting does not modify the list it was given', () {
      final list = hits();
      final before = list.map((h) => h.id).toList();
      FieldSearch.sortHits(list, SearchSort.name);
      expect(list.map((h) => h.id), before);
    });
  });

  group('kinds', () {
    test('every kind has its own singular and plural label', () {
      final singular = SearchKind.values.map((k) => k.label).toSet();
      final plural = SearchKind.values.map((k) => k.plural).toSet();
      expect(singular, hasLength(SearchKind.values.length));
      expect(plural, hasLength(SearchKind.values.length));
    });
  });
}
