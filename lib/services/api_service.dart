import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';

class ApiService {
  static Future<http.Response> post(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse("${AppConfig.apiBaseUrl}$endpoint");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    return response;
  }

  static Future<http.Response> get(String endpoint) async {
    final url = Uri.parse("${AppConfig.apiBaseUrl}$endpoint");
    final response = await http.get(url);
    return response;
  }
}
