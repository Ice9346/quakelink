// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'services/ws_alert_store.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => WsAlertStore(),
      child: const QuakeLinkApp(),
    ),
  );
}

class QuakeLinkApp extends StatelessWidget {
  const QuakeLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuakeLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
        brightness: Brightness.light,
      ),
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.authGateRoute,
    );
  }
}
