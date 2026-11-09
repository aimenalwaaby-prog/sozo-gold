import 'dart:convert';

import 'package:dio/dio.dart';

import 'stremio_addon_models.dart';
import 'package:soplay/features/sources/domain/watch_source_policy.dart';
import 'stremio_addon_store.dart';

/// Thrown for invalid addon URLs/manifests or malformed protocol responses.
class StremioAddonException implements Exception {
  const StremioAddonException(this.message);
  final String message;
  @override
  String toString() => 'StremioAddonException: $message';
}

/// Client for the HTTP Stremio Addon Protocol. Inject Dio and a store; request
/// size and timeouts are bounded, and only HTTP(S) URLs without userinfo pass.
class StremioAddonClient {
  StremioAddonClient({required Dio dio, required StremioAddonStore store,
    this.maxResponseBytes = 2 * 1024 * 1024,
    this.connectTimeout = const Duration(seconds: 8),
    this.receiveTimeout = const Duration(seconds: 15)}) : _dio = dio, _store = store;

  final Dio _dio;
  final StremioAddonStore _store;
  final int maxResponseBytes;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// Normalize an addon base URL or manifest URL to the manifest endpoint.
  static Uri normalizeManifestUrl(String value) {
    final input = value.trim();
    final uri = Uri.tryParse(input);
    if (uri == null || !uri.isAbsolute || !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const StremioAddonException('URL must be a valid HTTP(S) URL without userinfo.');
    }
    final segments = [...uri.pathSegments];
    if (segments.isEmpty || segments.last.toLowerCase() != 'manifest.json') segments.add('manifest.json');
    return uri.replace(pathSegments: segments);
  }

  /// Download, validate, and persist a manifest. Existing entry with the same
  /// manifest id is updated; other addon records are not touched.
  Future<StremioManifest> addOrUpdate(String url) async {
    final uri = normalizeManifestUrl(url);
    final json = await _getJson(uri);
    final manifest = validateManifest(json);
    final hints = json['behaviorHints'];
    final adult = hints is Map && hints['adult'] == true;
    if (!WatchSourcePolicy.allowsCatalogItem(
      name: manifest.name,
      id: manifest.id,
      repo: uri.host,
      lang: '',
      nsfw: adult,
    )) {
      throw const StremioAddonException('Adult or blocked addons are not allowed.');
    }
    await _store.put(manifest.id, {'url': uri.toString(), 'manifest': json});
    return manifest;
  }

  /// Official viewing addons sourced from the Stremio official-addons index.
  /// The local-file addon is intentionally excluded; it cannot run in Sozo.
  static const officialViewingAddonUrls = <String>[
    'https://v3-cinemeta.strem.io/manifest.json',
    'https://v3-channels.strem.io/manifest.json',
    'https://watchhub.strem.io/manifest.json',
    'https://caching.stremio.net/publicdomainmovies.now.sh/manifest.json',
    'https://opensubtitles-v3.strem.io/manifest.json',
    'https://opensubtitles.strem.io/stremio/v1',
  ];

  /// Installs or refreshes the safe official addons once the page is opened.
  Future<int> ensureOfficialViewingAddons() async {
    var count = 0;
    for (final url in officialViewingAddonUrls) {
      try {
        await addOrUpdate(url);
        count++;
      } on Object {
        // One unavailable official addon must not hide the others.
      }
    }
    return count;
  }

  /// Read previously stored raw addon record by manifest id.
  Map<String, dynamic>? getAddon(String id) => _store.get(id);

  /// List all stored addon records in this store's namespace.
  Map<String, Map<String, dynamic>> get addons => _store.all();

  /// Remove one addon by id only.
  Future<void> removeAddon(String id) => _store.remove(id);

