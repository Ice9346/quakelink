import 'package:google_maps_flutter/google_maps_flutter.dart';

class SensorRegistry {
  SensorRegistry._();

  static const List<String> expectedDeviceNames = [
    'EarthquakeSensor001',
    'EarthquakeSensor003',
    'EarthquakeSensor004',
    'EarthquakeSensor005',
  ];

  static const Map<String, LatLng> fixedLatLng = {
    'EarthquakeSensor001': LatLng(14.0227, 99.5328), // Kanchanaburi
    'EarthquakeSensor003': LatLng(19.9105, 99.8406), // Chiang Rai
    'EarthquakeSensor004': LatLng(18.1446, 100.1403), // Phrae
    'EarthquakeSensor005': LatLng(18.7883, 98.9853), // Chiang Mai
  };

  static int sortIndex(String deviceName) {
    final index = expectedDeviceNames.indexOf(deviceName);
    return index == -1 ? 999 : index;
  }
}
