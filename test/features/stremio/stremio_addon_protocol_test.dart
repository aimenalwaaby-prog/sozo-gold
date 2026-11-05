import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soplay/features/stremio/data/stremio_addon_client.dart';
import 'package:soplay/features/stremio/data/stremio_addon_store.dart';

void main() {
  const addonUrl = 'https://addons.example.test/addon';

  group('Stremio Addon Protocol resources', () {
    test('catalog uses the protocol path and parses metas', () async {
      final adapter = _ResponseAdapter({
        'metas': [
          {'id': 'movie-1', 'type': 'movie', 'name': 'Example'},
        ],
      });
      final client = _client(adapter);

      final result = await client.catalog(
        addonUrl,
        'movie',
        'top',
        extra: ['genre', 'action'],
      );

      expect(adapter.requestedUris.single.path,
          '/addon/catalog/movie/top/genre/action.json');
      expect(result.metas.single.id, 'movie-1');
      expect(result.metas.single.name, 'Example');
    });

    test('meta unwraps the protocol meta object', () async {
      final adapter = _ResponseAdapter({
        'meta': {'id': 'series-1', 'type': 'series', 'name': 'Example Series'},
      });
      final client = _client(adapter);

      final result = await client.meta(addonUrl, 'series', 'series-1');

      expect(adapter.requestedUris.single.path, '/addon/meta/series/series-1.json');
      expect(result.id, 'series-1');
      expect(result.type, 'series');
      expect(result.name, 'Example Series');
    });

    test('streams uses the protocol path and parses stream entries', () async {
      final adapter = _ResponseAdapter({
        'streams': [
          {'name': 'Source', 'title': '1080p', 'url': 'https://video.example.test/a.m3u8'},
        ],
      });
      final client = _client(adapter);

      final result = await client.streams(addonUrl, 'movie', 'movie-1');

      expect(adapter.requestedUris.single.path, '/addon/stream/movie/movie-1.json');
      expect(result.streams.single.name, 'Source');
      expect(result.streams.single.url, 'https://video.example.test/a.m3u8');
    });

    test('subtitles uses the protocol path and parses subtitle entries', () async {
      final adapter = _ResponseAdapter({
        'subtitles': [
          {'id': 'sub-1', 'lang': 'ar', 'url': 'https://subs.example.test/a.vtt'},
        ],
      });
      final client = _client(adapter);

      final result = await client.subtitles(addonUrl, 'movie', 'movie-1');

      expect(adapter.requestedUris.single.path,
          '/addon/subtitles/movie/movie-1.json');
      expect(result.subtitles.single.id, 'sub-1');
      expect(result.subtitles.single.lang, 'ar');
      expect(result.subtitles.single.url, 'https://subs.example.test/a.vtt');
    });

    test('rejects an unexpected meta response shape', () async {
      final client = _client(_ResponseAdapter({'id': 'movie-1'}));

      await expectLater(
        client.meta(addonUrl, 'movie', 'movie-1'),
        throwsA(isA<StremioAddonException>()),
      );
    });

    test('rejects non-object entries in resource arrays', () async {
      final client = _client(_ResponseAdapter({'streams': ['not-an-object']}));

      await expectLater(
        client.streams(addonUrl, 'movie', 'movie-1'),
        throwsA(isA<StremioAddonException>()),
      );
    });
  });

  group('Stremio Addon Protocol failures', () {
    test('maps non-success HTTP status to a protocol exception', () async {
      final client = _client(_ResponseAdapter({'error': 'offline'}, statusCode: 503));

      await expectLater(
        client.catalog(addonUrl, 'movie', 'top'),
        throwsA(
          isA<StremioAddonException>().having(
            (error) => error.message,
            'message',
            contains('HTTP 503'),
          ),
        ),
      );
    });

    test('maps connection failures without leaking the request URL', () async {
      final client = _client(_FailingAdapter());

      await expectLater(
        client.catalog(addonUrl, 'movie', 'top'),
        throwsA(
          isA<StremioAddonException>()
              .having((error) => error.message, 'message', contains('connectionTimeout'))
              .having((error) => error.message, 'message', isNot(contains('addons.example.test'))),
        ),
      );
    });

    test('rejects malformed JSON and non-object JSON responses', () async {
      final malformed = _client(_ResponseAdapter.raw('not-json'));
      final listResponse = _client(_ResponseAdapter.raw('[1,2,3]'));

      await expectLater(
        malformed.catalog(addonUrl, 'movie', 'top'),
        throwsA(isA<StremioAddonException>()),
      );
      await expectLater(
        listResponse.catalog(addonUrl, 'movie', 'top'),
        throwsA(isA<StremioAddonException>()),
      );
    });
  });

  test('adding the same manifest updates its record and deletion is isolated', () async {
    final store = _MemoryStore();
    final adapter = _ResponseAdapter({
      'id': 'addon.one',
      'name': 'Addon One',
      'version': '1.0.0',
      'resources': ['catalog'],
      'types': ['movie'],
      'catalogs': [],
    });
    final client = _client(adapter, store: store);

    await client.addOrUpdate(addonUrl);
    await client.addOrUpdate(addonUrl);
    await store.put('addon.two', {'url': 'https://other.example.test/manifest.json'});
    expect(client.addons.keys, containsAll(['addon.one', 'addon.two']));
    expect(adapter.requestedUris, hasLength(2));

    await client.removeAddon('addon.one');

    expect(client.getAddon('addon.one'), isNull);
    expect(client.getAddon('addon.two'), isNotNull);
  });
}

StremioAddonClient _client(HttpClientAdapter adapter, {StremioAddonStore? store}) {
  return StremioAddonClient(
    dio: Dio()..httpClientAdapter = adapter,
    store: store ?? _MemoryStore(),
  );
}

class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter(this.payload, {this.statusCode = 200})
      : _rawBody = null;

  _ResponseAdapter.raw(String body, {this.statusCode = 200})
      : payload = null,
        _rawBody = body;

  final Object? payload;
  final String? _rawBody;
  final int statusCode;
  final requestedUris = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUris.add(options.uri);
    final body = _rawBody ?? jsonEncode(payload);
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionTimeout,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryStore implements StremioAddonStore {
  final _records = <String, Map<String, dynamic>>{};

  @override
  Future<void> put(String id, Map<String, dynamic> record) async {
    _records[id] = Map<String, dynamic>.from(record);
  }

  @override
  Map<String, dynamic>? get(String id) => _records[id];

  @override
  Map<String, Map<String, dynamic>> all() => {
        for (final entry in _records.entries)
          entry.key: Map<String, dynamic>.from(entry.value),
      };

  @override
  Future<void> remove(String id) async {
    _records.remove(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
