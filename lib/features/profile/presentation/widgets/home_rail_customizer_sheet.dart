import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:soplay/core/content/content_mode.dart';
import 'package:soplay/core/di/injection.dart';
import 'package:soplay/core/storage/hive_service.dart';
import 'package:soplay/core/theme/app_colors.dart';
import 'package:soplay/features/home/domain/home_banner_style.dart';
import 'package:soplay/features/home/domain/home_content_kind.dart';
import 'package:soplay/features/home/domain/entities/home_section_entity.dart';
import 'package:soplay/features/home/domain/home_rail.dart';
import 'package:soplay/features/home/domain/home_section_layout.dart';
import 'package:soplay/features/profile/presentation/bloc/provider_bloc.dart';
import 'package:soplay/features/profile/presentation/bloc/provider_state.dart';

/// Reorders and hides the bands on the home screen.
///
/// ## A draft, saved on Save
///
/// Every change edits a copy. The alternative — writing as you drag — means
/// closing the sheet with the back gesture leaves whatever half-arrangement
/// was on screen at that moment, and there is nothing to undo it with.
///
/// ## Compact editing rows
///
/// Each row has a visibility switch and a dedicated drag handle. Keeping the
/// list compact lets the complete home order fit without placeholder artwork.
String _currentHomeScope(BuildContext context) {
  final hive = getIt<HiveService>();
  final providerId = hive.getCurrentProvider();
  final mode = ContentMode.fromId(hive.getContentMode());
  var category = '';
  try {
    final state = context.read<ProviderBloc>().state;
    if (state is ProviderLoaded && state.currentProviderId == providerId) {
      category = state.currentProvider?.category ?? '';
    }
  } catch (_) {
    // Profile/settings surfaces may be mounted before ProviderBloc is ready.
  }
  return HomeContentKind.resolve(
        providerId: providerId,
        mode: mode,
        category: category,
      )?.catalogueKind ??
      switch (mode) {
        ContentMode.video => 'tmdb',
        ContentMode.manga => 'anilist-manga',
        ContentMode.novel => 'anilist-novel',
      };
}

Future<void> showHomeRailCustomizer(
  BuildContext context, {
  String? scope,
  String? providerId,
  List<HomeSectionEntity> sections = const [],
}) {
  final layoutScope = scope ?? _currentHomeScope(context);
  final layoutProviderId = providerId ?? getIt<HiveService>().getCurrentProvider();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _HomeRailCustomizerSheet(
        scope: layoutScope,
        providerId: layoutProviderId,
        sections: sections,
      ),
    ),
  );
}

class _HomeRailCustomizerSheet extends StatefulWidget {
  const _HomeRailCustomizerSheet({
    required this.scope,
    required this.providerId,
    required this.sections,
  });

  final String scope;
  final String providerId;
  final List<HomeSectionEntity> sections;

  @override
  State<_HomeRailCustomizerSheet> createState() =>
      _HomeRailCustomizerSheetState();
}

class _HomeRailCustomizerSheetState extends State<_HomeRailCustomizerSheet> {
  late List<HomeRail> _order;
  late Set<String> _hidden;
  late String _bannerStyle;
  late List<HomeSectionOrderEntry> _sectionOrder;
  bool _editingSections = false;

  String get _scopeLabelKey => switch (widget.scope) {
    'anilist' => 'home_rails.layout_anime',
    'anilist-manga' => 'home_rails.layout_manga',
    'anilist-novel' => 'home_rails.layout_novel',
    'tmdb' => 'home_rails.layout_movies',
    _ => 'home_rails.layout_movies',
  };

  @override
  void initState() {
    super.initState();
    final hive = getIt<HiveService>();
    _order = sanitizeRailOrder(hive.getHomeRailOrder(scope: widget.scope));
    _hidden = {...hive.getHomeRailHidden(scope: widget.scope)};
    _bannerStyle = hive.getHomeBannerStyle(scope: widget.scope);
    _sectionOrder = sanitizeHomeSectionLayout(
      hive.getHomeSectionLayout(
        scope: widget.scope,
        providerId: widget.providerId,
        sections: widget.sections,
      ),
      widget.sections,
    );
  }

  /// The catalogue cannot be hidden.
  ///
  /// It is the app: hiding it leaves a home screen of chrome around nothing,
  /// and somebody who did it by accident has no reason to look in a customizer
  /// for the way back.
  bool _canHide(HomeRail rail) => rail != HomeRail.catalogue;

  void _toggle(HomeRail rail) {
    if (!_canHide(rail)) return;
    setState(() {
      if (!_hidden.remove(rail.id)) _hidden.add(rail.id);
    });
  }

  /// `onReorderItem` rather than `onReorder`: the newer callback hands back an
  /// index already corrected for the removed row, which is the off-by-one every
  /// hand-written reorder gets wrong in one direction only.
  void _reorder(int from, int to) {
    setState(() => _order.insert(to, _order.removeAt(from)));
  }

  void _toggleSection(HomeSectionOrderEntry entry) {
    setState(() {
      _sectionOrder = [
        for (final current in _sectionOrder)
          if (current.id == entry.id)
            HomeSectionOrderEntry(current.id, hidden: !current.hidden)
          else
            current,
      ];
    });
  }

  void _reorderSections(int from, int to) {
    setState(() => _sectionOrder.insert(to, _sectionOrder.removeAt(from)));
  }

