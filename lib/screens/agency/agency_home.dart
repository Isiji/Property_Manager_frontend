import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AgencyHome extends StatelessWidget {
  const AgencyHome({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    Widget sectionTitle(String text) {
      return Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10, top: 6),
        child: Text(
          text,
          style: t.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: t.colorScheme.onSurface.withOpacity(.75),
          ),
        ),
      );
    }

    Widget actionCard({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
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
                      Text(
                        title,
                        style: t.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.hintColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.chevron_right_rounded, color: t.hintColor),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        // ===== Header / Hero =====
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.dividerColor.withOpacity(.18)),
            color: t.colorScheme.primary.withOpacity(.06),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.colorScheme.primary.withOpacity(.14),
                  ),
                  child: Icon(LucideIcons.building2, color: t.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agency Dashboard',
                        style: t.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Monitor agents, properties, maintenance, and collections.',
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.colorScheme.onSurface.withOpacity(.65),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),
        sectionTitle('Quick actions'),

        // ===== Cards =====
        actionCard(
          icon: LucideIcons.building2,
          title: 'Properties',
          subtitle: 'View all properties visible to the agency',
          onTap: () => Navigator.of(context).pushNamed('/manager_properties'),
        ),

        actionCard(
          icon: LucideIcons.users,
          title: 'Agents / Staff',
          subtitle: 'Add staff, assign work, and track performance',
          onTap: () {
            // ✅ This should navigate (make sure route exists in main.dart)
            Navigator.of(context).pushNamed('/agency_agents');
          },
        ),

        actionCard(
          icon: LucideIcons.wrench,
          title: 'Maintenance',
          subtitle: 'Track maintenance requests under the agency',
          onTap: () => Navigator.of(context).pushNamed('/manager_maintenance_inbox'),
        ),

        actionCard(
          icon: LucideIcons.wallet,
          title: 'Collections & Payments',
          subtitle: 'Agency-wide payment status and collections overview',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Agency payments overview coming next.')),
            );
          },
        ),
      ],
    );
  }
}
