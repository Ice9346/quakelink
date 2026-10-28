import 'package:flutter/material.dart';
import '../app_router.dart';
import '../services/auth_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final ok = await AuthService.instance.isLoggedIn();

    if (!mounted) return;

    //  ถ้าล็อกอินแล้วเข้า MainShell (route "/")
    //  ถ้ายังไม่ล็อกอินไปหน้า Login
    Navigator.pushReplacementNamed(
      context,
      ok ? AppRouter.mainRoute : AppRouter.loginRoute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
