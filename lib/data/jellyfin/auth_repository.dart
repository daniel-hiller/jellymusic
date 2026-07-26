import 'dart:convert';

import 'package:dart_jellyfin/dart_jellyfin.dart';
import 'package:uuid/uuid.dart';

import '../models/server_session.dart';
import 'jellyfin_service.dart';
import 'resilient_secure_storage.dart';

/// Handles login / logout and persists **multiple** accounts (users across
/// servers) so the user can switch between them. One is "active" at a time;
/// its session is what the [JellyfinService] is connected to.
class AuthRepository {
  AuthRepository(this._service, this._storage);

  final JellyfinService _service;
  final ResilientSecureStorage _storage;

  static const _kSessions = 'jellymusic.sessions';
  static const _kActiveKey = 'jellymusic.activeKey';
  static const _kLegacySession = 'jellymusic.session'; // pre-multiserver
  static const _kDeviceId = 'jellymusic.deviceId';

  /// A stable per-install device id. Generated once, then reused so
  /// Jellyfin keeps recognising this client's sessions.
  static Future<String> ensureDeviceId(ResilientSecureStorage storage) async {
    final existing = await storage.read(key: _kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await storage.write(key: _kDeviceId, value: id);
    return id;
  }

  // ─── Persistence helpers ───────────────────────────────────────────

  Future<List<ServerSession>> _readSessions() async {
    final raw = await _storage.read(key: _kSessions);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final e in list)
          ServerSession.fromJson(e as Map<String, dynamic>),
      ];
    }
    // Migrate a single pre-multiserver session, if present.
    final legacy = await _storage.read(key: _kLegacySession);
    if (legacy != null) {
      final session = ServerSession.decode(legacy);
      await _writeSessions([session]);
      await _storage.write(key: _kActiveKey, value: session.key);
      await _storage.delete(key: _kLegacySession);
      return [session];
    }
    return [];
  }

  Future<void> _writeSessions(List<ServerSession> sessions) async {
    await _storage.write(
      key: _kSessions,
      value: jsonEncode([for (final s in sessions) s.toJson()]),
    );
  }

  /// All saved accounts.
  Future<List<ServerSession>> sessions() => _readSessions();

  void _connect(ServerSession s) => _service.restore(
        baseUrl: s.baseUrl,
        token: s.accessToken,
        userId: s.userId,
      );

  // ─── Public API ────────────────────────────────────────────────────

  /// Restore the active account into the service. Returns it if present.
  Future<ServerSession?> restoreSession() async {
    final sessions = await _readSessions();
    if (sessions.isEmpty) return null;
    final activeKey = await _storage.read(key: _kActiveKey);
    final active = sessions.firstWhere(
      (s) => s.key == activeKey,
      orElse: () => sessions.first,
    );
    _connect(active);
    return active;
  }

  /// Log in with username + password against [baseUrl]; the new account
  /// becomes active (existing accounts are kept).
  Future<ServerSession> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    _service.connect(baseUrl);
    final JellyfinAuthResult auth = await _service.client.user
        .authenticateByName(username: username, password: password);

    _service.setSession(token: auth.accessToken, userId: auth.user.id);
    return _persistAsActive(auth);
  }

  // ─── Quick Connect ─────────────────────────────────────────────────

  /// Begin a Quick Connect attempt against [baseUrl]. The returned state
  /// carries the `code` to show the user and the `secret` to poll with.
  Future<JellyfinQuickConnectState> quickConnectInitiate(String baseUrl) async {
    _service.connect(baseUrl);
    return _service.client.quickConnect.initiate();
  }

  /// Poll a Quick Connect attempt; `authenticated` flips to true once the
  /// user approves it in the Jellyfin web UI.
  Future<JellyfinQuickConnectState> quickConnectPoll(String secret) =>
      _service.client.quickConnect.state(secret);

  /// Exchange an approved Quick Connect secret for a session (becomes active).
  Future<ServerSession> quickConnectComplete(String secret) async {
    final auth =
        await _service.client.user.authenticateWithQuickConnect(secret: secret);
    _service.setSession(token: auth.accessToken, userId: auth.user.id);
    return _persistAsActive(auth);
  }

  /// Build a session from an auth result, store it, and make it active.
  Future<ServerSession> _persistAsActive(JellyfinAuthResult auth) async {
    final session = ServerSession(
      baseUrl: _service.client.baseUrl!,
      accessToken: auth.accessToken,
      userId: auth.user.id,
      userName: auth.user.name,
      deviceId: _service.deviceId,
    );
    final sessions = await _readSessions()
      ..removeWhere((s) => s.key == session.key);
    sessions.add(session);
    await _writeSessions(sessions);
    await _storage.write(key: _kActiveKey, value: session.key);
    await _service.clearCache();
    return session;
  }

  /// Switch the active account to [session] (must already be saved).
  Future<ServerSession> switchTo(ServerSession session) async {
    await _storage.write(key: _kActiveKey, value: session.key);
    _connect(session);
    await _service.clearCache();
    return session;
  }

  /// Log the active account out. If other accounts remain, the first of them
  /// becomes active and is returned; otherwise returns null.
  Future<ServerSession?> logout() async {
    final activeKey = await _storage.read(key: _kActiveKey);
    final sessions = await _readSessions()
      ..removeWhere((s) => s.key == activeKey);
    await _writeSessions(sessions);
    await _service.clearCache();

    if (sessions.isEmpty) {
      await _storage.delete(key: _kActiveKey);
      _service.logout();
      return null;
    }
    final next = sessions.first;
    await _storage.write(key: _kActiveKey, value: next.key);
    _connect(next);
    return next;
  }
}
