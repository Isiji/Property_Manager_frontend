import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:property_manager_frontend/screens/auth/login_screen.dart';
import 'package:property_manager_frontend/screens/auth/register_screen.dart';
import 'package:property_manager_frontend/screens/settings/settings_screen.dart';
import 'package:property_manager_frontend/screens/tenant/tenant_home.dart';
import 'package:property_manager_frontend/screens/dashboard/dashboard_shell.dart';
import 'package:property_manager_frontend/screens/common/maintenance_inbox.dart';
import 'package:property_manager_frontend/screens/landlord/landlord_property_units.dart';
import 'package:property_manager_frontend/screens/landlord/landlord_overview.dart';
import 'package:property_manager_frontend/screens/landlord/landlord_payouts.dart';

import 'package:property_manager_frontend/screens/manager/manager_payments.dart';
import 'package:property_manager_frontend/screens/manager/manager_properties.dart';
import 'package:property_manager_frontend/screens/manager/manager_tenants.dart';

import 'package:property_manager_frontend/screens/agency/agency_agents.dart';

import 'package:property_manager_frontend/theme/app_theme.dart';
import 'package:property_manager_frontend/providers/theme_provider.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';
import 'package:property_manager_frontend/screens/lease/lease_view.dart';

import 'package:property_manager_frontend/screens/manager/manager_dashboard_router.dart';

// Admin screens
import 'package:property_manager_frontend/screens/admin/admin_properties.dart';
import 'package:property_manager_frontend/screens/admin/admin_finance.dart';
import 'package:property_manager_frontend/screens/admin/admin_maintenance.dart';
import 'package:property_manager_frontend/screens/admin/admin_notifications.dart';
import 'package:property_manager_frontend/screens/admin/admin_home.dart';
import 'package:property_manager_frontend/screens/admin/admin_logs.dart';
import 'package:property_manager_frontend/screens/admin/admin_landlords.dart';
import 'package:property_manager_frontend/screens/admin/admin_managers.dart';
import 'package:property_manager_frontend/screens/admin/admin_payouts.dart';
import 'package:property_manager_frontend/screens/auth/forgot_password_screen.dart';
import 'package:property_manager_frontend/screens/auth/reset_password_screen.dart';
// Super admin screens
import 'package:property_manager_frontend/screens/super_admin/super_admin_home.dart';
import 'package:property_manager_frontend/screens/super_admin/super_admin_admins.dart';

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

        '/dashboard': (_) => const DashboardShell(),
        '/lease_view': (ctx) => const LeaseViewScreen(),

        '/landlord_maintenance_inbox': (ctx) => const LandlordMaintenanceInbox(),
        '/manager_maintenance_inbox': (ctx) => const LandlordMaintenanceInbox(forManager: true),

        '/landlord_dashboard': (_) => const DashboardShell(),
        '/manager_dashboard': (_) => const ManagerDashboardRouter(),
        '/admin_dashboard': (_) => const DashboardShell(),
        '/tenant_dashboard': (_) => const DashboardShell(),

        '/super_admin_dashboard': (_) => const SuperAdminHomeScreen(),
        '/super_admin_admins': (_) => const SuperAdminAdminsScreen(),

        '/landlord_payouts': (_) => const LandlordPayoutsScreen(),
        '/landlord_overview': (_) => const LandlordOverview(),

        '/manager_properties': (_) => const ManagerPropertiesScreen(),

        '/manager_payments': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map?;
          final propertyId = (args?['propertyId'] as num?)?.toInt() ?? 0;
          final propertyCode = args?['propertyCode']?.toString();
          final propertyName = args?['propertyName']?.toString();
          final period = args?['period']?.toString();

          if (propertyId == 0) {
            throw ArgumentError('Route /manager_payments requires propertyId');
          }

          return ManagerPaymentsScreen(
            propertyId: propertyId,
            propertyCode: propertyCode,
            propertyName: propertyName,
            initialPeriod: period,
          );
        },

        '/agency_agents': (_) => const AgencyAgentsScreen(),

        '/manager_tenants': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map?;
          final propertyId = (args?['propertyId'] as num?)?.toInt() ?? 0;
          final propertyCode = args?['propertyCode']?.toString();
          final propertyName = args?['propertyName']?.toString();

          if (propertyId == 0) {
            throw ArgumentError('Route /manager_tenants requires propertyId');
          }

          return ManagerTenantsScreen(
            propertyId: propertyId,
            propertyCode: propertyCode,
            propertyName: propertyName,
          );
        },

        '/landlord_property_units': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
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
        '/admin_properties': (_) => const AdminPropertiesScreen(),
        '/admin_finance': (_) => const AdminFinanceScreen(),
        '/admin_maintenance': (_) => const AdminMaintenanceScreen(),
        '/admin_notifications': (_) => const AdminNotificationsScreen(),
        '/admin_home': (_) => const AdminHome(),
        '/admin_logs': (_) => const AdminLogsScreen(),
        '/admin_landlords': (_) => const AdminLandlordsScreen(),
        '/admin_managers': (_) => const AdminManagersScreen(),
        '/admin_payouts': (_) => const AdminPayoutsScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/reset_password': (context) => const ResetPasswordScreen(),
        '/admin_property_detail': (_) => const Scaffold(
              body: Center(child: Text('Admin property detail coming soon')),
            ),
      },
      home: const LaunchDecider(),
    );
  }
}

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
      final role = session.role;
      debugPrint('[LaunchDecider] Logged in as $role');

      if (role == 'manager') {
        Navigator.of(context).pushReplacementNamed('/manager_dashboard');
        return;
      }

      if (role == 'super_admin') {
        Navigator.of(context).pushReplacementNamed('/super_admin_dashboard');
        return;
      }

      if (role == 'admin') {
        Navigator.of(context).pushReplacementNamed('/dashboard');
        return;
      }

      Navigator.of(context).pushReplacementNamed('/dashboard', arguments: {
        'role': role,
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