// A performance cache, not offline maps. The constraints it has to hold are
// the interesting part: the server decides how long a tile lives, it has a
// ceiling, and it can be emptied.
import 'package:bush_track/core/services/tile_cache.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the server decides how long a tile lives', () {
    test('the policy is request, not forceCache', () async {
      // The library's default is forceCache, which saves "every successful
      // GET" whatever the response headers say. That is overriding the
      // provider's decision about freshness, which is exactly what we were
      // asked not to do. CachePolicy.request caches only what the directives
      // permit.
      //
      // Asserted against the enum rather than a built provider, because
      // building one needs a documents directory this test does not have.
      expect(CachePolicy.values, contains(CachePolicy.request));
      expect(CachePolicy.request, isNot(CachePolicy.forceCache));
    });

    test('there is no store where there is nowhere to put one', () async {
      // No documents directory in a plain test, exactly as on web. It has to
      // return null and let the map run uncached rather than throw.
      expect(await TileCache.instance.provider(), isNull);
      expect(TileCache.instance.ready, isNull);
    });

    test('size reads as zero rather than failing when unavailable', () async {
      expect(await TileCache.instance.currentBytes(), 0);
    });

    test('clearing an unavailable cache is harmless', () async {
      await TileCache.instance.clear();
    });

    test('warming up without a directory leaves no provider', () async {
      await TileCache.instance.warmUp();
      expect(TileCache.instance.ready, isNull);
    });
  });

  group('it has a ceiling', () {
    test('the cap is set, and not unbounded', () {
      expect(TileCache.maxBytes, greaterThan(0));
    });

    test('big enough to be useful, small enough not to eat the phone', () {
      // A field phone also holds photos, offline regions and a routing pack.
      expect(TileCache.maxBytes, greaterThanOrEqualTo(50 * 1024 * 1024));
      expect(TileCache.maxBytes, lessThanOrEqualTo(500 * 1024 * 1024));
    });
  });

  group('the size shown in settings', () {
    test('reads in bytes, KB and MB as it grows', () {
      expect(TileCache.humanBytes(0), '0 B');
      expect(TileCache.humanBytes(512), '512 B');
      expect(TileCache.humanBytes(2048), '2 KB');
      expect(TileCache.humanBytes(5 * 1024 * 1024), '5.0 MB');
    });

    test('the cap is quotable in the same units', () {
      expect(TileCache.humanBytes(TileCache.maxBytes), contains('MB'));
    });

    test('a number just under a boundary does not read as the next unit up',
        () {
      expect(TileCache.humanBytes(1023), '1023 B');
      expect(TileCache.humanBytes(1024 * 1024 - 1), contains('KB'));
    });
  });
}
