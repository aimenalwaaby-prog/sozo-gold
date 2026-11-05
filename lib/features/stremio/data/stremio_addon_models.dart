/// Typed, permissive wrappers for Stremio Addon Protocol JSON objects.
/// Unknown protocol fields are retained to remain forward-compatible.
library;

typedef StremioJson = Map<String, dynamic>;

class StremioManifest {
  StremioManifest.fromJson(StremioJson json)
    : json = Map.unmodifiable(json),
      id = json['id'] as String,
      name = json['name'] as String,
      version = json['version'] as String,
      resources = List.unmodifiable(json['resources'] as List),
      types = List.unmodifiable(json['types'] as List),
      catalogs = List.unmodifiable(json['catalogs'] as List);

  final StremioJson json;
  final String id;
  final String name;
  final String version;
  final List<dynamic> resources;
  final List<dynamic> types;
  final List<dynamic> catalogs;
}

class StremioCatalogResponse {
  StremioCatalogResponse.fromJson(StremioJson json)
    : metas = List.unmodifiable(
        (json['metas'] as List? ?? const []).map(
          (e) => StremioMeta.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
  final List<StremioMeta> metas;
}

class StremioMeta {
  StremioMeta.fromJson(this.json);
  final StremioJson json;
  String? get id => json['id'] as String?;
  String? get type => json['type'] as String?;
  String? get name => json['name'] as String?;
  String? get poster => json['poster'] as String?;
  String? get background => json['background'] as String?;
  String? get description => json['description'] as String?;
  String? get year => json['year']?.toString();
  String? get genre => json['genre'] is List
      ? (json['genre'] as List).whereType<String>().join(', ')
      : json['genre'] as String?;
  List<StremioVideo> get videos {
    final value = json['videos'];
    if (value is! List) return const [];
    return List.unmodifiable(
      value.whereType<Map>().map(
        (item) => StremioVideo.fromJson(Map<String, dynamic>.from(item)),
      ),
    );
  }
}

class StremioVideo {
  const StremioVideo(this.json);
  factory StremioVideo.fromJson(StremioJson json) =>
      StremioVideo(Map.unmodifiable(json));
  final StremioJson json;
  String? get id => json['id'] as String?;
  String? get title => json['title'] as String?;
  String? get overview => json['overview'] as String?;
  int? get season => (json['season'] as num?)?.toInt();
  int? get episode => (json['episode'] as num?)?.toInt();
  String? idFor(String parentId) {
    final explicit = id;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final s = season;
    final e = episode;
    return s == null || e == null ? null : '$parentId:$s:$e';
  }
}

class StremioStreamResponse {
  StremioStreamResponse.fromJson(StremioJson json)
    : streams = List.unmodifiable(
        (json['streams'] as List? ?? const []).map(
          (e) => StremioStream.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
  final List<StremioStream> streams;
}

class StremioStream {
  StremioStream.fromJson(this.json);
  final StremioJson json;
  String? get url => json['url'] as String?;
  String? get name => json['name'] as String?;
  String? get title => json['title'] as String?;
  String? get type => json['type'] as String?;
  Map<String, String> get headers => _protocolHeaders(json);
}

class StremioSubtitleResponse {
  StremioSubtitleResponse.fromJson(StremioJson json)
    : subtitles = List.unmodifiable(
        (json['subtitles'] as List? ?? const []).map(
          (e) => StremioSubtitle.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
  final List<StremioSubtitle> subtitles;
}

class StremioSubtitle {
  StremioSubtitle.fromJson(this.json);
  final StremioJson json;
  String? get id => json['id'] as String?;
  String? get url => json['url'] as String?;
  String? get lang => json['lang'] as String?;
  Map<String, String> get headers => _protocolHeaders(json);
}

Map<String, String> _protocolHeaders(StremioJson json) {
  Object? raw = json['headers'];
  if (raw is! Map) {
    final hints = json['behaviorHints'];
    final proxyHeaders = hints is Map ? hints['proxyHeaders'] : null;
    raw = proxyHeaders is Map ? proxyHeaders['request'] : null;
  }
  if (raw is! Map) return const {};
  return Map.unmodifiable({
    for (final entry in raw.entries)
      if (entry.key is String && entry.value is String)
        entry.key as String: entry.value as String,
  });
}
