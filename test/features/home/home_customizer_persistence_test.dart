import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:soplay/core/constants/app_constants.dart';
import 'package:soplay/core/storage/hive_service.dart';
import 'package:soplay/features/home/domain/entities/home_section_entity.dart';
import 'package:soplay/features/home/domain/entities/view_all.dart';
import 'package:soplay/features/home/domain/home_rail.dart';

void main() {
  late Directory directory;
  late HiveService store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sozo-home-editor-');
    Hive.init(directory.path);
    await Hive.openBox(AppConstants.authBox);
    await Hive.openBox(AppConstants.settingsBox);
    store = HiveService();
  });
  tearDown(() async {
    store.homeRailsChanged.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test(
    'an optional rail enabled in the editor stays enabled after reload',
    () async {
      expect(store.getHomeRailHidden(), isNot(contains('watch_services')));
      await store.saveHomeRails(
        HomeRail.defaults.map((r) => r.id).toList(),
        {},
        fromCustomizer: true,
      );
      expect(
        HiveService().getHomeRailHidden(),
        isNot(contains('watch_services')),
      );
      expect(store.getHomeRailHidden(), isEmpty);
    },
  );
  test('explicitly hidden streaming services stay hidden', () async {
    final order = HomeRail.defaults.map((r) => r.id).toList();
    await store.saveHomeRails(order, {});
    expect(store.hasAnsweredHomeSuggestion('watch_services'), isFalse);
    await store.saveHomeRails(order, {'watch_services'}, fromCustomizer: true);
    expect(store.getHomeRailHidden(), contains('watch_services'));
  });

  test('each catalogue keeps its own home order and visibility', () async {
    final defaults = HomeRail.defaults.map((r) => r.id).toList();
    final animeOrder = [...defaults];
    animeOrder.insert(0, animeOrder.removeAt(1));
    await store.saveHomeRails(
      animeOrder,
      {'genres'},
      scope: 'anilist',
      fromCustomizer: true,
    );
    await store.saveHomeRails(
      defaults,
      {'live_tv'},
      scope: 'tmdb',
      fromCustomizer: true,
    );

    expect(store.getHomeRailOrder(scope: 'anilist'), animeOrder);
    expect(store.getHomeRailHidden(scope: 'anilist'), contains('genres'));
    expect(store.getHomeRailOrder(scope: 'tmdb'), defaults);
    expect(store.getHomeRailHidden(scope: 'tmdb'), contains('live_tv'));
    expect(store.getHomeRailHidden(scope: 'tmdb'), isNot(contains('genres')));
    await store.saveHomeBannerStyle('panels', scope: 'anilist');
    expect(store.getHomeBannerStyle(scope: 'anilist'), 'panels');
    expect(store.getHomeBannerStyle(scope: 'tmdb'), 'edge');
  });

  test('scoped layouts inherit old shared preferences until individually saved',
      () async {
    final order = HomeRail.defaults.map((r) => r.id).toList();
    await store.saveHomeRails(order.reversed.toList(), {'genres'});

    expect(store.getHomeRailOrder(scope: 'anilist'), order.reversed.toList());
    expect(store.getHomeRailHidden(scope: 'anilist'), contains('genres'));

    await store.saveHomeRails(order, {}, scope: 'anilist');
    expect(store.getHomeRailOrder(scope: 'anilist'), order);
    expect(store.getHomeRailOrder(scope: 'tmdb'), order.reversed.toList());
    expect(store.getHomeRailHidden(scope: 'tmdb'), contains('genres'));
  });

  test('catalogue section layouts persist by interface and source', () async {
    final sections = [
      for (final id in ['popular', 'trending'])
        HomeSectionEntity(
          key: id,
          label: id,
          viewAll: ViewAllEntity(type: 'catalogue', slug: id),
          items: const [],
        ),
    ];
    await store.saveHomeSectionLayout(
      scope: 'anilist',
      providerId: 'catalogue:anilist',
      entries: ['section:trending', '!section:popular'],
    );

    expect(
      store.getHomeSectionLayout(
        scope: 'anilist',
        providerId: 'catalogue:anilist',
        sections: sections,
      ),
      ['section:trending', '!section:popular'],
    );
    expect(
      store.getHomeSectionLayout(
        scope: 'tmdb',
        providerId: 'catalogue:tmdb',
        sections: sections,
      ),
      ['section:popular', 'section:trending'],
    );
  });
}
