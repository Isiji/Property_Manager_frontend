// lib/services/notification_service.dart
// Updated to AVOID calling /notifications/unread_count (prevents 422 spam).

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class NotificationService {
  static Map<String, String> _json(Map<String, String> h) => {
        'Content-Type': 'application/json',
        ...h,
      };

  static Future<Map<String, String>> _auth() => TokenManager.authHeaders();

  /// Simple alias kept for older widgets; resolves current user and calls /notifications/{id}
  static Future<List<Map<String, dynamic>>> list({int limit = 50}) async {
    return listMe(limit: limit);
  }

  /// Preferred: resolve current user and fetch their notifications
  static Future<List<Map<String, dynamic>>> listMe({int limit = 50}) async {
    final h = await _auth();
    final me = await TokenManager.currentUserId();
    if (me == null) {
      throw Exception('No current user id');
    }
    final url = Uri.parse('${AppConfig.apiBaseUrl}/notifications/$me')
        .replace(queryParameters: {'limit': '$limit'});
    final r = await http.get(url, headers: _json(h));
    if (r.statusCode == 200) {
      final b = jsonDecode(r.body);
      if (b is List) {
        return b.map<Map<String, dynamic>>((e) {
          if (e is Map) return e.cast<String, dynamic>();
          return <String, dynamic>{};
        }).toList();
      }
      return const [];
    }
    throw Exception('Notifications failed: ${r.statusCode} ${r.body}');
  }

  /// No-op for now to stop 422s. If you later add the endpoint, implement it here.
  static Future<int> getUnreadCount() async {
    return 0; // deliberately not calling the backend
  }

  /// No-op for now; implement if/when backend route exists.
  static Future<void> markAllRead() async {
    // intentionally blank
  }
}
