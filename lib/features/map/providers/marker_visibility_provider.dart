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
///  * [scopeFileId] — a project: only work filed under it.
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
    this.scopeFileId,
    this.soloPinId,
    this.soloZoneId,
  });

  final Set<int> hiddenPins;
  final Set<int> hiddenZones;

  /// When set, only pins and zones filed under this project are drawn.
  ///
  /// Loose work — anything filed under nothing — is out of scope too. Opening
  /// a project means seeing that project.
  final int? scopeFileId;

  /// When set, this is the only pin drawn, and no zones at all.
  final int? soloPinId;

  /// When set, this is the only zone drawn, and no pins at all.
  final int? soloZoneId;

  bool get isScoped => scopeFileId != null;

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

  bool _inScope(int? fileId) => scopeFileId == null || fileId == scopeFileId;

  /// How many things have been put away by hand. Does not count what a project
  /// scope is holding back, which is a different idea and has its own label.
  int get hiddenCount => hiddenPins.length + hiddenZones.length;

  MarkerVisibility copyWith({
    Set<int>? hiddenPins,
    Set<int>? hiddenZones,
    int? scopeFileId,
    int? soloPinId,
    int? soloZoneId,
    bool clearScope = false,
    bool clearSolo = false,
  }) =>
      MarkerVisibility(
        hiddenPins: hiddenPins ?? this.hiddenPins,
        hiddenZones: hiddenZones ?? this.hiddenZones,
        scopeFileId: clearScope ? null : scopeFileId ?? this.scopeFileId,
        soloPinId: clearSolo ? null : soloPinId ?? this.soloPinId,
        soloZoneId: clearSolo ? null : soloZoneId ?? this.soloZoneId,
      );
}

class MarkerVisibilityNotifier extends StateNotifier<MarkerVisibility> {
  MarkerVisibilityNotifier() : super(const MarkerVisibility()) {
    _load();
  }

  static const _pinsKey = 'hidden_pin_ids';
  static const _zonesKey = 'hidden_zone_ids';
  static const _scopeKey = 'marker_scope_file_id';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      state = MarkerVisibility(
        hiddenPins: _read(prefs, _pinsKey),
        hiddenZones: _read(prefs, _zonesKey),
        scopeFileId: prefs.getInt(_scopeKey),
        // Solo is deliberately not restored. It is a "look at this one thing
        // for a moment" state, and coming back to the app a day later with a
        // single pin on the map and no memory of why reads as lost data.
      );
    } catch (e) {
      debugPrint('MarkerVisibility load error: $e');
    }
  }

  Set<int> _read(SharedPreferences prefs, String key) =>
      (prefs.getStringList(key) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _pinsKey, state.hiddenPins.map((e) => '$e').toList());
      await prefs.setStringList(
          _zonesKey, state.hiddenZones.map((e) => '$e').toList());
      final scope = state.scopeFileId;
      if (scope == null) {
        await prefs.remove(_scopeKey);
      } else {
        await prefs.setInt(_scopeKey, scope);
      }
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
    state = state.copyWith(scopeFileId: fileId, clearSolo: true);
    await _save();
  }

  /// Back to everything, wherever it is filed.
  Future<void> closeProject() async {
    state = state.copyWith(clearScope: true);
    await _save();
  }

  /// A project is dropped, so nothing can be scoped to it any more.
  Future<void> forgetProject(int fileId) async {
    if (state.scopeFileId != fileId) return;
    await closeProject();
  }

  Future<void> togglePin(int id) async {
    final next = Set<int>.from(state.hiddenPins);
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copyWith(hiddenPins: next, clearSolo: true);
    await _save();
  }

  Future<void> toggleZone(int id) async {
    final next = Set<int>.from(state.hiddenZones);
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copyWith(hiddenZones: next, clearSolo: true);
    await _save();
  }

  /// Show one thing and nothing else — for when you are working to a single
  /// target and everything else is noise.
  Future<void> soloPin(int id) async {
    // Built directly rather than through copyWith, which cannot set one solo
    // and clear the other in the same step.
    state = MarkerVisibility(
      hiddenPins: state.hiddenPins,
      hiddenZones: state.hiddenZones,
      scopeFileId: state.scopeFileId,
      soloPinId: id,
    );
    await _save();
  }

  Future<void> soloZone(int id) async {
    state = MarkerVisibility(
      hiddenPins: state.hiddenPins,
      hiddenZones: state.hiddenZones,
      scopeFileId: state.scopeFileId,
      soloZoneId: id,
    );
    await _save();
  }

  Future<void> clearSolo() async {
    state = state.copyWith(clearSolo: true);
    await _save();
  }

  /// Everything back on the map: no project scope, no solo, nothing put away.
  Future<void> showEverything() async {
    state = const MarkerVisibility();
    await _save();
  }
}

final markerVisibilityProvider =
    StateNotifierProvider<MarkerVisibilityNotifier, MarkerVisibility>(
        (ref) => MarkerVisibilityNotifier());
