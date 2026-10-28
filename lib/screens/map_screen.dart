// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import '../models/sensor_node.dart';
import '../widgets/sensor_status_chip.dart';
import '../app_router.dart';
import 'sensor_detail_screen.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  List<SensorNode> _mockNodes() {
    return [
      SensorNode(
        id: 'node1',
        name: 'Node CMU',
        latitude: 18.8,
        longitude: 98.9,
        isOnline: true,
        vibrationLevel: 0.1,
        lastUpdate: DateTime.now(),
      ),
      SensorNode(
        id: 'node2',
        name: 'Node Old City',
        latitude: 18.79,
        longitude: 98.98,
        isOnline: true,
        vibrationLevel: 0.3,
        lastUpdate: DateTime.now(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _mockNodes();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        return Card(
          child: ListTile(
            title: Text(node.name),
            subtitle: Text(
                'Online: ${node.isOnline} • Vibration: ${(node.vibrationLevel * 100).toStringAsFixed(0)}%'),
            trailing: SensorStatusChip(node: node),
            onTap: () {
              Navigator.of(context).pushNamed(
                AppRouter.sensorDetailRoute,
                arguments: SensorDetailArgs(node: node),
              );
            },
          ),
        );
      },
    );
  }
}
