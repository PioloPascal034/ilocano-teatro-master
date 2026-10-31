import 'package:flutter/material.dart';

import '../features/auth/auth_gate.dart';
import 'app_routes.dart';
import 'app_theme.dart';

class TeatroApp extends StatelessWidget {
  const TeatroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ilocano Teatro Master',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
