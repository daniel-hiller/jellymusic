import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../features/settings/settings_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/player_providers.dart';

/// True on the three desktop platforms (where a system tray exists).
bool get isDesktop =>
    !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

/// Hosts a system-tray icon with quick transport controls (desktop only).
///
/// Wraps the app so it can read the player providers and localisation. On
/// mobile/web it's a transparent pass-through — [child] is returned untouched
/// and no tray is created.
class DesktopTray extends ConsumerStatefulWidget {
  const DesktopTray({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DesktopTray> createState() => _DesktopTrayState();
}

class _DesktopTrayState extends ConsumerState<DesktopTray>
    with TrayListener, WindowListener {
  // Transparent brand mark; the tray panel supplies its own background.
  static const _iconPath = 'assets/icon/brand-1024.png';

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (isDesktop) {
      trayManager.addListener(this);
      windowManager.addListener(this);
      _init();
    }
  }

  @override
  void dispose() {
    if (isDesktop) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await trayManager.setIcon(_iconPath);
      await trayManager.setToolTip('JellyMusic');
    } catch (_) {
      // A missing/incompatible icon shouldn't take the app down; the menu
      // still works without it.
    }
    _ready = true;
    await _syncMenu();
  }

  /// Rebuild the context menu to reflect the current track and play state.
  Future<void> _syncMenu() async {
    if (!_ready || !mounted) return;
    final l = AppLocalizations.of(context);
    final playing = ref.read(isPlayingProvider);
    final item = ref.read(currentMediaItemProvider).value;
    final nowPlaying = item == null
        ? l.trayNothingPlaying
        : [item.title, item.artist].where((s) => s != null && s.isNotEmpty)
            .join(' — ');

    final menu = Menu(
      items: [
        MenuItem(key: 'now_playing', label: nowPlaying, disabled: true),
        MenuItem.separator(),
        MenuItem(
          key: 'play_pause',
          label: playing ? l.trayPause : l.trayPlay,
        ),
        MenuItem(key: 'previous', label: l.trayPrevious),
        MenuItem(key: 'next', label: l.trayNext),
        MenuItem.separator(),
        MenuItem(key: 'show', label: l.trayShow),
        MenuItem(key: 'quit', label: l.trayQuit),
      ],
    );
    try {
      await trayManager.setContextMenu(menu);
    } catch (_) {}
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  // ── TrayListener ──────────────────────────────────────────────────
  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final controller = ref.read(playerControllerProvider);
    switch (menuItem.key) {
      case 'play_pause':
        controller.togglePlay();
      case 'previous':
        controller.previous();
      case 'next':
        controller.next();
      case 'show':
        _showWindow();
      case 'quit':
        windowManager.destroy();
    }
  }

  // ── WindowListener ────────────────────────────────────────────────
  @override
  void onWindowClose() {
    // Only fires while preventClose is set (i.e. close-to-tray is on): hide to
    // the tray instead of quitting.
    if (ref.read(closeToTrayProvider).value ?? false) {
      windowManager.hide();
    } else {
      windowManager.destroy();
    }
  }

  @override
  void onWindowMinimize() {
    if (ref.read(minimizeToTrayProvider).value ?? false) {
      windowManager.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      // Keep the menu labels in step with playback and locale changes.
      ref.watch(isPlayingProvider);
      ref.watch(currentMediaItemProvider);
      AppLocalizations.of(context); // re-run on locale change
      // Intercept the window close button only when close-to-tray is on.
      final closeToTray = ref.watch(closeToTrayProvider).value ?? false;
      windowManager.setPreventClose(closeToTray);
      if (_ready) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncMenu());
      }
    }
    return widget.child;
  }
}
