import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage that degrades gracefully when the platform keyring is
/// unavailable.
///
/// On Linux the OS keyring (via libsecret) can be **locked or missing** — this
/// happens on desktops that don't auto-unlock the login keyring on sign-in
/// (e.g. COSMIC), where `flutter_secure_storage` throws `KeyringLocked`. That
/// used to crash startup. This wrapper tries the real keyring first and, on any
/// failure, falls back to `shared_preferences` for the rest of the session so
/// the app stays usable (log in, remember the server, etc.).
///
/// The fallback store is **not** encrypted — tokens then live in plain prefs —
/// so it's a deliberate downgrade for keyring-less setups, not the default
/// path. Callers use the same read/write/delete API either way.
class ResilientSecureStorage {
  ResilientSecureStorage(this._secure);

  final FlutterSecureStorage _secure;

  /// Once the keyring has failed we stop retrying it (it won't recover mid-run)
  /// and keep everything consistent in the fallback store.
  bool _useFallback = false;

  static const _prefix = 'jellymusic.securefallback.';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> read({required String key}) async {
    if (!_useFallback) {
      try {
        return await _secure.read(key: key);
      } catch (e) {
        _fellBack(e);
      }
    }
    return (await _prefs).getString('$_prefix$key');
  }

  Future<void> write({required String key, required String value}) async {
    if (!_useFallback) {
      try {
        await _secure.write(key: key, value: value);
        return;
      } catch (e) {
        _fellBack(e);
      }
    }
    await (await _prefs).setString('$_prefix$key', value);
  }

  Future<void> delete({required String key}) async {
    if (!_useFallback) {
      try {
        await _secure.delete(key: key);
        return;
      } catch (e) {
        _fellBack(e);
      }
    }
    await (await _prefs).remove('$_prefix$key');
  }

  void _fellBack(Object error) {
    if (!_useFallback) {
      _useFallback = true;
      debugPrint('ResilientSecureStorage: keyring unavailable ($error) — '
          'falling back to shared_preferences for this session.');
    }
  }
}
