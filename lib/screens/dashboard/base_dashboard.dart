// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class DashboardNavItem {
  final IconData icon;
  final String label;
  final String route;
  final Object? arguments;

  DashboardNavItem({
    required this.icon,
    required this.label,
    required this.route,
    this.arguments,
  });
}

/// A responsive dashboard shell:
/// - ≥800px: left sidebar (collapsible) + content.
/// - <800px: hamburger Drawer + full-width content.
/// Optional property pills: [propertyCode] (copyable) and [unitsCount].
class BaseDashboard extends StatefulWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;

  /// Optional: show a copyable property code chip in the AppBar row.
  final String? propertyCode;

  /// Optional: show units count chip in the AppBar row.
  final int? unitsCount;

  /// ✅ Provide navigation items (role-aware).
  final List<DashboardNavItem> navItems;

  /// ✅ For highlighting current item (route name).
  final String currentRoute;

  const BaseDashboard({
    super.key,
    required this.title,
    required this.body,
    required this.navItems,
    required this.currentRoute,
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

  void _go(DashboardNavItem item) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == item.route) return;

    Navigator.pushReplacementNamed(
      context,
      item.route,
      arguments: item.arguments,
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

        final side = _SideNav(
          collapsed: _collapsed,
          currentRoute: widget.currentRoute,
          items: widget.navItems,
          onTap: _go,
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
                      right: BorderSide(color: theme.dividerColor.withOpacity(.3)),
                    ),
                  ),
                  child: side,
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
          drawer: Drawer(child: SafeArea(child: _SideNav(collapsed: false, currentRoute: widget.currentRoute, items: widget.navItems, onTap: (i) {
            Navigator.pop(context);
            _go(i);
          }))),
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

class _SideNav extends StatelessWidget {
  final bool collapsed;
  final String currentRoute;
  final List<DashboardNavItem> items;
  final void Function(DashboardNavItem) onTap;

  const _SideNav({
    required this.collapsed,
    required this.currentRoute,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const SizedBox(height: 8),
        ...items.map((e) => _SideTile(item: e, collapsed: collapsed, selected: e.route == currentRoute, onTap: () => onTap(e))),
      ],
    );
  }
}

class _SideTile extends StatelessWidget {
  final DashboardNavItem item;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  const _SideTile({
    required this.item,
    required this.collapsed,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bg = selected ? theme.colorScheme.primary.withOpacity(.10) : Colors.transparent;
    final fg = selected ? theme.colorScheme.primary : theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: fg),
            if (!collapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  ),
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
        border: Border.all(color: t.dividerColor.withOpacity(.25)),
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
        border: Border.all(color: t.dividerColor.withOpacity(.25)),
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
