// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

const Duration kClientMaxSession = Duration(hours: 2);
const String kNgrokBypassHeader = 'ngrok-skip-browser-warning';
const String kNgrokBypassValue = 'true';

class AuthSession {
  final String token;
  final String role; // admin | landlord | manager | tenant
  final int userId; // for manager: staff id
  final int? managerId; // for manager: org id
  final DateTime expiresAt;

  AuthSession({
    required this.token,
    required this.role,
    required this.userId,
    required this.expiresAt,
    this.managerId,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'token': token,
        'role': role,
        'userId': userId,
        'managerId': managerId,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        role: json['role'] as String,
        userId: (json['userId'] as num).toInt(),
        managerId: json['managerId'] == null ? null : (json['managerId'] as num).toInt(),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

class TokenManager {
  static const _kSessionKey = 'auth_session_v1';

  static Future<void> saveSession({
    required String token,
    required String role,
    required int userId,
    int? managerId,
  }) async {
    final now = DateTime.now();

    DateTime? jwtExp;
    try {
      if (token.isNotEmpty && !JwtDecoder.isExpired(token)) {
        jwtExp = JwtDecoder.getExpirationDate(token);
      }
    } catch (_) {}

    final clientCap = now.add(kClientMaxSession);
    final expiresAt = (jwtExp == null) ? clientCap : _minDate(jwtExp, clientCap);

    final session = AuthSession(
      token: token,
      role: role,
      userId: userId,
      managerId: managerId,
      expiresAt: expiresAt,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionKey, jsonEncode(session.toJson()));
  }

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

  static Future<bool> isLoggedIn() async {
    final s = await loadSession();
    return s != null && !s.isExpired;
  }

  static Future<Map<String, String>> authHeaders() async {
    final s = await loadSession();
    final headers = <String, String>{
      kNgrokBypassHeader: kNgrokBypassValue,
    };
    if (s != null) {
      headers['Authorization'] = 'Bearer ${s.token}';
    }
    return headers;
  }

  static Future<String?> currentRole() async => (await loadSession())?.role;
  static Future<int?> currentUserId() async => (await loadSession())?.userId;
  static Future<int?> currentManagerId() async => (await loadSession())?.managerId;

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);
  }

  static DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
}
