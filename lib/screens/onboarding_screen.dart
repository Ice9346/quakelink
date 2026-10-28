// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import '../app_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _goNext(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(AppRouter.mainRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                'QuakeLink',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Real-time Earthquake Alerts\n'
                'แอปแจ้งเตือนแผ่นดินไหวสำหรับประชาชน',
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              const Icon(Icons.vibration, size: 96),
              const SizedBox(height: 24),
              const Text(
                'Permissions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Location – เพื่อคำนวณระยะห่างจากจุดศูนย์กลาง\n'
                  '• Notifications – แสดงการแจ้งเตือนฉุกเฉิน'),
              const Spacer(),
              FilledButton(
                onPressed: () => _goNext(context),
                child: const Text('เริ่มใช้งาน (Start)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
