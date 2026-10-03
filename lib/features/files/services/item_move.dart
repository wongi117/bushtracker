import 'package:bush_track/core/models/field_file.dart';

/// Somewhere a pin, boundary or trail can be moved to.
///
/// Unsorted is one of these, which is the point: "take this out of the project"
/// and "put this in that project" are the same gesture, and splitting them into
/// a move and a separate remove gives two ways to do one thing and a way to end
/// up with neither.
class MoveDestination {
  const MoveDestination.project(FieldFile file) : _file = file;

  const MoveDestination.unsorted() : _file = null;

  final FieldFile? _file;

  /// What to write to `file_id`. Null for Unsorted -- which is a view over
  /// `file_id IS NULL`, so moving something there means clearing the column,
  /// not writing [FieldFile.unsortedId] into it. Writing -1 would file items
  /// under a project that does not exist and hide them from every list.
  int? get targetFileId => _file?.id;

  bool get isUnsorted => _file == null;

  String get name => _file?.name ?? 'Unsorted';

  String? get colour => _file?.colour;
}

/// Where the selected items can go, given where they are now.
///
/// [currentFileId] is the list being moved out of: a project's id, or null for
/// the Unsorted view. That destination is left out, because moving something to
/// where it already is reads as a no-op that did nothing wrong but also did
/// nothing, and the user is left wondering which.
///
/// Archived projects are offered. Filing into one is a reasonable thing to want
/// -- adding a pin to last season's survey -- and refusing it silently would be
/// worse than letting it happen.
List<MoveDestination> destinationsFor(
  List<FieldFile> files, {
  required int? currentFileId,
}) {
  final out = <MoveDestination>[
    for (final f in files)
      if (f.id != null && f.id != currentFileId && !f.isUnsorted)
        MoveDestination.project(f),
  ];

  // Unsorted last: it is where things end up, not somewhere you usually choose.
  if (currentFileId != null) out.add(const MoveDestination.unsorted());

  return out;
}

/// What the confirmation says once a move has happened.
///
/// Counted and named, because a move that says only "done" leaves no way to
/// tell a move of three items from a move of thirty, and no way to notice that
/// the wrong thing was ticked.
String describeMove(int count, String destination) =>
    '$count ${count == 1 ? 'item' : 'items'} moved to $destination';
