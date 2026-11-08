import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Dark, gold-tinted glass surfaces used by the Sozo Gold experience.
///
/// The widget deliberately keeps a translucent body and a real backdrop blur:
/// artwork and gradients remain visible behind the surface instead of being
/// covered by a flat card. The two hairline gradients and the low shadow add
/// the small depth cues that make the panel read as a floating 3D object.
class GoldGlass extends StatelessWidget {
  const GoldGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.padding,
    this.blur = 18,
    this.opacity = 0.34,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.105),
                AppColors.primary.withValues(alpha: opacity),
                AppColors.primaryDark.withValues(alpha: 0.16),
                Colors.black.withValues(alpha: 0.30),
              ],
              stops: const [0.0, 0.18, 0.62, 1.0],
            ),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.30),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.42),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.11),
                blurRadius: 18,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}

/// A lightweight backdrop for Home. It supplies depth behind the translucent
/// rails without adding an extra scrollable or intercepting gestures.
class GoldGlassBackdrop extends StatelessWidget {
  const GoldGlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        gradient: RadialGradient(
          center: const Alignment(-0.72, -0.92),
          radius: 1.25,
          colors: [
            AppColors.primaryDark.withValues(alpha: 0.24),
            AppColors.background.withValues(alpha: 0.94),
            AppColors.background,
          ],
          stops: const [0.0, 0.46, 1.0],
        ),
      ),
      child: child,
    );
  }
}
