import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:soplay/features/detail/domain/entities/player_args.dart';
import 'package:soplay/features/detail/domain/entities/subtitle_entity.dart';
import 'package:soplay/features/detail/domain/entities/video_source_entity.dart';
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
      _message = 'stremio.added'.tr(args: [manifest.name]);
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
    setState(
      () => _message = 'stremio.removed'.tr(args: [addon.manifest.name]),
    );
  }

  Future<void> _showCatalog(_AddonRecord addon) async {
    final catalogs = addon.manifest.catalogs.whereType<Map>().toList();
    if (catalogs.isEmpty) {
      setState(() {
        _error = true;
        _message = 'stremio.no_catalogs'.tr();
      });
      return;
    }
    Map<String, dynamic>? catalog;
    if (catalogs.length == 1) {
      catalog = Map<String, dynamic>.from(catalogs.single);
    } else {
      catalog = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'stremio.choose_catalog'.tr(),
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              for (final value in catalogs)
                ListTile(
                  leading: const Icon(Icons.video_library_outlined),
                  title: Text(
                    value['name']?.toString() ??
                        value['id']?.toString() ??
                        'stremio.catalog'.tr(),
                  ),
                  subtitle: Text(value['type']?.toString() ?? ''),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(Map<String, dynamic>.from(value)),
                ),
            ],
          ),
        ),
      );
    }
    if (catalog == null) return;
    final type = catalog['type']?.toString() ?? '';
    final id = catalog['id']?.toString() ?? '';
    if (type.isEmpty || id.isEmpty) return;
    setState(() {
      _busy = true;
      _message = 'stremio.loading_catalog'.tr(args: [addon.manifest.name]);
      _error = false;
    });
    try {
      final result = await _client.catalog(addon.url, type, id);
      if (!mounted) return;
      final search = TextEditingController();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) {
            final query = search.text.trim().toLowerCase();
            final metas = result.metas.where(
              (meta) =>
                  query.isEmpty ||
                  (meta.name ?? '').toLowerCase().contains(query),
            );
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .8,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        addon.manifest.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: search,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          labelText: 'stremio.search_catalog'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: metas.isEmpty
                          ? Center(
                              child: Text(
                                result.metas.isEmpty
                                    ? 'stremio.empty_catalog'.tr()
                                    : 'stremio.no_search_results'.tr(),
                              ),
                            )
                          : ListView(
                              children: [
                                for (final meta in metas)
                                  _metaTile(addon, meta),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      search.dispose();
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

  Future<void> _openStreams(_AddonRecord addon, StremioMeta meta) async {
    final type = meta.type;
    final id = meta.id;
    if (type == null || id == null || type.isEmpty || id.isEmpty) return;
    setState(() {
      _busy = true;
      _message = 'stremio.loading_streams'.tr();
      _error = false;
    });
    try {
      final result = await _client.streams(addon.url, type, id);
      final subtitles = <SubtitleEntity>[];
      try {
        final subtitleResult = await _client.subtitles(addon.url, type, id);
        for (final subtitle in subtitleResult.subtitles) {
          final url = subtitle.url;
          if (url == null || url.isEmpty) continue;
          subtitles.add(
            SubtitleEntity(
              label: subtitle.lang ?? 'stremio.subtitle'.tr(),
              file: url,
              headers: subtitle.headers,
            ),
          );
        }
      } on StremioAddonException {
        // The subtitle resource is optional in the Addon Protocol. Streams
        // remain playable when an addon does not implement it.
      }
      if (!mounted) return;
      if (result.streams.isEmpty) {
        setState(() {
          _error = true;
          _message = 'stremio.no_streams'.tr();
        });
        return;
      }
      final stream = await showModalBottomSheet<StremioStream>(
        context: context,
        builder: (_) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  meta.name ?? id,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final candidate in result.streams)
                ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: Text(candidate.name ?? 'stremio.stream'.tr()),
                  subtitle: Text(candidate.title ?? candidate.url ?? ''),
                  enabled: candidate.url?.isNotEmpty == true,
                  onTap: () => Navigator.of(context).pop(candidate),
                ),
            ],
          ),
        ),
      );
      if (!mounted || stream?.url == null || stream!.url!.isEmpty) return;
      context.push(
        '/player',
        extra: PlayerArgs(
          title: meta.name ?? id,
          provider: 'stremio:${addon.manifest.id}',
          contentUrl: id,
          movieUrl: id,
          type: type,
          headers: const {},
          showDownloadAction: false,
          initialSubtitles: subtitles,
          videoSources: [
            VideoSourceEntity(
              quality: stream.title ?? stream.name ?? 'Stremio',
              videoUrl: stream.url!,
              isDefault: true,
              accessible: true,
              rawLabel: stream.title,
              type: stream.type,
              headers: stream.headers,
            ),
          ],
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

  Future<void> _openMeta(_AddonRecord addon, StremioMeta catalogMeta) async {
    final type = catalogMeta.type;
    final id = catalogMeta.id;
    if (type == null || id == null || type.isEmpty || id.isEmpty) return;
    setState(() {
      _busy = true;
      _message = 'stremio.loading_details'.tr();
      _error = false;
    });
    try {
      final meta = await _client.meta(addon.url, type, id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(meta.name ?? catalogMeta.name ?? id),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (meta.poster != null)
                  Center(
                    child: Image.network(
                      meta.poster!,
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  [
                    meta.type,
                    meta.year,
                    meta.genre,
                  ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                ),
                if (meta.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(meta.description!),
                ],
                if (meta.videos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'stremio.episodes'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final video in meta.videos)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(
                        video.title ??
                            [
                              if (video.season != null) 'S${video.season}',
                              if (video.episode != null) 'E${video.episode}',
                            ].join(' '),
                      ),
                      subtitle: video.overview == null
                          ? null
                          : Text(video.overview!),
                      onTap: () {
                        final episodeId = video.idFor(id);
                        if (episodeId == null) return;
                        Navigator.of(context).pop();
                        _openStreams(
                          addon,
                          StremioMeta.fromJson({
                            ...meta.json,
                            'id': episodeId,
                            'name': video.title ?? meta.name,
                          }),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('stremio.close'.tr()),
            ),
            if (meta.videos.isEmpty)
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openStreams(addon, meta);
                },
                child: Text('stremio.view_streams'.tr()),
              ),
          ],
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

  Widget _metaTile(_AddonRecord addon, StremioMeta meta) => ListTile(
    leading: meta.poster == null
        ? const Icon(Icons.movie_outlined)
        : Image.network(
            meta.poster!,
            width: 42,
            height: 62,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
          ),
    title: Text(meta.name ?? meta.id ?? 'stremio.untitled'.tr()),
    subtitle: Text([meta.type, meta.id].whereType<String>().join(' · ')),
    onTap: () => _openMeta(addon, meta),
  );

  @override
  Widget build(BuildContext context) {
    final addons = _addons;
    return Scaffold(
      appBar: AppBar(title: Text('stremio.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _url,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              labelText: 'stremio.manifest_url'.tr(),
              hintText: 'https://example.com/manifest.json',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _add,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text('stremio.add_update'.tr()),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
              style: TextStyle(color: _error ? Colors.red : Colors.green),
            ),
          ],
          const SizedBox(height: 24),
          if (addons.isEmpty)
            Text('stremio.no_addons'.tr())
          else
            for (final addon in addons)
              Card(
                child: ListTile(
                  title: Text(addon.manifest.name),
                  subtitle: Text(
                    '${addon.manifest.id} · v${addon.manifest.version}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'catalog') _showCatalog(addon);
                      if (action == 'remove') _remove(addon);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'catalog',
                        child: Text('stremio.open_catalog'.tr()),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('stremio.remove_addon'.tr()),
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

class _AddonRecord {
  const _AddonRecord({
    required this.id,
    required this.url,
    required this.manifest,
  });

  final String id;
  final String url;
  final StremioManifest manifest;
}
