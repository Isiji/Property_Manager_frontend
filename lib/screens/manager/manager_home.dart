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
        // Header
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
                      Text('Manager', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        _managerId == null ? 'Loading…' : 'Manager ID: $_managerId',
                        style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
                        maxLines: 1,
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

        // Quick actions
        _ActionCard(
          icon: LucideIcons.building2,
          title: 'My Properties',
          subtitle: 'View properties assigned to you',
          onTap: () => Navigator.pushNamed(context, '/manager_properties'),
        ),
        _ActionCard(
          icon: LucideIcons.wrench,
          title: 'Maintenance Inbox',
          subtitle: 'Requests from tenants & landlords',
          onTap: () => Navigator.pushNamed(context, '/manager_maintenance_inbox'),
        ),
        _ActionCard(
          icon: LucideIcons.wallet,
          title: 'Payments',
          subtitle: 'Rent payments & reconciliations (coming next)',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payments screen coming next.')),
            );
          },
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.colorScheme.primary.withOpacity(.12),
                ),
                child: Icon(icon, color: t.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: t.textTheme.bodySmall?.copyWith(color: t.hintColor)),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight),
            ],
          ),
        ),
      ),
    );
  }
}
