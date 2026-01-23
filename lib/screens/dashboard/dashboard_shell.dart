// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/utils/token_manager.dart';
import 'package:property_manager_frontend/screens/dashboard/base_dashboard.dart';

import 'package:property_manager_frontend/screens/landlord/landlord_home.dart';
import 'package:property_manager_frontend/screens/manager/manager_home.dart';
import 'package:property_manager_frontend/screens/agency/agency_home.dart';

import 'package:property_manager_frontend/services/manager_service.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  String? _role;
  bool _isAgency = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessionContext();
  }

  Future<void> _loadSessionContext() async {
    final role = await TokenManager.currentRole();
    print('🧭 dashboard shell -> role=$role');

    bool isAgency = false;

    // If manager, check manager_type from backend (/managers/me)
    if (role == 'manager') {
      try {
        final me = await ManagerService.getMe();
        final t = (me['manager_type'] ?? '').toString().toLowerCase();
        isAgency = t == 'agency';
        print('🏢 manager_type=$t -> isAgency=$isAgency');
      } catch (e) {
        print('⚠️ failed to load /managers/me: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _role = role;
      _isAgency = isAgency;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Widget content;
    String title;
    List<DashboardNavItem> nav;
    const String currentRoute = '/dashboard';

    switch (_role) {
      case 'landlord':
        title = 'Landlord';
        content = const LandlordHome();
        nav = [
          DashboardNavItem(icon: LucideIcons.layoutDashboard, label: 'Overview', route: '/dashboard'),
          DashboardNavItem(icon: LucideIcons.building2, label: 'Properties', route: '/dashboard'),
          DashboardNavItem(icon: LucideIcons.wrench, label: 'Maintenance', route: '/landlord_maintenance_inbox'),
          DashboardNavItem(icon: LucideIcons.wallet, label: 'Payouts', route: '/landlord_payouts'),
          DashboardNavItem(icon: LucideIcons.settings, label: 'Settings', route: '/settings'),
        ];
        break;

      case 'manager':
        if (_isAgency) {
          title = 'Agency';
          content = const AgencyHome();
          nav = [
            DashboardNavItem(icon: LucideIcons.layoutDashboard, label: 'Overview', route: '/dashboard'),
            DashboardNavItem(icon: LucideIcons.building2, label: 'Properties', route: '/manager_properties'),
            DashboardNavItem(icon: LucideIcons.users, label: 'Agents', route: '/agency_agents'),
            DashboardNavItem(icon: LucideIcons.wrench, label: 'Maintenance', route: '/manager_maintenance_inbox'),
            DashboardNavItem(icon: LucideIcons.settings, label: 'Settings', route: '/settings'),
          ];
        } else {
          title = 'Manager';
          content = const ManagerHome();
          nav = [
            DashboardNavItem(icon: LucideIcons.layoutDashboard, label: 'Overview', route: '/dashboard'),
            DashboardNavItem(icon: LucideIcons.building2, label: 'Properties', route: '/manager_properties'),
            DashboardNavItem(icon: LucideIcons.wrench, label: 'Maintenance', route: '/manager_maintenance_inbox'),
            DashboardNavItem(icon: LucideIcons.settings, label: 'Settings', route: '/settings'),
          ];
        }
        break;

      case 'admin':
        title = 'Admin';
        content = const Center(child: Text('Admin dashboard coming soon'));
        nav = [
          DashboardNavItem(icon: LucideIcons.layoutDashboard, label: 'Overview', route: '/dashboard'),
          DashboardNavItem(icon: LucideIcons.settings, label: 'Settings', route: '/settings'),
        ];
        break;

      case 'tenant':
        title = 'Tenant';
        content = const Center(child: Text('Tenant dashboard coming soon'));
        nav = [
          DashboardNavItem(icon: LucideIcons.layoutDashboard, label: 'Overview', route: '/dashboard'),
          DashboardNavItem(icon: LucideIcons.settings, label: 'Settings', route: '/settings'),
        ];
        break;

      default:
        title = 'Dashboard';
        content = const Center(child: CircularProgressIndicator());
        nav = [
          DashboardNavItem(icon: LucideIcons.layoutDashboard, label: 'Overview', route: '/dashboard'),
        ];
    }

    final routeName = ModalRoute.of(context)?.settings.name ?? currentRoute;

    return BaseDashboard(
      title: title,
      body: content,
      navItems: nav,
      currentRoute: routeName,
    );
  }
}
