import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import 'settings_providers.dart';

/// Bottom sheet of theme swatches, split into Dark and Light tabs. Each swatch
/// previews itself in its own palette. Shared by settings and login.
Future<void> showThemePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _ThemeSheet(),
  );
}

class _ThemeSheet extends ConsumerStatefulWidget {
  const _ThemeSheet();

  @override
  ConsumerState<_ThemeSheet> createState() => _ThemeSheetState();
}

class _ThemeSheetState extends ConsumerState<_ThemeSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    // Open on the tab matching the current theme's brightness.
    final current =
        ref.read(themeProvider).value ?? JellyTheme.nocturne;
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: current.isDark ? 0 : 1,
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final current = ref.watch(themeProvider).value ?? JellyTheme.nocturne;
    final dark = _tabs.index == 0;
    final themes =
        JellyTheme.values.where((t) => t.isDark == dark).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabs,
              tabs: [
                Tab(text: l.themeDark),
                Tab(text: l.themeLight),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.6,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    for (final theme in themes)
                      _Swatch(
                        theme: theme,
                        selected: theme == current,
                        onTap: () {
                          ref.read(themeProvider.notifier).setTheme(theme);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable preview tile painted in the theme's own colours.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final JellyTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = theme.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? c.accent : c.ring,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _dot(c.surfaceHigh),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _dot(c.accent),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                theme.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: c.accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
