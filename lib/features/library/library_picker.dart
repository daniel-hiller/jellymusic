import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';

/// Where the picker is being shown, and therefore how much room it gets.
enum LibraryPickerStyle {
  /// Compact form for the library app bar on phones.
  appBar,

  /// Full-width row at the top of the desktop sidebar.
  rail,

  /// The sidebar's icon-only form while the rail is collapsed.
  railCollapsed,
}

/// Switches the music library everything browses, with "all libraries" as the
/// first choice.
///
/// Renders nothing when the server has a single music library — which is the
/// common case, and where a switcher would only be a control that can't move
/// anything.
class LibraryPicker extends ConsumerWidget {
  const LibraryPicker({super.key, required this.style});

  final LibraryPickerStyle style;

  /// A popup menu reads a `null` selection as "dismissed", so "all libraries"
  /// travels as an empty id and is mapped back on the way out.
  static const _allLibraries = '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final views = ref.watch(musicViewsProvider).value ?? const [];
    if (views.length < 2) return const SizedBox.shrink();

    final active = ref.watch(activeMusicViewProvider).value;
    var label = l.libraryAll;
    for (final view in views) {
      if (view.id == active) label = view.name;
    }

    return PopupMenuButton<String>(
      tooltip: l.libraryPickerTitle,
      initialValue: active ?? _allLibraries,
      onSelected: (id) => ref
          .read(activeMusicViewProvider.notifier)
          .select(id == _allLibraries ? null : id),
      itemBuilder: (context) => [
        PopupMenuItem(value: _allLibraries, child: Text(l.libraryAll)),
        for (final view in views)
          PopupMenuItem(value: view.id, child: Text(view.name)),
      ],
      child: switch (style) {
        LibraryPickerStyle.appBar => _CompactLabel(label: label),
        LibraryPickerStyle.rail => _RailLabel(label: label),
        LibraryPickerStyle.railCollapsed => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Icon(Icons.library_music_outlined,
                size: 22, color: context.colors.textSecondary),
          ),
      },
    );
  }
}

/// The app-bar form: the library name, truncated so a long name can't push the
/// title out of the bar.
class _CompactLabel extends StatelessWidget {
  const _CompactLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.library_music_outlined, size: 20),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.arrow_drop_down_rounded),
        ],
      ),
    );
  }
}

/// The sidebar form: a full-width tinted row that reads like a header.
class _RailLabel extends StatelessWidget {
  const _RailLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigher,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.library_music_outlined,
              size: 20, color: context.colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.unfold_more_rounded,
              size: 18, color: context.colors.textTertiary),
        ],
      ),
    );
  }
}
