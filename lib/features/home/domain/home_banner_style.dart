/// Selectable Home hero arrangements adapted from Zangetsu's real Home banner
/// options. The ids are persisted per catalogue and must remain stable.
enum HomeBannerStyle {
  edge('edge', 'home_rails.banner_edge'),
  card('card', 'home_rails.banner_card'),
  panels('panels', 'home_rails.banner_panels');

  const HomeBannerStyle(this.id, this.labelKey);

  final String id;
  final String labelKey;

  static const HomeBannerStyle defaultStyle = edge;

  static HomeBannerStyle fromId(String? id) => HomeBannerStyle.values.firstWhere(
    (style) => style.id == id,
    orElse: () => defaultStyle,
  );
}
