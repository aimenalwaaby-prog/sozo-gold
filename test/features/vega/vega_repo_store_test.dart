import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soplay/features/vega/data/vega_repo_store.dart';

void main() {
  test('persists repositories and providers across store instances', () async {
    final persistence = _MemoryPersistence();
    final store = _store(persistence);

    final result = await store.addRepository('owner/repository');

    expect(result.errors, isEmpty);
    expect(store.repositories.single.id, 'owner/repository');
    expect(store.providers.map((VegaProvider p) => p.value),
        containsAll(<String>['alpha', 'beta']));

    await store.setInstalled('owner/repository', 'alpha', true);

    final restored = _store(persistence);
    expect(restored.repositories.single.id, 'owner/repository');
    expect(restored.installedProviders.single.value, 'alpha');
    expect(restored.availableProviders.single.value, 'beta');
  });

  test('removes one provider without removing its repository or siblings', () async {
    final persistence = _MemoryPersistence();
    final store = _store(persistence);
    await store.addRepository('owner/repository');

    await store.removeProvider('owner/repository', 'alpha');

    expect(store.repositories.single.id, 'owner/repository');
    expect(store.providers.map((VegaProvider p) => p.value), <String>['beta']);
  });

  test('removing a repository removes only its providers', () async {
    final persistence = _MemoryPersistence();
    final store = _store(persistence);
    await store.addRepository('owner/repository');
    await store.addRepository('other/repository');

    await store.removeRepository('owner/repository');

    expect(store.repositories.map((VegaRepo r) => r.id), <String>['other/repository']);
    expect(store.providers.every((VegaProvider p) => p.repoId == 'other/repository'), isTrue);
  });

  test('keeps cached providers when a refresh cannot fetch the manifest', () async {
    final persistence = _MemoryPersistence();
    final adapter = _FixtureAdapter();
    final store = _store(persistence, adapter: adapter);
    await store.addRepository('owner/repository');

    adapter.failManifest = true;
    final result = await store.refreshRepository('owner/repository');

    expect(result.errors, contains('manifest'));
    expect(store.providers.map((VegaProvider p) => p.value),
        containsAll(<String>['alpha', 'beta']));
  });

  test('does not publish an incomplete provider when a required module fails', () async {
    final persistence = _MemoryPersistence();
    final adapter = _FixtureAdapter()..failRequiredModule = 'stream';
    final store = _store(persistence, adapter: adapter);

    final result = await store.addRepository('owner/repository');

    expect(result.errors, contains('alpha'));
    expect(store.repositories, isEmpty);
    expect(store.providers, isEmpty);
  });
}

VegaRepoStore _store(_MemoryPersistence persistence, { _FixtureAdapter? adapter }) {
  final dio = Dio()..httpClientAdapter = adapter ?? _FixtureAdapter();
  return VegaRepoStore(dio: dio, persistence: persistence);
}

class _MemoryPersistence implements VegaRepoPersistence {
  final Map<String, String> values = <String, String>{};

  @override
  String? read(String key) => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _FixtureAdapter implements HttpClientAdapter {
  bool failManifest = false;
  String? failRequiredModule;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    if (failManifest && options.uri.path.endsWith('/manifest.json')) {
      return ResponseBody.fromString('unavailable', 503);
    }
    final path = options.uri.path;
    if (path.endsWith('/manifest.json')) {
      return ResponseBody.fromString(jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'value': 'alpha',
          'display_name': 'Alpha',
          'version': '1.0.0',
          'type': 'anime',
        },
        <String, dynamic>{
          'value': 'beta',
          'display_name': 'Beta',
          'version': '1.0.0',
          'type': 'anime',
        },
      ]), 200);
    }
    if (failRequiredModule != null && path.endsWith('/$failRequiredModule.js')) {
      return ResponseBody.fromString('missing', 503);
    }
    return ResponseBody.fromString('export default {};', 200);
  }

  @override
  void close({bool force = false}) {}
}
