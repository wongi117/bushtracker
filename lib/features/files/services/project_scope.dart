import 'package:bush_track/core/models/field_file.dart';

/// Which projects' work is shown on the map.
///
/// This is deliberately a different thing from `activeFileId`. That one is
/// where *new* pins get filed; this is what you can *see*. Conflating them
/// would mean choosing where to save also silently hid the rest of the map —
/// and on a field phone a pin that is not there does not read as "filtered",
/// it reads as "I have lost this morning's work".
///
/// So two rules hold throughout:
///
///  * [all] is the default and the resting state. Nothing is hidden until
///    somebody asks for it to be.
///  * An empty selection means [all], never an empty map. Deleting the last
///    project in a scope must not blank the map — see [only].
class ProjectScope {
  /// Everything is visible.
  const ProjectScope.all() : visible = null;

  /// Only the given projects are visible.
  ///
  /// An empty or all-pruned set collapses to [all]. The alternative — an
  /// honest empty scope — gives a blank map with no pins, no zones and no
  /// trails, which is indistinguishable from a database that failed to load.
  /// There is no useful reason to ask for it, so it is not representable.
  // Not const: the empty-collapses-to-all rule is a computation.
  ProjectScope.only(Set<int> ids) : visible = ids.isEmpty ? null : ids;

  /// Null means everything. Otherwise the set of visible project ids, where
  /// [FieldFile.unsortedId] stands for work filed under nothing.
  final Set<int>? visible;

  bool get isFiltered => visible != null;

  /// How many projects are showing, for the badge. Null when unfiltered.
  int? get count => visible?.length;

  /// Whether an item filed under [fileId] is shown. A null [fileId] is
  /// unfiled work, which travels under [FieldFile.unsortedId].
  bool isVisible(int? fileId) {
    final set = visible;
    if (set == null) return true;
    return set.contains(fileId ?? FieldFile.unsortedId);
  }

  /// Whether [fileId] is one of the chosen projects.
  ///
  /// Not the same question as [isVisible]: when nothing is filtered every
  /// project is visible, but none of them is individually selected, and a
  /// checkbox that showed everything ticked would make "show only this one"
  /// look like it had already happened.
  bool isSelected(int fileId) => visible?.contains(fileId) ?? false;

  /// Adds or removes one project.
  ///
  /// Turning the last one off returns to [all] rather than to nothing, by the
  /// rule above.
  ProjectScope toggle(int fileId) {
    final next = {...?visible};
    // Starting from unfiltered, the first tap means "only this one" — not
    // "everything except this one". Picking a project out of a crowded map is
    // what the toggle is for.
    if (visible == null) return ProjectScope.only({fileId});
    if (!next.remove(fileId)) next.add(fileId);
    return ProjectScope.only(next);
  }

  /// Shows only these, discarding whatever was selected before.
  ProjectScope showOnly(Set<int> ids) => ProjectScope.only(ids);

  /// Back to showing everything.
  ProjectScope clear() => const ProjectScope.all();

  /// Drops ids that no longer exist, so a deleted project cannot keep hiding
  /// the map from beyond the grave. Pruning everything away returns to [all].
  ProjectScope prune(Set<int> existing) {
    final set = visible;
    if (set == null) return this;
    return ProjectScope.only(
      set.where((id) => id == FieldFile.unsortedId || existing.contains(id))
          .toSet(),
    );
  }

  /// For SharedPreferences, which stores lists of strings.
  List<String> encode() => visible?.map((i) => i.toString()).toList() ?? const [];

  /// An absent or unparseable value restores [all] — the safe end of the
  /// range, since the failure mode of the other end is a blank map.
  static ProjectScope decode(List<String>? stored) {
    if (stored == null || stored.isEmpty) return const ProjectScope.all();
    final ids = <int>{};
    for (final s in stored) {
      final n = int.tryParse(s);
      if (n != null) ids.add(n);
    }
    return ProjectScope.only(ids);
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectScope &&
      (visible == null) == (other.visible == null) &&
      (visible == null ||
          (visible!.length == other.visible!.length &&
              visible!.containsAll(other.visible!)));

  @override
  int get hashCode => visible == null ? 0 : Object.hashAllUnordered(visible!);

  @override
  String toString() =>
      visible == null ? 'ProjectScope.all' : 'ProjectScope.only($visible)';
}
