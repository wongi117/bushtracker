import 'package:bush_track/features/files/providers/files_provider.dart';
import 'package:bush_track/features/files/services/project_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which pins and zones are drawn on the map and through the camera.
///
/// After a few days of work in one area the map fills up, and everything
/// competing for the same patch of screen makes the one thing you are actually
/// looking for harder to find — the opposite of the point. Hiding is never
/// deleting: the record stays, it just stops being drawn.
///
/// Three mechanisms, narrowest first:
///
///  * [soloPinId] / [soloZoneId] — one thing and nothing else.
///  * [scope] - one or more projects: only work filed under them.
///  * [hiddenPins] / [hiddenZones] — individual things put away by hand.
///
/// The project scope filters on which file a pin belongs to rather than by
/// listing ids, which matters: the previous "isolate" wrote every *other* id
/// into the hidden set, so the next pin created was not in that list and
/// appeared anyway, and the stored list grew for as long as the app was used.
/// A rule about where something is filed keeps working on pins that do not
/// exist yet.
@immutable
class MarkerVisibility {
  const MarkerVisibility({
    this.hiddenPins = const {},
    this.hiddenZones = const {},
    this.scope = const ProjectScope.all(),
    this.soloPinId,
    this.soloZoneId,
  });

  final Set<int> hiddenPins;
  final Set<int> hiddenZones;

  /// Which projects are drawn. [ProjectScope.all] -- the default -- is
  /// everything.
  ///
  /// A set rather than a single project, because a survey and the heritage
  /// boundaries that constrain it are two things you need on screen at
  /// once, and the single-project version forced a choice between them.
  ///
  /// Loose work -- anything filed under nothing -- is out of scope too
  /// unless Unsorted is picked explicitly. Opening a project means seeing
  /// that project.
  final ProjectScope scope;

  /// When set, this is the only pin drawn, and no zones at all.
  final int? soloPinId;

  /// When set, this is the only zone drawn, and no pins at all.
  final int? soloZoneId;

  bool get isScoped => scope.isFiltered;

  /// Whether this project is one of the chosen ones, for a checkbox.
  bool showsProject(int fileId) => scope.isSelected(fileId);

  bool get isSoloed => soloPinId != null || soloZoneId != null;

  /// True when something is being held back, whatever the reason. What the map
  /// uses to decide whether to warn that it is not showing everything.
  bool get isFiltered => isScoped || isSoloed || hiddenCount > 0;

  /// Should this pin be drawn? [fileId] is the project it is filed under, or
  /// null for loose work.
  bool showsPin({int? id, int? fileId}) {
    if (soloZoneId != null) return false;
    if (soloPinId != null) return id == soloPinId;
    if (!_inScope(fileId)) return false;
    return id == null || !hiddenPins.contains(id);
  }

  /// Should this zone be drawn? [fileId] as for [showsPin].
  bool showsZone({int? id, int? fileId}) {
    if (soloPinId != null) return false;
    if (soloZoneId != null) return id == soloZoneId;
    if (!_inScope(fileId)) return false;
    return id == null || !hiddenZones.contains(id);
  }

  /// Should this drawing be drawn? Follows the project scope like everything
  /// else, and steps aside while one pin or zone is soloed.
  bool showsDrawing({int? fileId}) {
    if (soloPinId != null || soloZoneId != null) return false;
    return _inScope(fileId);
  }

  bool _inScope(int? fileId) => scope.isVisible(fileId);

  /// How many things have been put away by hand. Does not count what a project
  /// scope is holding back, which is a different idea and has its own label.
  int get hiddenCount => hiddenPins.length + hiddenZones.length;

  MarkerVisibility copyWith({
    Set<int>? hiddenPins,
    Set<int>? hiddenZones,
    ProjectScope? scope,
    int? soloPinId,
    int? soloZoneId,
    bool clearScope = false,
    bool clearSolo = false,
  }) =>
      MarkerVisibility(
        hiddenPins: hiddenPins ?? this.hiddenPins,
        hiddenZones: hiddenZones ?? this.hiddenZones,
        scope: clearScope ? const ProjectScope.all() : scope ?? this.scope,
        soloPinId: clearSolo ? null : soloPinId ?? this.soloPinId,
        soloZoneId: clearSolo ? null : soloZoneId ?? this.soloZoneId,
      );
}

