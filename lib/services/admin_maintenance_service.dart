// lib/services/admin_maintenance_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AdminMaintenanceService {
  static Future<List<Map<String, dynamic>>> listStatuses() async {
    final headers = await TokenManager.authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/maintenance/status');

    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load statuses: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  /// Admin can view all requests via GET /maintenance (no role guard in your backend code)
  static Future<List<Map<String, dynamic>>> listAllRequests() async {
    final headers = await TokenManager.authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/maintenance');

    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load maintenance requests: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }
}