import 'package:flutter_test/flutter_test.dart';
import 'package:soplay/features/stremio/data/stremio_addon_models.dart';

void main() {
  test('parses series videos and preserves protocol episode identifiers', () {
    final meta = StremioMeta.fromJson({
      'id': 'series-id',
      'type': 'series',
      'name': 'A Series',
      'videos': [
        {'id': 'series-id:1:1', 'season': 1, 'episode': 1, 'title': 'Pilot'},
        {'season': 2, 'episode': 4, 'title': 'Finale', 'overview': 'End.'},
        'invalid',
      ],
    });

    expect(meta.videos, hasLength(2));
    expect(meta.videos.first.idFor(meta.id!), 'series-id:1:1');
    expect(meta.videos.last.idFor(meta.id!), 'series-id:2:4');
    expect(meta.videos.last.overview, 'End.');
  });

  test('keeps direct and proxy request headers from streams and subtitles', () {
    final stream = StremioStream.fromJson({
      'url': 'https://video.example.test/file.m3u8',
      'type': 'application/vnd.apple.mpegurl',
      'behaviorHints': {
        'proxyHeaders': {
          'request': {'Referer': 'https://example.test'},
        },
      },
    });
    final subtitle = StremioSubtitle.fromJson({
      'url': 'https://sub.example.test/ar.vtt',
      'headers': {'Authorization': 'Bearer token'},
    });

    expect(stream.type, 'application/vnd.apple.mpegurl');
    expect(stream.headers, {'Referer': 'https://example.test'});
    expect(subtitle.headers, {'Authorization': 'Bearer token'});
  });
}
