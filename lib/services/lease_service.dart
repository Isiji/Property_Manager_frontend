// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class LeaseService {
  /// Create a lease
  /// Expected backend route: POST /leases/
  /// Payload: { tenant_id, unit_id, start_date, end_date?, rent_amount, active }
  /// NOTE: start_date should be ISO8601 string (DateTime.toIso8601String()).
  static Future<Map<String, dynamic>> createLease({
    required int tenantId,
    required int unitId,
    required num rentAmount,
    required DateTime startDate,
    int active = 1,
    DateTime? endDate,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/leases/');

    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'unit_id': unitId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'rent_amount': rentAmount,
      'active': active,
    }..removeWhere((k, v) => v == null);

    print('[LeaseService] POST $url');
    print('[LeaseService] payload=$payload');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    print('[LeaseService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create lease: ${res.statusCode} ${res.body}');
  }

  /// End (close) a lease
  /// Expected backend route: PUT /leases/{lease_id}/end
  /// If your backend uses a different path, tweak this endpoint accordingly.
  static Future<Map<String, dynamic>> endLease({
    required int leaseId,
    DateTime? endDate,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/leases/$leaseId/end');

    final payload = <String, dynamic>{
      if (endDate != null) 'end_date': endDate.toIso8601String(),
    };

    print('[LeaseService] PUT $url');
    if (payload.isNotEmpty) print('[LeaseService] payload=$payload');

    final res = await http.put(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: payload.isEmpty ? null : jsonEncode(payload),
    );

    print('[LeaseService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to end lease: ${res.statusCode} ${res.body}');
  }

  /// Fetch active lease by unit (optional helper)
  /// Expected backend route (guess): GET /leases/active?unit_id=123
  static Future<Map<String, dynamic>?> getActiveLeaseByUnit(int unitId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/leases/active?unit_id=$unitId');

    print('[LeaseService] GET $url');
    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    print('[LeaseService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body == null || body.toString() == 'null' || (body is String && body.isEmpty)) {
        return null;
      }
      return body as Map<String, dynamic>;
    }
    if (res.statusCode == 404) return null;
    throw Exception('Failed to fetch active lease: ${res.statusCode} ${res.body}');
  }
}
