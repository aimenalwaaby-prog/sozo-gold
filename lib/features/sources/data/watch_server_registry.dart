import 'package:soplay/core/aniyomi/aniyomi_channel.dart';
import 'package:soplay/core/cloudstream/cloudstream_channel.dart';
import 'package:soplay/core/di/injection.dart';
import 'package:soplay/features/extensions/data/mangayomi_repo_store.dart';

/// Curated video repositories shipped as embedded viewing servers.
/// Manga, novel, and their existing repositories are deliberately not listed here.
class WatchServerRegistry {
  WatchServerRegistry._();

  static const cloudStreamRepositories = <String>[
    'https://raw.githubusercontent.com/Abodabodd/re-3arabi/refs/heads/main/repo.json',
    'https://raw.githubusercontent.com/dhomred/cloudstream-extensions-arabic/master/repo.json',
    'https://raw.githubusercontent.com/aymanbest/Arabico/main/repo.json',
    'https://raw.githubusercontent.com/rhoulou/TotalArab/main/repo.json',
    'https://codeberg.org/cloudstream/arab/raw/branch/builds/repo.json',
    'https://raw.githubusercontent.com/alyabroudy1/Abu-Repo/builds/repo.json',
  ];

  static const aniyomiRepositories = <String>[
    'https://raw.githubusercontent.com/salmanbappi/extensions-repo/main/index.min.json',
    'https://raw.githubusercontent.com/yuzono/anime-repo/repo/index.min.json',
    'https://raw.githubusercontent.com/msrofficial/anime-repo/repo/index.min.json',
    'https://raw.githubusercontent.com/aniyomi-addons/anime-extensions-repo/repo/index.min.json',
    'https://raw.githubusercontent.com/Kholbi/aniyomiext/repo/index.min.json',
    'https://raw.githubusercontent.com/Confused-Creature-180/aniyomi-extensions/repo/index.min.json',
  ];

  static const mangayomiAnimeRepositories = <String>[
    'https://m2k3a.github.io/mangayomi-extensions/anime_index.json',
    'https://raw.githubusercontent.com/kashrtx/yomi-extensions/refs/heads/main/anime_index.json',
  ];

  static Future<void>? _inFlight;

  /// Installs only the curated video sources internally. Repeated calls are safe.
  static Future<void> ensureInstalled() {
    return _inFlight ??= _install().whenComplete(() => _inFlight = null);
  }

  static Future<void> _install() async {
    if (CloudStreamChannel.isSupported) {
      final current = await CloudStreamChannel.listRepos();
      final installed = _urls(current);
      for (final url in cloudStreamRepositories) {
        if (!installed.contains(url)) await CloudStreamChannel.addRepo(url);
      }
    }
    if (AniyomiChannel.isSupported) {
      final current = await AniyomiChannel.listRepos();
      final installed = _urls(current);
      for (final url in aniyomiRepositories) {
        if (!installed.contains(url)) await AniyomiChannel.addRepo(url);
      }
    }
    final store = getIt<MangayomiRepoStore>();
    final installed = store.repos().toSet();
    for (final url in mangayomiAnimeRepositories) {
      if (!installed.contains(url)) {
        try {
          await store.addRepo(url);
        } catch (_) {
          // A single unavailable server must not hide the remaining servers.
        }
      }
    }
  }

  static Set<String> _urls(List<dynamic> entries) => entries
      .map((entry) => entry is String ? entry : entry is Map ? entry['url'] : null)
      .whereType<String>()
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toSet();
}
