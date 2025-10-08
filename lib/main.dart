import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:property_manager_frontend/screens/auth/login_screen.dart';
import 'package:property_manager_frontend/screens/auth/register_screen.dart';
import 'package:property_manager_frontend/screens/settings/settings_screen.dart';
import 'package:property_manager_frontend/theme/app_theme.dart';
import 'package:property_manager_frontend/providers/theme_provider.dart';

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
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/settings': (_) => const SettingsScreen(),
        // Future dashboard routes:
        // '/tenant_dashboard': (_) => const TenantDashboard(),
        // '/landlord_dashboard': (_) => const LandlordDashboard(),
        // '/manager_dashboard': (_) => const ManagerDashboard(),
        // '/admin_dashboard': (_) => const AdminDashboard(),
      },
    );
  }
}
