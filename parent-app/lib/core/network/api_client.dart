import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String keyToken = 'access_token';
  static const String keyUser = 'user_data';
  static const String keyFamily = 'family_data';

  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(keyToken);
  }

  static String? get token => _token;
  static bool get isAuthenticated => _token != null;

  static Future<void> saveSession(String token, Map<String, dynamic> user, Map<String, dynamic>? family) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyToken, token);
    await prefs.setString(keyUser, jsonEncode(user));
    if (family != null) {
      await prefs.setString(keyFamily, jsonEncode(family));
    }
  }

  static Future<void> clearSession() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyToken);
    await prefs.remove(keyUser);
    await prefs.remove(keyFamily);
  }

  static Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  static Future<http.Response> get(String url) async {
    return await http.get(Uri.parse(url), headers: _headers());
  }

  static Future<http.Response> post(String url, Map<String, dynamic> body) async {
    return await http.post(
      Uri.parse(url),
      headers: _headers(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> put(String url, Map<String, dynamic> body) async {
    return await http.put(
      Uri.parse(url),
      headers: _headers(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(String url) async {
    return await http.delete(Uri.parse(url), headers: _headers());
  }
}
