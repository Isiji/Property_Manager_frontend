import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:property_manager_frontend/screens/auth/login_screen.dart';
import 'package:property_manager_frontend/screens/auth/register_screen.dart';
import 'package:property_manager_frontend/screens/settings/settings_screen.dart';
import 'package:property_manager_frontend/screens/dashboard/base_dashboard.dart';

import 'package:property_manager_frontend/theme/app_theme.dart';
import 'package:property_manager_frontend/providers/theme_provider.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';
import 'package:property_manager_frontend/screens/landlord/landlord_dashboard.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const PropSmartApp(),
    ),
  );
}

class PropSmartApp extends StatelessWidget {
  const PropSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final light = AppTheme.lightTheme.copyWith(
      colorScheme: AppTheme.lightTheme.colorScheme.copyWith(
        primary: themeProvider.accentColor,
      ),
      textTheme: AppTheme.lightTheme.textTheme.apply(
        fontFamily: themeProvider.fontFamily,
      ),
    );

    final dark = AppTheme.darkTheme.copyWith(
      colorScheme: AppTheme.darkTheme.colorScheme.copyWith(
        primary: themeProvider.accentColor,
      ),
      textTheme: AppTheme.darkTheme.textTheme.apply(
        fontFamily: themeProvider.fontFamily,
      ),
    );

    return MaterialApp(
      title: 'PropSmart Management System',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      themeMode: themeProvider.themeMode,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/dashboard': (_) => const BaseDashboard(),
        '/landlord_dashboard': (_) => const LandlordDashboard(),
      },
      home: const LaunchDecider(),
    );
  }
}

/// Decides navigation based on saved session
class LaunchDecider extends StatefulWidget {
  const LaunchDecider({super.key});

  @override
  State<LaunchDecider> createState() => _LaunchDeciderState();
}

class _LaunchDeciderState extends State<LaunchDecider> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    debugPrint('[LaunchDecider] Checking session...');
    final session = await TokenManager.loadSession();

    if (!mounted) return;

    if (session != null && !session.isExpired) {
      debugPrint(
          '[LaunchDecider] Logged in as ${session.role} → Navigating to dashboard');
      Navigator.of(context).pushReplacementNamed('/dashboard', arguments: {
        'role': session.role,
        'userId': session.userId,
      });
    } else {
      debugPrint('[LaunchDecider] No active session → going to login');
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
