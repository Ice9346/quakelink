// lib/widgets/sensor_status_chip.dart
import 'package:flutter/material.dart';
import '../models/sensor_node.dart';

class SensorStatusChip extends StatelessWidget {
  final SensorNode node;

  const SensorStatusChip({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final color = node.isOnline ? Colors.green : Colors.grey;
    final label = node.isOnline ? 'Online' : 'Offline';

    return Chip(
      label: Text(label),
      side: BorderSide(color: color),
      avatar: CircleAvatar(
        backgroundColor: color,
        radius: 6,
      ),
    );
  }
}
