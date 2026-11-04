import 'package:hive/hive.dart';

/// Persists individual manifests in an injected Hive settings box.
/// Uses a dedicated key namespace; removing one addon never clears the box.
class StremioAddonStore {
  StremioAddonStore(this.settingsBox, {this.keyPrefix = 'stremio.addon.'});

  final Box<dynamic> settingsBox;
  final String keyPrefix;
  String _key(String id) => '$keyPrefix$id';

  /// Save/replace a manifest record under its protocol id.
  Future<void> put(String id, Map<String, dynamic> record) =>
      settingsBox.put(_key(id), Map<String, dynamic>.from(record));

  /// Read one stored addon record, or null when absent.
  Map<String, dynamic>? get(String id) {
    final value = settingsBox.get(_key(id));
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  /// List this module's addon records only.
  Map<String, Map<String, dynamic>> all() {
    final result = <String, Map<String, dynamic>>{};
    for (final key in settingsBox.keys) {
      if (key is String && key.startsWith(keyPrefix)) {
        final value = settingsBox.get(key);
        if (value is Map) result[key.substring(keyPrefix.length)] = Map<String, dynamic>.from(value);
      }
    }
    return result;
  }

  /// Delete exactly one addon entry, preserving all other settings and addons.
  Future<void> remove(String id) => settingsBox.delete(_key(id));
}
