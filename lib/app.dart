import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/settings_providers.dart';
import 'l10n/app_localizations.dart';
import 'providers/cast_providers.dart';

/// Root widget: wires the router, the single dark theme, and localisation.
class JellyMusicApp extends ConsumerWidget {
  const JellyMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Keeps this device announced as a cast target while logged in; the
    // provider itself handles login changes and the on/off setting.
    ref.watch(castReceiverProvider);
    // null locale -> follow the system language.
    final locale = ref.watch(localeProvider).value;
    // Selected theme; defaults to Nocturne until the saved value loads.
    final theme = ref.watch(themeProvider).value ?? JellyTheme.nocturne;

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: theme.themeData,
      themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
