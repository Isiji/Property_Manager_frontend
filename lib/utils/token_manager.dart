import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// How long a session should live at most (even if server gives longer).
const Duration kClientMaxSession = Duration(hours: 2);

class AuthSession {
  final String token;
  final String role;     // admin | landlord | manager | tenant
  final int userId;
  final DateTime expiresAt;

  AuthSession({
    required this.token,
    required this.role,
    required this.userId,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'token': token,
        'role': role,
        'userId': userId,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        role: json['role'] as String,
        userId: (json['userId'] as num).toInt(),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

class TokenManager {
  static const _kSessionKey = 'auth_session_v1';

  /// Save a new session. We’ll respect the server’s JWT `exp` if present,
  /// but still cap it at 2 hours client-side.
  static Future<void> saveSession({
    required String token,
    required String role,
    required int userId,
  }) async {
    final now = DateTime.now();

    // Try to read exp from JWT (in seconds since epoch). If absent, ignore.
    DateTime? jwtExp;
    try {
      if (token.isNotEmpty && !JwtDecoder.isExpired(token)) {
        final exp = JwtDecoder.getExpirationDate(token);
        jwtExp = exp;
      }
    } catch (_) {
      // If parsing fails, we just ignore and rely on client cap.
    }

    final clientCap = now.add(kClientMaxSession);
    final expiresAt = (jwtExp == null) ? clientCap : _minDate(jwtExp, clientCap);

    final session = AuthSession(
      token: token,
      role: role,
      userId: userId,
      expiresAt: expiresAt,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionKey, jsonEncode(session.toJson()));
  }

  /// Load existing session (null if none or expired).
  static Future<AuthSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSessionKey);
    if (raw == null) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final s = AuthSession.fromJson(map);
      if (s.isExpired) {
        await clearSession();
        return null;
      }
      return s;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  /// Quick check for guards.
  static Future<bool> isLoggedIn() async {
    final s = await loadSession();
    return s != null && !s.isExpired;
  }

  /// Use in your API client: `headers: await TokenManager.authHeaders()`
  static Future<Map<String, String>> authHeaders() async {
    final s = await loadSession();
    if (s == null) return {};
    return {'Authorization': 'Bearer ${s.token}'};
  }

  /// For routing decisions (e.g., pick a dashboard).
  static Future<String?> currentRole() async => (await loadSession())?.role;

  static Future<int?> currentUserId() async => (await loadSession())?.userId;

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);
  }

  static DateTime _minDate(DateTime a, DateTime b) =>
      a.isBefore(b) ? a : b;
}
