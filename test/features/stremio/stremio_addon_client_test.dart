import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soplay/features/stremio/data/stremio_addon_client.dart';
import 'package:soplay/features/stremio/data/stremio_addon_store.dart';

void main() {
  group('StremioAddonClient URL and manifest validation', () {
    test('normalizes a base path and retains query and fragment', () {
      expect(StremioAddonClient.normalizeManifestUrl('https://example.com/addons?x=1').toString(),
          'https://example.com/addons/manifest.json?x=1');
      expect(StremioAddonClient.normalizeManifestUrl('https://example.com/manifest.json').path,
          '/manifest.json');
    });

    test('rejects non-http schemes, userinfo, and malformed URLs', () {
      for (final url in ['file:///tmp/addon', 'https://user:pass@example.com', 'not a url']) {
        expect(() => StremioAddonClient.normalizeManifestUrl(url),
            throwsA(isA<StremioAddonException>()));
      }
    });

    test('requires manifest fields and expected JSON types', () {
      expect(() => StremioAddonClient.validateManifest({'id': 'x'}),
          throwsA(isA<StremioAddonException>()));
      final manifest = StremioAddonClient.validateManifest({
        'id': 'addon.test', 'name': 'Test', 'version': '1.0.0',
        'resources': ['catalog', 'meta'], 'types': ['movie'], 'catalogs': [],
      });
      expect(manifest.id, 'addon.test');
    });
  });

  test('uses official catalog path including extra path segments', () async {
    final dio = Dio()..httpClientAdapter = _RecordingAdapter();
    final store = _UnusedStore();
    final client = StremioAddonClient(dio: dio, store: store);
    final result = await client.catalog('https://example.com/addon', 'movie', 'top', extra: ['genre', 'action']);
    expect(result.metas, isEmpty);
    expect((_recordedUri!).path, '/addon/catalog/movie/top/genre/action.json');
  });
}

Uri? _recordedUri;

class _RecordingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    _recordedUri = options.uri;
    return ResponseBody.fromString(jsonEncode({'metas': []}), 200,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

class _UnusedStore implements StremioAddonStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
