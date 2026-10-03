import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bush_track/core/models/field_file.dart';
import 'package:bush_track/core/services/database_service.dart';
import 'package:bush_track/core/services/photo_file_store.dart';
import 'package:bush_track/main.dart';

class FilesState {
  final List<FieldFile> files;

  /// The file new pins, zones and notes get filed under. Null means loose
  /// work that belongs to no file, which is the normal state until someone
  /// opens one.
  final int? activeFileId;

  /// Notes for whichever file is being looked at.
  final int? viewingFileId;
  final List<FileNote> notes;

  /// Whether the list has come back from the database yet.
  ///
  /// Needed because an empty list means two different things. Anything that
  /// reconciles against the set of projects -- pruning a map scope, say --
  /// would otherwise do it once against the empty list that exists before the
  /// first query returns, and throw away perfectly good state.
  final bool loaded;

  const FilesState({
    this.files = const [],
    this.activeFileId,
    this.viewingFileId,
    this.notes = const [],
    this.loaded = false,
  });

  /// The projects that belong in the list.
  ///
  /// Archived ones are kept in [files] rather than being filtered out at the
  /// source, so an archived project that is still the active one, or still
  /// scoped on the map, can be found by id instead of silently resolving to
  /// null.
  List<FieldFile> get liveFiles =>
      files.where((f) => !f.isArchived).toList();

  List<FieldFile> get archivedFiles =>
      files.where((f) => f.isArchived).toList();

  FieldFile? get activeFile {
    final matches = files.where((f) => f.id == activeFileId);
    return matches.isEmpty ? null : matches.first;
  }

  FilesState copyWith({
    List<FieldFile>? files,
    int? activeFileId,
    int? viewingFileId,
    List<FileNote>? notes,
    bool? loaded,
    bool clearActive = false,
  }) =>
      FilesState(
        files: files ?? this.files,
        activeFileId: clearActive ? null : activeFileId ?? this.activeFileId,
        viewingFileId: viewingFileId ?? this.viewingFileId,
        notes: notes ?? this.notes,
        loaded: loaded ?? this.loaded,
      );
}

class FilesNotifier extends StateNotifier<FilesState> {
  FilesNotifier(this.db) : super(const FilesState()) {
    _load();
  }

  final DatabaseService db;

  static const _activeKey = 'active_field_file_id';

  Future<void> _load() async {
    try {
      final rows = await db.getFieldFiles();
      // The screen can be torn down mid-load; touching state after that throws.
      if (!mounted) return;
      final files = rows.map(FieldFile.fromMap).toList();

      int? active;
      try {
        final prefs = await SharedPreferences.getInstance();
        active = prefs.getInt(_activeKey);
      } catch (_) {
        // Preferences are unavailable in some browser contexts; the app works
        // without a remembered file, it just starts with none open.
      }
      if (!mounted) return;

      // A file deleted on another device (or in a previous session) must not
      // leave new work filed under an id that no longer exists.
      if (active != null && !files.any((f) => f.id == active)) active = null;

      state = state.copyWith(
        files: files,
        activeFileId: active,
        clearActive: active == null,
        loaded: true,
      );
    } catch (e) {
      debugPrint('FilesNotifier load error: $e');
      // Marked loaded even on failure, or anything waiting for the list waits
      // forever. A failed load is an empty list we know about.
      if (mounted) state = state.copyWith(loaded: true);
    }
  }

  Future<FieldFile?> createFile({
    required String name,
    String? description,
    LatLng? position,
  }) async {
    final now = DateTime.now();
    final file = FieldFile(
      name: name,
      description: description,
      latitude: position?.latitude,
      longitude: position?.longitude,
      createdAt: now,
      updatedAt: now,
    );
    try {
      final id = await db.insertFieldFile(file.toMap());
      await _load();
      // A new file is the one being worked in — that is why it was made.
      await setActiveFile(id);
      final made = state.files.where((f) => f.id == id);
      return made.isEmpty ? null : made.first;
    } catch (e) {
      debugPrint('FilesNotifier create error: $e');
      return null;
    }
  }

  Future<void> updateFile(FieldFile file) async {
    if (file.id == null) return;
    await db.updateFieldFile(
        file.copyWith(updatedAt: DateTime.now()).toMap());
    await _load();
  }

  /// What is filed under a project, for a delete confirmation.
  Future<ProjectContents> contentsOf(int id) => db.countFieldFileContents(id);

  /// Delete a project.
  ///
  /// [withContents] false unfiles its pins, zones and trails -- they stay on
  /// the map as Unsorted. True deletes them, which is the one action in the app
  /// that can lose collected work, so the caller must have shown the counts
  /// first.
  Future<void> deleteFile(int id, {bool withContents = false}) async {
    await db.deleteFieldFile(id, withContents: withContents);
    if (state.activeFileId == id) await setActiveFile(null);
    await _load();

    if (withContents) {
      // Photos are removed by being unreferenced, not by the paths that were
      // just deleted: two pins can point at the same file, and deleting by
      // path would take it out from under the one that remains.
      try {
        final store = PhotoFileStore();
        if (!await store.isAvailable) return;
        final referenced = await db.referencedPhotoPaths();
        for (final orphan in await store.orphans(referenced)) {
          await store.delete(orphan);
        }
      } catch (e) {
        // A photo left on disk costs space; a crash here costs the delete. The
        // orphan sweep can run again later.
        debugPrint('Photo cleanup after project delete failed: $e');
      }
    }
  }

  /// Open a file for work, or pass null to close whatever is open.
  Future<void> setActiveFile(int? id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(_activeKey);
      } else {
        await prefs.setInt(_activeKey, id);
      }
    } catch (_) {
      // Not being able to remember it across restarts is survivable; the rest
      // of this session still files work correctly.
    }
    if (!mounted) return;
    state = state.copyWith(activeFileId: id, clearActive: id == null);
  }

  Future<void> loadNotes(int fileId) async {
    try {
      final rows = await db.getFileNotes(fileId);
      if (!mounted) return;
      state = state.copyWith(
        viewingFileId: fileId,
        notes: rows.map(FileNote.fromMap).toList(),
      );
    } catch (e) {
      debugPrint('FilesNotifier notes error: $e');
    }
  }

  Future<void> addNote({
    required int fileId,
    required String body,
    LatLng? position,
  }) async {
    final note = FileNote(
      fileId: fileId,
      body: body,
      latitude: position?.latitude,
      longitude: position?.longitude,
      createdAt: DateTime.now(),
    );
    await db.insertFileNote(note.toMap());
    // Writing in a file counts as working in it, so it sorts to the top.
    final owner = state.files.where((f) => f.id == fileId);
    if (owner.isNotEmpty) {
      await db.updateFieldFile(
          owner.first.copyWith(updatedAt: DateTime.now()).toMap());
    }
    await loadNotes(fileId);
    await _load();
  }

  Future<void> deleteNote(int noteId, int fileId) async {
    await db.deleteFileNote(noteId);
    await loadNotes(fileId);
  }
}

final filesProvider =
    StateNotifierProvider<FilesNotifier, FilesState>((ref) {
  return FilesNotifier(ref.watch(databaseServiceProvider));
});
