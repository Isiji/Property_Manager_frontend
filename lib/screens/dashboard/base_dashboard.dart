// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class BaseDashboard extends StatefulWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;

  const BaseDashboard({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
  });

  @override
  State<BaseDashboard> createState() => _BaseDashboardState();
}

class _BaseDashboardState extends State<BaseDashboard> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sideWidth = _collapsed ? 72.0 : 248.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: _collapsed ? 'Expand menu' : 'Collapse menu',
            icon: Icon(_collapsed ? LucideIcons.panelRightOpen : LucideIcons.panelLeftClose),
            onPressed: () => setState(() => _collapsed = !_collapsed),
          ),
        ],
      ),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: sideWidth,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                right: BorderSide(color: theme.dividerColor.withValues(alpha: .3)),
              ),
            ),
            child: _SideNav(collapsed: _collapsed),
          ),
          Expanded(
            child: Container(
              color: theme.colorScheme.surfaceContainerLowest,
              child: widget.body,
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}

class _SideNav extends StatelessWidget {
  final bool collapsed;
  const _SideNav({required this.collapsed});

  @override
  Widget build(BuildContext context) {
    final entries = <_NavItem>[
      _NavItem(
        icon: LucideIcons.layoutDashboard,
        label: 'Overview',
        onTap: () {
          // stays on dashboard
          Navigator.pushReplacementNamed(context, '/dashboard');
        },
      ),
      _NavItem(
        icon: LucideIcons.building2,
        label: 'Properties',
        onTap: () {
          // landlord overview already shows properties; keep route here for future sections
          Navigator.pushReplacementNamed(context, '/dashboard');
        },
      ),
      _NavItem(
        icon: LucideIcons.settings,
        label: 'Settings',
        onTap: () => Navigator.pushNamed(context, '/settings'),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const SizedBox(height: 8),
        ...entries.map((e) => _SideTile(item: e, collapsed: collapsed)),
      ],
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _NavItem({required this.icon, required this.label, required this.onTap});
}

class _SideTile extends StatelessWidget {
  final _NavItem item;
  final bool collapsed;
  const _SideTile({required this.item, required this.collapsed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: theme.colorScheme.primary),
            if (!collapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
