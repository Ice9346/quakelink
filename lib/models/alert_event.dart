// lib/models/alert_event.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum SeverityLevel { severe, moderate, caution }

class AlertEvent {
  final String alertId;
  final SeverityLevel severity;
  final double magnitude;
  final String location;
  final String description;
  final DateTime timestamp;
  final double distanceKm;
  final double lat;
  final double lng;
  final String? nodeId;

  AlertEvent({
    required this.alertId,
    required this.severity,
    required this.magnitude,
    required this.location,
    required this.description,
    required this.timestamp,
    required this.distanceKm,
    required this.lat,
    required this.lng,
    this.nodeId,
  });

  LatLng get position => LatLng(lat, lng);

  static SeverityLevel parseSeverity(dynamic v) {
    final s = (v ?? '').toString().toLowerCase().trim();
    switch (s) {
      case 'severe':
        return SeverityLevel.severe;
      case 'moderate':
        return SeverityLevel.moderate;
      case 'caution':
      default:
        return SeverityLevel.caution;
    }
  }

  // ✅ robust timestamp parser
  static DateTime _parseTimestamp(dynamic raw) {
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();

    // Prisma/JSON ปกติจะมาเป็น String ISO
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();

      // ถ้าไม่มี timezone (ไม่มี Z หรือ +07:00) ให้ treat เป็น UTC แล้วเติม Z
      final hasTZ = RegExp(r'Z$|[+\-]\d{2}:\d{2}$').hasMatch(s);
      final normalized = hasTZ ? s : '${s}Z';

      final dt = DateTime.tryParse(normalized);
      if (dt == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
      return dt.toLocal();
    }

    // ถ้ามาเป็น epoch
    if (raw is int) {
      // heuristic: ถ้าใหญ่กว่า 1e12 ถือว่าเป็น ms
      final ms = raw > 1000000000000 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    if (raw is double) {
      final v = raw.toInt();
      final ms = v > 1000000000000 ? v : v * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }

    // fallback
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
  }

  factory AlertEvent.fromJson(Map<String, dynamic> json) {
    // ✅ สำคัญ: ถ้า alertId ไม่มีจริง ๆ อย่าเอา id มาแทนแบบมั่ว ๆ
    // แต่ถ้าจำเป็นจริง ๆ ก็ยังให้ fallback ได้
    final alertId = (json['alertId'] ?? '').toString().trim().isNotEmpty
        ? json['alertId'].toString()
        : (json['id'] ?? '').toString();

    return AlertEvent(
      alertId: alertId,
      severity: parseSeverity(json['severity']),
      magnitude: (json['magnitude'] as num?)?.toDouble() ?? 0.0,
      location: (json['location'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      // ✅ ตรงนี้แก้แล้ว
      timestamp: _parseTimestamp(json['timestamp']),
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      nodeId: json['nodeId']?.toString(),
    );
  }

  static AlertEvent mock() {
    return AlertEvent(
      alertId: 'AL-MOCK',
      severity: SeverityLevel.moderate,
      magnitude: 4.2,
      location: 'Phuket',
      description: 'Moderate earthquake detected near Phuket area',
      timestamp: DateTime.now(),
      distanceKm: 45.2,
      lat: 7.8804,
      lng: 98.3923,
      nodeId: 'node-003',
    );
  }
}
