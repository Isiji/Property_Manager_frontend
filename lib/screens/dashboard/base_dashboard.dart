// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class DashboardNavItem {
  final String key; // e.g. 'overview', 'properties'
  final IconData icon;
  final String label;

  const DashboardNavItem({
    required this.key,
    required this.icon,
    required this.label,
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

  /// Side nav control
  final List<DashboardNavItem> navItems;
  final String selectedNavKey;
  final ValueChanged<String> onSelectNav;

  /// Optional: show a copyable property code chip in the AppBar row.
  final String? propertyCode;

  /// Optional: show units count chip in the AppBar row.
  final int? unitsCount;

  const BaseDashboard({
    super.key,
    required this.title,
    required this.body,
    required this.navItems,
    required this.selectedNavKey,
    required this.onSelectNav,
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

  void _selectNav(String key, {required bool isWide}) {
    widget.onSelectNav(key);
    if (!isWide) {
      // close drawer after selection on small screens
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800.0;
        final sideWidth = _collapsed ? 72.0 : 248.0;

        // Common AppBar actions
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

        // Title row with optional pills
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

        final sideNav = _SideNav(
          collapsed: _collapsed,
          items: widget.navItems,
          selectedKey: widget.selectedNavKey,
          onSelect: (k) => _selectNav(k, isWide: isWide),
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
                  child: sideNav,
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
            actions: actions.where((w) => w is! IconButton || (w as IconButton).tooltip != 'Expand menu').toList(),
          ),
          drawer: Drawer(
            child: SafeArea(child: _SideNav(collapsed: false, items: widget.navItems, selectedKey: widget.selectedNavKey, onSelect: (k) => _selectNav(k, isWide: isWide))),
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

class _SideNav extends StatelessWidget {
  final bool collapsed;
  final List<DashboardNavItem> items;
  final String selectedKey;
  final ValueChanged<String> onSelect;

  const _SideNav({
    required this.collapsed,
    required this.items,
    required this.selectedKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const SizedBox(height: 8),
        ...items.map((e) => _SideTile(
              icon: e.icon,
              label: e.label,
              collapsed: collapsed,
              selected: e.key == selectedKey,
              onTap: () => onSelect(e.key),
            )),
      ],
    );
  }
}

class _SideTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  const _SideTile({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary.withOpacity(.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colorScheme.primary.withOpacity(.25) : theme.dividerColor.withOpacity(.10),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? theme.colorScheme.primary : theme.hintColor),
            if (!collapsed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
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

/// Small informative pill "Label: Value"
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

/// Copyable pill for property code
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
