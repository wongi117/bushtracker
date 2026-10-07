import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/core/services/database_service.dart';
import 'package:bush_track/features/drawing/models/drawing.dart';
import 'package:bush_track/main.dart';

/// Every live drawing, in the order they were made.
class DrawingsNotifier extends StateNotifier<List<Drawing>> {
  DrawingsNotifier(this._db) : super(const []) {
    load();
  }

  final DatabaseService _db;

  Future<void> load() async {
    try {
      final rows = await _db.getDrawings();
      if (!mounted) return;
      state = rows.map(Drawing.fromMap).toList();
    } catch (e) {
      // Kept, not cleared: an empty list here would read as every drawing
      // gone, which is worse than a stale one.
      debugPrint('Error loading drawings: $e');
    }
  }

  /// Save a new drawing and hand it back with its id.
  ///
  /// A line of fewer than two points is not saved: it has no length, nothing
  /// to draw, and would sit in a project's list as a blank entry.
  Future<Drawing?> add(Drawing drawing) async {
    if (drawing.points.length < 2) return null;
    if (drawing.fileId == FieldFile.unsortedId) {
      drawing = drawing.copyWith(clearFile: true);
    }
    final saved =
        drawing.copyWith(id: await _db.insertDrawing(drawing.toMap()));
    if (mounted) state = [...state, saved];
    return saved;
  }

  Future<void> save(Drawing drawing) async {
    final id = drawing.id;
    if (id == null) return;
    final updated = drawing.copyWith(updatedAt: DateTime.now());
    await _db.updateDrawing(updated.toMap());
    if (mounted) {
      state = [for (final d in state) d.id == id ? updated : d];
    }
  }

  /// File a drawing under a project, or under nothing for Unsorted.
  ///
  /// [FieldFile.unsortedId] is taken to mean Unsorted and stored as NULL. -1
  /// written to file_id would file it under a project that does not exist.
  Future<void> moveToFile(Drawing drawing, int? fileId) => save(
        fileId == null || fileId == FieldFile.unsortedId
            ? drawing.copyWith(clearFile: true)
            : drawing.copyWith(fileId: fileId),
      );

  Future<void> delete(int id) async {
    await _db.deleteDrawing(id);
    if (mounted) state = state.where((d) => d.id != id).toList();
  }
}

final drawingsProvider =
    StateNotifierProvider<DrawingsNotifier, List<Drawing>>(
        (ref) => DrawingsNotifier(ref.watch(databaseServiceProvider)));
