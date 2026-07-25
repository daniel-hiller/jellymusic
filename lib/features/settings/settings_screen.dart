import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/theme/jelly_colors.dart';
import '../../data/update_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/cast_providers.dart';
import '../../providers/providers.dart';
import '../../widgets/brand_mark.dart';
import 'settings_providers.dart';
import 'theme_picker.dart';

/// App settings, grouped into tabs: account, playback, appearance and about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.settingsTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.settingsTabAccount),
              Tab(text: l.settingsTabPlayback),
              Tab(text: l.settingsTabAppearance),
              Tab(text: l.settingsTabAbout),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AccountTab(),
            _PlaybackTab(),
            _AppearanceTab(),
            _AboutTab(),
          ],
        ),
      ),
    );
  }
}

// ─── Account ─────────────────────────────────────────────────────────

class _AccountTab extends ConsumerWidget {
  const _AccountTab();

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.settingsSignOutConfirmTitle),
        content: Text(l.settingsSignOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.settingsSignOut),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(authControllerProvider.notifier).logout();
    // The router's auth redirect takes over and routes to /login.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final session = ref.watch(authControllerProvider).value;
    final accounts = ref.watch(savedAccountsProvider).value ?? const [];
    return ListView(
      children: [
        for (final a in accounts)
          ListTile(
            leading: Icon(
              a.key == session?.key
                  ? Icons.check_circle_rounded
                  : Icons.person_outline_rounded,
              color: a.key == session?.key ? context.colors.accent : null,
            ),
            title: Text(a.userName.isEmpty ? a.baseUrl : a.userName),
            subtitle:
                Text(a.baseUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: a.key == session?.key
                ? null
                : () => ref
                    .read(authControllerProvider.notifier)
                    .switchServer(a),
          ),
        ListTile(
          leading: const Icon(Icons.add_rounded),
          title: Text(l.settingsAddServer),
          onTap: () => context.push('/add-account'),
        ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.logout_rounded, color: context.colors.error),
          title: Text(
            accounts.length > 1 ? l.settingsSignOutCurrent : l.settingsSignOut,
            style: TextStyle(color: context.colors.error),
          ),
          onTap: () => _logout(context, ref),
        ),
      ],
    );
  }
}

// ─── Playback ────────────────────────────────────────────────────────

class _PlaybackTab extends ConsumerWidget {
  const _PlaybackTab();

  String _qualityLabel(AppLocalizations l, AudioQuality q) => switch (q) {
        AudioQuality.auto => l.qualityAuto,
        AudioQuality.low => l.qualityLow,
        AudioQuality.medium => l.qualityMedium,
        AudioQuality.high => l.qualityHigh,
        AudioQuality.max => l.qualityMax,
      };

  String _fadeLabel(AppLocalizations l, int seconds) =>
      seconds == 0 ? l.fadeOff : l.fadeSeconds('$seconds');

  Future<void> _pickQuality(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final current = ref.read(audioQualityProvider).value;
    final picked = await showDialog<AudioQuality>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.settingsStreamingQuality),
        children: [
          for (final q in AudioQuality.values)
            ListTile(
              title: Text(_qualityLabel(l, q)),
              trailing: q == current
                  ? Icon(Icons.check_rounded, color: context.colors.accent)
                  : null,
              onTap: () => Navigator.of(context).pop(q),
            ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(audioQualityProvider.notifier).setQuality(picked);
    }
  }

  Future<void> _pickFade(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final current = ref.read(fadeSecondsProvider).value ?? 0;
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.settingsFade),
        children: [
          for (final seconds in const [0, 2, 3, 5, 8])
            ListTile(
              title: Text(_fadeLabel(l, seconds)),
              trailing: seconds == current
                  ? Icon(Icons.check_rounded, color: context.colors.accent)
                  : null,
              onTap: () => Navigator.of(context).pop(seconds),
            ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(fadeSecondsProvider.notifier).set(picked);
    }
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    await ref.read(jellyfinServiceProvider).clearCache();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.settingsCacheCleared)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final quality = ref.watch(audioQualityProvider).value;
    final fade = ref.watch(fadeSecondsProvider).value;
    final gapless = ref.watch(gaplessProvider).value ?? true;
    final castReceiver =
        ref.watch(castReceiverEnabledProvider).value ?? true;
    // The prefetch knob is a libmpv setting, so it only exists on the desktop
    // backend — mobile plays a ConcatenatingAudioSource gaplessly anyway.
    final hasGaplessToggle = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows);

    return ListView(
      children: [
        _SectionHeader(l.settingsAudio),
        ListTile(
          leading: const Icon(Icons.high_quality_rounded),
          title: Text(l.settingsStreamingQuality),
          subtitle: Text(quality == null ? '…' : _qualityLabel(l, quality)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _pickQuality(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.multitrack_audio_rounded),
          title: Text(l.settingsFade),
          subtitle: Text(fade == null ? '…' : _fadeLabel(l, fade)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _pickFade(context, ref),
        ),
        if (hasGaplessToggle)
          SwitchListTile(
            secondary: const Icon(Icons.all_inclusive_rounded),
            title: Text(l.settingsGapless),
            subtitle: Text(l.settingsGaplessSubtitle),
            value: gapless,
            onChanged: (v) => ref.read(gaplessProvider.notifier).set(v),
          ),
        const Divider(),
        _SectionHeader(l.settingsCast),
        SwitchListTile(
          secondary: const Icon(Icons.cast_rounded),
          title: Text(l.settingsCastReceiver),
          subtitle: Text(l.settingsCastReceiverSubtitle),
          value: castReceiver,
          onChanged: (v) =>
              ref.read(castReceiverEnabledProvider.notifier).set(v),
        ),
        const Divider(),
        _SectionHeader(l.settingsStorage),
        ListTile(
          leading: const Icon(Icons.cleaning_services_rounded),
          title: Text(l.settingsClearCache),
          subtitle: Text(l.settingsClearCacheSubtitle),
          onTap: () => _clearCache(context, ref),
        ),
      ],
    );
  }
}

