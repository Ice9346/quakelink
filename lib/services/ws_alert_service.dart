// lib/services/ws_alert_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../models/alert_event.dart';
import '../models/sensor_snapshot.dart';
import 'ws_alert_store.dart';

class WsAlertService {
  WsAlertService._();
  static final WsAlertService instance = WsAlertService._();

  WebSocketChannel? _ch;
  StreamSubscription? _sub;

  Timer? _reconnectTimer;
  int _retry = 0;

  // ✅ iOS Simulator/device
  static String get _wsUrl => AppConfig.wsBaseUrl;

  WsAlertStore? _store;

  // Request one snapshot on connect, then rely on server-side WS broadcasts.
  Timer? _tbPollTimer;

  bool get isConnected => _ch != null && _sub != null;

  // ✅ THROTTLE: กัน log/งานหนักสำหรับ payload ใหญ่
  DateTime? _lastNonAlertLogAt;

  // ✅ ถ้าต้องการเปิด log รายละเอียดจริง ๆ ค่อยสลับเป็น true
  static const bool _verboseAlertLog = false;
  static const bool _verboseTbLog = false;

  /// ✅ เรียกครั้งเดียวตอนเปิดแอป (เช่นใน MainShell.initState หรือ main.dart)
  /// แล้วทุกหน้าจะ update อัตโนมัติผ่าน ChangeNotifier
  void connect(WsAlertStore store) {
    _store = store;

    // กัน connect ซ้ำ
    disconnect(silent: true);
    _connectInternal(_wsUrl);
  }

  // ---------------------------------------------------------------------------
  // ✅ NEW: extract tb_latest_all list robustly (รองรับหลายรูปแบบ)
  // ---------------------------------------------------------------------------
  List<Map<String, dynamic>> _extractTbRows(Map<String, dynamic> root) {
    dynamic data =
        root['data'] ?? root['payload'] ?? root['latestAll'] ?? root['devices'];

    // 1) data เป็น List ตรง ๆ
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }

    // 2) data เป็น Map ที่มี list ซ้อนอยู่
    if (data is Map) {
      final m = data.cast<String, dynamic>();
      final inner = m['data'] ?? m['items'] ?? m['list'] ?? m['devices'];
      if (inner is List) {
        return inner
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }

    // 3) เผื่อ list อยู่ที่ root key อื่น
    for (final k in const ['items', 'list', 'devices']) {
      final v = root[k];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }

    return const <Map<String, dynamic>>[];
  }

