import 'package:flutter/material.dart';
import 'package:property_manager_frontend/screens/landlord/landlord_payouts.dart';
import 'package:provider/provider.dart';

import 'package:property_manager_frontend/screens/auth/login_screen.dart';
import 'package:property_manager_frontend/screens/auth/register_screen.dart';
import 'package:property_manager_frontend/screens/settings/settings_screen.dart';
import 'package:property_manager_frontend/screens/tenant/tenant_home.dart';
// Shell that hosts role-specific content (topbar + collapsible side nav)
import 'package:property_manager_frontend/screens/dashboard/dashboard_shell.dart';

// Landlord detail screen for a property’s units
import 'package:property_manager_frontend/screens/landlord/landlord_property_units.dart';
import 'package:property_manager_frontend/screens/landlord/landlord_overview.dart';

import 'package:property_manager_frontend/theme/app_theme.dart';
import 'package:property_manager_frontend/providers/theme_provider.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

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
        '/tenant_home': (_) => const TenantHome(),
        // ✅ One common dashboard shell
        '/dashboard': (_) => const DashboardShell(),

        // ✅ Route aliases (old routes still work)
        '/landlord_dashboard': (_) => const DashboardShell(),
        '/manager_dashboard': (_) => const DashboardShell(),
        '/admin_dashboard': (_) => const DashboardShell(),
        '/tenant_dashboard': (_) => const DashboardShell(),
        '/landlord_payouts': (_) => const LandlordPayoutsScreen(),
        '/landlord_overview': (_) => const LandlordOverview(),
        // ✅ Landlord’s property units page; accepts either an int or {propertyId: int}
        '/landlord_property_units': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          int propertyId;
          if (args is int) {
            propertyId = args;
          } else if (args is Map && args['propertyId'] is int) {
            propertyId = args['propertyId'] as int;
          } else {
            throw ArgumentError(
              'Route /landlord_property_units requires an int propertyId or {propertyId: int}',
            );
          }
          return LandlordPropertyUnits(propertyId: propertyId);
        },
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
        '[LaunchDecider] Logged in as ${session.role} → Navigating to /dashboard',
      );
      Navigator.of(context).pushReplacementNamed('/dashboard', arguments: {
        'role': session.role,
        'userId': session.userId,
      });
    } else {
      debugPrint('[LaunchDecider] No active session → going to /login');
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
