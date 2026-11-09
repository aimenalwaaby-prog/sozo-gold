import 'package:soplay/core/content/content_mode.dart';
import 'package:soplay/features/profile/domain/entities/provider_entity.dart';

/// Safety boundary for the viewing catalogue.
///
/// The archive supplied for this task is a visual curation reference, not an
/// executable source repository. Provider metadata is therefore treated as
/// untrusted: a source is shown in the viewing list only when it is a video
/// provider, is not marked NSFW, and does not contain a known adult marker.
/// Manga and novel providers remain available to their future workstreams but
/// never leak into the viewing/server list.
abstract final class WatchSourcePolicy {
  static const _blockedMarkers = <String>{
    '18+',
    'adult',
    'ecchi',
    'ero',
    'hentai',
    'lewd',
    'nhentai',
    'nsfw',
    'nude',
    'porn',
    'rule34',
    'sex',
    'xxx',
  };

  static bool allowsProvider(ProviderEntity provider) {
    if (provider.nsfw || provider.id.contentMode != ContentMode.video) {
      return false;
    }
    final haystack = [
      provider.id,
      provider.name,
      provider.category,
      provider.repo,
      provider.lang,
    ].join(' ').toLowerCase();
    return !_blockedMarkers.any((marker) => haystack.contains(marker));
  }

  static bool allowsCatalogItem({
    required String name,
    required String id,
    required String repo,
    required String lang,
    required bool nsfw,
  }) {
    if (nsfw) return false;
    final haystack = '$name $id $repo $lang'.toLowerCase();
    return !_blockedMarkers.any((marker) => haystack.contains(marker));
  }
}
