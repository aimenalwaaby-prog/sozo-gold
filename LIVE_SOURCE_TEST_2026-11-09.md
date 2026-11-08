# اختبار حي لمصادر Sozo Gold

وقت الاختبار: 2026-11-08T21:50:28.182876+00:00

اختبار شبكي فعلي للـmanifest والفهارس وبعض موارد catalog/meta/stream/subtitles وملفات الإضافات. لا يعني توفر ملف APK أو CS3 أن تشغيله تم داخل Android؛ ذلك يحتاج جهاز Android أو محاكي.

## Stremio — Cinemeta
- **status:** `200`
- **id:** `"com.linvo.cinemeta"`
- **resources:** `["catalog", "meta", "addon_catalog"]`
- **types:** `["movie", "series"]`
- **catalog_count:** `8`
- **catalog_status:** `200`
- **catalog_items:** `49`
- **sample_titles:** `["Obsession", "Hocus Pocus", "Verity"]`

## Stremio — OpenSubtitles
- **status:** `200`
- **id:** `"org.stremio.opensubtitlesv3"`
- **resources:** `["subtitles"]`
- **types:** `["movie", "series"]`
- **catalog_count:** `0`
- **sample_id:** `"tt0133093"`
- **subtitle_status:** `200`
- **subtitles:** `26`
- **sample_languages:** `["ger", "ger", "ger", "ger", "ell", "ell", "ell", "fin"]`

## Stremio — Torrentio
- **status:** `200`
- **id:** `"com.stremio.torrentio.addon"`
- **resources:** `[{"name": "stream", "types": ["movie", "series", "anime"], "idPrefixes": ["tt", "kitsu"]}]`
- **types:** `["movie", "series", "anime", "other"]`
- **catalog_count:** `0`
- **sample_id:** `"tt0133093"`
- **stream_status:** `200`
- **streams:** `130`
- **sample_streams:** `["Матрица / The Matrix [1999 WEB-DL 2160p HDR10 Dolby Vision] [Hybrid] Dub + Original (Eng) + Sub (Rus Eng)\n👤 344 💾 18.45 GB ⚙️ Rutracker\n🇬🇧 / 🇷🇺", "The.Matrix.1999.RERIP.2160p.UHD.BluRay.x265.10bit.HDR.TrueHD.7.1.Atmos-IAMABLE\n👤 107 💾 35.09 GB ⚙️ RARBG", "The Matrix 1999 UHD Blu-ray 2160p HDR Remux Multi Atmos 7.1-DTOne\n👤 79 💾 51.3 GB ⚙️ 1337x\nMulti Audio / 🇬🇧 / 🇮🇹 / 🇵🇹 / 🇰🇷 / 🇨🇳 / 🇫🇷 / 🇩🇪 / 🇸🇦"]`

## Vega — Zenda-Cross/vega-providers
- **manifest_status:** `200`
- **providers:** `63`
- **مزودو Vega:** [{"value": "vega", "display_name": "VMovies", "modules": {"catalog": {"status": 200, "bytes": 2231, "has_export": true}, "posts": {"status": 200, "bytes": 8527, "has_export": true}, "meta": {"status": 200, "bytes": 15586, "has_export": true}, "stream": {"status": 200, "bytes": 26304, "has_export": true}}}, {"value": "autoEmbed", "display_name": "MultiStream", "modules": {"catalog": {"status": 200, "bytes": 1131, "has_export": true}, "posts": {"status": 200, "bytes": 3839, "has_export": true}, "meta": {"status": 200, "bytes": 14067, "has_export": true}, "stream": {"status": 200, "bytes": 62641, "has_export": true}}}, {"value": "drive", "display_name": "MoviesDrive", "modules": {"catalog": {"status": 200, "bytes": 1424, "has_export": true}, "posts": {"status": 200, "bytes": 6849, "has_export": true}, "meta": {"status": 200, "bytes": 13217, "has_export": true}, "stream": {"status": 200, "bytes": 22069, "has_export": true}}}]

## CloudStream — CloudStream Official
- **repo_status:** `200`
- **plugin_entries_sampled_lists:** `1`
- **plugin_entries_count_in_sampled_lists:** `5`
- **عينات CloudStream:** [{"name": "DailymotionProvider", "url": "https://raw.githubusercontent.com/recloudstream/extensions/builds/DailymotionProvider.cs3", "status": 200, "bytes": 11472}, {"name": "InternetArchiveProvider", "url": "https://raw.githubusercontent.com/recloudstream/extensions/builds/InternetArchiveProvider.cs3", "status": 200, "bytes": 28037}]

