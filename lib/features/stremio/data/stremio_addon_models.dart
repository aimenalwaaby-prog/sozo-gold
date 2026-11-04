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
      : metas = List.unmodifiable((json['metas'] as List? ?? const [])
            .map((e) => StremioMeta.fromJson(Map<String, dynamic>.from(e as Map))));
  final List<StremioMeta> metas;
}

class StremioMeta {
  StremioMeta.fromJson(this.json);
  final StremioJson json;
  String? get id => json['id'] as String?;
  String? get type => json['type'] as String?;
  String? get name => json['name'] as String?;
  String? get poster => json['poster'] as String?;
}

class StremioStreamResponse {
  StremioStreamResponse.fromJson(StremioJson json)
      : streams = List.unmodifiable((json['streams'] as List? ?? const [])
            .map((e) => StremioStream.fromJson(Map<String, dynamic>.from(e as Map))));
  final List<StremioStream> streams;
}

class StremioStream {
  StremioStream.fromJson(this.json);
  final StremioJson json;
  String? get url => json['url'] as String?;
  String? get name => json['name'] as String?;
  String? get title => json['title'] as String?;
}

class StremioSubtitleResponse {
  StremioSubtitleResponse.fromJson(StremioJson json)
      : subtitles = List.unmodifiable((json['subtitles'] as List? ?? const [])
            .map((e) => StremioSubtitle.fromJson(Map<String, dynamic>.from(e as Map))));
  final List<StremioSubtitle> subtitles;
}

class StremioSubtitle {
  StremioSubtitle.fromJson(this.json);
  final StremioJson json;
  String? get id => json['id'] as String?;
  String? get url => json['url'] as String?;
  String? get lang => json['lang'] as String?;
}
