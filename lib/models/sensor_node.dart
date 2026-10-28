// lib/models/sensor_node.dart
class SensorNode {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final bool isOnline;
  final double vibrationLevel; // 0-1
  final DateTime lastUpdate;

  SensorNode({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.isOnline,
    required this.vibrationLevel,
    required this.lastUpdate,
  });
}
