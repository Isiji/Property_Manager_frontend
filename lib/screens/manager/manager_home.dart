// ignore_for_file: avoid_print, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  int? _managerId;

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
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

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
                        'Welcome, Manager',
                        style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _managerId == null ? 'Loading…' : 'Manager ID: $_managerId',
                        style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                      ),
                    ],
                  ),
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
                  '• Settings\n',
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
