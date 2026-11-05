import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:soplay/features/stremio/data/stremio_addon_client.dart';
import 'package:soplay/features/stremio/data/stremio_addon_models.dart';

/// Real Stremio addon management surface.
///
/// Manifests are validated by [StremioAddonClient] and persisted by its Hive
/// store. Catalog requests are made against the selected addon's declared
/// catalog; no placeholder rows are created when the network is unavailable.
class StremioAddonsPage extends StatefulWidget {
  const StremioAddonsPage({super.key});

  @override
  State<StremioAddonsPage> createState() => _StremioAddonsPageState();
}

class _StremioAddonsPageState extends State<StremioAddonsPage> {
  final _url = TextEditingController();
  late final StremioAddonClient _client = GetIt.I<StremioAddonClient>();
  bool _busy = false;
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  List<_AddonRecord> get _addons => [
        for (final entry in _client.addons.entries)
          if (entry.value['manifest'] is Map)
            _AddonRecord(
              id: entry.key,
              url: entry.value['url']?.toString() ?? '',
              manifest: StremioManifest.fromJson(
                Map<String, dynamic>.from(entry.value['manifest'] as Map),
              ),
            ),
      ];

  Future<void> _add() async {
    final value = _url.text.trim();
    if (value.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      final manifest = await _client.addOrUpdate(value);
      _url.clear();
      _message = 'Added ${manifest.name}';
    } catch (e) {
      _error = true;
      _message = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(_AddonRecord addon) async {
    await _client.removeAddon(addon.id);
    if (!mounted) return;
    setState(() => _message = 'Removed ${addon.manifest.name}');
  }

  Future<void> _showCatalog(_AddonRecord addon) async {
    final catalogs = addon.manifest.catalogs.whereType<Map>().toList();
    if (catalogs.isEmpty) {
      setState(() {
        _error = true;
        _message = 'This addon does not declare a catalog.';
      });
      return;
    }
    final catalog = Map<String, dynamic>.from(catalogs.first);
    final type = catalog['type']?.toString() ?? '';
    final id = catalog['id']?.toString() ?? '';
    if (type.isEmpty || id.isEmpty) return;
    setState(() {
      _busy = true;
      _message = 'Loading ${addon.manifest.name}…';
      _error = false;
    });
    try {
      final result = await _client.catalog(addon.url, type, id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(addon.manifest.name,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (result.metas.isEmpty)
                const Text('The addon returned an empty catalog.')
              else
                for (final meta in result.metas) _metaTile(meta),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _metaTile(StremioMeta meta) => ListTile(
        leading: meta.poster == null
            ? const Icon(Icons.movie_outlined)
            : Image.network(meta.poster!, width: 42, height: 62, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined)),
        title: Text(meta.name ?? meta.id ?? 'Untitled'),
        subtitle: Text([meta.type, meta.id].whereType<String>().join(' · ')),
      );

  @override
  Widget build(BuildContext context) {
    final addons = _addons;
    return Scaffold(
      appBar: AppBar(title: const Text('Stremio Addons')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _url,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            decoration: const InputDecoration(
              labelText: 'Manifest URL',
              hintText: 'https://example.com/manifest.json',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _add,
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add),
            label: const Text('Add or update addon'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(_message!, style: TextStyle(color: _error ? Colors.red : Colors.green)),
          ],
          const SizedBox(height: 24),
          if (addons.isEmpty)
            const Text('No Stremio addons installed.')
          else
            for (final addon in addons)
              Card(
                child: ListTile(
                  title: Text(addon.manifest.name),
                  subtitle: Text('${addon.manifest.id} · v${addon.manifest.version}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'catalog') _showCatalog(addon);
                      if (action == 'remove') _remove(addon);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'catalog', child: Text('Open catalog')),
                      PopupMenuItem(value: 'remove', child: Text('Remove addon')),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _AddonRecord {
  const _AddonRecord({required this.id, required this.url, required this.manifest});

  final String id;
  final String url;
  final StremioManifest manifest;
}
