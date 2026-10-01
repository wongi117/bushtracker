import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// What kind of thing a result is.
enum SearchKind {
  pin,
  waypoint,
  boundary,
  track,
  file,
  note;

  String get label => switch (this) {
        SearchKind.pin => 'Pin',
        SearchKind.waypoint => 'Waypoint',
        SearchKind.boundary => 'Boundary',
        SearchKind.track => 'Track',
        SearchKind.file => 'Project',
        SearchKind.note => 'Note',
      };

  /// The chip that selects this kind, plural.
  String get plural => switch (this) {
        SearchKind.pin => 'Pins',
        SearchKind.waypoint => 'Waypoints',
        SearchKind.boundary => 'Boundaries',
        SearchKind.track => 'Tracks',
        SearchKind.file => 'Projects',
        SearchKind.note => 'Notes',
      };
}

/// How to order results.
enum SearchSort { relevance, name, date, distance }

/// One thing the search found.
class SearchHit {
  const SearchHit({
    required this.kind,
    required this.id,
    required this.title,
    required this.score,
    this.subtitle,
    this.position,
    this.colorHex,
    this.date,
    this.fileId,
    this.matchedField,
  });

  final SearchKind kind;
  final int id;
  final String title;
  final String? subtitle;
  final LatLng? position;
  final String? colorHex;
  final DateTime? date;
  final int? fileId;

  /// Higher is a better match.
  final double score;

  /// Which field the query actually hit, so the list can say why a result is
  /// there when the name alone does not explain it.
  final String? matchedField;

  SearchHit withScore(double s) => SearchHit(
        kind: kind,
        id: id,
        title: title,
        subtitle: subtitle,
        position: position,
        colorHex: colorHex,
        date: date,
        fileId: fileId,
        score: s,
        matchedField: matchedField,
      );
}

/// Searching what is in Files, offline.
///
/// Everything happens over lists already in memory — no index, no network, no
/// database round trip — because the whole point of this app is that it works
/// with no signal, and a search that needs a server is a search that does not
/// work when it is needed.
class FieldSearch {
  const FieldSearch._();

  /// Score a query against one piece of text. 0 means no match.
  ///
  /// Graded rather than yes/no, so the ranking can put the obvious answer at
  /// the top: the whole field matching beats the start of it, which beats a
  /// word inside it, which beats a near-miss spelling.
  static double scoreText(String query, String? text) {
    if (text == null) return 0;
    final q = query.trim().toLowerCase();
    final t = text.trim().toLowerCase();
    if (q.isEmpty || t.isEmpty) return 0;

    if (t == q) return 100;
    if (t.startsWith(q)) return 80;

    // At a word boundary reads as a real match; mid-word is weaker.
    final words = t.split(RegExp(r'[\s,\-_/]+'));
    if (words.any((w) => w == q)) return 75;
    if (words.any((w) => w.startsWith(q))) return 65;
    if (t.contains(q)) return 45;

    // Near-miss spelling, for a word long enough that a typo is likelier than
    // a coincidence. "shaft" finds "shatf"; two letters out of four would
    // match almost anything, so short words are left alone.
    if (q.length >= 4) {
      for (final w in words) {
        if (w.length < 3) continue;
        final d = _editDistance(q, w, max: 2);
        if (d == 1) return 35;
        if (d == 2 && q.length >= 6) return 25;
      }
    }

    return 0;
  }

  /// The best score across several fields, and which one it was.
  static ({double score, String? field}) scoreFields(
      String query, Map<String, String?> fields) {
    var best = 0.0;
    String? bestField;
    for (final entry in fields.entries) {
      final s = scoreText(query, entry.value);
      if (s > best) {
        best = s;
        bestField = entry.key;
      }
    }
    return (score: best, field: bestField);
  }

  /// Edit distance that counts a transposition as one mistake, not two.
  ///
  /// Plain Levenshtein charges two edits for swapping a pair of letters, which
  /// is the single commonest way to mistype a word: "shatf" for "shaft" scored
  /// the same as two unrelated errors and fell outside the tolerance, so the
  /// one typo the feature most needed to forgive was the one it did not. This
  /// is restricted Damerau-Levenshtein, which charges one.
  ///
  /// Abandoned once it passes [max]. It runs against every word of every
  /// record on every keystroke, and "further than two" is as useful an answer
  /// as the exact number for a fraction of the work.
  static int _editDistance(String a, String b, {int max = 2}) {
    if ((a.length - b.length).abs() > max) return max + 1;
    if (a == b) return 0;

    // Three rows, because a transposition looks two back.
    var twoBack = <int>[];
    var previous = List<int>.generate(b.length + 1, (i) => i);

    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      var rowBest = current[0];

      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var best = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );

        // The two letters are each other's, the wrong way round.
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          best = math.min(best, twoBack[j - 2] + 1);
        }

        current[j] = best;
        if (best < rowBest) rowBest = best;
      }

      if (rowBest > max) return max + 1;
      twoBack = previous;
      previous = current;
    }
    return previous[b.length];
  }

  /// Order results, and break ties sensibly.
  ///
  /// Relevance first by default. The other orders still fall back to relevance
  /// for equal keys, so a list sorted by name does not shuffle between
  /// keystrokes.
  static List<SearchHit> sortHits(
    List<SearchHit> hits,
    SearchSort sort, {
    LatLng? from,
  }) {
    final sorted = [...hits];
    switch (sort) {
      case SearchSort.relevance:
        sorted.sort((a, b) {
          final byScore = b.score.compareTo(a.score);
          return byScore != 0
              ? byScore
              : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      case SearchSort.name:
        sorted.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case SearchSort.date:
        sorted.sort((a, b) {
          final ad = a.date;
          final bd = b.date;
          // Undated things go last rather than pretending to be the oldest.
          if (ad == null && bd == null) return b.score.compareTo(a.score);
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });
      case SearchSort.distance:
        if (from == null) return sortHits(hits, SearchSort.relevance);
        const d = Distance();
        sorted.sort((a, b) {
          final ap = a.position;
          final bp = b.position;
          // Same reasoning: no position means no place in a distance order.
          if (ap == null && bp == null) return b.score.compareTo(a.score);
          if (ap == null) return 1;
          if (bp == null) return -1;
          return d(from, ap).compareTo(d(from, bp));
        });
    }
    return sorted;
  }
}
