import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:soplay/core/theme/app_colors.dart';

import 'package:soplay/features/vega/data/vega_repo_store.dart';
import 'package:soplay/features/vega/presentation/pages/vega_provider_page.dart';

/// Vega repository/provider management.
///
/// Providers are downloaded and validated by [VegaRepoStore], then executed by
/// the shared sandbox runtime on platforms that support a headless WebView.
class VegaSourcesPage extends StatefulWidget {
  const VegaSourcesPage({super.key});

  @override
  State<VegaSourcesPage> createState() => _VegaSourcesPageState();
}

class _VegaSourcesPageState extends State<VegaSourcesPage> {
  final _url = TextEditingController();
  final _search = TextEditingController();
  late final VegaRepoStore _store = GetIt.I<VegaRepoStore>();
  bool _busy = false;
  String? _message;
  bool _error = false;
  String _query = '';
  String _language = 'all';

  @override
  void dispose() {
    _url.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_ensureRequestedRepository());
  }

  Future<void> _ensureRequestedRepository() async {
    if (_store.repositories.isNotEmpty) return;
    try {
      await _store.addRepository('https://github.com/rohan-js/vega-stremio-addon');
      if (mounted) setState(() => _message = 'Vega repository loaded.');
    } catch (_) {
      // The manual URL field remains available when the remote repo is offline.
    }
  }

  bool _matches(VegaProvider provider) {
    final haystack = '${provider.displayName} ${provider.value} ${provider.type}'.toLowerCase();
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty && !haystack.contains(query)) return false;
    return _language == 'all' || haystack.contains(_language);
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

  Future<void> _setInstalled(VegaProvider provider, bool installed) async {
    await _store.setInstalled(provider.repoId, provider.value, installed);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repositories = _store.repositories;
    final providers = _store.providers.where(_matches).toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vega Sources'),
        actions: [
          IconButton(
            tooltip: 'Clear filters',
            onPressed: _query.isEmpty && _language == 'all'
                ? null
                : () => setState(() {
                    _query = '';
                    _language = 'all';
                    _search.clear();
                  }),
            icon: const Icon(Icons.filter_alt_off_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.primaryLight),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add a repository, filter providers by name or language, enable the ones you want, then tap an enabled provider to browse and play its sources.',
                    ),
                  ),
                ],
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
              style: TextStyle(color: _error ? AppColors.error : AppColors.success),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              labelText: 'Search providers',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final code in const ['all', 'ar', 'en', 'fr', 'es', 'tr', 'de', 'ja'])
                FilterChip(
                  selected: _language == code,
                  label: Text(code == 'all' ? 'All languages' : code.toUpperCase()),
                  onSelected: (_) => setState(() => _language = code),
                ),
            ],
          ),
          const SizedBox(height: 12),
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
          Row(
            children: [
              Expanded(
                child: Text('Providers (${providers.length})',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (_store.providers.length != providers.length)
                Text('${_store.providers.length} total',
                    style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          if (providers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No providers match the current filters.'),
            )
          else
            for (final provider in providers)
              Card(
                child: ListTile(
                  leading: Icon(
                    provider.installed
                        ? Icons.check_circle
                        : Icons.extension_outlined,
                    color: provider.installed
                        ? AppColors.primaryLight
                        : AppColors.textSecondary,
                  ),
                  title: Text(provider.displayName),
                  subtitle: Text('${provider.repoId} · ${provider.version}'),
                  enabled: provider.installed,
                  onTap: provider.installed
                      ? () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => VegaProviderPage(provider: provider),
                          ))
                      : null,
                  trailing: Switch(
                    value: provider.installed,
                    onChanged: (value) => _setInstalled(provider, value),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