## CloudStream — Phisher Extensions
- **repo_status:** `200`
- **plugin_entries_sampled_lists:** `1`
- **plugin_entries_count_in_sampled_lists:** `86`
- **عينات CloudStream:** [{"name": "AllMovieLandProvider", "url": "https://raw.githubusercontent.com/phisher98/cloudstream-extensions-phisher/builds/AllMovieLandProvider.cs3", "status": 200, "bytes": 86145}, {"name": "AllWish", "url": "https://raw.githubusercontent.com/phisher98/cloudstream-extensions-phisher/builds/AllWish.cs3", "status": 200, "bytes": 72639}]

## CloudStream — Redowan CloudStream
- **repo_status:** `200`
- **plugin_entries_sampled_lists:** `1`
- **plugin_entries_count_in_sampled_lists:** `18`
- **عينات CloudStream:** [{"name": "9kMovies", "url": "https://raw.githubusercontent.com/redowan99/Redowan-CloudStream/builds/9kMovies.cs3", "status": 200, "bytes": 16446}, {"name": "BanglaPlex", "url": "https://raw.githubusercontent.com/redowan99/Redowan-CloudStream/builds/BanglaPlex.cs3", "status": 200, "bytes": 35067}]

## Aniyomi/Manga — Yuzono Anime
- **status:** `200`
- **bytes:** `79414`
- **entries:** `250`
- **عينات APK:** [{"name": "Aniyomi: AnimeOnsen", "apk_status": 200, "apk_bytes": 74451, "apk_url_tested": "repo/apk/animeonsen.apk"}, {"name": "Aniyomi: AnimeWorld India", "apk_status": 200, "apk_bytes": 85847, "apk_url_tested": "repo/apk/animeworld india.apk"}, {"name": "Aniyomi: AnimeXin", "apk_status": 200, "apk_bytes": 122473, "apk_url_tested": "repo/apk/animexin.apk"}]

## Aniyomi/Manga — Secozzi
- **status:** `200`
- **bytes:** `476`
- **entries:** `1`
- **عينات APK:** [{"name": "Outdated App, switch to Animiru 0.20+", "apk_status": 404, "apk_bytes": 0, "apk_note": "الفهرس نفسه يعلن Outdated App والمسار غير موجود"}]

## Aniyomi/Manga — Keiyoushi Manga
- **status:** `200`
- **bytes:** `114083`

## Mangayomi/LNReader — Kodjodevf official
- **status:** `200`
- **bytes:** `222902`
- **entries:** `363`
- **عينات JavaScript:** [{"name": "1st Kiss-Manga (unoriginal)", "code_status": 200, "code_bytes": 15375, "language": "en"}, {"name": "Akuma no Tenshi", "code_status": 200, "code_bytes": 15375, "language": "pt-BR"}, {"name": "Anikiga", "code_status": 200, "code_bytes": 15375, "language": "tr"}]

## Mangayomi/LNReader — Mallyd11 anime
- **status:** `200`
- **bytes:** `13043`
- **entries:** `17`
- **عينات JavaScript:** [{"name": "AniKoto", "code_status": 200, "code_bytes": 73178, "language": "en"}, {"name": "ReAnime", "code_status": 200, "code_bytes": 63586, "language": "en"}, {"name": "Senshi", "code_status": 200, "code_bytes": 89254, "language": "en"}]

## Mangayomi/LNReader — LNReader official
- **status:** `200`
- **bytes:** `122928`
- **entries:** `327`
- **عينات JavaScript:** [{"name": "ArNovel", "code_status": 200, "code_bytes": 16962, "language": "‎العربية"}, {"name": "Azora", "code_status": 200, "code_bytes": 20128, "language": "‎العربية"}, {"name": "Azora Manga", "code_status": 200, "code_bytes": 6853, "language": "‎العربية"}]

## Mangayomi/LNReader — Arabic novels
- **status:** `200`
- **bytes:** `2388`
- **entries:** `4`
- **عينات JavaScript:** [{"name": "ملوك الروايات", "code_status": 200, "code_bytes": 18082, "language": "ar"}, {"name": "مملكة الروايات", "code_status": 200, "code_bytes": 10585, "language": "ar"}, {"name": "مركز الروايات", "code_status": 200, "code_bytes": 17374, "language": "ar"}]
