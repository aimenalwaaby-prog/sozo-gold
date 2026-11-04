/// Minimal data layer for Vega provider repositories.
///
/// This stores source files only; it does not evaluate JavaScript or make a
/// provider executable. GitHub repositories are currently the only accepted
/// repository source. The Vega guide describes `manifest.json` entries and
/// `dist/<value>/{catalog,posts,meta,stream,episodes,settings}.js` modules.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

const String vegaReposStorageKey = 'vega_repo_store.repos.v1';
const String vegaProvidersStorageKey = 'vega_repo_store.providers.v1';
const int vegaMaxManifestBytes = 512 * 1024;
const int vegaMaxModuleBytes = 2 * 1024 * 1024;
const List<String> vegaRequiredModuleGroups = <String>[
  'catalog', 'posts', 'meta', 'stream',
];
const List<String> vegaOptionalModuleGroups = <String>['episodes', 'settings'];
const List<String> vegaModuleGroups = <String>[
  ...vegaRequiredModuleGroups,
  ...vegaOptionalModuleGroups,
];

/// Persistence port. A single [write] is used to publish each changed group.
abstract interface class VegaRepoPersistence {
  String? read(String key);
  Future<void> write(String key, String value);
}

/// Stores JSON values in the app's already-open shared settings box.
class HiveVegaRepoPersistence implements VegaRepoPersistence {
  HiveVegaRepoPersistence(this.settingsBox);
  final Box settingsBox;

  @override
  String? read(String key) => settingsBox.get(key) as String?;

  @override
  Future<void> write(String key, String value) async {
    await settingsBox.put(key, value);
  }
}

/// Persisted repository record.
class VegaRepo {
  const VegaRepo({required this.url, required this.owner, required this.name,
    this.branch = 'main', this.lastRefreshed});
  final String url;
  final String owner;
  final String name;
  final String branch;
  final DateTime? lastRefreshed;

  String get id => '$owner/$name';
  Map<String, dynamic> toJson() => <String, dynamic>{
    'url': url, 'owner': owner, 'name': name, 'branch': branch,
    if (lastRefreshed != null) 'lastRefreshed': lastRefreshed!.toIso8601String(),
  };
  factory VegaRepo.fromJson(Map<String, dynamic> json) => VegaRepo(
    url: json['url'] as String, owner: json['owner'] as String,
    name: json['name'] as String, branch: json['branch'] as String? ?? 'main',
    lastRefreshed: json['lastRefreshed'] == null ? null :
      DateTime.tryParse(json['lastRefreshed'] as String),
  );
}

/// Manifest metadata plus the six downloaded source modules.
class VegaProvider {
  const VegaProvider({required this.repoId, required this.value,
    required this.displayName, required this.version, required this.type,
    required this.modules, this.icon, this.installed = false});
  final String repoId;
  final String value;
  final String displayName;
  final String version;
  final String type;
  final String? icon;
  final bool installed;
  final Map<String, String> modules;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'repoId': repoId, 'value': value, 'displayName': displayName,
    'version': version, 'type': type, 'icon': icon, 'installed': installed,
    'modules': modules,
  };
  factory VegaProvider.fromJson(Map<String, dynamic> json) => VegaProvider(
    repoId: json['repoId'] as String, value: json['value'] as String,
    displayName: json['displayName'] as String,
    version: json['version'] as String, type: json['type'] as String,
    icon: json['icon'] as String?, installed: json['installed'] == true,
    modules: (json['modules'] as Map).map((dynamic k, dynamic v) =>
      MapEntry<String, String>(k as String, v as String)),
  );
}

/// Result of one fetch/update pass; failures are isolated per provider.
class VegaRefreshResult {
  const VegaRefreshResult({required this.providers, required this.errors});
  final List<VegaProvider> providers;
  final Map<String, String> errors;
}

/// Repository registry and source downloader. No runtime execution is provided.
class VegaRepoStore {
  VegaRepoStore({required Dio dio, required VegaRepoPersistence persistence,
    this.maxManifestBytes = vegaMaxManifestBytes,
    this.maxModuleBytes = vegaMaxModuleBytes})
      : _dio = dio, _persistence = persistence;

