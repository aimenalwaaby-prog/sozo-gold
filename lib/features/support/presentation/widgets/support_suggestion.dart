import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:soplay/core/theme/app_colors.dart';
import 'package:soplay/features/support/data/support_models.dart';

/// Keeps error-state call sites source-compatible while opening the developer
/// email instead of the removed support inbox.
class SupportSuggestion extends StatelessWidget {
  const SupportSuggestion({
    super.key,
    required this.screen,
    this.category = SupportCategory.bug,
    this.provider,
    this.content,
    this.error,
  });

  final String screen;
  final SupportCategory category;
  final String? provider;
  final String? content;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => launchUrl(
        Uri.parse('mailto:aimenalwwaby@gmail.com?subject=Sozo%20Gold%20issue'),
        mode: LaunchMode.externalApplication,
      ),
      style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
      icon: const Icon(Icons.email_outlined, size: 17),
      label: const Text('تواصل مع المطور', style: TextStyle(fontSize: 13)),
    );
  }
}
