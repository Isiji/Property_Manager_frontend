// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';
import 'package:property_manager_frontend/screens/dashboard/base_dashboard.dart';
import 'package:property_manager_frontend/screens/landlord/landlord_home.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await TokenManager.currentRole();
    print('🧭 dashboard shell -> role=$role');
    if (!mounted) return;
    setState(() => _role = role);
  }

  @override
  Widget build(BuildContext context) {
    // You can add tenant/manager/admin content later and switch here.
    Widget content;
    String title;

    switch (_role) {
      case 'landlord':
        title = 'Landlord';
        content = const LandlordHome(); // content-only widget
        break;
      case 'manager':
        title = 'Manager';
        content = const Center(child: Text('Manager dashboard coming soon'));
        break;
      case 'admin':
        title = 'Admin';
        content = const Center(child: Text('Admin dashboard coming soon'));
        break;
      case 'tenant':
        title = 'Tenant';
        content = const Center(child: Text('Tenant dashboard coming soon'));
        break;
      default:
        title = 'Dashboard';
        content = const Center(child: CircularProgressIndicator());
    }

    return BaseDashboard(
      title: title,
      body: content,
    );
  }
}
