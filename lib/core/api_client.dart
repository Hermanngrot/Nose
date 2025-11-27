import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
import 'dart:developer' as developer;

class ApiClient {
  final String baseUrl;

  // Store last request/response summary for diagnostics (useful in web builds)
  static String? lastRequestSummary;
  static String? lastResponseSummary;
  // Store last response headers for diagnostics / Location fallback
  static Map<String, String>? lastResponseHeaders;

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? apiBaseUrl;

  Future<dynamic> getJson(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _buildHeaders();
    developer.log('HTTP GET: $uri', name: 'ApiClient');
    developer.log('Request headers: ${headers.toString()}', name: 'ApiClient');
    lastRequestSummary = 'GET $uri headers=${headers.toString()}';
    final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    developer.log('Response ${resp.statusCode}: ${resp.body}', name: 'ApiClient');
    lastResponseHeaders = Map<String, String>.from(resp.headers);
    lastResponseSummary = 'Status ${resp.statusCode} headers=${resp.headers.toString()} body=${resp.body}';
    return _handleResponse(resp);
  }

  Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = await _buildHeaders();
    developer.log('HTTP POST: $uri', name: 'ApiClient');
    developer.log('Request headers: ${headers.toString()}', name: 'ApiClient');
    developer.log('Request body: ${jsonEncode(body)}', name: 'ApiClient');
    lastRequestSummary = 'POST $uri headers=${headers.toString()} body=${jsonEncode(body)}';
    final resp = await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 12));
    developer.log('Response ${resp.statusCode}: ${resp.body}', name: 'ApiClient');
    lastResponseHeaders = Map<String, String>.from(resp.headers);
    lastResponseSummary = 'Status ${resp.statusCode} headers=${resp.headers.toString()} body=${resp.body}';
    return _handleResponse(resp);
  }

  Future<Map<String, String>> _buildHeaders() async {
    final Map<String, String> h = {'Content-Type': 'application/json'};
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  dynamic _handleResponse(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      developer.log('HTTP ERROR ${resp.statusCode}: ${resp.body}', name: 'ApiClient');
      lastResponseSummary = 'ERROR ${resp.statusCode} body=${resp.body}';
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    if (resp.body.isEmpty) return {};
    try {
      return jsonDecode(resp.body);
    } catch (e) {
      // If the body is not a JSON object, log and return it wrapped
      developer.log('Failed to decode JSON body: ${e.toString()}', name: 'ApiClient');
      return {'_raw': resp.body};
    }
  }
}
