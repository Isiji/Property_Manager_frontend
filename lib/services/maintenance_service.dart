import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class MaintenanceService {
  static Map<String, String> _json(Map<String, String> h) => {'Content-Type':'application/json', ...h};

  static Future<List<dynamic>> listMine() async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/maintenance/my');
    final r = await http.get(url, headers: _json(h));
    if (r.statusCode == 200) {
      final b = jsonDecode(r.body);
      return (b is List) ? b : const [];
    }
    throw Exception('maintenance/my failed: ${r.statusCode} ${r.body}');
  }
}
