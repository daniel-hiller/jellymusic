import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/theme/jelly_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../widgets/brand_mark.dart';
import '../settings/settings_providers.dart';
import '../settings/theme_picker.dart';

/// Server URL + username + password login. In normal mode the router
/// redirects to the home shell on success; in [addMode] (adding a second
/// server while already logged in) it pops back to where it was opened from.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.addMode = false});

  final bool addMode;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _submitted = false;

  @override
  void dispose() {
    _server.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _submitted = true;
    await ref.read(authControllerProvider.notifier).login(
          server: _server.text,
          username: _user.text,
          password: _pass.text,
        );
  }

  Future<void> _quickConnect() async {
    final l = AppLocalizations.of(context);
    if (_server.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l.quickConnectServerFirst)));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuickConnectDialog(baseUrl: _server.text.trim()),
    );
    // In add-account mode the auth redirect won't move us; pop on success.
    if (ok == true &&
        widget.addMode &&
        mounted &&
        Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Language + theme pickers, shared by the app bar (add-server mode) and the
  /// top-right overlay (first login).
  List<Widget> _actions(AppLocalizations l) => [
        PopupMenuButton<String>(
          tooltip: l.settingsLanguage,
          icon:
              Icon(Icons.language_rounded, color: context.colors.textSecondary),
          onSelected: (code) =>
              ref.read(localeProvider.notifier).setLanguage(code),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'system', child: Text(l.languageSystem)),
            PopupMenuItem(value: 'de', child: Text(l.languageGerman)),
            PopupMenuItem(value: 'en', child: Text(l.languageEnglish)),
          ],
        ),
        IconButton(
          tooltip: l.themeChoose,
          icon:
              Icon(Icons.palette_outlined, color: context.colors.textSecondary),
          onPressed: () => showThemePicker(context),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final loading = auth.isLoading;

    ref.listen(authControllerProvider, (prev, next) {
      if (next.hasError && !next.isLoading) {
        _submitted = false;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              backgroundColor: context.colors.error,
              content: Text(l.loginFailed('${next.error}')),
            ),
          );
      }
      // In add-account mode the redirect won't move us, so pop on success.
      if (widget.addMode &&
          _submitted &&
          !next.isLoading &&
          next.value != null &&
          Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      appBar: widget.addMode
          ? AppBar(
              title: Text(l.addServerTitle),
              actions: _actions(l),
            )
          : null,
      body: Stack(
        children: [
          // Reachable in first-login mode where there is no app bar.
          if (!widget.addMode)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child:
                    Row(mainAxisSize: MainAxisSize.min, children: _actions(l)),
              ),
            ),
          // Sticky footer: project link + copyright.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse(AppInfo.repoUrl),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.code_rounded, size: 18),
                      label: Text(l.aboutGithub),
                      style: TextButton.styleFrom(
                          foregroundColor: context.colors.textSecondary),
                    ),
                    Text(
                      l.aboutCopyright(AppInfo.author),
                      style: TextStyle(
                          color: context.colors.textTertiary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              // Extra bottom inset so the centred form clears the sticky footer.
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 88),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BrandMark(size: 72),
                      const SizedBox(height: 16),
                      Text(
                        l.appTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.loginTagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _server,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: InputDecoration(
                          hintText: l.loginServerHint,
                          prefixIcon: const Icon(Icons.dns_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l.loginServerRequired
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _user,
                        autocorrect: false,
                        decoration: InputDecoration(
                          hintText: l.loginUsernameHint,
                          prefixIcon: const Icon(Icons.person_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l.loginUsernameRequired
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pass,
                        obscureText: _obscure,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: l.loginPasswordHint,
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: loading ? null : _submit,
                        child: loading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.colors.onAccent),
                              )
                            : Text(l.loginSignIn),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: loading ? null : _quickConnect,
                        icon: const Icon(Icons.qr_code_rounded, size: 20),
                        label: Text(l.quickConnect),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Runs a Quick Connect attempt: initiate, show the code, poll until the user
/// approves it in Jellyfin, then finalise the login. Pops `true` on success.
class _QuickConnectDialog extends ConsumerStatefulWidget {
  const _QuickConnectDialog({required this.baseUrl});

  final String baseUrl;

  @override
  ConsumerState<_QuickConnectDialog> createState() =>
      _QuickConnectDialogState();
}

class _QuickConnectDialogState extends ConsumerState<_QuickConnectDialog> {
  Timer? _poll;
  String? _code;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final repo = ref.read(authRepositoryProvider);
    try {
      final state = await repo.quickConnectInitiate(widget.baseUrl);
      if (!mounted) return;
      setState(() => _code = state.code);
      final secret = state.secret;
      _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
        try {
          final s = await repo.quickConnectPoll(secret);
          if (s.authenticated) {
            _poll?.cancel();
            await ref
                .read(authControllerProvider.notifier)
                .completeQuickConnect(secret);
            if (mounted) Navigator.of(context).pop(true);
          }
        } catch (_) {/* keep polling */}
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.quickConnect),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Text(_error!, style: TextStyle(color: context.colors.error))
          else if (_code == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else ...[
            Text(l.quickConnectInstruction, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(
              _code!,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
                color: context.colors.accent,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text(l.quickConnectWaiting),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(_error != null ? l.commonClose : l.commonCancel),
        ),
      ],
    );
  }
}
