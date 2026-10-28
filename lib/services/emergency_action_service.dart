import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/alert_event.dart';

class EmergencyActionService {
  EmergencyActionService._();

  static Future<void> callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Cannot open phone dialer');
    }
  }

  static Future<void> shareImSafe({AlertEvent? event}) async {
    final locationText = await _currentLocationText();
    final eventText = event == null
        ? ''
        : '\n\nLatest alert: ${event.location}, magnitude ${event.magnitude.toStringAsFixed(1)} at ${_formatTime(event.timestamp)}.';

    await Share.share(
      'I am safe right now.$locationText$eventText\n\nSent from QuakeLink.',
      subject: 'I am safe',
    );
  }

  static Future<void> shareCurrentLocation() async {
    final locationText = await _currentLocationText(includeUnavailable: true);
    await Share.share(
      'My current location:$locationText\n\nSent from QuakeLink.',
      subject: 'My location',
    );
  }

  static Future<void> shareAlert(AlertEvent event) async {
    await Share.share(
      'Earthquake alert: ${event.location}\n'
      'Magnitude: ${event.magnitude.toStringAsFixed(1)}\n'
      'Severity: ${event.severity.name.toUpperCase()}\n'
      'Time: ${_formatTime(event.timestamp)}\n'
      'Distance: ${event.distanceKm.toStringAsFixed(1)} km\n'
      'Location: https://maps.google.com/?q=${event.lat},${event.lng}\n\n'
      'Sent from QuakeLink.',
      subject: 'QuakeLink earthquake alert',
    );
  }

  static Future<String> _currentLocationText({
    bool includeUnavailable = false,
  }) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return includeUnavailable ? '\nLocation service is off.' : '';
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return includeUnavailable
            ? '\nLocation permission is not available.'
            : '';
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      return '\nhttps://maps.google.com/?q=${pos.latitude},${pos.longitude}';
    } catch (_) {
      return includeUnavailable ? '\nLocation is unavailable.' : '';
    }
  }

  static String _formatTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}
