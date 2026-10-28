import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // ✅ iOS Simulator: http://localhost:8080
  // Android Emulator: http://10.0.2.2:8080
  // Device จริง: http://192.168.x.x:8080
  static String get baseUrl => AppConfig.apiBaseUrl;

  static const _tokenKey = 'accessToken';

  // ✅ ตั้ง options ให้เสถียรขึ้น (โดยเฉพาะ Android)
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// อ่าน token แบบตรง ๆ (อาจได้ null)
  Future<String?> getToken() => _storage.read(key: _tokenKey);

  /// ✅ ใช้สำหรับ "เช็คเฉย ๆ" (ไม่ throw) — เหมาะกับ guard / social callback
  Future<String?> getTokenOrNull() async {
    try {
      final t = await getToken();
      final s = (t ?? '').trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToken(String token) async {
    final t = token.trim();
    if (t.isEmpty) return;

    // เขียนทับค่าเดิมให้ชัวร์
    await _storage.write(key: _tokenKey, value: t);
  }

  Future<void> logout() async {
    // ลบทิ้งให้ชัวร์
    await _storage.delete(key: _tokenKey);
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final x = jsonDecode(body);
      return x is Map<String, dynamic> ? x : {'raw': x};
    } catch (_) {
      return {'raw': body};
    }
  }

  String _messageFrom(Map<String, dynamic> data, String fallback) {
    final error = data['error'];
    if (error is Map && error['message'] != null) {
      return error['message'].toString();
    }
    return (data['message'] ?? data['detail'] ?? data['raw'] ?? fallback)
        .toString();
  }

  /// ✅ ใช้เวลายิง API ที่ต้อง auth: ถ้าไม่มี token จะ throw ชัด ๆ
  Future<String> requireToken() async {
    final token = await getTokenOrNull();
    if (token == null) {
      throw Exception('Missing access token. Please login again.');
    }
    return token;
  }

  /// ✅ header มาตรฐานสำหรับเรียก API
  Map<String, String> _jsonHeaders({String? token}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    final t = (token ?? '').trim();
    if (t.isNotEmpty) {
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    String? province,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/auth/register'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'email': email.trim().toLowerCase(),
            'password': password,
            'name': name.trim(),
            'province': (province == null || province.trim().isEmpty)
                ? null
                : province.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    final data = _decode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final token = (data['accessToken'] ?? '').toString().trim();
      if (token.isEmpty) {
        throw Exception('Register succeeded but server did not return token.');
      }
      await saveToken(token);
      return;
    }

    throw Exception(_messageFrom(data, 'Register failed (${res.statusCode})'));
  }

  Future<void> login({required String email, required String password}) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'email': email.trim().toLowerCase(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 20));

    final data = _decode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final token = (data['accessToken'] ?? '').toString().trim();
      if (token.isEmpty) {
        throw Exception('Login succeeded but server did not return token.');
      }
      await saveToken(token);
      return;
    }

    throw Exception(_messageFrom(data, 'Login failed (${res.statusCode})'));
  }

  Future<bool> isLoggedIn() async {
    final token = await getTokenOrNull();
    return token != null && token.isNotEmpty;
  }
}
