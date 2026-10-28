// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/alert_event.dart';
import 'auth_service.dart';

class ApiClient {
  ApiClient({required this.baseUrl});
  final String baseUrl;

  // ---------------- Alerts (DB) ----------------
  Future<List<AlertEvent>> fetchAlerts({int take = 100}) async {
    final uri = Uri.parse('$baseUrl/alerts?take=$take');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('fetchAlerts failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);

    // ✅ รองรับทั้ง {ok:true,data:[...]} และ [...] เผื่ออนาคต
    final List<dynamic> list = decoded is List
        ? decoded
        : (decoded is Map<String, dynamic> ? (decoded['data'] as List? ?? []) : []);

    return list
        .whereType<Map<String, dynamic>>()
        .map(AlertEvent.fromJson)
        .toList();
  }

  // ---------------- ThingsBoard latest (via server) ----------------
  /// ✅ ดึง telemetry ล่าสุดจาก ThingsBoard ผ่าน backend
  /// server route: GET /tb/latest?deviceName=...
  /// response: { ok:true, telemetry:{pga,si,temp,timestamp,...}, ... }
  Future<Map<String, dynamic>> fetchTbLatest({String? deviceName}) async {
    // ✅ ใช้ token เดียวกับ login ในแอป
    final token = await AuthService.instance.requireToken();

    // ✅ ใช้ queryParameters กัน deviceName มีช่องว่าง/อักขระพิเศษแล้วพัง
    final uri = Uri.parse('$baseUrl/tb/latest').replace(
      queryParameters: (deviceName == null || deviceName.trim().isEmpty)
          ? null
          : {'deviceName': deviceName.trim()},
    );

    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('fetchTbLatest failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) return decoded;

    throw Exception('fetchTbLatest invalid response: ${res.body}');
  }

  /// ✅ helper เรียกแบบชัด ๆ (สำหรับ sensor 4 ตัว)
  Future<Map<String, dynamic>> fetchTbLatestByDeviceName(String deviceName) {
    return fetchTbLatest(deviceName: deviceName);
  }
}
