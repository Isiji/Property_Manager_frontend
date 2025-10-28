// lib/services/report_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class ReportService {
  static Future<Map<String, dynamic>> landlordMonthlySummary({
    required int landlordId,
    int? year,
    int? month,
  }) async {
    final headers = await TokenManager.authHeaders();
    final params = <String, String>{};
    if (year != null) params['year'] = '$year';
    if (month != null) params['month'] = '$month';

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/landlord/$landlordId/monthly-summary',
    ).replace(queryParameters: params.isEmpty ? null : params);
    print('[ReportService] GET $uri');

    final res = await http.get(uri, headers: {'Content-Type': 'application/json', ...headers});
    print('[ReportService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to load monthly summary: ${res.statusCode} ${res.body}');
  }

  static Future<Map<String, dynamic>> propertyMonthlySummary({
    required int propertyId,
    int? year,
    int? month,
  }) async {
    final headers = await TokenManager.authHeaders();
    final params = <String, String>{};
    if (year != null) params['year'] = '$year';
    if (month != null) params['month'] = '$month';

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/property/$propertyId/monthly-summary',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final res = await http.get(uri, headers: {'Content-Type': 'application/json', ...headers});
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to load property monthly summary: ${res.statusCode} ${res.body}');
  }

  static Future<Uint8List> downloadMonthlyCsv({
    required int landlordId,
    int? year,
    int? month,
  }) async {
    final headers = await TokenManager.authHeaders();
    final params = <String, String>{};
    if (year != null) params['year'] = '$year';
    if (month != null) params['month'] = '$month';

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/landlord/$landlordId/monthly-summary.csv',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final res = await http.get(uri, headers: {'Accept': 'text/csv', ...headers});
    if (res.statusCode == 200) {
      return Uint8List.fromList(res.bodyBytes);
    }
    throw Exception('Failed to download CSV: ${res.statusCode} ${res.body}');
  }

  static Future<Map<String, dynamic>> sendReminders({
    required int landlordId,
    int? year,
    int? month,
    bool dryRun = false,
  }) async {
    final headers = await TokenManager.authHeaders();
    final params = <String, String>{};
    if (year != null) params['year'] = '$year';
    if (month != null) params['month'] = '$month';
    params['dry_run'] = dryRun ? 'true' : 'false';

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/landlord/$landlordId/send-reminders',
    ).replace(queryParameters: params);

    final res = await http.post(uri, headers: {'Content-Type': 'application/json', ...headers});
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Failed to send reminders: ${res.statusCode} ${res.body}');
  }
}
