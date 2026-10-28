// lib/screens/sensor_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/sensor_node.dart';
import 'package:intl/intl.dart';

class SensorDetailArgs {
  final SensorNode node;

  SensorDetailArgs({required this.node});
}

class SensorDetailScreen extends StatelessWidget {
  final SensorDetailArgs args;

  const SensorDetailScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final node = args.node;
    final df = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: Text(node.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Node ID'),
            subtitle: Text(node.id),
          ),
          ListTile(
            title: const Text('Status'),
            subtitle: Text(node.isOnline ? 'Online' : 'Offline'),
          ),
          ListTile(
            title: const Text('Vibration Level'),
            subtitle:
                Text('${(node.vibrationLevel * 100).toStringAsFixed(0)} %'),
          ),
          ListTile(
            title: const Text('Last Update'),
            subtitle: Text(df.format(node.lastUpdate)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hardware Info (ตัวอย่าง)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '• MCU: ESP32 / ESP32-S3\n'
            '• Connectivity: WiFi Mesh\n'
            '• Power: AC + DC backup\n'
            '• Location: Configurable via backend',
          ),
        ],
      ),
    );
  }
}
