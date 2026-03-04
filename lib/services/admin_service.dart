// lib/services/admin_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AdminService {
  static Future<Map<String, dynamic>> getOverview({String? period}) async {
    final headers = await TokenManager.authHeaders();

    final q = <String, String>{};
    if (period != null && period.trim().isNotEmpty) q['period'] = period.trim();

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/admin/overview').replace(queryParameters: q);

    final res = await http.get(
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
    throw Exception('Failed to load admin overview: ${res.statusCode} ${res.body}');
  }

  static Future<List<Map<String, dynamic>>> getProperties({int limit = 200}) async {
    final headers = await TokenManager.authHeaders();

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/admin/properties')
        .replace(queryParameters: {'limit': '$limit'});

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
    throw Exception('Failed to load admin properties: ${res.statusCode} ${res.body}');
  }

  static Future<List<Map<String, dynamic>>> getFinanceSummary({String? period, int limit = 200}) async {
    final headers = await TokenManager.authHeaders();

    final q = <String, String>{'limit': '$limit'};
    if (period != null && period.trim().isNotEmpty) q['period'] = period.trim();

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/admin/finance/summary').replace(queryParameters: q);

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
    throw Exception('Failed to load finance summary: ${res.statusCode} ${res.body}');
  }

  static Future<Map<String, dynamic>> getMaintenanceSummary() async {
    final headers = await TokenManager.authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/admin/maintenance/summary');

    final res = await http.get(
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
    throw Exception('Failed to load maintenance summary: ${res.statusCode} ${res.body}');
  }
}