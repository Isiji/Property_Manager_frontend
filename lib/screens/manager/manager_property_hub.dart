// ignore_for_file: avoid_print, use_build_context_synchronously
// lib/screens/manager/manager_property_hub.dart

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ManagerPropertyHubScreen extends StatelessWidget {
  final int propertyId;
  final String? propertyCode;

  const ManagerPropertyHubScreen({
    super.key,
    required this.propertyId,
    this.propertyCode,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Property Hub'),
      ),
      body: ListView(
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
                    child: Icon(LucideIcons.building2, color: t.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Property #$propertyId',
                          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${propertyCode ?? "—"}',
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

          _HubTile(
            icon: LucideIcons.grid,
            title: 'Units',
            subtitle: 'View units and their status',
            onTap: () => Navigator.pushNamed(
              context,
              '/landlord_property_units',
              arguments: {'propertyId': propertyId},
            ),
          ),
          _HubTile(
            icon: LucideIcons.users,
            title: 'Tenants',
            subtitle: 'Assigned tenants (coming next)',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tenants screen coming next.')),
              );
            },
          ),
          _HubTile(
            icon: LucideIcons.wrench,
            title: 'Maintenance',
            subtitle: 'Requests for this property',
            onTap: () => Navigator.pushNamed(context, '/manager_maintenance_inbox'),
          ),
          _HubTile(
            icon: LucideIcons.wallet,
            title: 'Payments',
            subtitle: 'Rent payments & receipts (coming next)',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payments screen coming next.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubTile({
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
