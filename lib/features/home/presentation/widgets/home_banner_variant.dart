import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:soplay/core/system/platform_utils.dart';
import 'package:soplay/core/theme/app_colors.dart';
import 'package:soplay/features/home/domain/entities/hero_slide.dart';
import 'package:soplay/features/home/domain/home_banner_style.dart';

import 'home_banner.dart';

/// Renders the selected Zangetsu Home banner arrangement using Sozo's existing
/// movie/catalogue and CMS slide handlers.
class HomeBannerVariant extends StatelessWidget {
  const HomeBannerVariant({
    super.key,
    required this.style,
    required this.slides,
    required this.topPadding,
    this.showSkeleton = true,
  });

  final HomeBannerStyle style;
  final List<HeroSlide> slides;
  final double topPadding;
  final bool showSkeleton;

  @override
  Widget build(BuildContext context) {
    if (isDesktopPlatform || style == HomeBannerStyle.edge) {
      return HomeBanner(
        slides: slides,
        topPadding: topPadding,
        showSkeleton: showSkeleton,
      );
    }
    if (slides.isEmpty) {
      return HomeBanner(
        slides: slides,
        topPadding: topPadding,
        showSkeleton: showSkeleton,
      );
    }
    if (style == HomeBannerStyle.panels) {
      return _PanelsBanner(
        slides: slides,
        topPadding: topPadding,
      );
    }

    final heroHeight = mobileHeroHeight(context);
    final topInset = topPadding + 54;
    return SizedBox(
      height: heroHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(15, topInset, 15, 10),
        child: _GoldGlassFrame(
          radius: 20,
          child: HomeBanner(
            slides: slides,
            topPadding: 0,
            showSkeleton: showSkeleton,
          ),
        ),
      ),
    );
  }
}

class _PanelsBanner extends StatefulWidget {
  const _PanelsBanner({required this.slides, required this.topPadding});

  final List<HeroSlide> slides;
  final double topPadding;

  @override
  State<_PanelsBanner> createState() => _PanelsBannerState();
}

class _PanelsBannerState extends State<_PanelsBanner> {
  static const _tilt = -0.008;
  Timer? _timer;
  int _index = 0;

  List<HeroSlide> get _slides => widget.slides.take(6).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _PanelsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.slides, widget.slides)) {
      _index = 0;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_slides.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
        setState(() => _index = (_index + 1) % _slides.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    final height = mobileHeroHeight(context);
    if (slides.isEmpty) return SizedBox(height: height);
    final topReserve = widget.topPadding + 56;
    final sideCount = (slides.length - 1).clamp(0, 2);
    final main = slides[_index % slides.length];

    Widget panel(HeroSlide slide, {required double radius}) => _GoldGlassFrame(
      key: ValueKey(_slideKey(slide)),
      radius: radius,
      child: HomeBanner(slides: [slide], topPadding: 0, showSkeleton: false),
    );

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, topReserve, 14, 12),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 80 || slides.length < 2) return;
            setState(() {
              _index = (_index + (velocity < 0 ? 1 : -1) + slides.length) %
                  slides.length;
            });
            _startTimer();
          },
          child: Transform.rotate(
            angle: _tilt * 2 * 3.141592653589793,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 172, child: panel(main, radius: 18)),
                if (sideCount > 0) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: panel(
                            slides[(_index + 1) % slides.length],
                            radius: 15,
                          ),
                        ),
                        if (sideCount > 1) ...[
                          const SizedBox(height: 6),
                          Expanded(
                            child: panel(
                              slides[(_index + 2) % slides.length],
                              radius: 15,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _slideKey(HeroSlide slide) => switch (slide) {
  MovieHeroSlide(:final movie) => 'movie:${movie.provider}:${movie.url}',
  BannerHeroSlide(:final banner) => 'banner:${banner.id}',
};

/// Thin metallic edge, translucent black glass backing, and a restrained lift
/// shadow shared by the inset and manga-spread banner variants.
class _GoldGlassFrame extends StatelessWidget {
  const _GoldGlassFrame({super.key, required this.child, required this.radius});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.72),
        borderRadius: borderRadius,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.36),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.56),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }
}
