import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:soplay/core/system/responsive.dart';
import 'package:soplay/core/theme/app_colors.dart';
import 'package:soplay/features/profile/presentation/widgets/settings_tiles.dart';
import 'package:url_launcher/url_launcher.dart';

/// Build information and direct developer contact.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'profile.about'.tr(),
      children: const [AboutSection(showLabel: false)],
    );
  }
}

/// The About card on its own, so the desktop Profile panel and [AboutPage]
/// share one copy.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key, this.showLabel = true});

  final bool showLabel;

  /// Resolved once: rebuilt per build() it dropped the version row back to
  /// "…" on every rebuild of the list.
  static final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  static Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _showDeveloper(BuildContext context) {
    showAdaptiveModal<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  'https://avatars.githubusercontent.com/u/108933534?v=4',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 56,
                    height: 56,
                    color: AppColors.primary,
                    child: const Center(
                      child: Text(
                        'AX',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Azamov X',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'profile.developer_role'.tr(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _open('mailto:aimenalwwaby@gmail.com'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: Color(0xFF2AABEE),
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'aimenalwwaby@gmail.com',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.open_in_new_rounded,
                            color: AppColors.textHint,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) SettingsLabel('profile.section_about'.tr()),
        SettingsCard(
          children: [
            SettingsNavTile(
              icon: Icons.info_outline_rounded,
              title: 'Sozo',
              trailing: FutureBuilder<PackageInfo>(
                future: _packageInfo,
                builder: (_, snap) => Text(
                  snap.hasData
                      ? 'v${snap.data!.version} (${snap.data!.buildNumber})'
                      : '…',
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SettingsDivider(),
            SettingsNavTile(
              icon: Icons.person_outline_rounded,
              title: 'profile.developer'.tr(),
              value: 'Azamov X',
              onTap: () => _showDeveloper(context),
            ),
            const SettingsDivider(),
            SettingsNavTile(
              icon: Icons.email_outlined,
              title: 'تواصل مع المطور',
              value: 'aimenalwwaby@gmail.com',
              onTap: () => _open('mailto:aimenalwwaby@gmail.com'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialIcon(
              icon: Icons.email_outlined,
              label: 'Email',
              onTap: () => _open('mailto:aimenalwwaby@gmail.com'),
            ),
            const SizedBox(width: 16),
            _SocialIcon(
              icon: Icons.language_rounded,
              label: 'profile.website'.tr(),
              onTap: () => _open('https://sozo.azamov.me'),
            ),
            const SizedBox(width: 16),
            _SocialIcon(
              icon: Icons.code_rounded,
              label: 'GitHub',
              onTap: () => _open('https://github.com/professorDeveloper'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverTap(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
