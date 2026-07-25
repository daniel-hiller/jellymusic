import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/jelly_colors.dart';
import '../../data/update_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/brand_mark.dart';
import '../player/mini_player.dart';

/// Responsive chrome around the four top-level branches (Home / Library /
/// Search / Settings).
///
/// - Wide (≥ 800 px): a custom Nocturne nav rail on the left with the brand at
///   the top, the primary destinations, and **Settings pinned at the bottom**.
/// - Narrow (phones): a bottom [NavigationBar] with the three primary
///   destinations and the mini player docked above it; Settings is reached via
///   the gear in each screen's app bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _rail = 800.0;
  static const int _settingsBranch = 3;

  void _go(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= _rail;
    final index = navigationShell.currentIndex;

    final miniPlayer = MiniPlayer(onTap: () => context.push('/now-playing'));

    final primary = [
      (l.navHome, Icons.home_rounded, Icons.home_outlined),
      (l.navLibrary, Icons.library_music_rounded, Icons.library_music_outlined),
      (l.navSearch, Icons.search_rounded, Icons.search_outlined),
    ];

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 212,
              color: context.colors.navSurface,
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 4, 12, 22),
                    child: Row(
                      children: [
                        BrandMark(size: 26),
                        SizedBox(width: 11),
                        Text('JellyMusic',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  for (var i = 0; i < primary.length; i++)
                    _RailItem(
                      label: primary[i].$1,
                      icon: index == i ? primary[i].$2 : primary[i].$3,
                      selected: index == i,
                      onTap: () => _go(i),
                    ),
                  const Spacer(),
                  _RailItem(
                    label: l.settingsTitle,
                    icon: Icons.settings_rounded,
                    selected: index == _settingsBranch,
                    onTap: () => _go(_settingsBranch),
                  ),
                ],
              ),
            ),
            VerticalDivider(width: 1, color: context.colors.ring),
            Expanded(
              child: Column(
                children: [
                  const _UpdateBanner(),
                  Expanded(child: navigationShell),
                  miniPlayer,
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          const _UpdateBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          miniPlayer,
          NavigationBar(
            selectedIndex: index,
            onDestinationSelected: _go,
            destinations: [
              for (final d in primary)
                NavigationDestination(
                  icon: Icon(d.$3),
                  selectedIcon: Icon(d.$2),
                  label: d.$1,
                ),
              // Settings lives in the bottom nav on phones (it's a gear in the
              // sidebar on desktop instead).
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: l.settingsTitle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single rail destination: rounded pill, accent-tinted when active.
class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? context.colors.textPrimary : context.colors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? context.colors.accent.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 14),
                Text(label,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A slim, dismissible strip shown when a newer release exists on GitHub.
/// Hidden entirely on iOS/web and until the check resolves (see updateProvider).
class _UpdateBanner extends ConsumerWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(updateProvider).value;
    final dismissed = ref.watch(updateBannerDismissedProvider);
    if (info == null || dismissed) return const SizedBox.shrink();

    final l = AppLocalizations.of(context);
    final accent = context.colors.accent;
    return Material(
      color: accent.withValues(alpha: 0.14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            Icon(Icons.system_update_rounded, size: 20, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.updateBannerTitle(info.version),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => launchUrl(Uri.parse(info.url),
                  mode: LaunchMode.externalApplication),
              child: Text(l.commonView),
            ),
            IconButton(
              tooltip: l.commonDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () =>
                  ref.read(updateBannerDismissedProvider.notifier).state = true,
            ),
          ],
        ),
      ),
    );
  }
}
