// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/manager_service.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AgencyDashboard extends StatefulWidget {
  const AgencyDashboard({super.key});

  @override
  State<AgencyDashboard> createState() => _AgencyDashboardState();
}

class _AgencyDashboardState extends State<AgencyDashboard> {
  bool _loading = true;

  String _agencyName = '—';
  String _staffName = '—';
  String _staffPhone = '';

  int? _staffId;
  int? _managerId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirm != true) return;

    await TokenManager.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _init() async {
    try {
      final role = await TokenManager.currentRole();
      final id = await TokenManager.currentUserId();

      if (!mounted) return;

      if (role != 'manager' || id == null) {
        await TokenManager.clearSession();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }

      _staffId = id;

      final me = await ManagerService.getMe();

      final managerType = (me['manager_type'] ?? 'individual').toString().toLowerCase();
      if (managerType != 'agency') {
        // not an agency? send to normal manager landing
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/manager_properties');
        return;
      }

      final agencyName = (me['manager_name'] ?? me['company_name'] ?? '').toString().trim();
      final staffName = (me['display_name'] ?? '').toString().trim();
      final staffPhone = (me['staff_phone'] ?? '').toString().trim();

      final managerId = (me['manager_id'] is num) ? (me['manager_id'] as num).toInt() : null;

      if (!mounted) return;
      setState(() {
        _agencyName = agencyName.isEmpty ? '—' : agencyName;
        _staffName = staffName.isEmpty ? '—' : staffName;
        _staffPhone = staffPhone;
        _managerId = managerId;
      });
    } catch (e) {
      print('💥 AgencyDashboard init failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(LucideIcons.chevronRight),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final subtitle = _loading
        ? 'Loading…'
        : '${_staffName == '—' ? 'Staff' : _staffName}'
            '${_staffPhone.trim().isEmpty ? '' : ' • $_staffPhone'}'
            ' • Staff ID: ${_staffId ?? "—"}'
            '${_managerId == null ? '' : ' • Org ID: $_managerId'}';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/dashboard');
            }
          },
        ),
        title: const Text('Agency • Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: _init,
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(LucideIcons.logOut),
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.colorScheme.primary.withOpacity(.12),
                    ),
                    child: Icon(LucideIcons.building2, color: t.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _agencyName == '—' ? 'Agency' : _agencyName,
                          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          _card(
            icon: LucideIcons.users,
            title: 'Agents / Staff',
            subtitle: 'Register staff, assign properties, track performance.',
            onTap: () => Navigator.pushNamed(context, '/agency_staff'),
          ),
          _card(
            icon: LucideIcons.building2,
            title: 'Properties',
            subtitle: 'All properties visible to your agency.',
            onTap: () => Navigator.pushNamed(context, '/manager_properties'),
          ),
          _card(
            icon: LucideIcons.wrench,
            title: 'Maintenance Inbox',
            subtitle: 'Requests across all assigned properties.',
            onTap: () => Navigator.pushNamed(context, '/manager_maintenance_inbox'),
          ),
          _card(
            icon: LucideIcons.fileBarChart2,
            title: 'Reports',
            subtitle: 'Collections, arrears, occupancy, agent dashboards.',
            onTap: () => Navigator.pushNamed(context, '/agency_reports'),
          ),
          _card(
            icon: LucideIcons.settings,
            title: 'Agency Settings',
            subtitle: 'Company profile, branding, staff roles.',
            onTap: () => Navigator.pushNamed(context, '/agency_settings'),
          ),
        ],
      ),
    );
  }
}
