// The bug: photos are stored as base64 data URIs, and every data URI contains a
// comma. The column was written with join(',') and read with split(','), so one
// saved photo came back as two useless fragments — the pin said "2 photos",
// showed a 1/2 counter, and drew the placeholder twice.
import 'dart:convert';

import 'package:bush_track/core/models/photo_paths_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A data URI shaped exactly like the ones the camera writes.
  String uri([String payload = 'AAECAwQFBgcICQoLDA0ODw==']) =>
      'data:image/jpeg;base64,$payload';

  group('the bug itself', () {
    test('one photo does not come back as two', () {
      final saved = PhotoPathsCodec.encode([uri()]);
      final read = PhotoPathsCodec.decode(saved);
      expect(read, hasLength(1), reason: 'this is the 2 photos / 1 of 2 bug');
      expect(read!.single, uri());
    });

    test('the old format is exactly as broken as reported', () {
      // Proof the diagnosis is right, not a guess: this is what the previous
      // code did, and it shreds one photo into two pieces.
      final legacyColumn = [uri()].join(',');
      final legacyRead = legacyColumn.split(',');
      expect(legacyRead, hasLength(2));
      expect(legacyRead.first, 'data:image/jpeg;base64');
      expect(() => base64Decode(legacyRead.first.split(',').last),
          throwsA(anything),
          reason: 'the first fragment cannot decode, hence the placeholder');
    });

    test('two photos come back as two, not four', () {
      final saved = PhotoPathsCodec.encode([uri('AAAA'), uri('BBBB')]);
      expect(PhotoPathsCodec.decode(saved), hasLength(2));
    });
  });

  group('round trip', () {
    test('several photos survive in order', () {
      final photos = [uri('AAAA'), uri('BBBB'), uri('CCCC')];
      expect(PhotoPathsCodec.decode(PhotoPathsCodec.encode(photos)), photos);
    });

    test('a long realistic payload survives intact', () {
      // Base64 of a kilobyte of bytes: plenty of + and / characters.
      final bytes = List<int>.generate(1024, (i) => (i * 37) % 256);
      final photo = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final read = PhotoPathsCodec.decode(PhotoPathsCodec.encode([photo]));
      expect(read!.single, photo);
      // And it still decodes to the original bytes.
      expect(base64Decode(read.single.split(',').last), bytes);
    });

    test('file paths still work, for whatever still uses them', () {
      final paths = ['/data/user/0/app/files/a.jpg', '/storage/b.jpg'];
      expect(PhotoPathsCodec.decode(PhotoPathsCodec.encode(paths)), paths);
    });

    test('no photos is an empty column, not an empty array', () {
      expect(PhotoPathsCodec.encode(null), isNull);
      expect(PhotoPathsCodec.encode([]), isNull);
    });
  });

  group('recovering photos already on the phone', () {
    test('one comma-joined data URI is put back together', () {
      // Exactly what is sitting in the database right now.
      final legacy = [uri()].join(',');
      final read = PhotoPathsCodec.decode(legacy);
      expect(read, hasLength(1));
      expect(read!.single, uri());
    });

    test('and the recovered photo actually decodes to an image', () {
      final bytes = List<int>.generate(300, (i) => (i * 11) % 256);
      final legacy = ['data:image/jpeg;base64,${base64Encode(bytes)}'].join(',');
      final read = PhotoPathsCodec.decode(legacy)!;
      expect(base64Decode(read.single.split(',').last), bytes,
          reason: 'recovery has to give back the original bytes');
    });

    test('several comma-joined data URIs are separated correctly', () {
      final photos = [uri('AAAA'), uri('BBBB'), uri('CCCC')];
      final read = PhotoPathsCodec.decode(photos.join(','));
      expect(read, photos);
    });

    test('a payload containing no comma is still one photo', () {
      // Base64 never contains a comma, so the only comma in a data URI is the
      // header separator — which is why cutting at `data:` is safe.
      expect(uri().split(',').length, 2);
    });

    test('legacy file paths are still split on the comma', () {
      expect(PhotoPathsCodec.decode('/a/one.jpg,/b/two.jpg'),
          ['/a/one.jpg', '/b/two.jpg']);
    });

    test('a single legacy file path comes back as one entry', () {
      expect(PhotoPathsCodec.decode('/a/one.jpg'), ['/a/one.jpg']);
    });
  });

  group('rubbish in the column', () {
    test('null and blank give no photos at all', () {
      expect(PhotoPathsCodec.decode(null), isNull);
      expect(PhotoPathsCodec.decode(''), isNull);
      expect(PhotoPathsCodec.decode('   '), isNull);
    });

    test('an empty JSON array gives no photos', () {
      expect(PhotoPathsCodec.decode('[]'), isNull);
    });

    test('a JSON array with blanks in it drops them', () {
      expect(PhotoPathsCodec.decode('["a","","b"]'), ['a', 'b']);
    });

    test('something that starts like JSON but is not falls back', () {
      // Must not throw, and must not lose the content.
      expect(PhotoPathsCodec.decode('[not json'), isNotNull);
    });

    test('trailing commas do not become empty photos', () {
      expect(PhotoPathsCodec.decode('/a/one.jpg,,'), ['/a/one.jpg']);
    });
  });

  group('telling a broken photo from no photo', () {
    test('a well formed data URI looks like an image', () {
      expect(PhotoPathsCodec.looksLikeImage(uri()), isTrue);
    });

    test('a shredded fragment does not', () {
      expect(PhotoPathsCodec.looksLikeImage('data:image/jpeg;base64'), isFalse);
      expect(PhotoPathsCodec.looksLikeImage('/9j/4AAQSkZJRg'), isFalse);
    });

    test('a header with nothing after the comma does not', () {
      expect(PhotoPathsCodec.looksLikeImage('data:image/jpeg;base64,'), isFalse);
    });
  });
}
