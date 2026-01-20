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
  int? _managerId;

  String _managerName = '—';
  String _managerPhone = '';
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await TokenManager.currentUserId();
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

    setState(() => _managerId = id);
    await _loadManagerProfile();
  }

  Future<void> _loadManagerProfile() async {
    if (_managerId == null) return;
    try {
      setState(() => _loadingProfile = true);

      final m = await ManagerService.getManager(_managerId!);
      final name = (m['name'] ?? '').toString().trim();
      final phone = (m['phone'] ?? '').toString().trim();

      if (!mounted) return;
      setState(() {
        _managerName = name.isEmpty ? '—' : name;
        _managerPhone = phone;
      });
    } catch (e) {
      print('💥 manager profile load failed: $e');
      if (!mounted) return;
      setState(() {
        _managerName = '—';
        _managerPhone = '';
      });
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final subtitle = _loadingProfile
        ? 'Loading profile…'
        : (_managerPhone.trim().isEmpty
            ? 'ID: ${_managerId ?? "—"}'
            : '$_managerPhone • ID: ${_managerId ?? "—"}');

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
                  child: Icon(LucideIcons.userCog, color: t.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _managerName == '—' ? 'Welcome, Manager' : 'Welcome, $_managerName',
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
                  onPressed: _loadManagerProfile,
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
