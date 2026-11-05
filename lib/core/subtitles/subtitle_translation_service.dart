import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:soplay/core/di/injection.dart';

enum GoogleTranslationKeyFailure {
  invalid,
  apiDisabled,
  quota,
  network,
  unexpected,
}

class GoogleTranslationKeyException implements Exception {
  const GoogleTranslationKeyException(this.failure, {this.statusCode});
  final GoogleTranslationKeyFailure failure;
  final int? statusCode;
}

enum OpenAiKeyFailure { invalid, quota, network, unexpected }

class OpenAiKeyException implements Exception {
  const OpenAiKeyException(this.failure, {this.statusCode});
  final OpenAiKeyFailure failure;
  final int? statusCode;
}

/// Result of asking the backend to translate a subtitle.
class SubtitleTranslationResult {
  const SubtitleTranslationResult({
    required this.url,
    required this.cueCount,
    required this.provider,
    required this.cached,
  });

  /// R2 url of the translated .srt — loaded like any other subtitle track.
  final String url;
  final int cueCount;
  final String provider;

  /// True when it came straight from the cache — meaning it did not count
  /// against the daily limit.
  final bool cached;
}

/// A translation already made for the current media, ready to load.
class ReadySubtitle {
  const ReadySubtitle({
    required this.url,
    required this.targetLang,
    required this.cueCount,
  });
  final String url;
  final String targetLang;
  final int cueCount;
}

/// Today's translation allowance for the account.
class SubtitleQuota {
  const SubtitleQuota({
    required this.enabled,
    required this.limit,
    required this.used,
    required this.remaining,
  });

  final bool enabled;
  final int limit;
  final int used;
  final int remaining;
}