class MarkerVisibilityNotifier extends StateNotifier<MarkerVisibility> {
  MarkerVisibilityNotifier() : super(const MarkerVisibility()) {
    restored = _load();
  }

  /// Completes when the saved state has been read back.
  ///
  /// Held so tests can wait for it instead of guessing at a number of
  /// microtasks, which is the kind of test that passes until the day it does
  /// not.
  late final Future<void> restored;

  /// Whether the user has changed anything since launch.
  ///
  /// The restore is asynchronous -- it waits on SharedPreferences -- so a tap
  /// can land before it finishes. Without this, restoring would write the
  /// saved state straight over that tap: on the phone, filtering to a project
  /// in the first moments after opening the app would silently undo itself and
  /// look like the chip did not work.
  bool _touched = false;

  /// The projects that existed the last time anything told us.
  ///
  /// Kept because the two inputs arrive in either order: restoring the scope
  /// from preferences is async, and the project list can land first. Without
  /// this, a scope read from disk after the only prune would never be checked
  /// against the projects that actually exist, and a deleted project could go
  /// on hiding the map for the whole session.
  Set<int>? _knownProjects;

  static const _pinsKey = 'hidden_pin_ids';
  static const _zonesKey = 'hidden_zone_ids';
  static const _scopeKey = 'marker_scope_file_ids';

