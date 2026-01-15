// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class BaseDashboard extends StatefulWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;

  final String? propertyCode;
  final int? unitsCount;

  const BaseDashboard({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.propertyCode,
    this.unitsCount,
  });

  @override
  State<BaseDashboard> createState() => _BaseDashboardState();
}

class _BaseDashboardState extends State<BaseDashboard> {
  bool _collapsed = false;

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await TokenManager.clearSession();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out: $e')),
      );
    }
  }

  Future<void> _copyPropertyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Property code copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800.0;
        final sideWidth = _collapsed ? 72.0 : 248.0;

        final actions = <Widget>[
          if (isWide)
            IconButton(
              tooltip: _collapsed ? 'Expand menu' : 'Collapse menu',
              icon: Icon(_collapsed ? LucideIcons.panelRightOpen : LucideIcons.panelLeftClose),
              onPressed: () => setState(() => _collapsed = !_collapsed),
            ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(LucideIcons.logOut),
            onPressed: () => _logout(context),
          ),
          const SizedBox(width: 8),
        ];

        final titleRow = LayoutBuilder(
          builder: (ctx, c) {
            final narrowTitle = c.maxWidth < 420;
            final pills = <Widget>[
              if (widget.propertyCode != null)
                _CopyablePill(
                  icon: LucideIcons.qrCode,
                  label: 'Code',
                  value: widget.propertyCode!,
                  onCopy: () => _copyPropertyCode(widget.propertyCode!),
                ),
              if (widget.unitsCount != null)
                _InfoPill(
                  icon: LucideIcons.building2,
                  label: 'Units',
                  value: '${widget.unitsCount}',
                ),
            ];

            final title = Text(widget.title, overflow: TextOverflow.ellipsis);

            if (pills.isEmpty) return title;

            if (narrowTitle) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: pills),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 8),
                Wrap(spacing: 8, runSpacing: 8, children: pills),
              ],
            );
          },
        );

        if (isWide) {
          return Scaffold(
            appBar: AppBar(title: titleRow, actions: actions),
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
                    child: SafeArea(top: false, child: widget.body),
                  ),
                ),
              ],
            ),
            floatingActionButton: widget.floatingActionButton,
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: titleRow,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(LucideIcons.menu),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            actions: actions,
          ),
          drawer: Drawer(
            child: SafeArea(child: _SideNav(collapsed: false)),
          ),
          body: Container(
            color: theme.colorScheme.surfaceContainerLowest,
            child: SafeArea(top: false, child: widget.body),
          ),
          floatingActionButton: widget.floatingActionButton,
        );
      },
    );
  }
}

class _SideNav extends StatefulWidget {
  final bool collapsed;
  const _SideNav({required this.collapsed});

  @override
  State<_SideNav> createState() => _SideNavState();
}

class _SideNavState extends State<_SideNav> {
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final r = await TokenManager.currentRole();
    if (!mounted) return;
    setState(() => _role = r);
  }

  @override
  Widget build(BuildContext context) {
    final role = _role;

    // Default while loading role
    if (role == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final entries = <_NavItem>[
      _NavItem(
        icon: LucideIcons.layoutDashboard,
        label: 'Overview',
        onTap: () => Navigator.pushReplacementNamed(context, '/dashboard'),
      ),

      // Manager nav
      if (role == 'manager') ...[
        _NavItem(
          icon: LucideIcons.building2,
          label: 'Properties',
          onTap: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
        _NavItem(
          icon: LucideIcons.grid,
          label: 'Units',
          onTap: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
        _NavItem(
          icon: LucideIcons.wrench,
          label: 'Maintenance',
          onTap: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
      ],

      // Landlord nav (you can adjust later)
      if (role == 'landlord') ...[
        _NavItem(
          icon: LucideIcons.building2,
          label: 'Properties',
          onTap: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
      ],

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
        ...entries.map((e) => _SideTile(item: e, collapsed: widget.collapsed)),
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoPill({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.dividerColor.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: t.hintColor),
          const SizedBox(width: 6),
          Text('$label:', style: t.textTheme.labelMedium),
          const SizedBox(width: 4),
          Text(
            value,
            style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CopyablePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _CopyablePill({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.dividerColor.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: t.hintColor),
          const SizedBox(width: 6),
          Text('$label:', style: t.textTheme.labelMedium),
          const SizedBox(width: 4),
          Text(
            value,
            style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.copy_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