  void _connectInternal(String wsUrl) {
    debugPrint('🔌 Connecting WS: $wsUrl');

    try {
      _ch = WebSocketChannel.connect(Uri.parse(wsUrl));
    } catch (e) {
      debugPrint('❌ WS connect throw: $e');
      _scheduleReconnect(wsUrl);
      return;
    }

    _startTbLatestAllPolling();

    _sub = _ch!.stream.listen(
      (data) {
        final s = data.toString();

        // ✅ FAST PATH: ทำให้ยืดหยุ่นขึ้น (กันกรณี spacing/newline)
        // - tb_latest_all: แค่มีคำนี้ก็พอ
        // - alert: บางที backend อาจส่งไม่มี type แต่มี alertId
        final looksLikeTbAll = s.contains('tb_latest_all');
        final looksLikeAlert =
            s.contains('"type":"alert"') ||
            s.contains('"type": "alert"') ||
            s.contains('"alertId"') ||
            s.contains('"severity"');
        final looksLikeHello = s.contains('hello');
        final looksLikeError = s.contains('error');

        // ถ้าไม่ใช่ alert/tb_latest_all/hello/error -> ข้าม (กัน decode หนัก)
        if (!looksLikeAlert &&
            !looksLikeTbAll &&
            !looksLikeHello &&
            !looksLikeError) {
          final now = DateTime.now();
          final last = _lastNonAlertLogAt;
          if (last == null || now.difference(last).inSeconds >= 3) {
            _lastNonAlertLogAt = now;
            debugPrint('⬅️ WS recv (other) — skipped decode');
          }
          return;
        }

        // ✅ เฉพาะที่เราสนใจค่อย decode
        try {
          final obj = jsonDecode(s);
          if (obj is! Map) return;

          final map = obj.cast<String, dynamic>();
          final type = (map['type'] ?? '').toString();

          if (type == 'hello') return;

          if (type == 'error') {
            final msg = (map['message'] ?? '').toString();
            debugPrint('⚠️ WS server error: $msg');
            _store?.setTbWsStatus(
              connected: true,
              error: msg,
              lastAt: DateTime.now(),
            );
            return;
          }

          // ------------------------------------------------------------------
          // ✅ 1) ALERT
          // ------------------------------------------------------------------
          if (type.isEmpty || type == 'alert' || looksLikeAlert) {
            if (_verboseAlertLog) {
              debugPrint('⬅️ WS recv (alert): $s');
            } else {
              debugPrint('⬅️ WS recv (alert)');
            }

            final event = AlertEvent.fromJson(map);
            _store?.addAlert(event);

            _retry = 0;
            return;
          }

          // ------------------------------------------------------------------
          // ✅ 2) TB LATEST ALL  { type:"tb_latest_all", ... }
          // ------------------------------------------------------------------
          if (type == 'tb_latest_all' || looksLikeTbAll) {
            if (_verboseTbLog) debugPrint('⬅️ WS recv (tb_latest_all): $s');

            final rows = _extractTbRows(map);

            final list = rows.map(SensorSnapshot.fromJson).toList();

            _store?.setTbLatestAll(list, receivedAt: DateTime.now());
            _store?.setTbWsStatus(
              connected: true,
              error: null,
              lastAt: DateTime.now(),
            );

            _retry = 0;
            return;
          }

          // type อื่น ๆ ไม่สนใจ
        } catch (e) {
          debugPrint('⚠️ WS parse error: $e');
        }
      },
      onError: (e) {
        debugPrint('❌ WS error: $e');
        _store?.setTbWsStatus(
          connected: false,
          error: e.toString(),
          lastAt: DateTime.now(),
        );
        _scheduleReconnect(wsUrl);
      },
      onDone: () {
        debugPrint('⚪️ WS closed');
        _store?.setTbWsStatus(
          connected: false,
          error: 'WS closed',
          lastAt: DateTime.now(),
        );
        _scheduleReconnect(wsUrl);
      },
      cancelOnError: true,
    );

    // reset retry เมื่อ connect สำเร็จ
    _retry = 0;
    _store?.setTbWsStatus(connected: true, error: null, lastAt: DateTime.now());
  }

  // ✅ ยิงขอ snapshot ผ่าน WS
  void _requestTbLatestAll() {
    final ws = _ch;
    if (ws == null) return;

    try {
      ws.sink.add(jsonEncode({'type': 'get_tb_latest_all'}));
    } catch (e) {
      debugPrint('⚠️ WS send get_tb_latest_all error: $e');
      _store?.setTbWsStatus(
        connected: false,
        error: e.toString(),
        lastAt: DateTime.now(),
      );
    }
  }

  void _startTbLatestAllPolling() {
    _tbPollTimer?.cancel();

    // Ask for the initial snapshot only. The backend broadcasts updates.
    _requestTbLatestAll();
  }

  void _stopTbLatestAllPolling() {
    _tbPollTimer?.cancel();
    _tbPollTimer = null;
  }

  void _scheduleReconnect(String wsUrl) {
    if (_reconnectTimer?.isActive ?? false) return;

    _retry = (_retry + 1).clamp(1, 8);
    final delay = Duration(seconds: _retry); // 1..8 วินาที

    debugPrint('🔁 Reconnecting in ${delay.inSeconds}s...');
    _reconnectTimer = Timer(delay, () {
      disconnect(silent: true);
      _connectInternal(wsUrl);
    });
  }

  void disconnect({bool silent = false}) {
    _stopTbLatestAllPolling();

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _sub?.cancel();
    _sub = null;

    try {
      _ch?.sink.close();
    } catch (_) {}

    _ch = null;

    if (!silent) {
      debugPrint('🔌 WS disconnected');
    }

    _store?.setTbWsStatus(
      connected: false,
      error: 'disconnected',
      lastAt: DateTime.now(),
    );
  }
}
