// lib/services/notification_service.dart
// Token-aware notifications: list current user's notifications, unread count, mark-all-read.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class NotificationService {
  static Map<String, String> _json(Map<String, String> h) => {
        'Content-Type': 'application/json',
        ...h,
      };

  /// List notifications for the CURRENT token user
  static Future<List<dynamic>> listMe({int limit = 50}) async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/notifications/me')
        .replace(queryParameters: {'limit': '$limit'});
    final r = await http.get(url, headers: _json(h));
    if (r.statusCode == 200) {
      final b = jsonDecode(r.body);
      return (b is List) ? b : const [];
    }
    throw Exception('Notifications failed: ${r.statusCode} ${r.body}');
  }

  static Future<int> getUnreadCount() async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/notifications/unread_count');
    final r = await http.get(url, headers: _json(h));
    if (r.statusCode == 200) {
      final b = jsonDecode(r.body);
      return (b is Map && b['count'] is num) ? (b['count'] as num).toInt() : 0;
    }
    throw Exception('unread_count failed: ${r.statusCode} ${r.body}');
  }

  static Future<void> markAllRead() async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/notifications/mark_all_read');
    final r = await http.post(url, headers: _json(h));
    if (r.statusCode == 200) return;
    throw Exception('mark_all_read failed: ${r.statusCode} ${r.body}');
  }
}