// ─── Appearance ──────────────────────────────────────────────────────

class _AppearanceTab extends ConsumerWidget {
  const _AppearanceTab();

  String _languageLabel(AppLocalizations l, Locale? locale) =>
      switch (locale?.languageCode) {
        'de' => l.languageGerman,
        'en' => l.languageEnglish,
        _ => l.languageSystem,
      };

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final options = <String, String>{
      'system': l.languageSystem,
      'de': l.languageGerman,
      'en': l.languageEnglish,
    };
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.settingsLanguage),
        children: [
          for (final e in options.entries)
            ListTile(
              title: Text(e.value),
              onTap: () => Navigator.of(context).pop(e.key),
            ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(localeProvider.notifier).setLanguage(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = ref.watch(themeProvider).value;
    final locale = ref.watch(localeProvider).value;
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.palette_rounded),
          title: Text(l.settingsTheme),
          subtitle: Text(theme?.label ?? '…'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showThemePicker(context),
        ),
        ListTile(
          leading: const Icon(Icons.language_rounded),
          title: Text(l.settingsLanguage),
          subtitle: Text(_languageLabel(l, locale)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _pickLanguage(context, ref),
        ),
      ],
    );
  }
}

// ─── About ───────────────────────────────────────────────────────────

class _AboutTab extends ConsumerWidget {
  const _AboutTab();

  static Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final update = ref.watch(updateProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const _AboutHero(),
        const SizedBox(height: 20),

        // Update status — only where update checks make sense (not iOS/web).
        if (AppInfo.supportsUpdateCheck)
          update.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (info) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: info == null
                  ? _AboutStatusCard(
                      icon: Icons.check_circle_rounded,
                      label: l.updateUpToDate,
                    )
                  : _AboutStatusCard(
                      icon: Icons.system_update_rounded,
                      label: l.updateAvailable(info.version),
                      action: FilledButton(
                        onPressed: () => _open(info.url),
                        child: Text(l.updateDownload),
                      ),
                      onTap: () => _open(info.url),
                    ),
            ),
          ),

        // Grouped external links.
        _AboutLinkGroup(
          rows: [
            _AboutLink(
              icon: Icons.code_rounded,
              label: l.aboutGithub,
              onTap: () => _open(AppInfo.repoUrl),
            ),
            _AboutLink(
              icon: Icons.auto_awesome_rounded,
              label: l.aboutWhatsNew,
              onTap: () => _open(AppInfo.releasesUrl),
            ),
            _AboutLink(
              icon: Icons.bug_report_rounded,
              label: l.aboutReportIssue,
              onTap: () => _open(AppInfo.issuesUrl),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Center(
          child: Text(
            '${l.aboutBuiltWith}  ·  ${l.aboutCopyright(AppInfo.author)}',
            style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// The About header: a soft accent-gradient panel with the brand mark, name,
/// tagline and a version pill.
class _AboutHero extends StatelessWidget {
  const _AboutHero();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.ring),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.accent.withValues(alpha: 0.20),
            c.accentAlt.withValues(alpha: 0.08),
            c.surfaceHigh.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        children: [
          const BrandMark(size: 72),
          const SizedBox(height: 16),
          const Text('JellyMusic',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).aboutTagline,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              AppInfo.version,
              style: TextStyle(
                color: c.accentBright,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single-line status card (update state) with an optional trailing action.
class _AboutStatusCard extends StatelessWidget {
  const _AboutStatusCard({
    required this.icon,
    required this.label,
    this.action,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: c.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (action != null) action!,
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded card grouping several [_AboutLink] rows with hairline dividers.
class _AboutLinkGroup extends StatelessWidget {
  const _AboutLinkGroup({required this.rows});

  final List<_AboutLink> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.ring),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _AboutLink extends StatelessWidget {
  const _AboutLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 22, color: c.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.open_in_new_rounded, size: 18, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: context.colors.accent,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
