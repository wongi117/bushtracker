import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bush_track/core/models/artifact.dart';
import 'package:bush_track/core/services/database_service.dart';
import 'package:bush_track/main.dart';

class ArtifactState {
  final List<Artifact> artifacts;
  final bool isLoading;

  const ArtifactState({this.artifacts = const [], this.isLoading = false});

  ArtifactState copyWith({List<Artifact>? artifacts, bool? isLoading}) =>
      ArtifactState(
        artifacts: artifacts ?? this.artifacts,
        isLoading: isLoading ?? this.isLoading,
      );
}

class ArtifactNotifier extends StateNotifier<ArtifactState> {
  final DatabaseService _db;

  ArtifactNotifier(this._db) : super(const ArtifactState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    final maps = await _db.getArtifacts();
    state = state.copyWith(
      artifacts: maps.map(Artifact.fromMap).toList(),
      isLoading: false,
    );
  }

  Future<void> addArtifact(Artifact artifact) async {
    await _db.insertArtifact(artifact.toMap());
    await _load();
  }

  Future<void> updateArtifact(Artifact artifact) async {
    await _db.updateArtifact(artifact.toMap());
    await _load();
  }

  Future<void> deleteArtifact(int id) async {
    await _db.deleteArtifact(id);
    await _load();
  }
}

final artifactProvider =
    StateNotifierProvider<ArtifactNotifier, ArtifactState>((ref) {
  final db = ref.read(databaseServiceProvider);
  return ArtifactNotifier(db);
});
