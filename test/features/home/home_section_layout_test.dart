import 'package:flutter_test/flutter_test.dart';
import 'package:soplay/features/home/domain/entities/home_section_entity.dart';
import 'package:soplay/features/home/domain/entities/view_all.dart';
import 'package:soplay/features/home/domain/home_section_layout.dart';

HomeSectionEntity section(String key) => HomeSectionEntity(
  key: key,
  label: key,
  viewAll: ViewAllEntity(type: 'catalogue', slug: key),
  items: const [],
);

void main() {
  test('section ordering and hidden state are retained independently', () {
    final sections = [section('popular'), section('trending'), section('latest')];
    final layout = sanitizeHomeSectionLayout(
      ['section:latest', '!section:popular', 'removed', 'section:latest'],
      sections,
    );

    expect(layout.map((entry) => entry.encode()).toList(), [
      'section:latest',
      '!section:popular',
      'section:trending',
    ]);
    expect(
      orderedHomeSections(sections, layout).map((entry) => entry.key).toList(),
      ['latest', 'trending'],
    );
  });

  test('new sections append visible without changing saved order', () {
    final sections = [section('popular'), section('new')];
    final layout = sanitizeHomeSectionLayout(
      ['!section:popular'],
      sections,
    );

    expect(layout.map((entry) => entry.encode()).toList(), [
      '!section:popular',
      'section:new',
    ]);
  });
}
