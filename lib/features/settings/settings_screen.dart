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

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final update = ref.watch(updateProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      children: [
        const Center(child: BrandMark(size: 84)),
        const SizedBox(height: 16),
        const Center(
          child: Text('JellyMusic',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            l.aboutTagline,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '${l.aboutVersionLabel} ${AppInfo.version}',
            style: TextStyle(color: context.colors.textTertiary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 24),

        // Update status — only where update checks make sense (not iOS/web).
        if (AppInfo.supportsUpdateCheck)
          update.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (info) => info == null
                ? ListTile(
                    leading: Icon(Icons.check_circle_outline_rounded,
                        color: context.colors.accent),
                    title: Text(l.updateUpToDate),
                  )
                : ListTile(
                    leading: Icon(Icons.system_update_rounded,
                        color: context.colors.accent),
                    title: Text(l.updateAvailable(info.version)),
                    trailing: FilledButton(
                      onPressed: () => _open(info.url),
                      child: Text(l.updateDownload),
                    ),
                    onTap: () => _open(info.url),
                  ),
          ),

        ListTile(
          leading: const Icon(Icons.code_rounded),
          title: Text(l.aboutGithub),
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: () => _open(AppInfo.repoUrl),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            l.aboutCopyright(AppInfo.author),
            style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
          ),
        ),
      ],
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