  final Dio _dio;
  final VegaRepoPersistence _persistence;
  final int maxManifestBytes;
  final int maxModuleBytes;

  List<VegaRepo> get repositories => _decodeList<VegaRepo>(
    _persistence.read(vegaReposStorageKey), VegaRepo.fromJson);
  List<VegaProvider> get providers => _decodeList<VegaProvider>(
    _persistence.read(vegaProvidersStorageKey), VegaProvider.fromJson);
  List<VegaProvider> get availableProviders =>
      providers.where((VegaProvider p) => !p.installed).toList(growable: false);
  List<VegaProvider> get installedProviders =>
      providers.where((VegaProvider p) => p.installed).toList(growable: false);

  /// Adds and fetches a repository. If retrieval fails, no empty/broken repo is saved.
  Future<VegaRefreshResult> addRepository(String input) async {
    final repo = _parseGithub(input);
    if (repositories.any((VegaRepo r) => r.id == repo.id)) {
      return refreshRepository(repo.id);
    }
    final result = await _fetchAndMerge(repo);
    if (result.errors['manifest'] != null) return result;
    await _writeRepos(<VegaRepo>[...repositories, repo.copyRefreshed()]);
    return result;
  }

  /// Refreshes one configured repo; malformed/partial remote data leaves cached
  /// providers intact. Each provider's full module group is committed at once.
  Future<VegaRefreshResult> refreshRepository(String repoId) async {
    final repo = repositories.where((VegaRepo r) => r.id == repoId).firstOrNull;
    if (repo == null) throw ArgumentError.value(repoId, 'repoId', 'Unknown repo');
    return _fetchAndMerge(repo);
  }

  /// Removes repository and only its providers; unrelated providers remain.
  Future<void> removeRepository(String repoId) async {
    final nextRepos = repositories.where((VegaRepo r) => r.id != repoId).toList();
    final nextProviders = providers.where((VegaProvider p) => p.repoId != repoId).toList();
    await _writeProviders(nextProviders);
    await _writeRepos(nextRepos);
  }

  /// Removes just one provider, leaving its repository and siblings untouched.
  Future<void> removeProvider(String repoId, String value) async {
    final next = providers.where((VegaProvider p) =>
      !(p.repoId == repoId && p.value == value)).toList();
    await _writeProviders(next);
  }

  /// Toggles local installed/available state without confusing it with repo membership.
  Future<void> setInstalled(String repoId, String value, bool installed) async {
    final next = providers.map((VegaProvider p) => p.repoId == repoId && p.value == value
      ? VegaProvider(repoId: p.repoId, value: p.value, displayName: p.displayName,
        version: p.version, type: p.type, icon: p.icon, modules: p.modules,
        installed: installed) : p).toList();
    await _writeProviders(next);
  }

