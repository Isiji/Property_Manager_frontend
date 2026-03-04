// lib/services/admin_reports_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AdminReportsService {
  static Future<Map<String, dynamic>> landlordMonthlySummary({
    required int landlordId,
    required int year,
    required int month,
  }) async {
    final headers = await TokenManager.authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/reports/landlord/$landlordId/monthly-summary')
        .replace(queryParameters: {
      'year': '$year',
      'month': '$month',
    });

    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Monthly summary failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);
    return (data is Map) ? data.cast<String, dynamic>() : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> propertyStatus({
    required int propertyId,
    required String period, // YYYY-MM
  }) async {
    final headers = await TokenManager.authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/reports/property/$propertyId/status')
        .replace(queryParameters: {'period': period});

    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Property status failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body);
    return (data is Map) ? data.cast<String, dynamic>() : <String, dynamic>{};
  }
}