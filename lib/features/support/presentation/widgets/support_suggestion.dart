import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:soplay/core/theme/app_colors.dart';
import 'package:soplay/features/support/data/support_models.dart';

/// Keeps error-state call sites source-compatible while preserving the
/// diagnostic context in the in-app support request form.
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
      onPressed: () => context.push(
        '/support/new',
        extra: SupportRequestArgs(
          screen: screen,
          category: category,
          provider: provider,
          content: content,
          error: error,
        ),
      ),
      style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
      icon: const Icon(Icons.email_outlined, size: 17),
      label: const Text('تواصل مع المطور', style: TextStyle(fontSize: 13)),
    );
  }
}
