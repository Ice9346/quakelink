// lib/models/sensor_snapshot.dart
class SensorSnapshot {
  final String deviceName;
  final String? deviceId;

  final double? temp;
  final double? si;
  final double? pga;

  final dynamic events;
  final int? updatedAtTs;
  final DateTime? timestamp;
  final double? lat;
  final double? lng;
  final String? location;
  final double? distanceKm;

  const SensorSnapshot({
    required this.deviceName,
    this.deviceId,
    this.temp,
    this.si,
    this.pga,
    this.events,
    this.updatedAtTs,
    this.timestamp,
    this.lat,
    this.lng,
    this.location,
    this.distanceKm,
  });

  // ---------------- helpers ----------------

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      // กันกรณี "-"/"N/A"
      if (s == '-' || s.toLowerCase() == 'nan' || s.toLowerCase() == 'n/a') return null;
      return double.tryParse(s);
    }
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;

    // epoch ms / sec
    if (v is int) {
      if (v < 1000000000000) return DateTime.fromMillisecondsSinceEpoch(v * 1000);
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    if (v is num) {
      final i = v.toInt();
      if (i < 1000000000000) return DateTime.fromMillisecondsSinceEpoch(i * 1000);
      return DateTime.fromMillisecondsSinceEpoch(i);
    }

    if (v is String) {
      final s = v.trim();
      final dt = DateTime.tryParse(s);
      if (dt != null) return dt;

      final asInt = int.tryParse(s);
      if (asInt != null) {
        if (asInt < 1000000000000) return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
    }

    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map) return v.cast<String, dynamic>();
    return null;
  }

  static List? _asList(dynamic v) {
    if (v is List) return v;
    return null;
  }

  static String? _pickString(Map<String, dynamic> root, List<String> keys) {
    String? fromMap(Map<String, dynamic> map) {
      for (final key in keys) {
        final value = map[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return null;
    }

    final direct = fromMap(root);
    if (direct != null) return direct;

    for (final nestKey in const ['telemetry', 'latest', 'values', 'data', 'payload']) {
      final nested = _asMap(root[nestKey]);
      final value = nested == null ? null : fromMap(nested);
      if (value != null) return value;
    }
    return null;
  }

  /// ดึงค่า numeric จาก map แบบ case-insensitive + รองรับ nested + list(key/value)
  static double? _pickNum(Map<String, dynamic> root, List<String> keys) {
    // 1) เช็คที่ root แบบ case-insensitive
    double? fromMap(Map<String, dynamic> m) {
      // map แบบตรง ๆ
      for (final k in keys) {
        if (m.containsKey(k)) {
          final v = _toDouble(m[k]);
          if (v != null) return v;
        }
      }
      // case-insensitive
      final lower = <String, dynamic>{};
      m.forEach((k, v) => lower[k.toLowerCase()] = v);
      for (final k in keys) {
        final v = lower[k.toLowerCase()];
        final d = _toDouble(v);
        if (d != null) return d;
      }
      return null;
    }

    // 2) เผื่อรูปแบบ list ของ {key,value}
    double? fromKvList(List list) {
      for (final it in list) {
        if (it is! Map) continue;
        final mm = it.cast<String, dynamic>();
        final kk = (mm['key'] ?? mm['name'] ?? mm['k'] ?? '').toString().toLowerCase();
        if (kk.isEmpty) continue;

        for (final want in keys) {
          if (kk == want.toLowerCase()) {
            final v = _toDouble(mm['value'] ?? mm['v'] ?? mm['val']);
            if (v != null) return v;
          }
        }
      }
      return null;
    }

    // root
    final direct = fromMap(root);
    if (direct != null) return direct;

    // 3) เช็ค nested map ที่พบบ่อย
    for (final nestKey in const ['telemetry', 'latest', 'values', 'data', 'payload']) {
      final nest = root[nestKey];

      final asM = _asMap(nest);
      if (asM != null) {
        final d = fromMap(asM);
        if (d != null) return d;

        // เผื่อ nested ซ้อนอีกชั้น
        for (final nest2Key in const ['telemetry', 'latest', 'values', 'data']) {
          final asM2 = _asMap(asM[nest2Key]);
          if (asM2 != null) {
            final d2 = fromMap(asM2);
            if (d2 != null) return d2;
          }
        }
      }

      final asL = _asList(nest);
      if (asL != null) {
        final d = fromKvList(asL);
        if (d != null) return d;
      }
    }

    return null;
  }

  factory SensorSnapshot.fromJson(Map<String, dynamic> json) {
    final deviceName = (json['deviceName'] ??
            json['device_name'] ??
            json['name'] ??
            json['label'] ??
            '')
        .toString();

    final deviceId = (json['deviceId'] ?? json['device_id'] ?? json['id'])?.toString();

    final temp = _pickNum(json, const ['temp', 'temperature', 'tempc', 'temp_c', 't', 'TEMP']);
    final si = _pickNum(json, const ['si', 'SI', 'shaking_intensity']);
    final pga = _pickNum(json, const ['pga', 'PGA', 'pga_g', 'pgaGal', 'acc', 'accel']);

    final events = json['events'] ?? json['event'] ?? json['dataEvents'];

    final lat = _pickNum(json, const ['lat', 'latitude']);
    final lng = _pickNum(json, const ['lng', 'lon', 'longitude']);
    final distanceKm = _pickNum(json, const ['distanceKm', 'distance_km']);
    final location = _pickString(json, const ['location', 'place', 'area']);

    final updatedAtTs = _toInt(json['updatedAtTs'] ?? json['updated_at_ts'] ?? json['ts'] ?? json['updatedAt']);
    final timestamp = _toDateTime(json['timestamp'] ?? json['time'] ?? json['updated_at']);

    return SensorSnapshot(
      deviceName: deviceName,
      deviceId: deviceId,
      temp: temp,
      si: si,
      pga: pga,
      events: events,
      updatedAtTs: updatedAtTs,
      timestamp: timestamp,
      lat: lat,
      lng: lng,
      location: location,
      distanceKm: distanceKm,
    );
  }
}
