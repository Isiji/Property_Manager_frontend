import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:property_manager_frontend/services/auth_service.dart';

class SuperAdminHomeScreen extends StatelessWidget {
  const SuperAdminHomeScreen({super.key});

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String route,
  ) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.primary.withOpacity(.10),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await AuthService.logout();

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin • Control Center'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'Platform Governance',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage admins, inspect operations, and oversee the whole PropSmart universe without summoning auth chaos.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _tile(
              context,
              LucideIcons.shieldCheck,
              'Admin Management',
              'Create, activate, deactivate, and remove admins',
              '/super_admin_admins',
            ),
            const SizedBox(height: 10),
            _tile(
              context,
              LucideIcons.building2,
              'Properties',
              'View system-wide properties',
              '/admin_properties',
            ),
            const SizedBox(height: 10),
            _tile(
              context,
              LucideIcons.users,
              'Landlords',
              'View and support landlords',
              '/admin_landlords',
            ),
            const SizedBox(height: 10),
            _tile(
              context,
              LucideIcons.building,
              'Managers/Agencies',
              'View and support manager organizations',
              '/admin_managers',
            ),
            const SizedBox(height: 10),
            _tile(
              context,
              LucideIcons.wallet,
              'Finance & Payouts',
              'Review platform collections and payouts',
              '/admin_finance',
            ),
            const SizedBox(height: 10),
            _tile(
              context,
              LucideIcons.scrollText,
              'Audit Logs',
              'Inspect sensitive system activity',
              '/admin_logs',
            ),
            const SizedBox(height: 10),
            _tile(
              context,
              LucideIcons.wrench,
              'Maintenance',
              'Review maintenance activity',
              '/admin_maintenance',
            ),
          ],
        ),
      ),
    );
  }
}