  /// The single-project key this used to write. Read once, so somebody
  /// who had a project open when they updated still has it open after.
  static const _legacyScopeKey = 'marker_scope_file_id';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      if (_touched) {
        // Something was changed while this was in flight. That wins; all that
        // is left to do is reconcile it against the projects that exist.
        final known = _knownProjects;
        if (known != null) await pruneProjects(known);
        return;
      }
      state = MarkerVisibility(
        hiddenPins: _read(prefs, _pinsKey),
        hiddenZones: _read(prefs, _zonesKey),
        scope: _readScope(prefs),
        // Solo is deliberately not restored. It is a "look at this one thing
        // for a moment" state, and coming back to the app a day later with a
        // single pin on the map and no memory of why reads as lost data.
      );
      final known = _knownProjects;
      if (known != null) await pruneProjects(known);
    } catch (e) {
      debugPrint('MarkerVisibility load error: $e');
    }
  }

  ProjectScope _readScope(SharedPreferences prefs) {
    final stored = prefs.getStringList(_scopeKey);
    if (stored != null) return ProjectScope.decode(stored);
    final legacy = prefs.getInt(_legacyScopeKey);
    return legacy == null
        ? const ProjectScope.all()
        : ProjectScope.only({legacy});
  }

  Set<int> _read(SharedPreferences prefs, String key) =>
      (prefs.getStringList(key) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  /// Every user-driven change goes through here, so none of them can be
  /// quietly reverted by the restore landing late.
  Future<void> _apply(MarkerVisibility next) async {
    _touched = true;
    state = next;
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _pinsKey, state.hiddenPins.map((e) => '$e').toList());
      await prefs.setStringList(
          _zonesKey, state.hiddenZones.map((e) => '$e').toList());
      if (state.scope.isFiltered) {
        await prefs.setStringList(_scopeKey, state.scope.encode());
      } else {
        await prefs.remove(_scopeKey);
      }
      // The old key is dropped either way, so a stale single project cannot
      // come back the next time the new key happens to be absent.
      await prefs.remove(_legacyScopeKey);
    } catch (e) {
      debugPrint('MarkerVisibility save error: $e');
    }
  }

  /// Work on one project: show its pins and boundaries, and nothing else.
  ///
  /// Clears any solo, because opening a project is a wider view than looking
  /// at one pin, and leaving both on would show a single marker and look like
  /// the project was empty.
  Future<void> openProject(int fileId) async {
    await _apply(state.copyWith(
        scope: ProjectScope.only({fileId}), clearSolo: true));
  }

  /// Add or remove one project from the view, leaving the others alone.
  ///
  /// From "everything" the first tap narrows to just that project rather than
  /// hiding it -- picking one job out of a crowded map is what this is for.
  /// Turning the last one off goes back to everything, never to a blank map.
  Future<void> toggleProject(int fileId) async {
    await _apply(
        state.copyWith(scope: state.scope.toggle(fileId), clearSolo: true));
  }

  /// Show exactly these projects.
  Future<void> showOnlyProjects(Set<int> ids) async {
    await _apply(
        state.copyWith(scope: ProjectScope.only(ids), clearSolo: true));
  }

  /// Back to everything, wherever it is filed.
  Future<void> closeProject() async {
    await _apply(state.copyWith(clearScope: true));
  }

  /// A project is dropped, so nothing can be scoped to it any more.
  Future<void> forgetProject(int fileId) async {
    if (!state.scope.isSelected(fileId)) return;
    // Dropped from the scope rather than clearing the whole thing: deleting
    // one of three open projects should not also stop showing the other two.
    await _apply(state.copyWith(scope: state.scope.toggle(fileId)));
  }

  /// Drop any scoped project that no longer exists.
  ///
  /// Belt to [forgetProject]'s braces, for projects that went away by some
  /// other route -- a restore, a sync, a database rebuilt on a new phone.
  /// Without it a scope can go on hiding the map on behalf of a project the
  /// user cannot see to switch off.
  Future<void> pruneProjects(Set<int> existing) async {
    _knownProjects = existing;
    final next = state.scope.prune(existing);
    if (next == state.scope) return;
    state = state.copyWith(scope: next);
    await _save();
  }

  Future<void> togglePin(int id) async {
    final next = Set<int>.from(state.hiddenPins);
    next.contains(id) ? next.remove(id) : next.add(id);
    await _apply(state.copyWith(hiddenPins: next, clearSolo: true));
  }

  Future<void> toggleZone(int id) async {
    final next = Set<int>.from(state.hiddenZones);
    next.contains(id) ? next.remove(id) : next.add(id);
    await _apply(state.copyWith(hiddenZones: next, clearSolo: true));
  }

  /// Show one thing and nothing else — for when you are working to a single
  /// target and everything else is noise.
  Future<void> soloPin(int id) async {
    // Built directly rather than through copyWith, which cannot set one solo
    // and clear the other in the same step.
    await _apply(MarkerVisibility(
      hiddenPins: state.hiddenPins,
      hiddenZones: state.hiddenZones,
      scope: state.scope,
      soloPinId: id,
    ));
  }

  Future<void> soloZone(int id) async {
    await _apply(MarkerVisibility(
      hiddenPins: state.hiddenPins,
      hiddenZones: state.hiddenZones,
      scope: state.scope,
      soloZoneId: id,
    ));
  }

  Future<void> clearSolo() async {
    await _apply(state.copyWith(clearSolo: true));
  }

  /// Everything back on the map: no project scope, no solo, nothing put away.
  Future<void> showEverything() async {
    await _apply(const MarkerVisibility());
  }
}

final markerVisibilityProvider =
    StateNotifierProvider<MarkerVisibilityNotifier, MarkerVisibility>((ref) {
  final notifier = MarkerVisibilityNotifier();

  // A scoped project that no longer exists has to stop hiding the map. The
  // delete button calls forgetProject directly; this covers every other way a
  // project can go away -- a restore, a sync, a database rebuilt on a new
  // phone -- where otherwise the scope would go on filtering on behalf of
  // something the user cannot see in order to switch it off.
  //
  // Only once the list has actually loaded. Reconciling against the empty list
  // that exists before the first query returns would throw away the scope on
  // every single launch.
  ref.listen<FilesState>(filesProvider, (previous, next) {
    if (!next.loaded) return;
    notifier.pruneProjects(
        next.files.where((f) => f.id != null).map((f) => f.id!).toSet());
  }, fireImmediately: true);

  return notifier;
});
