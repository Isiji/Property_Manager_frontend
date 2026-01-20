// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/utils/token_manager.dart';
import 'package:property_manager_frontend/screens/dashboard/base_dashboard.dart';

import 'package:property_manager_frontend/screens/landlord/landlord_home.dart';
import 'package:property_manager_frontend/screens/manager/manager_home.dart';
import 'package:property_manager_frontend/screens/manager/manager_properties.dart';
import 'package:property_manager_frontend/screens/common/maintenance_inbox.dart';
import 'package:property_manager_frontend/screens/settings/settings_screen.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  String? _role;
  String _tab = 'overview'; // overview | properties | maintenance | settings

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

  List<DashboardNavItem> _navForRole(String role) {
    switch (role) {
      case 'manager':
        return const [
          DashboardNavItem(key: 'overview', icon: LucideIcons.layoutDashboard, label: 'Overview'),
          DashboardNavItem(key: 'properties', icon: LucideIcons.building2, label: 'Properties'),
          DashboardNavItem(key: 'maintenance', icon: LucideIcons.wrench, label: 'Maintenance'),
          DashboardNavItem(key: 'settings', icon: LucideIcons.settings, label: 'Settings'),
        ];
      case 'landlord':
        return const [
          DashboardNavItem(key: 'overview', icon: LucideIcons.layoutDashboard, label: 'Overview'),
          DashboardNavItem(key: 'properties', icon: LucideIcons.building2, label: 'Properties'),
          DashboardNavItem(key: 'maintenance', icon: LucideIcons.wrench, label: 'Maintenance'),
          DashboardNavItem(key: 'settings', icon: LucideIcons.settings, label: 'Settings'),
        ];
      default:
        return const [
          DashboardNavItem(key: 'overview', icon: LucideIcons.layoutDashboard, label: 'Overview'),
          DashboardNavItem(key: 'settings', icon: LucideIcons.settings, label: 'Settings'),
        ];
    }
  }

  String _titleFor(String role, String tab) {
    if (role == 'manager') {
      switch (tab) {
        case 'properties':
          return 'Manager • Properties';
        case 'maintenance':
          return 'Manager • Maintenance';
        case 'settings':
          return 'Manager • Settings';
        default:
          return 'Manager';
      }
    }

    if (role == 'landlord') {
      switch (tab) {
        case 'properties':
          return 'Landlord • Properties';
        case 'maintenance':
          return 'Landlord • Maintenance';
        case 'settings':
          return 'Landlord • Settings';
        default:
          return 'Landlord';
      }
    }

    return 'Dashboard';
  }

  Widget _bodyFor(String role, String tab) {
    if (role == 'manager') {
      switch (tab) {
        case 'properties':
          return const ManagerPropertiesScreen();
        case 'maintenance':
          return const LandlordMaintenanceInbox(forManager: true);
        case 'settings':
          return const SettingsScreen();
        default:
          return const ManagerHome(); // now simple (we’ll update below)
      }
    }

    if (role == 'landlord') {
      switch (tab) {
        case 'properties':
          return const LandlordHome();
        case 'maintenance':
          return const LandlordMaintenanceInbox();
        case 'settings':
          return const SettingsScreen();
        default:
          return const LandlordHome();
      }
    }

    return const Center(child: CircularProgressIndicator());
  }

  @override
  Widget build(BuildContext context) {
    final role = _role;

    if (role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final navItems = _navForRole(role);

    // safety: if current tab not allowed, reset
    final allowedKeys = navItems.map((e) => e.key).toSet();
    if (!allowedKeys.contains(_tab)) {
      _tab = navItems.first.key;
    }

    final title = _titleFor(role, _tab);
    final body = _bodyFor(role, _tab);

    return BaseDashboard(
      title: title,
      body: body,
      navItems: navItems,
      selectedNavKey: _tab,
      onSelectNav: (key) {
        if (!mounted) return;
        setState(() => _tab = key);
      },
    );
  }
}
