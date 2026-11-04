import 'dart:convert';

import 'package:dio/dio.dart';

import 'stremio_addon_models.dart';
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
    await _store.put(manifest.id, {'url': uri.toString(), 'manifest': json});
    return manifest;
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
      {List<String> extra = const []}) async => StremioCatalogResponse.fromJson(
        await _getJson(_resourceUri(baseUrl, ['catalog', type, id, ...extra], jsonSuffix: true)));

  /// Fetch metadata: /meta/{type}/{id}.json
  Future<StremioMeta> meta(String baseUrl, String type, String id) async =>
      StremioMeta.fromJson(await _getJson(_resourceUri(baseUrl, ['meta', type, id], jsonSuffix: true)));

  /// Fetch streams: /stream/{type}/{id}.json
  Future<StremioStreamResponse> streams(String baseUrl, String type, String id) async =>
      StremioStreamResponse.fromJson(await _getJson(_resourceUri(baseUrl, ['stream', type, id], jsonSuffix: true)));

  /// Fetch subtitles: /subtitles/{type}/{id}.json
  Future<StremioSubtitleResponse> subtitles(String baseUrl, String type, String id) async =>
      StremioSubtitleResponse.fromJson(await _getJson(_resourceUri(baseUrl, ['subtitles', type, id], jsonSuffix: true)));

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
    final cancelToken = CancelToken();
    final response = await _dio.getUri<Object?>(uri,
      options: Options(responseType: ResponseType.bytes, followRedirects: false,
        receiveDataWhenStatusError: false, connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout, onReceiveProgress: (received, total) {
          if (received > maxResponseBytes) {
            cancelToken.cancel('Addon response exceeds configured size limit.');
          }
        }),
      cancelToken: cancelToken);
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
