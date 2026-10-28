// lib/screens/alert_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/alert_event.dart';
import '../services/emergency_action_service.dart';
import '../widgets/emergency_action_grid.dart';

class AlertDetailsScreen extends StatelessWidget {
  final AlertEvent event;

  const AlertDetailsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final severityLabel = _severityLabel(event.severity);
    final severityColor = _severityColor(event.severity);

    // Backend does not provide depth/confidence yet.
    final depthText = 'N/A';
    final confidenceText = 'Not provided';
    final tremorRadiusKm = _estimateRadiusKm(event.magnitude);

    final latLngText =
        '${event.lat.toStringAsFixed(4)}°N, ${event.lng.toStringAsFixed(4)}°E';

    final localTime = _formatLocal(event.timestamp);
    final utcTime = _formatUtc(event.timestamp);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // ---------------- Header ----------------
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Alert Details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, size: 20),
                    onPressed: () => EmergencyActionService.shareAlert(event),
                  ),
                ],
              ),
            ),

            // ---------------- Body ----------------
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    // --------- Affected Area (Map จริง) ---------
                    _SectionCard(
                      title: 'Affected Area',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 220,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: _AffectedAreaMap(
                                position: event.position,
                                radiusKm: tremorRadiusKm,
                                severity: event.severity,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tremor radius and affected area (approximate)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --------- Magnitude / Depth / Distance + Severity ---------
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _StatColumn(
                                label: 'MAGNITUDE',
                                value: event.magnitude.toStringAsFixed(1),
                                unit: '',
                              ),
                              _VerticalDivider(),
                              _StatColumn(
                                label: 'DEPTH',
                                value: depthText,
                                unit: '',
                              ),
                              _VerticalDivider(),
                              _StatColumn(
                                label: 'DISTANCE',
                                value: event.distanceKm.toStringAsFixed(1),
                                unit: ' km',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: severityColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                severityLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: severityColor,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _SectionCard(
                      title: 'Emergency Actions',
                      child: EmergencyActionGrid(
                        event: event,
                        showTitle: false,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --------- Location ---------
                    _SectionCard(
                      title: 'Location',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.place_rounded,
                                size: 18,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  event.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            latLngText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // --------- Time ---------
                    _SectionCard(
                      title: 'Time',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 18,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Local: $localTime',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 26),
                            child: Text(
                              'UTC: $utcTime',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // --------- Detection Info ---------
                    _SectionCard(
                      title: 'Detection Info',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.wifi_tethering_rounded,
                                size: 18,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Sensor ID: ${event.nodeId ?? '-'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.only(left: 26),
                            child: Text(
                              'Confidence: $confidenceText',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 10,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Estimated affected radius: ${tremorRadiusKm.toStringAsFixed(0)} km',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // --------- Description ---------
                    _SectionCard(
                      title: 'Description',
                      child: Text(
                        event.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --------- Confirm button ---------
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 3,
                        ),
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'I Confirm I Understand',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _severityLabel(SeverityLevel s) {
    switch (s) {
      case SeverityLevel.severe:
        return 'SEVERE';
      case SeverityLevel.moderate:
        return 'MODERATE';
      case SeverityLevel.caution:
        return 'CAUTION';
    }
  }

  static Color _severityColor(SeverityLevel s) {
    switch (s) {
      case SeverityLevel.severe:
        return const Color(0xFFD32F2F);
      case SeverityLevel.moderate:
        return const Color(0xFFF57C00);
      case SeverityLevel.caution:
        return const Color(0xFFFFC107);
    }
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _formatLocal(DateTime dt) {
    // เวลาเครื่อง (ไทยก็จะแสดง +07 อัตโนมัติ)
    return '${_two(dt.day)}/${_two(dt.month)}/${dt.year} '
        '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
  }

  static String _formatUtc(DateTime dt) {
    final u = dt.toUtc();
    return '${_two(u.day)}/${_two(u.month)}/${u.year} '
        '${_two(u.hour)}:${_two(u.minute)}:${_two(u.second)} UTC';
  }

  static double _estimateRadiusKm(double magnitude) {
    // กันดูโล่ง ๆ: ประมาณการแบบง่าย (ปรับได้ทีหลัง)
    if (magnitude >= 6.0) return 120;
    if (magnitude >= 5.0) return 80;
    if (magnitude >= 4.0) return 50;
    return 30;
  }
}

/// ---------------- Map widget สำหรับ Affected Area ----------------
class _AffectedAreaMap extends StatelessWidget {
  final LatLng position;
  final double radiusKm;
  final SeverityLevel severity;

  const _AffectedAreaMap({
    required this.position,
    required this.radiusKm,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    final color = _mapColor(severity);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: position, zoom: 7.5),
      markers: {
        Marker(
          markerId: const MarkerId('quake'),
          position: position,
          infoWindow: const InfoWindow(title: 'Epicenter (approx.)'),
        ),
      },
      circles: {
        Circle(
          circleId: const CircleId('tremor_radius'),
          center: position,
          radius: radiusKm * 1000, // km -> m
          fillColor: color.withOpacity(0.18),
          strokeColor: color.withOpacity(0.70),
          strokeWidth: 2,
        ),
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Color _mapColor(SeverityLevel s) {
    switch (s) {
      case SeverityLevel.severe:
        return const Color(0xFFD32F2F);
      case SeverityLevel.moderate:
        return const Color(0xFFF57C00);
      case SeverityLevel.caution:
        return const Color(0xFFFFC107);
    }
  }
}

/// ---------------- Widgets ย่อยอื่น ๆ ----------------
class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.8,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value$unit',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey.withOpacity(0.25),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
