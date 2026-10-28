// lib/screens/history_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../config/sensor_registry.dart';
import '../models/alert_event.dart';
import '../services/auth_service.dart';
import 'alert_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // ---------------- API ----------------
  // ---------------- WS ----------------
  static String get _wsUrl => AppConfig.wsBaseUrl;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _tickTimer;

  bool _wsConnected = false;
  String? _wsError;
  DateTime? _lastWsAt;

  // ---------------- UI state ----------------
  bool _loading = false;
  String? _error;

  List<SensorSnapshot> _sensors = [];

  static const Map<String, LatLng> _sensorFixedLatLng =
      SensorRegistry.fixedLatLng;

  @override
  void initState() {
    super.initState();

    // ✅ โหลดครั้งแรกกันหน้าโล่ง
    _loadSensors(initial: true);

    // Connect WS and request the initial snapshot. Server broadcasts updates.
    _connectWs();
    _startRealtimePolling();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
    super.dispose();
  }

  // ========================================================================
  // ✅ REALTIME: WS connect + server broadcasts
  // ========================================================================

  void _connectWs() {
    try {
      _wsError = null;
      _wsConnected = false;

      _ws = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _wsSub = _ws!.stream.listen(
        (event) {
          _lastWsAt = DateTime.now();
          if (!_wsConnected && mounted) {
            setState(() => _wsConnected = true);
          }
          _handleWsMessage(event);
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _wsConnected = false;
            _wsError = e.toString();
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _wsConnected = false;
            _wsError = _wsError ?? 'WS disconnected';
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _wsConnected = false;
        _wsError = e.toString();
      });
    }
  }

  void _startRealtimePolling() {
    _tickTimer?.cancel();

    // Ask for the initial snapshot only. The backend broadcasts updates.
    _requestSnapshotViaWs();
  }

  void _requestSnapshotViaWs() {
    final ws = _ws;
    if (ws == null) return;

    try {
      ws.sink.add(jsonEncode({'type': 'get_tb_latest_all'}));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _wsConnected = false;
        _wsError = e.toString();
      });
    }
  }

  void _handleWsMessage(dynamic event) {
    try {
      final text = event is String ? event : utf8.decode(event as List<int>);
      final obj = jsonDecode(text);

      if (obj is! Map<String, dynamic>) return;
      final type = (obj['type'] ?? '').toString();

      // ✅ server: { type:"tb_latest_all", timestamp, data:[...] }
      if (type == 'tb_latest_all') {
        final rawList = (obj['data'] as List?) ?? const [];

        final list = rawList
            .whereType<Map>()
            .map((e) => SensorSnapshot.fromJson(e.cast<String, dynamic>()))
            .toList();

        // ✅ เรียงตาม expectedNames
        list.sort((a, b) {
          final ra = SensorRegistry.sortIndex(a.deviceName);
          final rb = SensorRegistry.sortIndex(b.deviceName);
          if (ra != rb) return ra.compareTo(rb);
          return a.deviceName.compareTo(b.deviceName);
        });

        if (!mounted) return;

        // ✅ สำคัญ: อัปเดตการ์ด “ทุกครั้ง” แม้ค่า/ไอดีจะซ้ำ
        setState(() {
          _sensors = list;
          _error = null;
        });
      }
    } catch (_) {
      // ignore bad json
    }
  }

  // ========================================================================
  // ✅ REST (manual refresh / fallback)
  // ========================================================================

  Future<void> _loadSensors({bool initial = false}) async {
    if (!mounted) return;
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await AuthService.instance.requireToken();
      final url = Uri.parse('${AppConfig.apiBaseUrl}/tb/latest-all');

      final headers = <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final res = await http.get(url, headers: headers);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(
          'TB latest-all failed (${res.statusCode}): ${res.body}',
        );
      }

      final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
      final rawList = (jsonMap['data'] as List?) ?? const [];

      final list = rawList
          .map((e) => SensorSnapshot.fromJson(e as Map<String, dynamic>))
          .toList();

      // ✅ เรียงตาม expectedNames
      list.sort((a, b) {
        final ra = SensorRegistry.sortIndex(a.deviceName);
        final rb = SensorRegistry.sortIndex(b.deviceName);
        if (ra != rb) return ra.compareTo(rb);
        return a.deviceName.compareTo(b.deviceName);
      });

      if (!mounted) return;
      setState(() {
        _sensors = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ========================================================================
  // UI
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    const title = 'Sensors';
    const subtitle = 'ข้อมูลเซนเซอร์ทั้งหมด (ThingsBoard)';

    final tt = Theme.of(context).textTheme;
    final scale = MediaQuery.textScaleFactorOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            // ---------------- Header (compact) ----------------
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back_ios_new,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: tt.titleMedium?.copyWith(
                            fontSize: scale >= 1.2 ? 15 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: tt.bodySmall?.copyWith(
                            fontSize: scale >= 1.2 ? 10.5 : 11,
                            color: Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _RoundIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: () => _loadSensors(),
                  ),
                ],
              ),
            ),

            // ---------------- WS status bar ----------------
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _wsConnected
                          ? Icons.wifi_rounded
                          : Icons.wifi_off_rounded,
                      size: 18,
                      color: _wsConnected ? Colors.black87 : Colors.redAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _wsConnected
                            ? 'WS connected • server updates'
                            : 'WS disconnected',
                        style: tt.bodySmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_lastWsAt != null)
                      Text(
                        _timeAgo(_lastWsAt!),
                        style: tt.bodySmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                    if (!_wsConnected)
                      TextButton(
                        onPressed: () {
                          _wsSub?.cancel();
                          _ws?.sink.close();
                          _connectWs();
                          _startRealtimePolling();
                        },
                        child: Text(
                          'Reconnect',
                          style: tt.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ---------------- Error / Loading banner (REST) ----------------
            if (_loading || _error != null || _wsError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_loading) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Syncing from ThingsBoard…',
                            style: tt.bodySmall?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Error: ${_wsError ?? _error}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _wsSub?.cancel();
                            _ws?.sink.close();
                            _connectWs();
                            _startRealtimePolling();
                          },
                          child: Text(
                            'Retry WS',
                            style: tt.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // ---------------- Body ----------------
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadSensors(),
                child: _sensors.isEmpty && !_loading
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(14, 36, 14, 16),
                        children: [
                          const Icon(Icons.sensors_off_rounded, size: 40),
                          const SizedBox(height: 10),
                          Text(
                            'No sensor data',
                            textAlign: TextAlign.center,
                            style: tt.titleMedium?.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ลองกด Refresh หรือเช็คว่า /tb/latest-all + WS ทำงานได้ไหมครับ',
                            textAlign: TextAlign.center,
                            style: tt.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: () => _loadSensors(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(
                                'Refresh',
                                style: tt.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                        itemCount: _sensors.length,
                        itemBuilder: (context, index) {
                          final s = _sensors[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SensorCardCompact(
                              sensor: s,
                              onViewDetail: () {
                                final event = _toAlertEventForDetail(s);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AlertDetailsScreen(event: event),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ snapshot -> AlertEvent (เพื่อไปหน้า AlertDetailsScreen)
  AlertEvent _toAlertEventForDetail(SensorSnapshot s) {
    final severity = _deriveSeverityFromPgaSi(s.pga, s.si);
    final now = DateTime.now();

    final fixed = _sensorFixedLatLng[s.deviceName];
    final lat = (s.lat != null && s.lat != 0.0)
        ? s.lat!
        : (fixed?.latitude ?? 0.0);
    final lng = (s.lng != null && s.lng != 0.0)
        ? s.lng!
        : (fixed?.longitude ?? 0.0);

    final stableTs =
        s.updatedAtTs ??
        (s.timestamp?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch);
    final alertId = 'TB-${s.deviceName}-$stableTs';

    return AlertEvent(
      alertId: alertId,
      timestamp: s.timestamp ?? now,
      severity: severity,
      magnitude: s.pga,
      location: (s.location?.isNotEmpty == true) ? s.location! : s.deviceName,
      description:
          'Sensor ${s.deviceName} update: pga=${s.pga.toStringAsFixed(2)}, si=${s.si.toStringAsFixed(2)}, temp=${s.temp.toStringAsFixed(1)}°C',
      distanceKm: s.distanceKm ?? 0.0,
      lat: lat,
      lng: lng,
      nodeId: s.deviceName,
    );
  }

  SeverityLevel _deriveSeverityFromPgaSi(double pga, double si) {
    if (pga >= 1.5 || si >= 80) return SeverityLevel.severe;
    if (pga >= 0.8 || si >= 40) return SeverityLevel.moderate;
    return SeverityLevel.caution;
  }
}

// ======================= UI: Card (COMPACT แบบในรูป) =======================

class _SensorCardCompact extends StatelessWidget {
  final SensorSnapshot sensor;
  final VoidCallback onViewDetail;

  const _SensorCardCompact({required this.sensor, required this.onViewDetail});

  bool get _isOnline {
    if (sensor.updatedAtTs == null) return false;
    final updated = DateTime.fromMillisecondsSinceEpoch(sensor.updatedAtTs!);
    final diff = DateTime.now().difference(updated);
    return diff.inMinutes <= 2;
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String _fmtUpdated() {
    if (sensor.updatedAtTs == null) return 'Unknown';
    final dt = DateTime.fromMillisecondsSinceEpoch(sensor.updatedAtTs!);
    return '${_two(dt.day)}/${_two(dt.month)}/${dt.year} ${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
  }

  String _timeAgoFromUpdated() {
    if (sensor.updatedAtTs == null) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(sensor.updatedAtTs!);
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  int? _eventsCount() {
    final e = sensor.events;
    if (e == null) return null;
    if (e is List) return e.length;
    if (e is Map) return e.length;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final eventsCount = _eventsCount();
    final scale = MediaQuery.textScaleFactorOf(context);

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final isNarrow = w < 360;
        final forceStackBottom = isNarrow || scale >= 1.2;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            isNarrow ? 14 : 16,
            14,
            isNarrow ? 14 : 16,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sensor.deviceName,
                      style: tt.titleMedium?.copyWith(
                        fontSize: isNarrow ? 16 : 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _PillStatus(
                    text: _isOnline ? 'ThingsBoard synced' : 'Offline',
                    online: _isOnline,
                    compact: true,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  const Icon(
                    Icons.wifi_tethering_rounded,
                    size: 16,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ID: ${(sensor.deviceId ?? sensor.deviceName)}',
                      style: tt.bodySmall?.copyWith(
                        fontSize: isNarrow ? 12.5 : 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _timeAgoFromUpdated(),
                    style: tt.bodySmall?.copyWith(
                      fontSize: isNarrow ? 12 : 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              isNarrow
                  ? Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: (w - 12) / 2,
                          child: _MetricTileLikeImage(
                            icon: Icons.thermostat_rounded,
                            label: 'Temp (°C)',
                            value: sensor.temp.toStringAsFixed(1),
                            compact: true,
                          ),
                        ),
                        SizedBox(
                          width: (w - 12) / 2,
                          child: _MetricTileLikeImage(
                            icon: Icons.speed_rounded,
                            label: 'SI',
                            value: sensor.si.toStringAsFixed(2),
                            compact: true,
                          ),
                        ),
                        SizedBox(
                          width: w,
                          child: _MetricTileLikeImage(
                            icon: Icons.graphic_eq_rounded,
                            label: 'PGA',
                            value: sensor.pga.toStringAsFixed(2),
                            compact: true,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _MetricTileLikeImage(
                            icon: Icons.thermostat_rounded,
                            label: 'Temp (°C)',
                            value: sensor.temp.toStringAsFixed(1),
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricTileLikeImage(
                            icon: Icons.speed_rounded,
                            label: 'SI',
                            value: sensor.si.toStringAsFixed(2),
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricTileLikeImage(
                            icon: Icons.graphic_eq_rounded,
                            label: 'PGA',
                            value: sensor.pga.toStringAsFixed(2),
                            compact: true,
                          ),
                        ),
                      ],
                    ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: forceStackBottom
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.event_note_rounded,
                                size: 16,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Events: ${eventsCount ?? '-'}',
                                  style: tt.labelLarge?.copyWith(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Updated: ${_fmtUpdated()}',
                            style: tt.bodySmall?.copyWith(
                              fontWeight: FontWeight.normal,
                              color: Colors.black54,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const Icon(
                            Icons.event_note_rounded,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Events: ${eventsCount ?? '-'}',
                              style: tt.labelLarge?.copyWith(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Updated: ${_fmtUpdated()}',
                              style: tt.bodySmall?.copyWith(
                                fontWeight: FontWeight.normal,
                                color: Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onViewDetail,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View details',
                    style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricTileLikeImage extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  const _MetricTileLikeImage({
    required this.icon,
    required this.label,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final h = compact ? 92.0 : 128.0;

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: compact ? 18 : 22, color: Colors.black54),
          const SizedBox(height: 6),
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              fontSize: compact ? 12 : 14,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: tt.titleLarge?.copyWith(
                    fontSize: compact ? 28 : 42,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillStatus extends StatelessWidget {
  final String text;
  final bool online;
  final bool compact;

  const _PillStatus({
    required this.text,
    required this.online,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final border = Colors.black.withOpacity(0.10);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: tt.labelMedium?.copyWith(
          fontSize: compact ? 12.5 : 14,
          fontWeight: FontWeight.w600,
          color: online ? Colors.black87 : Colors.black54,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(0.05),
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: Colors.black87),
        ),
      ),
    );
  }
}

// ======================================================================
// Helper time ago
// ======================================================================

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// ======================= Data model for TB latest-all =======================

class SensorSnapshot {
  final bool ok;
  final String deviceName;
  final String? deviceId;

  final int? updatedAtTs; // milliseconds epoch from TB response
  final dynamic events;

  final double pga;
  final double si;
  final double temp;

  final DateTime? timestamp;

  final double? lat;
  final double? lng;
  final String? location;
  final double? distanceKm;

  SensorSnapshot({
    required this.ok,
    required this.deviceName,
    required this.deviceId,
    required this.updatedAtTs,
    required this.events,
    required this.pga,
    required this.si,
    required this.temp,
    required this.timestamp,
    required this.lat,
    required this.lng,
    required this.location,
    required this.distanceKm,
  });

  factory SensorSnapshot.fromJson(Map<String, dynamic> json) {
    final telemetry =
        (json['telemetry'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final pga = (telemetry['pga'] is num)
        ? (telemetry['pga'] as num).toDouble()
        : 0.0;
    final si = (telemetry['si'] is num)
        ? (telemetry['si'] as num).toDouble()
        : 0.0;
    final temp = (telemetry['temp'] is num)
        ? (telemetry['temp'] as num).toDouble()
        : 0.0;

    final tsEpoch = (telemetry['timestamp'] is num)
        ? (telemetry['timestamp'] as num).toInt()
        : 0;
    final ts = tsEpoch > 0
        ? DateTime.fromMillisecondsSinceEpoch(tsEpoch, isUtc: true).toLocal()
        : null;

    final lat = (telemetry['lat'] is num)
        ? (telemetry['lat'] as num).toDouble()
        : null;
    final lng = (telemetry['lng'] is num)
        ? (telemetry['lng'] as num).toDouble()
        : null;

    final distanceKm = (telemetry['distanceKm'] is num)
        ? (telemetry['distanceKm'] as num).toDouble()
        : null;

    return SensorSnapshot(
      ok: json['ok'] == true,
      deviceName: (json['deviceName'] ?? 'UnknownSensor').toString(),
      deviceId: json['deviceId']?.toString(),
      updatedAtTs: (json['updatedAtTs'] is num)
          ? (json['updatedAtTs'] as num).toInt()
          : null,
      events: telemetry['events'],
      pga: pga,
      si: si,
      temp: temp,
      timestamp: ts,
      lat: lat,
      lng: lng,
      location: telemetry['location']?.toString(),
      distanceKm: distanceKm,
    );
  }
}
