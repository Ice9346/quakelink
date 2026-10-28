// lib/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'safety_guide_screen.dart';
import 'home_dashboard_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'chat_ai_screen.dart';

import '../services/ws_alert_store.dart';
import '../services/ws_alert_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  static const int _homeTab = 0;
  static const int _safetyTab = 1;
  static const int _chatTab = 2;
  static const int _alertsTab = 3;
  static const int _profileTab = 4;

  @override
  void initState() {
    super.initState();

    _pages = [
      HomeDashboardScreen(
        onOpenAlertsTab: () => _onNavTap(_alertsTab),
      ),
      const SafetyGuideScreen(),
      const ChatAiScreen(),
      const HistoryScreen(),
      const ProfileScreen(),
    ];

    // ✅ ต่อ WebSocket ครั้งเดียวที่ MainShell
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = context.read<WsAlertStore>();
      WsAlertService.instance.connect(store);
    });
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);

    // ✅ เข้าแท็บ Alerts แล้วนับ unread เป็น 0
    if (index == _alertsTab) {
      context.read<WsAlertStore>().markAllRead();
    }
  }

  @override
  void dispose() {
    // ถ้าต้องการตัด WS ตอนออกจาก shell:
    // WsAlertService.instance.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      // ✅ rebuild เฉพาะ BottomNav เมื่อ unread เปลี่ยน (ไม่ลากทั้งหน้า rebuild)
      bottomNavigationBar: Consumer<WsAlertStore>(
        builder: (context, store, _) {
          final unread = store.unreadCount;

          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onNavTap,
            backgroundColor: Colors.white,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.black54,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.shield),
                label: 'Safety',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.smart_toy_outlined),
                label: 'AI',
              ),
              BottomNavigationBarItem(
                icon: _BadgeIcon(
                  icon: Icons.notifications,
                  count: unread,
                ),
                label: 'Alerts',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;

  const _BadgeIcon({
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final show = count > 0;
    final text = count > 99 ? '99+' : '$count';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (show)
          Positioned(
            right: -10,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
