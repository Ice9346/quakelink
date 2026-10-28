// lib/screens/home_dashboard_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../config/app_config.dart';
import '../config/sensor_registry.dart';
import '../services/ws_alert_service.dart';
import '../app_router.dart';
import '../models/alert_event.dart';
import '../models/sensor_snapshot.dart';
import '../services/ws_alert_store.dart';
import '../services/api_client.dart';
import '../widgets/emergency_action_grid.dart';

import 'safety_guide_screen.dart';
import 'settings_screen.dart';
import 'alert_details_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenAlertsTab;

  const HomeDashboardScreen({super.key, required this.onOpenAlertsTab});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  // ---------------- DB ----------------
  late final ApiClient _api = ApiClient(baseUrl: AppConfig.apiBaseUrl);

  bool _dbLoading = false;
  String? _dbError;
  List<AlertEvent> _dbAlerts = [];

  // ---------------- LOCATION ----------------
  Position? _userPos;
  String? _nearestNodeId; // ✅ node ใกล้สุด (คงไว้ ไม่สลับไปเรื่อย ๆ)
  String? _locError;

  static const Map<String, LatLng> _sensorFixedLatLng =
      SensorRegistry.fixedLatLng;

  // ✅ Cache: เก็บ "ค่าความสั่นล่าสุดที่ตรวจจับได้จริง (non-zero)" ต่อ node
  final Map<String, _LastNonZeroReading> _lastNonZeroByDevice = {};

  @override
  void initState() {
    super.initState();

    _loadFromDb(initial: true);
    _initLocation();

    // MainShell owns the shared WebSocket connection.
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadFromDb({bool initial = false}) async {
    if (!mounted) return;

    setState(() {
      _dbLoading = true;
      _dbError = null;
    });

    try {
      final items = await _api.fetchAlerts(take: 50);
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (!mounted) return;
      setState(() {
        _dbAlerts = items;
        _dbLoading = false;
        _dbError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dbLoading = false;
        _dbError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ---------------- LOCATION helpers ----------------

  Future<void> _initLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        setState(() => _locError = 'Location service is OFF');
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied) {
        if (!mounted) return;
        setState(() => _locError = 'Location permission denied');
        return;
      }

      if (perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _locError = 'Location permission denied forever');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      if (!mounted) return;
      setState(() {
        _userPos = pos;
        _locError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _locError = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String? _computeNearestNodeId(Position p, Iterable<String> candidates) {
    double best = double.infinity;
    String? bestId;

    for (final id in candidates) {
      final ll = _sensorFixedLatLng[id];
      if (ll == null) continue;

      final d = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        ll.latitude,
        ll.longitude,
      );

      if (d < best) {
        best = d;
        bestId = id;
      }
    }
    return bestId;
  }

  void _updateNearestIfPossible(WsAlertStore store) {
    if (_nearestNodeId != null) return; // ✅ ล็อกไว้แล้ว ไม่สลับเอง
    final p = _userPos;
    if (p == null) return;

    final candidates = store.tbLatestAll
        .map((s) => s.deviceName.trim())
        .where((id) => id.isNotEmpty && _sensorFixedLatLng.containsKey(id))
        .toSet()
        .toList();

    if (candidates.isEmpty) return;

    final picked = _computeNearestNodeId(p, candidates);
    if (picked == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_nearestNodeId != null) return;
      setState(() => _nearestNodeId = picked);
    });
  }

  // ---------------- TB snapshot helpers ----------------

  SensorSnapshot? _pickNearestSnapshot(WsAlertStore store) {
    final picked = _nearestNodeId;
    if (picked == null) return null;

    for (final s in store.tbLatestAll) {
      if (s.deviceName.trim() == picked) return s;
    }
    return null;
  }

  SensorSnapshot? _pickAnyLatestSnapshot(WsAlertStore store) {
    if (store.tbLatestAll.isEmpty) return null;

    final list = store.tbLatestAll.toList();
    list.sort((a, b) {
      final at = a.updatedAtTs ?? 0;
      final bt = b.updatedAtTs ?? 0;
      if (bt != at) return bt.compareTo(at);

      final ta = a.timestamp?.millisecondsSinceEpoch ?? 0;
      final tb = b.timestamp?.millisecondsSinceEpoch ?? 0;
      if (tb != ta) return tb.compareTo(ta);

      return b.deviceName.compareTo(a.deviceName);
    });

    return list.first;
  }

  AlertEvent _snapshotToAlertEvent(SensorSnapshot s) {
    final fixed = _sensorFixedLatLng[s.deviceName.trim()];
    final lat = (s.lat != null && s.lat != 0) ? s.lat! : (fixed?.latitude ?? 0);
    final lng = (s.lng != null && s.lng != 0) ? s.lng! : (fixed?.longitude ?? 0);
    final timestamp = s.timestamp ??
        (s.updatedAtTs != null
            ? DateTime.fromMillisecondsSinceEpoch(s.updatedAtTs!)
            : DateTime.now());
    final stableTs = s.updatedAtTs ?? timestamp.millisecondsSinceEpoch;
    final name = s.deviceName.trim();
    final pga = s.pga ?? 0;
    final si = s.si ?? 0;

    return AlertEvent(
      alertId: 'TB-$name-$stableTs',
      severity: _deriveSeverityFromPgaSi(pga, si),
      magnitude: pga,
      location: (s.location?.trim().isNotEmpty == true) ? s.location!.trim() : name,
      description:
          'Sensor $name update: pga=${pga.toStringAsFixed(2)}, si=${si.toStringAsFixed(2)}, temp=${(s.temp ?? 0).toStringAsFixed(1)}°C',
      timestamp: timestamp,
      distanceKm: s.distanceKm ?? 0,
      lat: lat,
      lng: lng,
      nodeId: name,
    );
  }

  SeverityLevel _deriveSeverityFromPgaSi(double pga, double si) {
    if (pga >= 1.5 || si >= 80) return SeverityLevel.severe;
    if (pga >= 0.8 || si >= 40) return SeverityLevel.moderate;
    return SeverityLevel.caution;
  }

  // ✅ อัปเดต cache: เก็บ "ค่าล่าสุดที่ไม่ใช่ 0" ต่อ node
  // - ถ้าค่าปัจจุบันเป็น 0,0 => ห้ามทับ
  // - อัปเดตเฉพาะตอนมี si/pga non-zero อย่างน้อย 1 ค่า
  void _ingestLastNonZeroFromStore(WsAlertStore store) {
    for (final s in store.tbLatestAll) {
      final id = s.deviceName.trim();
      if (id.isEmpty) continue;
      if (!_sensorFixedLatLng.containsKey(id))
        continue; // ✅ เอาเฉพาะ 001-004 ตามที่กำหนด

      final si = s.si;
      final pga = s.pga;

      final hasNonZero = (si != null && si != 0) || (pga != null && pga != 0);
      if (!hasNonZero) continue;

      final rec = _lastNonZeroByDevice.putIfAbsent(
        id,
        () => _LastNonZeroReading(deviceName: id),
      );

      // อัปเดตเป็นรายค่า: ถ้าค่านี้ non-zero ค่อยทับ
      if (si != null && si != 0) rec.si = si;
      if (pga != null && pga != 0) rec.pga = pga;

      // temp: เก็บมาพร้อมกันกับตอน detect (ตามโจทย์ "ค่าแรงสั่นที่ตรวจจับได้จริงในตอนแรก")
      if (s.temp != null) rec.temp = s.temp;

      rec.time = (s.updatedAtTs != null)
          ? DateTime.fromMillisecondsSinceEpoch(s.updatedAtTs!)
          : (s.timestamp ?? DateTime.now());
    }
  }

  List<_LastNonZeroReading> _buildLastRecentTop4() {
    final list = _lastNonZeroByDevice.values
        .where((r) => (r.si != null) || (r.pga != null) || (r.temp != null))
        .toList();

    list.sort((a, b) {
      final at = a.time?.millisecondsSinceEpoch ?? 0;
      final bt = b.time?.millisecondsSinceEpoch ?? 0;
      if (bt != at) return bt.compareTo(at);

      // tie-breaker: ชื่อ
      return a.deviceName.compareTo(b.deviceName);
    });

    if (list.length <= 4) return list;
    return list.take(4).toList();
  }

  // ---------------- Alerts merge (เดิม) ----------------

  int _alertIdMillis(AlertEvent a) {
    final m = RegExp(r'AL-(\d+)').firstMatch(a.alertId);
    return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
  }

  List<AlertEvent> _mergeAlerts(List<AlertEvent> ws, List<AlertEvent> db) {
    final seen = <String>{};
    final out = <AlertEvent>[];

    void add(AlertEvent a) {
      final key = a.alertId.isNotEmpty
          ? a.alertId
          : '${a.timestamp.toIso8601String()}_${a.location}_${a.magnitude}';
      if (seen.add(key)) out.add(a);
    }

    for (final a in db) add(a);
    for (final a in ws) add(a);

    out.sort((a, b) {
      final t = b.timestamp.compareTo(a.timestamp);
      if (t != 0) return t;

      final bm = _alertIdMillis(b);
      final am = _alertIdMillis(a);
      final m = bm.compareTo(am);
      if (m != 0) return m;

      return b.alertId.compareTo(a.alertId);
    });

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WsAlertStore>();
    final wsAlerts = store.alerts;

    _updateNearestIfPossible(store);

    // ✅ update cache (ไม่มี setState) — build จะถูกเรียกเองเมื่อ store เปลี่ยน
    _ingestLastNonZeroFromStore(store);
    final lastRecentTop4 = _buildLastRecentTop4();

    final merged = _mergeAlerts(wsAlerts, _dbAlerts);
    final latestAlert = _dbAlerts.isNotEmpty
        ? _dbAlerts.first
        : (merged.isNotEmpty ? merged.first : null);

    final latestSensorEvents = store.tbLatestAll
        .map(_snapshotToAlertEvent)
        .where((e) => e.lat != 0 && e.lng != 0)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final recentForMap = [...latestSensorEvents, ...merged]
        .take(8)
        .toList();

    final mapHeight = MediaQuery.of(context).size.height * 0.40;

    final nearestSnap = _pickNearestSnapshot(store);
    final anySnap = _pickAnyLatestSnapshot(store);
    final snap = nearestSnap ?? anySnap;
    final latestSensorEvent = snap == null ? null : _snapshotToAlertEvent(snap);
    final viewDetailEvent = latestSensorEvent ?? latestAlert;

    final tbDeviceName = snap?.deviceName;
    final tbId = (snap?.deviceId ?? snap?.deviceName);

    final temp = snap?.temp;
    final si = snap?.si;
    final pga = snap?.pga;

    final eventsRaw = snap?.events;
    final eventsCount = (eventsRaw is List)
        ? eventsRaw.length
        : (eventsRaw is Map)
        ? eventsRaw.length
        : null;

    final tbTime = (snap?.updatedAtTs != null)
        ? DateTime.fromMillisecondsSinceEpoch(snap!.updatedAtTs!)
        : snap?.timestamp;

    final sensorsSynced = store.tbLatestAll.length;

    final tbLoading = false;
    final String? tbError = store.tbWsError;
    final tbConnected = store.tbWsConnected;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        top: true,
        bottom: false,
        minimum: const EdgeInsets.only(top: 4),
        child: RefreshIndicator(
          onRefresh: () async => _loadFromDb(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ HEADER
                Column(
                  children: [
                    SizedBox(
                      height: 52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/logos/quakelink.png',
                              height: 34,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.settings, size: 22),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Real-time Earthquake Monitoring',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                EmergencyActionGrid(event: latestAlert, elevated: true),

                const SizedBox(height: 12),

                // ✅ MAP + floating sensor card (ใต้ map) (เก็บไว้แค่อันนี้)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                            color: Colors.black.withOpacity(0.05),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 132),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Live Monitoring Map',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              if (_dbLoading)
                                const _StatusChip(
                                  icon: Icons.sync_rounded,
                                  label: 'Syncing…',
                                  tone: _ChipTone.neutral,
                                )
                              else if (_dbError != null)
                                _StatusChip(
                                  icon: Icons.error_outline_rounded,
                                  label: 'DB error',
                                  tone: _ChipTone.danger,
                                  onTap: () => _loadFromDb(),
                                )
                              else
                                const _StatusChip(
                                  icon: Icons.cloud_done_rounded,
                                  label: 'DB synced',
                                  tone: _ChipTone.good,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            recentForMap.isEmpty
                                ? 'Waiting for events…'
                                : 'Tap a marker to see details',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: mapHeight,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Stack(
                                children: [
                                  _LiveMonitoringMap(
                                    events: recentForMap,
                                    onOpenDetails: (e) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              AlertDetailsScreen(event: e),
                                        ),
                                      );
                                    },
                                  ),
                                  Positioned(
                                    left: 10,
                                    top: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: Colors.black.withOpacity(0.10),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 16,
                                            offset: const Offset(0, 10),
                                            color: Colors.black.withOpacity(
                                              0.06,
                                            ),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.location_searching_rounded,
                                            size: 16,
                                            color: Colors.black87,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            recentForMap.isEmpty
                                                ? 'No markers'
                                                : '${recentForMap.length} markers',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: IgnorePointer(
                                      ignoring: true,
                                      child: Container(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          24,
                                          12,
                                          10,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.35),
                                            ],
                                          ),
                                        ),
                                        child: Text(
                                          recentForMap.isEmpty
                                              ? 'Pull to refresh to sync DB.'
                                              : 'Tap a marker to view details',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const _MapLegendRow(),
                        ],
                      ),
                    ),

                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Material(
                        color: Colors.transparent,
                        child: _FloatingSensorStatusCard(
                          loading: tbLoading,
                          error: tbError,
                          deviceName: tbDeviceName,
                          sensorId: tbId,
                          temp: temp,
                          si: si,
                          pga: pga,
                          eventsCount: eventsCount,
                          time: tbTime,
                          sensorsSynced: sensorsSynced,
                          onRetry: () {
                            WsAlertService.instance.disconnect(silent: true);
                            WsAlertService.instance.connect(
                              context.read<WsAlertStore>(),
                            );
                          },
                          latestAlert: viewDetailEvent,
                          onViewDetails: (e) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AlertDetailsScreen(event: e),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _PrimaryActionButtonUnified(
                        icon: Icons.pan_tool_alt,
                        title: 'I Felt an Earthquake',
                        subtitle: 'Report shaking near you',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(AppRouter.feltReportRoute),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PrimaryActionButtonUnified(
                        icon: Icons.notifications_active_rounded,
                        title: 'Alert History',
                        subtitle: 'See all notifications',
                        onTap: widget.onOpenAlertsTab,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ✅ LAST RECENT (Design ใหม่) : ใช้ "ค่าล่าสุดที่ตรวจจับได้จริง (non-zero)" ไม่ให้ 0,0 มาทับ
                _LastRecentReadingsSection(
                  items: lastRecentTop4,
                  connected: tbConnected,
                ),

                const SizedBox(height: 14),

                if (_locError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Location: $_locError',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  )
                else if (_userPos == null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Location: waiting…',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  )
                else if (_nearestNodeId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Nearest node: $_nearestNodeId • TB WS: ${tbConnected ? 'connected' : 'disconnected'}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),

                const SizedBox(height: 4),

                Row(
                  children: [
                    Expanded(
                      child: _QuickLinkCard(
                        icon: Icons.menu_book_rounded,
                        title: 'Safety Guide',
                        subtitle: 'Emergency instructions',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SafetyGuideScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickLinkCard(
                        icon: Icons.wifi_tethering_rounded,
                        title: 'Live Feed',
                        subtitle: 'WS + DB updates',
                        onTap: widget.onOpenAlertsTab,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Helpers
/// ---------------------------------------------------------------------------

String _two(int v) => v.toString().padLeft(2, '0');

String _formatLocal(DateTime dt) {
  return '${_two(dt.day)}/${_two(dt.month)}/${dt.year} '
      '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

Color _severityColor(SeverityLevel s) {
  switch (s) {
    case SeverityLevel.severe:
      return const Color(0xFFD32F2F);
    case SeverityLevel.moderate:
      return const Color(0xFFF57C00);
    case SeverityLevel.caution:
      return const Color(0xFFFFC107);
  }
}

String _severityTag(SeverityLevel s) {
  switch (s) {
    case SeverityLevel.severe:
      return 'SEVERE';
    case SeverityLevel.moderate:
      return 'MODERATE';
    case SeverityLevel.caution:
      return 'CAUTION';
  }
}

/// ---------------------------------------------------------------------------
/// Small status chip
/// ---------------------------------------------------------------------------

enum _ChipTone { neutral, good, danger }

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final _ChipTone tone;
  final VoidCallback? onTap;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.tone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    Color bg;
    Color border;

    switch (tone) {
      case _ChipTone.good:
        iconColor = Colors.black87;
        bg = Colors.white;
        border = Colors.black.withOpacity(0.10);
        break;
      case _ChipTone.danger:
        iconColor = Colors.redAccent;
        bg = Colors.white;
        border = Colors.redAccent.withOpacity(0.35);
        break;
      case _ChipTone.neutral:
        iconColor = Colors.black87;
        bg = Colors.white;
        border = Colors.black.withOpacity(0.10);
        break;
    }

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          const Text('', style: TextStyle(fontSize: 0)),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: child,
    );
  }
}

/// ---------------------------------------------------------------------------
/// Floating Sensor Status card (ใต้ map) + View details (alert)
/// ---------------------------------------------------------------------------

class _FloatingSensorStatusCard extends StatelessWidget {
  final bool loading;
  final String? error;

  final String? deviceName;
  final String? sensorId;

  final double? temp;
  final double? si;
  final double? pga;

  final int? eventsCount;

  final DateTime? time;

  final int sensorsSynced;

  final VoidCallback onRetry;

  final AlertEvent? latestAlert;
  final void Function(AlertEvent event) onViewDetails;

  const _FloatingSensorStatusCard({
    required this.loading,
    required this.error,
    required this.deviceName,
    required this.sensorId,
    required this.temp,
    required this.si,
    required this.pga,
    required this.eventsCount,
    required this.time,
    required this.sensorsSynced,
    required this.onRetry,
    required this.latestAlert,
    required this.onViewDetails,
  });

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${_two(dt.day)}/${_two(dt.month)}/${dt.year} '
        '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
  }

  String _valueOrDash({required double? v, required int? eventsCount}) {
    // ✅ กัน 0,0 หลอกตา: ถ้า v == 0 และไม่มี event ให้โชว์เป็น '-'
    if (v == null) return '-';
    if (v == 0 && (eventsCount == null || eventsCount == 0)) return '-';
    return v.toStringAsFixed(2);
  }

  String _tempOrDash(double? v, int? eventsCount) {
    if (v == null) return '-';
    if (v == 0 && (eventsCount == null || eventsCount == 0)) return '-';
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final name = (deviceName ?? '').trim().isEmpty
        ? 'Sensor'
        : deviceName!.trim();
    final id = (sensorId ?? '').trim().isEmpty ? '-' : sensorId!.trim();

    final canView = latestAlert != null;
    final age = time == null ? null : DateTime.now().difference(time!);
    final stale = age == null || age.inSeconds > 30;

    Widget headerRight() {
      if (loading) {
        return const _TinyPill(label: 'Syncing…', tone: _PillTone.neutral);
      }
      if (error != null) {
        return InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(999),
          child: const _TinyPill(
            label: 'TB error • Tap to retry',
            tone: _PillTone.danger,
          ),
        );
      }
      if (stale) {
        return _TinyPill(label: 'Data may be old', tone: _PillTone.neutral);
      }
      return _TinyPill(label: 'Live: $sensorsSynced', tone: _PillTone.good);
    }

    Widget statMini({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.black.withOpacity(0.65)),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              headerRight(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.sensors_rounded,
                size: 16,
                color: Colors.black54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ID: $id',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                time == null ? '-' : _timeAgo(time!),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              statMini(
                icon: Icons.thermostat_rounded,
                label: 'Temp (°C)',
                value: _tempOrDash(temp, eventsCount),
              ),
              const SizedBox(width: 10),
              statMini(
                icon: Icons.speed_rounded,
                label: 'SI',
                value: _valueOrDash(v: si, eventsCount: eventsCount),
              ),
              const SizedBox(width: 10),
              statMini(
                icon: Icons.graphic_eq_rounded,
                label: 'PGA',
                value: _valueOrDash(v: pga, eventsCount: eventsCount),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Updated: ${_fmtTime(time)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: canView ? () => onViewDetails(latestAlert!) : null,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(
                    'View detail',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      color: canView ? Colors.black87 : Colors.black38,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _PillTone { neutral, good, danger }

class _TinyPill extends StatelessWidget {
  final String label;
  final _PillTone tone;
  const _TinyPill({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color fg;

    switch (tone) {
      case _PillTone.good:
        bg = Colors.white;
        border = Colors.black.withOpacity(0.10);
        fg = Colors.black87;
        break;
      case _PillTone.danger:
        bg = Colors.white;
        border = Colors.redAccent.withOpacity(0.35);
        fg = Colors.redAccent;
        break;
      case _PillTone.neutral:
        bg = Colors.white;
        border = Colors.black.withOpacity(0.10);
        fg = Colors.black87;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// LAST RECENT (Design ใหม่) : Temp / SI / PGA เท่านั้น
/// - แสดง "ค่าล่าสุดที่ตรวจจับได้จริง (non-zero)" ต่อ node
/// - ถ้าค่าปัจจุบันกลับเป็น 0,0 => ไม่ทับค่าเดิม
/// ---------------------------------------------------------------------------

class _LastRecentReadingsSection extends StatelessWidget {
  final List<_LastNonZeroReading> items;
  final bool connected;

  const _LastRecentReadingsSection({
    required this.items,
    required this.connected,
  });

  String _fmtTemp(double? v) => v == null ? '-' : v.toStringAsFixed(1);
  String _fmt(double? v) => v == null ? '-' : v.toStringAsFixed(2);

  Widget _metricPill({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black.withOpacity(0.70)),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Last Recent',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _TinyPill(
                label: connected ? 'TB connected' : 'TB disconnected',
                tone: connected ? _PillTone.good : _PillTone.danger,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text(
              'No non-zero readings yet (SI/PGA).',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            for (final r in items) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.deviceName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          r.time == null ? '-' : _timeAgo(r.time!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _metricPill(
                          icon: Icons.thermostat_rounded,
                          label: 'Temp',
                          value: _fmtTemp(r.temp),
                        ),
                        _metricPill(
                          icon: Icons.speed_rounded,
                          label: 'SI',
                          value: _fmt(r.si),
                        ),
                        _metricPill(
                          icon: Icons.graphic_eq_rounded,
                          label: 'PGA',
                          value: _fmt(r.pga),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _LastNonZeroReading {
  final String deviceName;
  double? temp;
  double? si;
  double? pga;
  DateTime? time;

  _LastNonZeroReading({required this.deviceName});
}

/// ---------------------------------------------------------------------------
/// Map Legend
/// ---------------------------------------------------------------------------

class _MapLegendRow extends StatelessWidget {
  const _MapLegendRow();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        dot(const Color(0xFFFFC107), 'Caution'),
        dot(const Color(0xFFF57C00), 'Moderate'),
        dot(const Color(0xFFD32F2F), 'Severe'),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Primary Action Button
/// ---------------------------------------------------------------------------

class _PrimaryActionButtonUnified extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PrimaryActionButtonUnified({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.80),
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withOpacity(0.9),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Quick Link Card
/// ---------------------------------------------------------------------------

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF2F2F2),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: Colors.black87),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Live Monitoring Map (marker + bottom sheet + view details)
/// ---------------------------------------------------------------------------

class _LiveMonitoringMap extends StatefulWidget {
  final List<AlertEvent> events;
  final void Function(AlertEvent event) onOpenDetails;

  const _LiveMonitoringMap({required this.events, required this.onOpenDetails});

  @override
  State<_LiveMonitoringMap> createState() => _LiveMonitoringMapState();
}

class _LiveMonitoringMapState extends State<_LiveMonitoringMap> {
  GoogleMapController? _controller;

  static const _fallback = CameraPosition(
    target: LatLng(15.8700, 100.9925),
    zoom: 5.2,
  );

  CameraPosition _initialCamera() {
    if (widget.events.isEmpty) return _fallback;
    return CameraPosition(target: widget.events.first.position, zoom: 7.2);
  }

  double _markerHue(SeverityLevel s) {
    switch (s) {
      case SeverityLevel.severe:
        return BitmapDescriptor.hueRed;
      case SeverityLevel.moderate:
        return BitmapDescriptor.hueOrange;
      case SeverityLevel.caution:
        return BitmapDescriptor.hueYellow;
    }
  }

  Future<void> _centerOnLatest() async {
    final c = _controller;
    if (c == null) return;

    if (widget.events.isEmpty) {
      await c.animateCamera(CameraUpdate.newCameraPosition(_fallback));
      return;
    }

    await c.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: widget.events.first.position, zoom: 7.4),
      ),
    );
  }

  void _openMarkerSheet(AlertEvent e) {
    final color = _severityColor(e.severity);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_severityTag(e.severity)} • Event',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _timeAgo(e.timestamp),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      size: 18,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.location,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    e.description,
                    style: const TextStyle(
                      color: Colors.black87,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniChip(
                      icon: Icons.social_distance_rounded,
                      label: '${e.distanceKm.toStringAsFixed(1)} km away',
                    ),
                    _MiniChip(
                      icon: Icons.access_time_rounded,
                      label: _formatLocal(e.timestamp),
                    ),
                    if ((e.nodeId ?? '').isNotEmpty)
                      _MiniChip(
                        icon: Icons.sensors_rounded,
                        label: 'Node: ${e.nodeId}',
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onOpenDetails(e);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F0F10),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'View details',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Set<Marker> _buildMarkers() {
    if (widget.events.isEmpty) return {};

    return widget.events.asMap().entries.map((entry) {
      final idx = entry.key;
      final e = entry.value;

      return Marker(
        markerId: MarkerId(
          'alert_${idx}_${e.alertId}_${e.timestamp.millisecondsSinceEpoch}',
        ),
        position: e.position,
        icon: BitmapDescriptor.defaultMarkerWithHue(_markerHue(e.severity)),
        onTap: () => _openMarkerSheet(e),
        infoWindow: InfoWindow(
          title: '${_severityTag(e.severity)}',
          snippet: '${e.location} • ${_formatLocal(e.timestamp)}',
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _initialCamera(),
          markers: _buildMarkers(),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (c) => _controller = c,
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _centerOnLatest,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black.withOpacity(0.10)),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                      color: Colors.black.withOpacity(0.06),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  size: 18,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Mini chip
/// ---------------------------------------------------------------------------

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black.withOpacity(0.75)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.72),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}
