import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, String route) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.25)),
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
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: TokenManager.loadSession(),
      builder: (context, snapshot) {
        final role = snapshot.data?.role;

        return Material(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  'System Control Center',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Admin resolves disputes, audits activity, and manages all parties.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),

                if (role == 'super_admin') ...[
                  _tile(context, LucideIcons.shieldCheck, 'Admin Management',
                      'Create, activate, deactivate, and remove admins', '/super_admin_admins'),
                  const SizedBox(height: 10),
                ],

                _tile(context, LucideIcons.building2, 'Properties', 'View all properties in the system', '/admin_properties'),
                const SizedBox(height: 10),
                _tile(context, LucideIcons.users, 'Landlords', 'Manage landlords (support & issues)', '/admin_landlords'),
                const SizedBox(height: 10),
                _tile(context, LucideIcons.building, 'Managers/Agencies', 'Manage agencies and managers', '/admin_managers'),
                const SizedBox(height: 10),
                _tile(context, LucideIcons.wallet, 'Payouts', 'See all payouts and disputes', '/admin_payouts'),
                const SizedBox(height: 10),
                _tile(context, LucideIcons.scrollText, 'Audit Logs', 'Track actions across the system', '/admin_logs'),
              ],
            ),
          ),
        );
      },
    );
  }
}