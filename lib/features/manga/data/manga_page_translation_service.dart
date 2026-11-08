import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:soplay/core/subtitles/subtitle_translation_service.dart';
import 'package:soplay/core/network/http_headers.dart';
import 'package:soplay/features/manga/domain/entities/manga_page_entity.dart';

/// A translated OCR region in source-image coordinates.
class MangaTextRegion {
  const MangaTextRegion({
    required this.source,
    required this.translation,
    required this.bounds,
  });

  final String source;
  final String translation;
  final Rect bounds;
}

class MangaPageTranslation {
  const MangaPageTranslation({required this.imageSize, required this.regions});

  final Size imageSize;
  final List<MangaTextRegion> regions;
}

/// OCRs only when the reader asks for it, then translates the detected text.
///
/// The image never leaves the device for OCR. Only the strings the user asked
/// to translate are sent to the existing translation provider, matching the
/// on-demand behaviour of image translators such as Ascent.
class MangaPageTranslationService {
  MangaPageTranslationService._();

  static final MangaPageTranslationService instance =
      MangaPageTranslationService._();

  static final Map<String, MangaPageTranslation> _memoryCache = {};

  static Future<MangaPageTranslation?> readOffline({
    required String imagePath,
    required String targetLanguage,
  }) async {
    try {
      final image = File(imagePath);
      final sidecar = File(
        '${image.parent.path}/translation_$targetLanguage.json',
      );
      if (!await sidecar.exists()) return null;
      final body = jsonDecode(await sidecar.readAsString());
      if (body is! Map || body['pages'] is! List) return null;
      final name = image.uri.pathSegments.last;
      final raw = (body['pages'] as List).whereType<Map>().firstWhere(
        (page) => page['file'] == name,
        orElse: () => <String, dynamic>{},
      );
      if (raw.isEmpty) return null;
      final width = (raw['width'] as num?)?.toDouble() ?? 0;
      final height = (raw['height'] as num?)?.toDouble() ?? 0;
      if (width <= 0 || height <= 0) return null;
      return MangaPageTranslation(
        imageSize: Size(width, height),
        regions: [
          for (final item in (raw['regions'] as List? ?? const []))
            if (item is Map)
              MangaTextRegion(
                source: '${item['source'] ?? ''}',
                translation: '${item['translation'] ?? ''}',
                bounds: Rect.fromLTWH(
                  (item['left'] as num?)?.toDouble() ?? 0,
                  (item['top'] as num?)?.toDouble() ?? 0,
                  (item['width'] as num?)?.toDouble() ?? 0,
                  (item['height'] as num?)?.toDouble() ?? 0,
                ),
              ),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<MangaPageTranslation> translatePage({
    required MangaPageEntity page,
    required Map<String, String> headers,
    required String targetLanguage,
  }) async {
    if (kIsWeb) throw UnsupportedError('Manga translation is mobile-only');
    final cacheKey = '${page.cacheKey ?? page.imageUrl}|$targetLanguage';
    final cached = _memoryCache[cacheKey];
    if (cached != null) return cached;

    final file = await _pageFile(page, headers);
    final recognizer = await _recognize(file.path);
    if (recognizer.blocks.isEmpty) {
      throw const MangaTranslationException('لم يتم العثور على نص في الصفحة');
    }
    final lines = [
      for (final block in recognizer.blocks)
        if (block.text.trim().isNotEmpty) block,
    ];
    final translated = await const SubtitleTranslationService().translateLines(
      lines: [for (final block in lines) block.text.trim()],
      targetLang: targetLanguage,
      docKey: cacheKey,
      count: true,
    );
    if (translated.length != lines.length) {
      throw const MangaTranslationException(
        'تعذر مطابقة النص المترجم مع الصفحة',
      );
    }

    final size = await _imageSize(file);
    final result = MangaPageTranslation(
      imageSize: size,
      regions: [
        for (var i = 0; i < lines.length; i++)
          MangaTextRegion(
            source: lines[i].text.trim(),
            translation: translated[i].trim(),
            bounds: lines[i].boundingBox,
          ),
      ],
    );
    _memoryCache[cacheKey] = result;
    return result;
  }

  Future<File> _pageFile(
    MangaPageEntity page,
    Map<String, String> headers,
  ) async {
    if (!page.imageUrl.startsWith('http')) return File(page.imageUrl);
    return DefaultCacheManager().getSingleFile(
      page.imageUrl,
      key: page.cacheKey,
      headers: mergeHttpHeaders([
        headers,
        page.headers,
        if (page.cookie?.isNotEmpty == true) {'Cookie': page.cookie!},
      ]),
    );
  }

  Future<RecognizedText> _recognize(String path) async {
    // Manga sources commonly mix Japanese, Chinese, Korean and Latin text.
    // Stop at the first script that finds blocks to avoid four OCR passes.
    for (final script in const [
      TextRecognitionScript.japanese,
      TextRecognitionScript.chinese,
      TextRecognitionScript.korean,
      TextRecognitionScript.latin,
    ]) {
      final recognizer = TextRecognizer(script: script);
      try {
        final result = await recognizer.processImage(
          InputImage.fromFilePath(path),
        );
        if (result.blocks.isNotEmpty) {
          await recognizer.close();
          return result;
        }
      } catch (_) {
        await recognizer.close();
        continue;
      }
      await recognizer.close();
    }
    return RecognizedText(text: '', blocks: const []);
  }

  Future<Size> _imageSize(File file) async {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    final frame = await codec.getNextFrame();
    final size = Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    codec.dispose();
    return size;
  }
}

class MangaTranslationException implements Exception {
  const MangaTranslationException(this.message);
  final String message;
  @override
  String toString() => message;
}
