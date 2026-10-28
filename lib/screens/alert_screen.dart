// lib/screens/alert_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alert_event.dart';
import '../services/ws_alert_store.dart';
import '../widgets/emergency_action_grid.dart';
import 'safety_guide_screen.dart';

class AlertScreenArgs {
  final String? alertId;
  final SeverityLevel? severity;

  final double magnitude;
  final String location;
  final String? description;

  final double distanceKm;
  final int? secondsToArrival; // เผื่อทำ EEW ในอนาคต
  final DateTime? timestamp;

  AlertScreenArgs({
    this.alertId,
    this.severity,
    required this.magnitude,
    required this.location,
    this.description,
    required this.distanceKm,
    this.secondsToArrival,
    this.timestamp,
  });

  factory AlertScreenArgs.mock() {
    return AlertScreenArgs(
      alertId: 'MOCK-001',
      severity: SeverityLevel.moderate,
      magnitude: 5.2,
      location: 'Chiang Mai, Thailand',
      description: 'Moderate earthquake detected in Chiang Mai region',
      distanceKm: 30,
      secondsToArrival: 5,
      timestamp: DateTime.now(),
    );
  }

  factory AlertScreenArgs.fromEvent(AlertEvent e) {
    return AlertScreenArgs(
      alertId: e.alertId,
      severity: e.severity,
      magnitude: e.magnitude,
      location: e.location,
      description: e.description,
      distanceKm: e.distanceKm,
      secondsToArrival: null,
      timestamp: e.timestamp,
    );
  }
}

class AlertScreen extends StatelessWidget {
  final AlertScreenArgs? args;

  const AlertScreen({super.key, this.args});

  @override
  Widget build(BuildContext context) {
    // ✅ ถ้าไม่ได้ส่ง args มา ให้ดึง "ล่าสุด" จาก store
    final store = context.watch<WsAlertStore>();
    final latest = store.alerts.isNotEmpty ? store.alerts.first : null;

    final data =
        args ??
        (latest != null
            ? AlertScreenArgs.fromEvent(latest)
            : AlertScreenArgs.mock());

    final severity = data.severity ?? SeverityLevel.moderate;
    final bg = _bgColor(severity);
    final event = latest;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'EARTHQUAKE ALERT',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  _SeverityPill(severity: severity),
                ],
              ),

              const SizedBox(height: 18),

              // ---------- Main content ----------
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ImmediateActionPanel(severity: severity),
                        const SizedBox(height: 18),

                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            data.magnitude.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 86,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 0.95,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Location
                        Text(
                          data.location,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        if ((data.description ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            data.description!,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Meta row
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _MetaChip(
                              icon: Icons.place_rounded,
                              text:
                                  '≈ ${data.distanceKm.toStringAsFixed(1)} km จากคุณ',
                            ),
                            if (data.timestamp != null)
                              _MetaChip(
                                icon: Icons.access_time_rounded,
                                text: _formatTime(data.timestamp!),
                              ),
                            if (data.secondsToArrival != null)
                              _MetaChip(
                                icon: Icons.timer_rounded,
                                text: 'Arrival ~ ${data.secondsToArrival}s',
                              ),
                          ],
                        ),

                        const SizedBox(height: 26),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                            ),
                          ),
                          child: const Column(
                            children: [
                              Text(
                                'หมอบ – กำบัง – ยึดจับ',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'อยู่ห่างหน้าต่าง อย่าใช้ลิฟต์ และปกป้องศีรษะกับคอ',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              EmergencyActionGrid(
                event: event,
                title: 'การช่วยเหลือด่วน',
                callLabel: 'โทรฉุกเฉิน 1669',
                safeLabel: 'ฉันปลอดภัย',
                locationLabel: 'แชร์ตำแหน่ง',
                inverted: true,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.45)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SafetyGuideScreen()),
                ),
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text(
                  'เปิดคู่มือความปลอดภัย',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _bgColor(SeverityLevel s) {
    switch (s) {
      case SeverityLevel.severe:
        return const Color(0xFF7A1010);
      case SeverityLevel.moderate:
        return const Color(0xFF8A3B00);
      case SeverityLevel.caution:
        return const Color(0xFF6B4B00);
    }
  }

  static String _formatTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}

class _ImmediateActionPanel extends StatelessWidget {
  final SeverityLevel severity;

  const _ImmediateActionPanel({required this.severity});

  @override
  Widget build(BuildContext context) {
    final text = switch (severity) {
      SeverityLevel.severe => 'สั่นแรง: หาที่กำบังทันที',
      SeverityLevel.moderate => 'เตรียมป้องกันตัวทันที',
      SeverityLevel.caution => 'ระวังแรงสั่นและติดตามสถานะ',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white.withOpacity(0.95)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeverityPill extends StatelessWidget {
  final SeverityLevel severity;

  const _SeverityPill({required this.severity});

  @override
  Widget build(BuildContext context) {
    final label = switch (severity) {
      SeverityLevel.severe => 'SEVERE',
      SeverityLevel.moderate => 'MODERATE',
      SeverityLevel.caution => 'CAUTION',
    };

    final color = switch (severity) {
      SeverityLevel.severe => const Color(0xFFD32F2F),
      SeverityLevel.moderate => const Color(0xFFF57C00),
      SeverityLevel.caution => const Color(0xFFFFC107),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