  Future<VegaRefreshResult> _fetchAndMerge(VegaRepo repo) async {
    final errors = <String, String>{};
    List<dynamic> entries;
    try {
      final bytes = await _getBytes('${_base(repo)}/manifest.json', maxManifestBytes);
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! List) throw const FormatException('manifest must be an array');
      entries = decoded;
    } catch (e) {
      return VegaRefreshResult(providers: providers, errors: <String, String>{'manifest': '$e'});
    }
    final current = providers;
    final merged = <String, VegaProvider>{for (final p in current) _key(p.repoId, p.value): p};
    for (final raw in entries) {
      if (raw is! Map) continue;
      try {
        final entry = Map<String, dynamic>.from(raw);
        if (entry['disabled'] == true) continue;
        final value = entry['value'];
        if (value is! String || !_validValue(value)) continue;
        final displayName = entry['display_name'];
        final version = entry['version'];
        final type = entry['type'];
        if (displayName is! String || displayName.trim().isEmpty ||
            version is! String || type is! String) continue;
        if (entry['icon'] != null && entry['icon'] is! String) continue;
        final modules = <String, String>{};
        for (final group in vegaRequiredModuleGroups) {
          final bytes = await _getBytes('${_base(repo)}/dist/$value/$group.js', maxModuleBytes);
          modules[group] = utf8.decode(bytes);
        }
        for (final group in vegaOptionalModuleGroups) {
          try {
            final bytes = await _getBytes('${_base(repo)}/dist/$value/$group.js', maxModuleBytes);
            modules[group] = utf8.decode(bytes);
          } on DioException catch (error) {
            final status = error.response?.statusCode;
            if (status != 404 && status != 410) rethrow;
          }
        }
        final old = merged[_key(repo.id, value)];
        merged[_key(repo.id, value)] = VegaProvider(repoId: repo.id, value: value,
          displayName: displayName.trim(), version: version, type: type,
          icon: entry['icon'] as String?, installed: old?.installed ?? false,
          modules: Map<String, String>.unmodifiable(modules));
      } catch (e) {
        final value = raw['value'];
        errors[value is String ? value : 'entry-${errors.length}'] = '$e';
        // A failed module set never overwrites the previous complete provider.
      }
    }
    // One serialized write atomically publishes all complete provider groups.
    await _writeProviders(merged.values.toList());
    final nextRepo = repo.withRefreshed(DateTime.now().toUtc());
    await _writeRepos(repositories.map((VegaRepo r) => r.id == repo.id ? nextRepo : r).toList());
    return VegaRefreshResult(providers: providers, errors: errors);
  }

  Future<List<int>> _getBytes(String url, int maxBytes) async {
    final response = await _dio.get<List<int>>(url,
      options: Options(responseType: ResponseType.bytes,
        followRedirects: false, receiveDataWhenStatusError: false,
        headers: const <String, String>{'Accept': '*/*'}));
    final data = response.data;
    if (response.statusCode != 200 || data == null) {
      throw DioException(requestOptions: response.requestOptions,
        response: response, message: 'HTTP ${response.statusCode}');
    }
    if (data.length > maxBytes) throw FormatException('File exceeds $maxBytes bytes');
    return data;
  }

  String _base(VegaRepo r) => 'https://raw.githubusercontent.com/${r.owner}/${r.name}/${r.branch}';
  static bool _validValue(String value) => value.length <= 100 &&
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(value) &&
    value != '.' && value != '..';
  static String _key(String repo, String value) => '$repo::$value';

  static VegaRepo _parseGithub(String input) {
    final trimmed = input.trim();
    final short = RegExp(r'^([A-Za-z0-9-]+)/([A-Za-z0-9_.-]+)(?:/vega-providers/main)?/?$').firstMatch(trimmed);
    if (short != null) {
      final owner = short.group(1)!;
      final name = short.group(2)!;
      return VegaRepo(url: 'https://github.com/$owner/$name', owner: owner, name: name);
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme != 'https' || uri.host.toLowerCase() != 'github.com' ||
        uri.userInfo.isNotEmpty || uri.hasPort || uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
      throw FormatException('Expected GitHub owner/repo or an HTTPS github.com repository URL');
    }
    final parts = uri.pathSegments.where((String p) => p.isNotEmpty).toList();
    if (parts.length != 2 || !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(parts[0]) ||
        !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(parts[1])) {
      throw FormatException('Malformed GitHub repository URL');
    }
    final owner = parts[0], name = parts[1].replaceFirst(RegExp(r'\.git$'), '');
    return VegaRepo(url: 'https://github.com/$owner/$name', owner: owner, name: name);
  }

  Future<void> _writeRepos(List<VegaRepo> values) => _persistence.write(
    vegaReposStorageKey, jsonEncode(values.map((VegaRepo e) => e.toJson()).toList()));
  Future<void> _writeProviders(List<VegaProvider> values) => _persistence.write(
    vegaProvidersStorageKey, jsonEncode(values.map((VegaProvider e) => e.toJson()).toList()));

  static List<T> _decodeList<T>(String? raw, T Function(Map<String, dynamic>) parse) {
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <T>[];
      return decoded.whereType<Map>().map((Map m) => parse(Map<String, dynamic>.from(m))).toList();
    } on Object {
      return <T>[];
    }
  }
}

extension on VegaRepo {
  VegaRepo withRefreshed(DateTime time) => VegaRepo(url: url, owner: owner,
    name: name, branch: branch, lastRefreshed: time);
  VegaRepo copyRefreshed() => withRefreshed(DateTime.now().toUtc());
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
