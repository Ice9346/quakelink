// lib/app_router.dart
import 'package:flutter/material.dart';

import 'screens/felt_earthquake_report_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';
import 'screens/alert_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/sensor_detail_screen.dart';
import 'screens/profile_edit_screen.dart';

// ✅ auth
import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

class AppRouter {
  // ✅ existing
  static const String onboardingRoute = '/onboarding';
  static const String mainRoute = '/';
  static const String alertRoute = '/alert';
  static const String profileRoute = '/profile';
  static const String adminRoute = '/admin';
  static const String sensorDetailRoute = '/sensor_detail';
  static const String profileEditRoute = '/profile-edit';

  // 👉 route ของหน้า I Felt The Shake
  static const String feltReportRoute = '/felt-report';

  // ✅ new auth routes
  static const String authGateRoute = '/auth-gate';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ✅ auth
      case authGateRoute:
        return MaterialPageRoute(
          builder: (_) => const AuthGate(),
          settings: settings,
        );

      case loginRoute:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      case registerRoute:
        return MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
          settings: settings,
        );

      // ✅ existing
      case onboardingRoute:
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
          settings: settings,
        );

      case mainRoute:
        return MaterialPageRoute(
          builder: (_) => const MainShell(),
          settings: settings,
        );

      case alertRoute:
        final args = settings.arguments as AlertScreenArgs?;
        return MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AlertScreen(args: args),
          settings: settings,
        );

      case profileRoute:
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );

      case profileEditRoute:
        return MaterialPageRoute(
          builder: (_) => const ProfileEditScreen(),
          settings: settings,
        );

      case adminRoute:
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(),
          settings: settings,
        );

      case sensorDetailRoute:
        final args = settings.arguments as SensorDetailArgs;
        return MaterialPageRoute(
          builder: (_) => SensorDetailScreen(args: args),
          settings: settings,
        );

      case feltReportRoute:
        return MaterialPageRoute(
          builder: (_) => const FeltEarthquakeReportScreen(),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }
}