/// Thrown when the account has used up its translations for the day.
class SubtitleDailyLimitReached implements Exception {
  const SubtitleDailyLimitReached(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Asks the backend to translate a subtitle the source has none of in the
/// target language.
///
/// The heavy work — parsing, the provider waterfall, caching — all lives on the
/// server; this just hands over the source url and waits for a translated one.
/// Uses the authenticated Dio because the daily limit is counted per account.
class SubtitleTranslationService {
  const SubtitleTranslationService();

  static const String _googleKeyName = 'google_cloud_translation_api_key';
  static const String _openAiKeyName = 'openai_api_key';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
  );

  Future<String?> readGoogleApiKey() =>
      _secureStorage.read(key: _googleKeyName);

  Future<void> saveGoogleApiKey(String value) async {
    final key = value.trim();
    if (key.isEmpty) {
      await _secureStorage.delete(key: _googleKeyName);
    } else {
      await _secureStorage.write(key: _googleKeyName, value: key);
    }
  }

  /// Performs a real, minimal Cloud Translation request before a key is saved.
  /// The one-word request can be billable by Google. [client] is injectable so
  /// the remote response contract can be tested without network access.
  Future<void> validateGoogleApiKey(String value, {Dio? client}) async {
    final key = value.trim();
    if (key.isEmpty) {
      throw const GoogleTranslationKeyException(
        GoogleTranslationKeyFailure.invalid,
      );
    }
    final dio =
        client ??
        Dio(
          BaseOptions(
            baseUrl: 'https://translation.googleapis.com',
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            validateStatus: (_) => true,
          ),
        );
    try {
      final response = await dio.post<Object?>(
        '/language/translate/v2',
        data: const {
          'q': ['Sozo'],
          'target': 'en',
          'format': 'text',
        },
        options: Options(headers: {'x-goog-api-key': key}),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw GoogleTranslationKeyException(
          _googleFailure(response.data, status),
          statusCode: status,
        );
      }
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      final translations = data is Map ? data['translations'] : null;
      if (translations is! List ||
          translations.length != 1 ||
          translations.first is! Map ||
          (translations.first as Map)['translatedText'] is! String ||
          ((translations.first as Map)['translatedText'] as String)
              .trim()
              .isEmpty) {
        throw const GoogleTranslationKeyException(
          GoogleTranslationKeyFailure.unexpected,
        );
      }
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw GoogleTranslationKeyException(
        status == null
            ? GoogleTranslationKeyFailure.network
            : _googleFailure(error.response?.data, status),
        statusCode: status,
      );
    }
  }

  GoogleTranslationKeyFailure _googleFailure(Object? body, int status) {
    final message = body is Map && body['error'] is Map
        ? ((body['error'] as Map)['message']?.toString() ?? '').toLowerCase()
        : body?.toString().toLowerCase() ?? '';
    if (status == 429 ||
        message.contains('quota') ||
        message.contains('rate limit')) {
      return GoogleTranslationKeyFailure.quota;
    }
    if (message.contains('api has not been used') ||
        message.contains('api is disabled') ||
        message.contains('not enabled')) {
      return GoogleTranslationKeyFailure.apiDisabled;
    }
    if (status == 400 ||
        status == 401 ||
        status == 403 ||
        message.contains('api key not valid') ||
        message.contains('invalid api key')) {
      return GoogleTranslationKeyFailure.invalid;
    }
    return GoogleTranslationKeyFailure.unexpected;
  }

  /// Google Translation v2 HTML-escapes some translated characters. Decode
  /// entities once (not recursively) before returning text to the subtitle UI.
  static String decodeGoogleTranslatedText(String value) =>
      value.replaceAllMapped(
        RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos|nbsp|#39);'),
        (match) {
          final entity = match[1]!;
          const named = {
            'amp': '&',
            'lt': '<',
            'gt': '>',
            'quot': '"',
            'apos': "'",
            'nbsp': ' ',
            '#39': "'",
          };
          if (named.containsKey(entity)) return named[entity]!;
          final code = entity.startsWith('#x')
              ? int.tryParse(entity.substring(2), radix: 16)
              : int.tryParse(entity.substring(1));
          if (code == null || code < 0 || code > 0x10ffff) return match[0]!;
          return String.fromCharCode(code);
        },
      );

  Future<String?> readOpenAiApiKey() =>
      _secureStorage.read(key: _openAiKeyName);

  Future<void> saveOpenAiApiKey(String value) async {
    final key = value.trim();
    if (key.isEmpty) {
      await _secureStorage.delete(key: _openAiKeyName);
    } else {
      await _secureStorage.write(key: _openAiKeyName, value: key);
    }
  }

  /// Authenticates the key using a short completion before saving. Usage may
  /// be billable by OpenAI. [client] supports deterministic tests.
  Future<void> validateOpenAiApiKey(String value, {Dio? client}) async {
    final key = value.trim();
    if (key.isEmpty) throw const OpenAiKeyException(OpenAiKeyFailure.invalid);
    final dio =
        client ??
        Dio(
          BaseOptions(
            baseUrl: 'https://api.openai.com/v1',
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            validateStatus: (_) => true,
          ),
        );
    try {
      final response = await dio.post<Object?>(
        '/chat/completions',
        data: const {
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content':
                  'Translate the user text to English. Return only the translation.',
            },
            {'role': 'user', 'content': 'Sozo'},
          ],
          'max_tokens': 8,
        },
        options: Options(headers: {'Authorization': 'Bearer $key'}),
      );
      final status = response.statusCode ?? 0;
      final body = response.data;
      final choices = body is Map ? body['choices'] : null;
      final message =
          choices is List && choices.isNotEmpty && choices.first is Map
          ? (choices.first as Map)['message']
          : null;
      if (status < 200 || status >= 300) {
        throw OpenAiKeyException(
          _openAiFailure(body, status),
          statusCode: status,
        );
      }
      if (message is! Map ||
          message['content'] is! String ||
          (message['content'] as String).trim().isEmpty) {
        throw const OpenAiKeyException(OpenAiKeyFailure.unexpected);
      }
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw OpenAiKeyException(
        status == null
            ? OpenAiKeyFailure.network
            : _openAiFailure(error.response?.data, status),
        statusCode: status,
      );
    }
  }

  OpenAiKeyFailure _openAiFailure(Object? body, int status) {
    final error = body is Map && body['error'] is Map
        ? body['error'] as Map
        : null;
    final code = error?['code']?.toString().toLowerCase() ?? '';
    final message = error?['message']?.toString().toLowerCase() ?? '';
    if (status == 429 || code.contains('quota') || message.contains('quota')) {
      return OpenAiKeyFailure.quota;
    }
    if (status == 401 || status == 403) return OpenAiKeyFailure.invalid;
    return OpenAiKeyFailure.unexpected;
  }

  /// Translations already made for this title/episode, across languages.
  Future<List<ReadySubtitle>> fetchReady({
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
  }) async {
    try {
      final response = await getIt<Dio>().get(
        '/contents/subtitles/ready',
        queryParameters: {
          'tmdbId': tmdbId,
          'type': type,
          'season': ?season,
          'episode': ?episode,
        },
      );
      final items =
          (response.data is Map ? response.data['items'] : null) as List? ??
          const [];
      return [
        for (final m in items)
          if (m is Map && m['url'] != null)
            ReadySubtitle(
              url: '${m['url']}',
              targetLang: '${m['targetLang'] ?? ''}',
              cueCount: (m['cueCount'] as num?)?.toInt() ?? 0,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Publishes a finished translation so other viewers can load it directly.
  /// Best-effort — a failure here never blocks playback. A translation made
  /// with the user's Google key stays on-device and is not uploaded to Sozo.
  Future<void> publishReady({
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
    required String targetLang,
    required String srt,
  }) async {
    try {
      final googleKey = await readGoogleApiKey();
      if (googleKey != null && googleKey.trim().isNotEmpty) return;
      await getIt<Dio>().post(
        '/contents/subtitles/ready',
        data: {
          'tmdbId': tmdbId,
          'type': type,
          'season': ?season,
          'episode': ?episode,
          'targetLang': targetLang,
          'srt': srt,
        },
      );
    } catch (_) {}
  }

  /// How many translations the account has left today, for showing before the
  /// person spends one. Returns null if it cannot be read — the UI then simply
  /// omits the count rather than blocking.
  Future<SubtitleQuota?> fetchQuota() async {
    try {
      final response = await getIt<Dio>().get('/contents/subtitles/quota');
      final data = response.data as Map<String, dynamic>;
      return SubtitleQuota(
        enabled: data['enabled'] as bool? ?? false,
        limit: (data['limit'] as num?)?.toInt() ?? 0,
        used: (data['used'] as num?)?.toInt() ?? 0,
        remaining: (data['remaining'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Translates one slice of subtitle lines. Order and count are preserved.
  ///
  /// [count] is true only for the first slice of a file, so the daily limit is
  /// charged once no matter how many slices a movie is split into.
  Future<List<String>> translateLines({
    required List<String> lines,
    required String targetLang,
    required String docKey,
    String? from,
    bool count = false,
  }) async {
    var directGoogle = false;
    var directOpenAi = false;
    try {
      String? googleKey;
      String? openAiKey;
      try {
        googleKey = await readGoogleApiKey();
        openAiKey = await readOpenAiApiKey();
      } catch (_) {
        // Keep the existing authenticated provider available when a platform
        // secure-storage backend is unavailable.
      }
      if (googleKey != null && googleKey.trim().isNotEmpty) {
        directGoogle = true;
        final response =
            await Dio(
              BaseOptions(
                baseUrl: 'https://translation.googleapis.com',
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
              ),
            ).post<Object?>(
              '/language/translate/v2',
              data: {
                'q': lines,
                'target': targetLang,
                'format': 'text',
                if (from != null && from.isNotEmpty) 'source': from,
              },
              options: Options(headers: {'x-goog-api-key': googleKey}),
            );
        final body = response.data;
        final data = body is Map ? body['data'] : null;
        final translations = data is Map ? data['translations'] : null;
        if (translations is! List ||
            translations.length != lines.length ||
            translations.any(
              (item) => item is! Map || item['translatedText'] is! String,
            )) {
          throw const FormatException(
            'Google returned an incomplete translation',
          );
        }
        return [
          for (final item in translations)
            decodeGoogleTranslatedText(
              (item as Map)['translatedText'] as String,
            ),
        ];
      }
      if (openAiKey != null && openAiKey.trim().isNotEmpty) {
        directOpenAi = true;
        final dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.openai.com/v1',
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 60),
          ),
        );
        final response = await dio.post<Object?>(
          '/chat/completions',
          data: {
            'model': 'gpt-4o-mini',
            'messages': [
              {
                'role': 'system',
                'content':
                    'Translate each string into $targetLang. Preserve order and meaning; keep markup/placeholders unchanged. Return a JSON object with one property "translations" containing exactly one string per input string. Do not add or remove entries.',
              },
              {'role': 'user', 'content': jsonEncode(lines)},
            ],
            'response_format': {'type': 'json_object'},
            'max_tokens': 4096,
          },
          options: Options(headers: {'Authorization': 'Bearer $openAiKey'}),
        );
        final body = response.data;
        final choices = body is Map ? body['choices'] : null;
        final message =
            choices is List && choices.isNotEmpty && choices.first is Map
            ? (choices.first as Map)['message']
            : null;
        final content = message is Map ? message['content'] : null;
        if (content is! String) {
          throw const FormatException('OpenAI returned no text');
        }
        final decoded = jsonDecode(content);
        final out = decoded is Map ? decoded['translations'] : null;
        if (out is! List ||
            out.length != lines.length ||
            out.any((item) => item is! String)) {
          throw const FormatException(
            'OpenAI returned an incomplete translation',
          );
        }
        return out.cast<String>();
      }

      final response = await getIt<Dio>().post(
        '/contents/subtitles/translate/lines',
        data: {
          'lines': lines,
          'targetLang': targetLang,
          'docKey': docKey,
          'count': count,
          if (from != null && from.isNotEmpty) 'from': from,
        },
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
      final data = response.data as Map<String, dynamic>;
      final out = (data['lines'] as List?)?.map((e) => e.toString()).toList();
      if (out == null || out.length != lines.length) {
        throw Exception('Tarjima natijasi mos kelmadi');
      }
      return out;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (directGoogle) {
        throw GoogleTranslationKeyException(
          status == null
              ? GoogleTranslationKeyFailure.network
              : _googleFailure(e.response?.data, status),
          statusCode: status,
        );
      }
      if (directOpenAi) {
        throw OpenAiKeyException(
          status == null
              ? OpenAiKeyFailure.network
              : _openAiFailure(e.response?.data, status),
          statusCode: status,
        );
      }
      if (status == 429) throw SubtitleDailyLimitReached(_messageFrom(e));
      throw Exception(_messageFrom(e));
    }
  }

  Future<SubtitleTranslationResult> translate({
    required String sourceUrl,
    required String targetLang,
    String? from,
    String? title,
    String? tmdbId,
  }) async {
    try {
      final response = await getIt<Dio>().post(
        '/contents/subtitles/translate',
        data: {
          'url': sourceUrl,
          'targetLang': targetLang,
          if (from != null && from.isNotEmpty) 'from': from,
          if (title != null && title.isNotEmpty) 'title': title,
          if (tmdbId != null && tmdbId.isNotEmpty) 'tmdbId': tmdbId,
        },
        options: Options(
          // Translation runs the whole waterfall server-side; the default
          // timeout is far too short for a fresh file.
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      final data = response.data as Map<String, dynamic>;
      return SubtitleTranslationResult(
        url: data['url'] as String,
        cueCount: (data['cueCount'] as num?)?.toInt() ?? 0,
        provider: data['provider'] as String? ?? '',
        cached: data['cached'] as bool? ?? false,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final message = _messageFrom(e);
      if (status == 429) throw SubtitleDailyLimitReached(message);
      throw Exception(message);
    }
  }

  String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String) return message;
    }
    return e.message ?? 'Tarjima qilib bo\'lmadi';
  }
}
