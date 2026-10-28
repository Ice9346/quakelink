// lib/services/ws_alert_store.dart
import 'package:flutter/foundation.dart';

import '../models/alert_event.dart';
import '../models/sensor_snapshot.dart';

class WsAlertStore extends ChangeNotifier {
  WsAlertStore({this.maxItems = 200});

  final int maxItems;

  // ===========================================================================
  // 1) ALERT FEED (เดิม) — สำหรับแผนที่/Recent Alerts/แจ้งเตือน
  // ===========================================================================
  final List<AlertEvent> _alerts = [];

  // index maps (สำหรับ alert)
  final Map<String, int> _indexById = {}; // alertId -> index
  final Map<String, int> _indexByNode = {}; // nodeId -> index (for TB stream alert)

  // fingerprint ต่อ node: ถ้าค่าเหมือนเดิมจะไม่ถือว่า update (TB stream alert)
  final Map<String, String> _lastFpByNode = {};

  int _unreadCount = 0;

  List<AlertEvent> get alerts => List.unmodifiable(_alerts);
  int get unreadCount => _unreadCount;

  // ===========================================================================
  // 2) TB SNAPSHOT (ใหม่) — สำหรับ Home "Live Monitoring" ให้เหมือน HistoryScreen
  //    server ส่งผ่าน WS type: "tb_latest_all"
  // ===========================================================================
  List<SensorSnapshot> _tbLatestAll = const [];
  DateTime? _tbLastAt;
  bool _tbWsConnected = false;
  String? _tbWsError;

  List<SensorSnapshot> get tbLatestAll => List.unmodifiable(_tbLatestAll);
  DateTime? get tbLastAt => _tbLastAt;
  bool get tbWsConnected => _tbWsConnected;
  String? get tbWsError => _tbWsError;

  // ---------------------------------------------------------------------------
  // ✅ NEW: Helpers for "nearest sensor" / per-node latest (จาก alert feed แบบ TB-*)
  // ---------------------------------------------------------------------------

  /// คืนรายชื่อ nodeId ที่มี TB stream อยู่ใน store (unique)
  /// เอาไปใช้คู่กับ _sensorFixedLatLng เพื่อหา nearest ได้
  List<String> get tbNodeIds {
    final s = <String>{};
    for (final a in _alerts) {
      final node = (a.nodeId ?? '').trim();
      if (node.isNotEmpty && a.alertId.startsWith('TB-')) {
        s.add(node);
      }
    }
    final out = s.toList()..sort();
    return out;
  }

  /// คืน TB event ล่าสุดของ node นั้น ๆ (จากข้อมูลที่ store มีอยู่แล้ว)
  /// ถ้าไม่มี จะคืน null
  AlertEvent? latestTbForNode(String nodeId) {
    final key = nodeId.trim();
    if (key.isEmpty) return null;

    // ✅ O(1) ถ้า map พร้อม
    final idx = _indexByNode[key];
    if (idx != null && idx >= 0 && idx < _alerts.length) {
      final a = _alerts[idx];
      if (a.alertId.startsWith('TB-') && (a.nodeId ?? '').trim() == key) return a;
    }

    // fallback scan (rare)
    for (final a in _alerts) {
      final node = (a.nodeId ?? '').trim();
      if (a.alertId.startsWith('TB-') && node == key) return a;
    }
    return null;
  }

  // ===========================================================================
  // ✅ TB SNAPSHOT setters (เรียกจาก WsAlertService)
  // ===========================================================================

  /// อัปเดต snapshot list “ทุกครั้ง” (เหมือน History)
  /// ใช้สำหรับหน้า Home ให้การ์ดเปลี่ยนตาม TB จริง ๆ
  void setTbLatestAll(List<SensorSnapshot> list, {DateTime? receivedAt}) {
    _tbLatestAll = List<SensorSnapshot>.unmodifiable(list);
    _tbLastAt = receivedAt ?? DateTime.now();
    notifyListeners();
  }

  /// สถานะ WS สำหรับ TB snapshot
  void setTbWsStatus({required bool connected, String? error, DateTime? lastAt}) {
    _tbWsConnected = connected;
    _tbWsError = error;
    if (lastAt != null) _tbLastAt = lastAt;
    notifyListeners();
  }

  // ===========================================================================
  // ALERT FEED (เดิม)
  // ===========================================================================

  // ---------------- fingerprint helpers ----------------

  // parse: "pga=0, si=0, temp=0" (รองรับ float/ติดลบ)
  double? _extractNum(String label, String desc) {
    final r = RegExp('$label\\s*=\\s*(-?\\d+(?:\\.\\d+)?)', caseSensitive: false);
    final m = r.firstMatch(desc);
    if (m == null) return null;
    return double.tryParse(m.group(1)!);
  }

