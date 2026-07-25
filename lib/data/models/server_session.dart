import 'dart:convert';

/// Everything we persist to restore a logged-in session on next launch.
///
/// Stored (encrypted) via `flutter_secure_storage`. The [deviceId] is a
/// stable per-install UUID — Jellyfin tracks sessions by it, so it must
/// survive restarts.
class ServerSession {
  final String baseUrl;
  final String accessToken;
  final String userId;
  final String userName;
  final String deviceId;

  const ServerSession({
    required this.baseUrl,
    required this.accessToken,
    required this.userId,
    required this.userName,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'accessToken': accessToken,
        'userId': userId,
        'userName': userName,
        'deviceId': deviceId,
      };

  factory ServerSession.fromJson(Map<String, dynamic> json) => ServerSession(
        baseUrl: json['baseUrl'] as String,
        accessToken: json['accessToken'] as String,
        userId: json['userId'] as String,
        userName: json['userName'] as String? ?? '',
        deviceId: json['deviceId'] as String,
      );

  /// Stable identity for a saved account (one user on one server).
  String get key => '$userId@$baseUrl';

  String encode() => jsonEncode(toJson());

  static ServerSession decode(String raw) =>
      ServerSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
