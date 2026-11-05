import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';

import 'package:soplay/features/detail/domain/entities/player_args.dart';
import 'package:soplay/features/detail/domain/entities/video_source_entity.dart';
import 'package:soplay/features/extensions/data/mangayomi_runtime.dart';
import 'package:soplay/features/vega/data/vega_repo_store.dart';

class VegaProviderPage extends StatefulWidget {
  const VegaProviderPage({super.key, required this.provider});
  final VegaProvider provider;

  @override
  State<VegaProviderPage> createState() => _VegaProviderPageState();
}

class _VegaProviderPageState extends State<VegaProviderPage> {
  final _runtime = GetIt.I<MangayomiRuntime>();
  List<dynamic> _catalog = const [];
  List<dynamic> _posts = const [];
  String? _selectedFilter;
  String? _message;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final value = await _runtime.callVega(
        provider: widget.provider,
        module: 'catalog',
        method: 'catalog',
        args: const {},
      );
      final catalog = value is List ? value : const [];
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _selectedFilter = catalog.isEmpty ? null : _filterOf(catalog.first);
      });
      await _loadPosts();
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _filterOf(dynamic item) => item is Map ? item['filter']?.toString() : null;
  String _titleOf(dynamic item) => item is Map
      ? item['title']?.toString() ?? item['name']?.toString() ?? 'Catalog'
      : 'Catalog';

  Future<void> _loadPosts() async {
    final filter = _selectedFilter;
    if (filter == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final value = await _runtime.callVega(
        provider: widget.provider,
        module: 'posts',
        method: 'getPosts',
        args: {'filter': filter, 'page': 1},
      );
      if (mounted) setState(() => _posts = value is List ? value : const []);
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _value(dynamic item, String key) => item is Map ? item[key]?.toString() : null;

  Future<void> _openPost(dynamic post) async {
    final link = _value(post, 'link');
    if (link == null || link.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final metaValue = await _runtime.callVega(
        provider: widget.provider,
        module: 'meta',
        method: 'getMeta',
        args: {'link': link},
      );
      final meta = metaValue is Map ? metaValue : const <String, dynamic>{};
      final streamValue = await _runtime.callVega(
        provider: widget.provider,
        module: 'stream',
        method: 'getStream',
        args: {'link': link, 'type': meta['type']?.toString() ?? 'movie'},
      );
      final streams = streamValue is List ? streamValue : const [];
      final sources = <VideoSourceEntity>[];
      for (final item in streams) {
        if (item is! Map) continue;
        final url = item['link']?.toString();
        if (url == null || url.isEmpty) continue;
        sources.add(VideoSourceEntity(
          quality: item['quality']?.toString() ?? item['server']?.toString() ?? 'Vega',
          videoUrl: url,
          isDefault: sources.isEmpty,
          accessible: true,
          rawLabel: item['title']?.toString(),
        ));
      }
      if (sources.isEmpty) throw StateError('Provider returned no playable streams.');
      if (!mounted) return;
      context.push('/player', extra: PlayerArgs(
        title: meta['title']?.toString() ?? _value(post, 'title') ?? 'Vega',
        provider: 'vega:${widget.provider.value}',
        contentUrl: link,
        movieUrl: link,
        type: meta['type']?.toString(),
        headers: const {},
        showDownloadAction: false,
        videoSources: sources,
      ));
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.provider.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_catalog.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _selectedFilter,
              decoration: const InputDecoration(labelText: 'Catalog'),
              items: [
                for (final item in _catalog)
                  DropdownMenuItem(value: _filterOf(item), child: Text(_titleOf(item))),
              ],
              onChanged: (value) {
                setState(() => _selectedFilter = value);
                _loadPosts();
              },
            ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: const TextStyle(color: Colors.red)),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_busy && _posts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No items returned by this provider.'),
            ),
          for (final post in _posts)
            Card(
              child: ListTile(
                leading: _value(post, 'image') == null
                    ? const Icon(Icons.movie_outlined)
                    : Image.network(_value(post, 'image')!, width: 48, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.movie_outlined)),
                title: Text(_value(post, 'title') ?? 'Untitled'),
                subtitle: Text(_value(post, 'link') ?? ''),
                onTap: () => _openPost(post),
              ),
            ),
        ],
      ),
    );
  }
}
