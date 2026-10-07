import 'package:sqflite_common/sqlite_api.dart';

/// Reading rows that may be too big for Android to hand back.
///
/// Android returns a query's rows through a CursorWindow of about 2 MB, and a
/// row bigger than that cannot be returned at all: the whole query throws
/// "Row too big to fit into CursorWindow". Photos were stored inside the
/// waypoint row as base64, 217-417 KB each, and on the test phone one pin
/// passed the limit during a drive. From then on:
///
///  * `SELECT * FROM waypoints` threw, so no waypoint loaded -- every pin
///    vanished from the map because of one;
///  * the photo migration, which exists to shrink exactly that row, threw on
///    its first query, so it could never fix it, on any launch.
///
/// The data was intact. It only had to be read in pieces small enough to fit,
/// which SQLite's `substr` allows. This does that, for the columns that can
/// grow: oversized values come back as NULL in the main query, then each one
/// is fetched in slices and put back. The caller gets the same rows it would
/// have got from a plain query.
///
/// Desktop and test SQLite have no such window, so the failure cannot be
/// reproduced off the phone; tests pass a tiny [limit] to drive the same path.
class OversizeRows {
  const OversizeRows._();

  /// Characters of one column fetched in one go. Base64 and JSON are ASCII,
  /// so this is bytes too; two such columns and the rest of a row stay well
  /// inside 2 MB.
  static const int defaultLimit = 256 * 1024;

  /// `query`, with [bigColumns] read safely however large they are.
  ///
  /// [columns] null means every column, as a plain query would. [idColumn] is
  /// the integer key used to go back for the oversized values.
  static Future<List<Map<String, dynamic>>> query(
    DatabaseExecutor db,
    String table, {
    required List<String> bigColumns,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    String idColumn = 'id',
    int limit = defaultLimit,
  }) async {
    final all = columns ??
        [
          for (final c in await db.rawQuery('PRAGMA table_info("$table")'))
            c['name'] as String,
        ];
    final big = bigColumns.where(all.contains).toList();
    final small = all.where((c) => !big.contains(c)).toList();
    final needId = !all.contains(idColumn);

    final select = [
      for (final c in small) '"$c"',
      if (needId) '"$idColumn"',
      for (final c in big) ...[
        'CASE WHEN length("$c") > $limit THEN NULL ELSE "$c" END AS "$c"',
        'length("$c") AS "${_lenKey(c)}"',
      ],
    ].join(', ');

    final rows = await db.rawQuery(
      'SELECT $select FROM "$table"'
      '${where == null ? '' : ' WHERE $where'}'
      '${orderBy == null ? '' : ' ORDER BY $orderBy'}',
      whereArgs,
    );

    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final m = Map<String, dynamic>.from(row);
      for (final c in big) {
        final len = m.remove(_lenKey(c));
        if (len is int && len > limit) {
          m[c] = await readText(db, table, c, m[idColumn] as int,
              idColumn: idColumn, limit: limit);
        }
      }
      if (needId) m.remove(idColumn);
      out.add(m);
    }
    return out;
  }

  /// One TEXT value, fetched [limit] characters at a time.
  static Future<String?> readText(
    DatabaseExecutor db,
    String table,
    String column,
    int id, {
    String idColumn = 'id',
    int limit = defaultLimit,
  }) async {
    final lenRows = await db.rawQuery(
        'SELECT length("$column") AS n FROM "$table" WHERE "$idColumn" = ?',
        [id]);
    if (lenRows.isEmpty) return null;
    final n = lenRows.first['n'];
    if (n is! int) return null;

    final buffer = StringBuffer();
    // substr is 1-based and counts characters, as length does.
    for (var start = 1; start <= n; start += limit) {
      final part = await db.rawQuery(
        'SELECT substr("$column", ?, ?) AS s FROM "$table" '
        'WHERE "$idColumn" = ?',
        [start, limit, id],
      );
      buffer.write(part.first['s'] as String? ?? '');
    }
    final text = buffer.toString();
    // A short read would hand back a truncated JSON list: silently fewer
    // photos. Refuse it rather than return something that looks fine.
    if (text.length != n) {
      throw StateError('Read $column of $table $id in pieces and got '
          '${text.length} of $n characters');
    }
    return text;
  }

  static String _lenKey(String column) => '__len_$column';
}
