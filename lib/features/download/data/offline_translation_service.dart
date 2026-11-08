import 'dart:convert';
import 'dart:io';

import 'package:soplay/core/subtitles/subtitle_translation_service.dart';
import 'package:soplay/features/download/domain/download_layout.dart';
import 'package:soplay/features/download/domain/entities/download_item.dart';
import 'package:soplay/features/manga/data/manga_page_translation_service.dart';
import 'package:soplay/features/manga/domain/entities/manga_page_entity.dart';

/// Builds optional translation artefacts after the original chapter is safely
/// downloaded. Translation failure never turns a valid offline chapter into a
/// failed download; the original remains readable.
class OfflineTranslationService {
  const OfflineTranslationService();

  Future<void> translate(DownloadItem item, String directory) async {
    if (!item.translateOffline) return;
    final language = (item.translationLanguage ?? 'ar').trim();
    if (language.isEmpty) return;
    try {
      if (item.isProse) {
        await _translateNovel(item, directory, language);
      } else {
        await _translateManga(item, directory, language);
      }
    } catch (_) {
      // Keep the original download usable when the translation provider is
      // unavailable or the user quota is exhausted.
    }
  }

  Future<void> _translateNovel(
    DownloadItem item,
    String directory,
    String language,
  ) async {
    final file = File('$directory/${DownloadLayout.chapterHtmlName}');
    if (!await file.exists()) return;
    final original = await file.readAsString();
    final textPattern = RegExp(r'>([^<>]{2,})<', multiLine: true);
    final matches = textPattern.allMatches(original).toList();
    final source = [
      for (final match in matches)
        if (match.group(1)!.trim().isNotEmpty) match.group(1)!.trim(),
    ];
    if (source.isEmpty) return;
    final translated = await const SubtitleTranslationService().translateLines(
      lines: source,
      targetLang: language,
      docKey: '${item.id}|$language',
      count: true,
    );
    if (translated.length != source.length) return;
    await File(
      '$directory/${DownloadLayout.chapterHtmlName}.original',
    ).writeAsString(original);
    var index = 0;
    final translatedHtml = original.replaceAllMapped(textPattern, (match) {
      final text = match.group(1)!;
      if (text.trim().isEmpty) return match[0]!;
      final value = translated[index++];
      return '>${value.replaceAll('>', '&gt;').replaceAll('<', '&lt;')}<';
    });
    await file.writeAsString(translatedHtml);
  }

  Future<void> _translateManga(
    DownloadItem item,
    String directory,
    String language,
  ) async {
    final dir = Directory(directory);
    final pages = <Map<String, dynamic>>[];
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((file) => file.uri.pathSegments.last.startsWith('p_'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final page = await MangaPageTranslationService.instance.translatePage(
        page: MangaPageEntity(index: pages.length, imageUrl: file.path),
        headers: const {},
        targetLanguage: language,
      );
      pages.add({
        'file': file.uri.pathSegments.last,
        'width': page.imageSize.width,
        'height': page.imageSize.height,
        'regions': [
          for (final region in page.regions)
            {
              'source': region.source,
              'translation': region.translation,
              'left': region.bounds.left,
              'top': region.bounds.top,
              'width': region.bounds.width,
              'height': region.bounds.height,
            },
        ],
      });
    }
    await File(
      '$directory/translation_$language.json',
    ).writeAsString(jsonEncode({'language': language, 'pages': pages}));
  }
}
