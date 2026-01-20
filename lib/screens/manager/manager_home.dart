// ignore_for_file: avoid_print, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/utils/token_manager.dart';
import 'package:property_manager_frontend/services/manager_service.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  int? _staffId;     // manager_user_id (staff)
  int? _managerId;   // manager_id (org)

  String _orgName = '—';       // manager_name
  String _staffName = '—';     // display_name
  String _staffPhone = '';
  String _managerType = 'individual';

  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await TokenManager.currentUserId(); // staff id after agency upgrade
    final role = await TokenManager.currentRole();
    print('🔐 manager home init => id=$id role=$role');

    if (!mounted) return;

    if (id == null || role != 'manager') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid session. Please log in again.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    // Save staff id (what you already store as userId)
    setState(() => _staffId = id);

    await _loadManagerMe();
  }

  Future<void> _loadManagerMe() async {
    try {
      setState(() => _loadingProfile = true);

      final me = await ManagerService.getMe();

      final orgName = (me['manager_name'] ?? '').toString().trim();
      final staffName = (me['display_name'] ?? '').toString().trim();
      final staffPhone = (me['staff_phone'] ?? '').toString().trim();
      final mType = (me['manager_type'] ?? 'individual').toString().trim();

      final staffId = (me['manager_user_id'] is num) ? (me['manager_user_id'] as num).toInt() : _staffId;
      final managerId = (me['manager_id'] is num) ? (me['manager_id'] as num).toInt() : null;

      if (!mounted) return;
      setState(() {
        _orgName = orgName.isEmpty ? '—' : orgName;
        _staffName = staffName.isEmpty ? '—' : staffName;
        _staffPhone = staffPhone;
        _managerType = mType.isEmpty ? 'individual' : mType;

        _staffId = staffId;
        _managerId = managerId;
      });

      // OPTIONAL (but recommended):
      // If you upgraded TokenManager to store managerId,
      // you can persist it here after /me resolves.
      //
      // await TokenManager.saveSession(
      //   token: (await TokenManager.loadSession())!.token,
      //   role: 'manager',
      //   userId: _staffId!,
      //   managerId: _managerId,
      // );

    } catch (e) {
      print('💥 manager /me load failed: $e');
      if (!mounted) return;
      setState(() {
        _orgName = '—';
        _staffName = '—';
        _staffPhone = '';
        _managerType = 'individual';
        _managerId = null;
      });
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    // headline: agency => org name; individual => "Welcome, {org name}"
    final headline = _loadingProfile
        ? 'Welcome'
        : (_managerType == 'agency'
            ? _orgName
            : (_orgName == '—' ? 'Welcome, Manager' : 'Welcome, $_orgName'));

    final subtitle = _loadingProfile
        ? 'Loading profile…'
        : '${_staffName == '—' ? 'Staff' : _staffName}'
          '${_staffPhone.trim().isEmpty ? '' : ' • $_staffPhone'}'
          ' • Staff ID: ${_staffId ?? "—"}'
          '${_managerId == null ? '' : ' • Org ID: $_managerId'}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                  child: Icon(
                    _managerType == 'agency' ? LucideIcons.building2 : LucideIcons.userCog,
                    color: t.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh profile',
                  onPressed: _loadManagerMe,
                  icon: const Icon(LucideIcons.refreshCcw, size: 18),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.info, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Navigation',
                      style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Use the side menu to move between:\n'
                  '• Properties (units, tenants, payments)\n'
                  '• Maintenance Inbox\n'
                  '• Settings',
                  style: t.textTheme.bodySmall?.copyWith(color: t.hintColor, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
