// lib/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ตรงนี้ในอนาคตเชื่อม backend ได้เลย
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.sensors),
            title: Text('Node Health Overview'),
            subtitle: Text('2 online • 0 offline'),
          ),
          ListTile(
            leading: Icon(Icons.analytics),
            title: Text('Events Statistics'),
            subtitle: Text('Today: 0 strong, 2 minor'),
          ),
          ListTile(
            leading: Icon(Icons.campaign),
            title: Text('Broadcast Message'),
            subtitle: Text('TODO: ส่งข้อความถึงผู้ใช้ทั้งหมด'),
          ),
        ],
      ),
    );
  }
}