  Future<void> _save() async {
    await getIt<HiveService>().saveHomeRails([
      for (final r in _order) r.id,
    ], _hidden, scope: widget.scope, fromCustomizer: true);
    await getIt<HiveService>().saveHomeBannerStyle(
      _bannerStyle,
      scope: widget.scope,
    );
    if (widget.sections.isNotEmpty) {
      await getIt<HiveService>().saveHomeSectionLayout(
        scope: widget.scope,
        providerId: widget.providerId,
        entries: [for (final entry in _sectionOrder) entry.encode()],
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _reset() => setState(() {
    _order = List.of(HomeRail.defaults);
    _hidden = {...HomeRail.optIn};
    _bannerStyle = HomeBannerStyle.defaultStyle.id;
    _sectionOrder = sanitizeHomeSectionLayout(const [], widget.sections);
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'home_rails.title'.tr(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _scopeLabelKey.tr(),
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  child: Text(
                    'nav_customize.reset'.tr(),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'home_rails.hint'.tr(),
              style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'home_rails.banner_style'.tr(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final style in HomeBannerStyle.values) ...[
                        ChoiceChip(
                          label: Text(style.labelKey.tr()),
                          selected: _bannerStyle == style.id,
                          onSelected: (_) =>
                              setState(() => _bannerStyle = style.id),
                          selectedColor: AppColors.primary.withValues(
                            alpha: 0.2,
                          ),
                          backgroundColor: AppColors.surface.withValues(
                            alpha: 0.72,
                          ),
                          side: BorderSide(
                            color: AppColors.primary.withValues(
                              alpha: _bannerStyle == style.id ? 0.48 : 0.17,
                            ),
                            width: 0.7,
                          ),
                          labelStyle: TextStyle(
                            color: _bannerStyle == style.id
                                ? AppColors.primaryLight
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (style != HomeBannerStyle.values.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                if (widget.sections.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text('home_rails.main_rows'.tr()),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('home_rails.catalogue_sections'.tr()),
                        ),
                      ],
                      selected: {_editingSections},
                      onSelectionChanged: (selection) => setState(
                        () => _editingSections = selection.first,
                      ),
                    ),
                  ),
                Expanded(
                  child: _editingSections
                      ? ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          buildDefaultDragHandles: false,
                          itemCount: _sectionOrder.length,
                          onReorderItem: _reorderSections,
                          proxyDecorator: (child, _, animation) => Material(
                            color: Colors.transparent,
                            child: Transform.scale(scale: 1.02, child: child),
                          ),
                          itemBuilder: (context, i) {
                            final entry = _sectionOrder[i];
                            final section = widget.sections.firstWhere(
                              (candidate) => homeSectionId(candidate) == entry.id,
                            );
                            return _SectionPreviewTile(
                              key: ValueKey(entry.id),
                              section: section,
                              entry: entry,
                              index: i,
                              onToggle: () => _toggleSection(entry),
                            );
                          },
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          buildDefaultDragHandles: false,
                          itemCount: _order.length,
                          onReorderItem: _reorder,
                          proxyDecorator: (child, _, animation) => Material(
                            color: Colors.transparent,
                            child: Transform.scale(scale: 1.02, child: child),
                          ),
                          itemBuilder: (context, i) {
                            final rail = _order[i];
                            return _RailPreviewTile(
                              key: ValueKey(rail.id),
                              rail: rail,
                              index: i,
                              hidden: _hidden.contains(rail.id),
                              canHide: _canHide(rail),
                              onToggle: () => _toggle(rail),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad + 12),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('nav_customize.cancel'.tr()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('nav_customize.save'.tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One band, drawn roughly as it appears on Home.
class _RailPreviewTile extends StatelessWidget {
  const _RailPreviewTile({
    super.key,
    required this.rail,
    required this.index,
    required this.hidden,
    required this.canHide,
    required this.onToggle,
  });

  final HomeRail rail;
  final int index;
  final bool hidden;
  final bool canHide;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        // Keep the control legible even when the rail is hidden.
        opacity: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surface.withValues(alpha: 0.78),
                    AppColors.background.withValues(alpha: 0.88),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.17),
                  width: 0.7,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.38),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.055),
                    blurRadius: 12,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(rail.icon, size: 17, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rail.labelKey.tr(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (canHide)
                    Switch(
                      value: !hidden,
                      onChanged: (_) => onToggle(),
                      thumbColor: const WidgetStatePropertyAll(Colors.white),
                      trackColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                      ),
                      trackOutlineColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.transparent
                            : AppColors.textHint,
                      ),
                      thumbIcon: WidgetStateProperty.resolveWith(
                        (states) => Icon(
                          states.contains(WidgetState.selected)
                              ? Icons.check_rounded
                              : Icons.remove_rounded,
                          color: states.contains(WidgetState.selected)
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                          size: 14,
                        ),
                      ),
                    )
                  else
                    // Locked rather than absent: an eye that is simply missing
                    // reads as a rendering bug, where a struck-through one
                    // says this cannot be turned off.
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 17,
                        color: AppColors.textHint,
                      ),
                    ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const SizedBox(
                      width: 44,
                      height: 48,
                      child: Icon(
                        Icons.drag_handle_rounded,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionPreviewTile extends StatelessWidget {
  const _SectionPreviewTile({
    super.key,
    required this.section,
    required this.entry,
    required this.index,
    required this.onToggle,
  });

  final HomeSectionEntity section;
  final HomeSectionOrderEntry entry;
  final int index;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surface.withValues(alpha: 0.78),
                  AppColors.background.withValues(alpha: 0.88),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.17),
                width: 0.7,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 8, 4),
            child: Row(
              children: [
                Icon(
                  Icons.view_agenda_outlined,
                  size: 17,
                  color: AppColors.primaryLight,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch(
                  value: !entry.hidden,
                  onChanged: (_) => onToggle(),
                  thumbColor: const WidgetStatePropertyAll(Colors.white),
                  trackColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const SizedBox(
                    width: 44,
                    height: 48,
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
