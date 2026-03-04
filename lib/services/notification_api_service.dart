// lib/services/notification_api_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class NotificationApiService {
  static Future<List<Map<String, dynamic>>> listMy({int limit = 50, String? type}) async {
    final headers = await TokenManager.authHeaders();

    final q = <String, String>{'limit': '$limit'};
    if (type != null && type.trim().isNotEmpty) q['type'] = type.trim();

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notifications').replace(queryParameters: q);

    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is List) {
        return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
      return [];
    }
    throw Exception('Failed to load notifications: ${res.statusCode} ${res.body}');
  }

  static Future<int> unreadCount() async {
    final headers = await TokenManager.authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notifications/unread_count');

    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data is Map && data['count'] is num) ? (data['count'] as num).toInt() : 0;
    }
    throw Exception('Failed to load unread count: ${res.statusCode} ${res.body}');
  }

  static Future<void> markAllRead() async {
    final headers = await TokenManager.authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notifications/mark_all_read');

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    );

    if (res.statusCode == 200) return;
    throw Exception('Failed to mark all read: ${res.statusCode} ${res.body}');
  }

  static Future<Map<String, dynamic>> markOneRead(int notifId) async {
    final headers = await TokenManager.authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notifications/$notifId/read');

    final res = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data is Map) ? data.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Failed to mark read: ${res.statusCode} ${res.body}');
  }
}