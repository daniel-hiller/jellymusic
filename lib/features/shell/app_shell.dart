import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/jelly_colors.dart';
import '../../data/update_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../widgets/brand_mark.dart';
import '../library/library_section.dart';
import '../player/mini_player.dart';
import '../settings/settings_providers.dart';

/// Responsive chrome around the four top-level branches (Home / Library /
/// Search / Settings).
///
/// - Wide (≥ 800 px): a custom Nocturne nav rail on the left with the brand at
///   the top, the primary destinations, and **Settings pinned at the bottom**.
/// - Narrow (phones): a bottom [NavigationBar] with the three primary
///   destinations and the mini player docked above it; Settings is reached via
///   the gear in each screen's app bar.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _rail = 800.0;
  static const int _homeBranch = 0;
  static const int _libraryBranch = 1;
  static const int _searchBranch = 2;
  static const int _settingsBranch = 3;

  void _go(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      // On desktop the library categories live directly in the rail (their tab
      // bar collapses), so the sidebar drives the active section. The rail can
      // be collapsed to icons only, and lists the user's playlists when open.
      final section = ref.watch(librarySectionProvider);
      final collapsed = ref.watch(sidebarCollapsedProvider).value ?? false;
      // Only the user's favourite playlists get a quick link in the rail.
      final playlists = collapsed
          ? const <JellyfinItem>[]
          : (ref.watch(favoritePlaylistsProvider).value ??
              const <JellyfinItem>[]);

      return Scaffold(
        body: Row(
          children: [
            Container(
              width: collapsed ? 68 : 212,
              color: context.colors.navSurface,
              padding: EdgeInsets.fromLTRB(
                  collapsed ? 8 : 14, 20, collapsed ? 8 : 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RailHeader(
                    collapsed: collapsed,
                    onToggle: () =>
                        ref.read(sidebarCollapsedProvider.notifier).toggle(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _RailItem(
                            collapsed: collapsed,
                            label: l.navHome,
                            icon: index == _homeBranch
                                ? Icons.home_rounded
                                : Icons.home_outlined,
                            selected: index == _homeBranch,
                            onTap: () => _go(_homeBranch),
                          ),
                          _RailItem(
                            collapsed: collapsed,
                            label: l.navSearch,
                            icon: index == _searchBranch
                                ? Icons.search_rounded
                                : Icons.search_outlined,
                            selected: index == _searchBranch,
                            onTap: () => _go(_searchBranch),
                          ),
                          if (collapsed)
                            const SizedBox(height: 8)
                          else
                            _RailSectionLabel(l.libraryTitle),
                          for (final s in LibrarySection.values)
                            _RailItem(
                              collapsed: collapsed,
                              label: s.label(l),
                              icon: (index == _libraryBranch && section == s)
                                  ? s.icon
                                  : s.outlinedIcon,
                              selected:
                                  index == _libraryBranch && section == s,
                              onTap: () {
                                ref
                                    .read(librarySectionProvider.notifier)
                                    .state = s;
                                _go(_libraryBranch);
                              },
                            ),
                          if (playlists.isNotEmpty) ...[
                            _RailSectionLabel(l.tabPlaylists),
                            for (final p in playlists)
                              _RailItem(
                                collapsed: false,
                                label: p.name,
                                icon: Icons.queue_music_outlined,
                                selected: false,
                                onTap: () =>
                                    context.go('/library/playlist/${p.id}'),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _RailItem(
                    collapsed: collapsed,
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

/// The rail's brand header with a collapse / expand toggle. Lays the brand and
/// chevron in a row when open, and stacks them when collapsed to icons.
class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.collapsed, required this.onToggle});

  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final toggle = IconButton(
      tooltip: MaterialLocalizations.of(context).drawerLabel,
      iconSize: 20,
      icon: Icon(collapsed
          ? Icons.chevron_right_rounded
          : Icons.chevron_left_rounded),
      onPressed: onToggle,
    );
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          children: [
            const BrandMark(size: 26),
            const SizedBox(height: 10),
            toggle,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 2, 20),
      child: Row(
        children: [
          const BrandMark(size: 26),
          const SizedBox(width: 11),
          const Expanded(
            child: Text('JellyMusic',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          toggle,
        ],
      ),
    );
  }
}

/// A single rail destination: rounded pill, accent-tinted when active. In
/// [collapsed] mode it shrinks to a centred icon with the label as a tooltip.
class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.collapsed = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool collapsed;

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
          child: Tooltip(
            message: collapsed ? label : '',
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 10 : 14, vertical: 10),
              child: collapsed
                  ? Icon(icon, size: 22, color: color)
                  : Row(
                      children: [
                        Icon(icon, size: 22, color: color),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: color),
                          ),
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

/// A small caps group heading in the rail (e.g. "BIBLIOTHEK").
class _RailSectionLabel extends StatelessWidget {
  const _RailSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: context.colors.textTertiary,
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
