import 'package:flutter/foundation.dart';
import 'package:soplay/features/stremio/data/stremio_addon_client.dart';
import 'package:soplay/features/vega/data/vega_repo_store.dart';

/// Built-in source registries. They are only seeded when absent; users can
/// remove or disable every entry from the existing management screens.
class BuiltinExtensionSources {
  BuiltinExtensionSources._();

  static const vegaRepositories = <String>['Zenda-Cross/vega-providers'];

  static const stremioManifests = <String>[
    'https://v3-cinemeta.strem.io/manifest.json',
    'https://opensubtitles-v3.strem.io/manifest.json',
    'https://torrentio.strem.fun/manifest.json',
  ];

  static Future<void> ensureDefaults({
    required VegaRepoStore vega,
    required StremioAddonClient stremio,
  }) async {
    await Future.wait([_seedVega(vega), _seedStremio(stremio)]);
  }

  static Future<void> _seedVega(VegaRepoStore store) async {
    for (final input in vegaRepositories) {
      try {
        final expected = input.split('/');
        final exists =
            expected.length == 2 &&
            store.repositories.any(
              (repo) => repo.owner == expected[0] && repo.name == expected[1],
            );
        if (!exists) {
          await store.addRepository(input);
        } else {
          final repoId = '${expected[0]}/${expected[1]}';
          final hasProvider = store.providers.any((p) => p.repoId == repoId);
          if (!hasProvider) await store.refreshRepository(repoId);
        }
      } catch (error) {
        debugPrint('[sources] default Vega repository skipped: $error');
      }
    }
  }

  static Future<void> _seedStremio(StremioAddonClient client) async {
    for (final manifestUrl in stremioManifests) {
      try {
        final normalized = StremioAddonClient.normalizeManifestUrl(
          manifestUrl,
        ).toString();
        final exists = client.addons.values.any(
          (record) => record['url']?.toString() == normalized,
        );
        if (!exists) await client.addOrUpdate(manifestUrl);
      } catch (error) {
        // One unavailable public addon must never prevent the others or startup.
        debugPrint('[sources] default Stremio addon skipped: $error');
      }
    }
  }
}