  String _fpForTb(AlertEvent e) {
    final desc = e.description;
    final pga = _extractNum('pga', desc);
    final si = _extractNum('si', desc);
    final temp = _extractNum('temp', desc);

    // ปัดทศนิยมเพื่อกันแกว่งเล็ก ๆ
    String f2(double? v) => v == null ? '-' : v.toStringAsFixed(2);
    String f1(double? v) => v == null ? '-' : v.toStringAsFixed(1);

    final node = (e.nodeId ?? '').trim();
    return 'node=$node|sev=${e.severity.name}|pga=${f2(pga)}|si=${f2(si)}|temp=${f1(temp)}|loc=${e.location}';
  }

  // เปรียบเทียบใหม่กว่าไหม (ไว้ตอน replace)
  int _compare(AlertEvent a, AlertEvent b) {
    final t = b.timestamp.compareTo(a.timestamp);
    if (t != 0) return t;
    return b.alertId.compareTo(a.alertId);
  }

  /// เพิ่ม/อัปเดต alert จาก WS
  /// ✅ TB stream alert: ไม่เพิ่ม unread ถ้าค่าไม่เปลี่ยน (แม้ id/timestamp เปลี่ยนทุก 3 วิ)
  void addAlert(AlertEvent event) {
    final id = event.alertId.trim();
    final node = (event.nodeId ?? '').trim();

    final isTbStream = node.isNotEmpty && event.alertId.startsWith('TB-');

    // ---------------- TB MODE (per-node replace) ----------------
    if (isTbStream) {
      final fp = _fpForTb(event);
      final lastFp = _lastFpByNode[node];

      // ✅ ค่าเหมือนเดิมทุกอย่าง -> ignore
      if (lastFp != null && lastFp == fp) return;

      _lastFpByNode[node] = fp;

      // ถ้าเคยมี node นี้แล้ว -> replace ของเดิม ไม่เพิ่มรายการใหม่
      final existingNodeIndex = _indexByNode[node];
      if (existingNodeIndex != null) {
        final old = _alerts[existingNodeIndex];

        // ถ้าอันใหม่ไม่ใหม่กว่า ก็ไม่ต้องทำอะไร
        if (_compare(event, old) < 0) return;

        _alerts[existingNodeIndex] = event;

        // ย้ายขึ้นบน
        final updated = _alerts.removeAt(existingNodeIndex);
        _alerts.insert(0, updated);

        _unreadCount += 1;

        _rebuildIndexMaps();
        _trimToMax();
        notifyListeners();
        return;
      }

      // node นี้ยังไม่เคยมี -> insert ใหม่
      _alerts.insert(0, event);
      _unreadCount += 1;

      _rebuildIndexMaps();
      _trimToMax();
      notifyListeners();
      return;
    }

    // ---------------- NORMAL MODE (id-based) ----------------
    if (id.isEmpty) {
      _alerts.insert(0, event);
      _unreadCount += 1;
      _trimToMax();
      _rebuildIndexMaps();
      notifyListeners();
      return;
    }

    final existingIdIndex = _indexById[id];
    if (existingIdIndex != null) {
      final old = _alerts[existingIdIndex];

      // ถ้าไม่ใหม่กว่า ไม่ต้องเด้ง
      if (_compare(event, old) < 0) return;

      _alerts[existingIdIndex] = event;

      // ย้ายขึ้นบน
      final updated = _alerts.removeAt(existingIdIndex);
      _alerts.insert(0, updated);

      // ไม่เพิ่ม unread เพราะเป็น id เดิม
      _rebuildIndexMaps();
      notifyListeners();
      return;
    }

    // ใหม่จริง
    _alerts.insert(0, event);
    _unreadCount += 1;
    _trimToMax();
    _rebuildIndexMaps();
    notifyListeners();
  }

  void markAllRead() {
    if (_unreadCount == 0) return;
    _unreadCount = 0;
    notifyListeners();
  }

  void clearAll() {
    _alerts.clear();
    _indexById.clear();
    _indexByNode.clear();
    _lastFpByNode.clear();
    _unreadCount = 0;

    _tbLatestAll = const [];
    _tbLastAt = null;
    _tbWsConnected = false;
    _tbWsError = null;

    notifyListeners();
  }

  void _trimToMax() {
    if (_alerts.length <= maxItems) return;
    _alerts.removeRange(maxItems, _alerts.length);
  }

  void _rebuildIndexMaps() {
    _indexById.clear();
    _indexByNode.clear();

    for (var i = 0; i < _alerts.length; i++) {
      final a = _alerts[i];
      final id = a.alertId.trim();
      if (id.isNotEmpty) _indexById[id] = i;

      final node = (a.nodeId ?? '').trim();
      if (node.isNotEmpty && a.alertId.startsWith('TB-')) {
        _indexByNode[node] = i;
      }
    }
  }
}
