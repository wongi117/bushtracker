import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:http_cache_core/http_cache_core.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-disk cache for map tiles.
///
/// **A performance cache, not offline maps.** It stops the app re-fetching
/// tiles it already has — every one of which is now billed per request against
/// Mapbox — and it means reopening the app does not pay for the same screen
/// twice. It is explicitly not a way to make imagery available with no signal:
/// Mapbox offline is their SDK's business and nothing here tries to stand in
/// for it. Nothing primes it, nothing downloads ahead, and it is wiped whenever
/// the person says so.
///
/// Three rules, all deliberate:
///
/// **The server decides how long a tile lives.** [CachePolicy.request] caches
/// only what the response's own directives permit, and `maxStale` is left null
/// so nothing is ever kept past the expiry the provider set. The library's
/// default is [CachePolicy.forceCache], which saves "every successful GET"
/// whatever the headers say — that would be overriding the provider's wishes,
/// so it is not used.
///
/// **It has a ceiling.** The file store has no size limit of its own, so one is
/// enforced here: past [maxBytes] the oldest files go until it is back under.
/// A map cache left to grow will happily eat the storage a field phone needs
/// for photos.
///
/// **It can be emptied.** From settings, in one tap.
class TileCache {
  TileCache._();

  static final TileCache instance = TileCache._();

  /// How much disk the cache may use.
  ///
  /// 200 MB holds a useful amount of a working area without competing with the
  /// photos, offline regions and routing packs that share the phone.
  static const int maxBytes = 200 * 1024 * 1024;

  static const String folderName = 'tile_cache';

  CacheStore? _store;
  Directory? _directory;
  bool _tried = false;

  TileProvider? _ready;

  /// The cached provider, if it has been warmed up. Null means use the default.
  ///
  /// Read synchronously by the map so the TileLayer is built with its final
  /// provider on the first frame. Handing it a provider later swaps it out and
  /// re-fetches every visible tile — the precise waste this cache exists to
  /// prevent, paid once on every launch.
  TileProvider? get ready => _ready;

  /// Prepare the cache during startup, before the map is built.
  Future<void> warmUp() async {
    _ready = await provider();
    debugPrint(_ready == null
        ? 'Tile cache unavailable; tiles will not be cached'
        : 'Tile cache ready (${humanBytes(await currentBytes())} used, '
            'cap ${humanBytes(maxBytes)})');
  }

  /// Null where there is nowhere to put it — web, or a platform with no
  /// documents directory. The map then runs uncached, exactly as before.
  Future<CacheStore?> _ensure() async {
    if (_tried) return _store;
    _tried = true;

    if (kIsWeb) {
      // The browser already has an HTTP cache, and there is no file system to
      // put one in. Nothing to do.
      return null;
    }

    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, folderName));
      if (!await dir.exists()) await dir.create(recursive: true);
      _directory = dir;
      _store = FileCacheStore(dir.path);
      await _enforceCap();
      return _store;
    } catch (e) {
      debugPrint('TileCache unavailable: $e');
      return null;
    }
  }

  /// A tile provider that caches, or null to use the default one.
  ///
  /// Call once and hold the result: building a new provider per frame would
  /// make a new Dio client per frame.
  Future<TileProvider?> provider() async {
    final store = await _ensure();
    if (store == null) return null;

    return CachedTileProvider(
      store: store,
      // Keeps the flaky-connection retry the plain provider had. Out here a
      // tile failure is usually a dropped connection or a name that would not
      // resolve while the radio was still coming up, and those are exactly the
      // ones worth trying again. Losing that to gain a cache would be a poor
      // trade.
      interceptors: [_TileRetryInterceptor()],
      // Honour the provider's cache headers rather than the library's default
      // of caching everything regardless. See the class comment.
      cachePolicy: CachePolicy.request,
      // Left null on purpose. maxStale would serve tiles beyond the expiry the
      // server set, which is overriding their decision about freshness —
      // imagery does get revised.
      maxStale: null,
    );
  }

  /// What the cache currently occupies, in bytes.
  Future<int> currentBytes() async {
    final dir = _directory ?? (await _ensure() == null ? null : _directory);
    if (dir == null) return 0;
    return _sizeOf(dir);
  }

  /// Empty it. Everything, including entries that have not expired.
  Future<void> clear() async {
    final store = await _ensure();
    try {
      await store?.clean();
    } catch (e) {
      debugPrint('TileCache clean failed: $e');
    }

    // The store's own clean leaves the directory tree behind, and on some
    // platforms leaves files it did not write. Sweep what is left so the
    // reported size actually goes to zero — a "clear cache" button that
    // reports 40 MB afterwards is not believable.
    final dir = _directory;
    if (dir == null) return;
    try {
      await for (final entry in dir.list(recursive: true)) {
        if (entry is File) await entry.delete();
      }
    } catch (e) {
      debugPrint('TileCache sweep failed: $e');
    }
  }

  /// Bring the cache back under [maxBytes] by deleting the oldest files.
  ///
  /// Oldest by modification time, which is a rough least-recently-used: a tile
  /// re-fetched or re-validated gets a fresh timestamp, so the ones that go are
  /// the ones nobody has looked at.
  Future<void> _enforceCap() async {
    final dir = _directory;
    if (dir == null) return;

    try {
      final files = <File>[];
      await for (final entry in dir.list(recursive: true)) {
        if (entry is File) files.add(entry);
      }

      var total = 0;
      for (final f in files) {
        total += await f.length();
      }
      if (total <= maxBytes) return;

      files.sort((a, b) =>
          a.statSync().modified.compareTo(b.statSync().modified));

      for (final f in files) {
        if (total <= maxBytes) break;
        final size = await f.length();
        await f.delete();
        total -= size;
      }
      debugPrint('TileCache trimmed to ${(total / 1048576).round()} MB');
    } catch (e) {
      debugPrint('TileCache cap check failed: $e');
    }
  }

  /// Called after a session of panning, to keep the ceiling honest.
  Future<void> trim() => _enforceCap();

  static Future<int> _sizeOf(Directory dir) async {
    var total = 0;
    try {
      await for (final entry in dir.list(recursive: true)) {
        if (entry is File) total += await entry.length();
      }
    } catch (e) {
      debugPrint('TileCache sizing failed: $e');
    }
    return total;
  }

  /// For the settings line.
  static String humanBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}


/// Retry a failed tile request, backing off.
///
/// Mirrors what the RetryClient did before the cache went in: any error, not
/// just a 5xx, because the failures seen in the field are dropped connections
/// and DNS misses in the first seconds after a cold start. Backs off so a
/// genuinely offline phone is not hammering the radio and flattening the
/// battery, which matters when the phone is the only navigation device out
/// there.
class _TileRetryInterceptor extends Interceptor {
  static const int _maxAttempts = 5;

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra['tileAttempt'] as int?) ?? 0;

    final status = err.response?.statusCode;
    // A 404 means the provider has no tile there; retrying costs a request and
    // cannot succeed. Against a per-request provider that is money for nothing.
    final worthRetrying = status == null || status >= 500;

    if (attempt >= _maxAttempts || !worthRetrying) {
      return handler.next(err);
    }

    // 0.5, 1, 2, 4, 8 seconds.
    await Future<void>.delayed(
        Duration(milliseconds: 500 * (1 << attempt)));

    final options = err.requestOptions
      ..extra['tileAttempt'] = attempt + 1;

    try {
      final dio = Dio();
      final response = await dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } catch (_) {
      // The retry failed too; pass the original failure on so flutter_map
      // shows its error tile rather than hanging on a pending request.
      return handler.next(err);
    }
  }
}
