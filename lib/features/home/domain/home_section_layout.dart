import 'entities/home_section_entity.dart';

/// A catalogue/source section's position and visibility on Home.
class HomeSectionOrderEntry {
  const HomeSectionOrderEntry(this.id, {this.hidden = false});

  final String id;
  final bool hidden;

  String encode() => hidden ? '!$id' : id;
}

String homeSectionId(HomeSectionEntity section) => 'section:${section.key}';

HomeSectionOrderEntry _decodeSectionEntry(String stored) =>
    stored.startsWith('!')
    ? HomeSectionOrderEntry(stored.substring(1), hidden: true)
    : HomeSectionOrderEntry(stored);

/// Reconciles saved order with the sections the active catalogue currently
/// supplies. Unknown and duplicate keys are dropped; newly supplied rows append
/// visible so an API update never silently hides new content.
List<HomeSectionOrderEntry> sanitizeHomeSectionLayout(
  List<String> stored,
  List<HomeSectionEntity> sections,
) {
  final available = sections.map(homeSectionId).toList(growable: false);
  final seen = <String>{};
  final result = <HomeSectionOrderEntry>[];
  for (final raw in stored) {
    final entry = _decodeSectionEntry(raw);
    if (available.contains(entry.id) && seen.add(entry.id)) result.add(entry);
  }
  for (final id in available) {
    if (seen.add(id)) result.add(HomeSectionOrderEntry(id));
  }
  return result;
}

List<HomeSectionEntity> orderedHomeSections(
  List<HomeSectionEntity> sections,
  List<HomeSectionOrderEntry> layout,
) {
  final byId = {for (final section in sections) homeSectionId(section): section};
  return [
    for (final entry in layout)
      if (!entry.hidden)
        if (byId[entry.id] case final section?) section,
  ];
}