  /// Validate required Addon Protocol manifest fields and their JSON types.
  static StremioManifest validateManifest(Map<String, dynamic> json) {
    for (final field in ['id', 'name', 'version']) {
      if (json[field] is! String || (json[field] as String).trim().isEmpty) {
        throw StremioAddonException('Manifest requires non-empty string $field.');
      }
    }
    for (final field in ['resources', 'types', 'catalogs']) {
      if (json[field] is! List) throw StremioAddonException('Manifest requires array $field.');
    }
    if ((json['resources'] as List).isEmpty || (json['types'] as List).isEmpty) {
      throw const StremioAddonException('Manifest resources and types must not be empty.');
    }
    return StremioManifest.fromJson(json);
  }

  /// Fetch catalog entries: /catalog/{type}/{id}[/{extra...}].json
  Future<StremioCatalogResponse> catalog(String baseUrl, String type, String id,
      {List<String> extra = const []}) async {
    final json = await _getJson(
      _resourceUri(baseUrl, ['catalog', type, id, ...extra], jsonSuffix: true),
    );
    _validateObjectList(json, 'metas');
    return StremioCatalogResponse.fromJson(json);
  }

  /// Fetch metadata: /meta/{type}/{id}.json
  Future<StremioMeta> meta(String baseUrl, String type, String id) async {
    final json = await _getJson(
      _resourceUri(baseUrl, ['meta', type, id], jsonSuffix: true),
    );
    final value = json['meta'];
    if (value is! Map) {
      throw const StremioAddonException('Invalid meta response: expected an object in "meta".');
    }
    return StremioMeta.fromJson(Map<String, dynamic>.from(value));
  }

  /// Fetch streams: /stream/{type}/{id}.json
  Future<StremioStreamResponse> streams(String baseUrl, String type, String id) async {
    final json = await _getJson(
      _resourceUri(baseUrl, ['stream', type, id], jsonSuffix: true),
    );
    _validateObjectList(json, 'streams');
    return StremioStreamResponse.fromJson(json);
  }

  /// Fetch subtitles: /subtitles/{type}/{id}.json
  Future<StremioSubtitleResponse> subtitles(String baseUrl, String type, String id) async {
    final json = await _getJson(
      _resourceUri(baseUrl, ['subtitles', type, id], jsonSuffix: true),
    );
    _validateObjectList(json, 'subtitles');
    return StremioSubtitleResponse.fromJson(json);
  }

  void _validateObjectList(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value == null) return;
    if (value is! List || value.any((item) => item is! Map)) {
      throw StremioAddonException('Invalid response: "$field" must be an array of objects.');
    }
  }

  Uri _resourceUri(String baseUrl, List<String> parts, {required bool jsonSuffix}) {
    final manifest = normalizeManifestUrl(baseUrl);
    final prefix = manifest.pathSegments.sublist(0, manifest.pathSegments.length - 1);
    final safe = parts.map((part) {
      if (part.isEmpty || part.contains('/') || part == '.' || part == '..') {
        throw const StremioAddonException('Invalid resource path segment.');
      }
      return part;
    }).toList();
    if (jsonSuffix) safe[safe.length - 1] = '${safe.last}.json';
    return manifest.replace(pathSegments: [...prefix, ...safe]);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    late final Response<Object?> response;
    try {
      response = await _dio.getUri<Object?>(uri,
        options: Options(responseType: ResponseType.bytes, followRedirects: false,
          receiveDataWhenStatusError: false, connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout, validateStatus: (_) => true));
    } on DioException catch (error) {
      throw StremioAddonException('Addon request failed (${error.type.name}).');
    }
    final data = response.data;
    if (data is! List<int> || data.length > maxResponseBytes) {
      throw const StremioAddonException('Response is not bytes or exceeds size limit.');
    }
    if ((response.statusCode ?? 500) < 200 || (response.statusCode ?? 500) >= 300) {
      throw StremioAddonException('Addon returned HTTP ${response.statusCode}.');
    }
    try {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is! Map) throw const FormatException('Expected JSON object');
      return Map<String, dynamic>.from(decoded);
    } on FormatException catch (error) {
      throw StremioAddonException('Invalid JSON response: $error');
    }
  }
}
