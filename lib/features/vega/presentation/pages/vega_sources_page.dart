import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:soplay/features/vega/data/vega_repo_store.dart';

/// Vega repository/provider management.
///
/// Vega JavaScript execution is intentionally not exposed here: the data layer
/// downloads and validates source modules, but no compatible isolated runtime
/// has been proven safe yet.
class VegaSourcesPage extends StatefulWidget {
  const VegaSourcesPage({super.key});

  @override
  State<VegaSourcesPage> createState() => _VegaSourcesPageState();
}

class _VegaSourcesPageState extends State<VegaSourcesPage> {
  final _url = TextEditingController();
  late final VegaRepoStore _store = GetIt.I<VegaRepoStore>();
  bool _busy = false;
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _addRepository() async {
    final input = _url.text.trim();
    if (input.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      final result = await _store.addRepository(input);
      _url.clear();
      final failed = result.errors.length;
      _message = failed == 0
          ? 'Repository refreshed successfully.'
          : 'Repository loaded with $failed provider error(s).';
    } catch (error) {
      _error = true;
      _message = error.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh(VegaRepo repo) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      final result = await _store.refreshRepository(repo.id);
      _message = result.errors.isEmpty
          ? 'Repository refreshed successfully.'
          : 'Refresh completed with ${result.errors.length} provider error(s).';
    } catch (error) {
      _error = true;
      _message = error.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeRepository(VegaRepo repo) async {
    await _store.removeRepository(repo.id);
    if (mounted) setState(() => _message = 'Repository removed.');
  }

  Future<void> _removeProvider(VegaProvider provider) async {
    await _store.removeProvider(provider.repoId, provider.value);
    if (mounted) setState(() => _message = 'Provider removed.');
  }

  Future<void> _setInstalled(VegaProvider provider, bool installed) async {
    await _store.setInstalled(provider.repoId, provider.value, installed);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repositories = _store.repositories;
    final providers = _store.providers;
    return Scaffold(
      appBar: AppBar(title: const Text('Vega Sources')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Vega repositories and providers can be managed here. JavaScript execution is not supported until a compatible isolated runtime is verified.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addRepository(),
            decoration: const InputDecoration(
              labelText: 'GitHub repository',
              hintText: 'owner/repository',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _addRepository,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_link),
            label: const Text('Add or refresh repository'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
              style: TextStyle(color: _error ? Colors.red : Colors.green),
            ),
          ],
          const SizedBox(height: 20),
          Text('Repositories (${repositories.length})',
              style: Theme.of(context).textTheme.titleMedium),
          if (repositories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No Vega repositories configured.'),
            )
          else
            for (final repo in repositories)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.source_outlined),
                  title: Text(repo.id),
                  subtitle: Text(repo.branch),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'refresh') _refresh(repo);
                      if (action == 'remove') _removeRepository(repo);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 20),
          Text('Providers (${providers.length})',
              style: Theme.of(context).textTheme.titleMedium),
          if (providers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No Vega providers loaded.'),
            )
          else
            for (final provider in providers)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.extension_outlined),
                  title: Text(provider.displayName),
                  subtitle: Text('${provider.repoId} · ${provider.version}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'install') {
                        _setInstalled(provider, !provider.installed);
                      }
                      if (action == 'remove') _removeProvider(provider);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'install',
                        child: Text(provider.installed ? 'Disable' : 'Enable'),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove provider'),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
