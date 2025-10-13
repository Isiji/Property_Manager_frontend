import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';


class BaseDashboard extends StatefulWidget {
  const BaseDashboard({super.key});

  @override
  State<BaseDashboard> createState() => _BaseDashboardState();
}

class _BaseDashboardState extends State<BaseDashboard> {
  String role = '';
  int selectedIndex = 0;
  bool isCollapsed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['role'] != null) {
      role = args['role'].toString();
      debugPrint('[BaseDashboard] Role received via args: $role');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRoleIfMissing();
  }

  Future<void> _loadRoleIfMissing() async {
    if (role.isEmpty) {
      final s = await TokenManager.loadSession();
      if (s != null) {
        setState(() => role = s.role);
        debugPrint('[BaseDashboard] Role loaded from session: $role');
      } else {
        debugPrint('[BaseDashboard] No session found. Redirecting to login.');
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  List<_MenuItem> _menuForRole(String r) {
    debugPrint('[BaseDashboard] Building menu for $r');
    switch (r) {
      case 'landlord':
        return [
          _MenuItem('Overview', LucideIcons.home),
          _MenuItem('Properties', LucideIcons.building),
          _MenuItem('Units', LucideIcons.layers),
          _MenuItem('Tenants', LucideIcons.users),
          _MenuItem('Payments', LucideIcons.receipt),
          _MenuItem('Reports', LucideIcons.barChart3),
          _MenuItem('Notifications', LucideIcons.bell),
          _MenuItem('Settings', LucideIcons.settings),
        ];
      case 'property_manager':
      case 'manager':
        return [
          _MenuItem('Overview', LucideIcons.home),
          _MenuItem('Properties', LucideIcons.building),
          _MenuItem('Units', LucideIcons.layers),
          _MenuItem('Tenants', LucideIcons.users),
          _MenuItem('Payments', LucideIcons.receipt),
          _MenuItem('Maintenance', LucideIcons.wrench),
          _MenuItem('Reports', LucideIcons.barChart3),
          _MenuItem('Notifications', LucideIcons.bell),
          _MenuItem('Settings', LucideIcons.settings),
        ];
      case 'admin':
        return [
          _MenuItem('Overview', LucideIcons.home),
          _MenuItem('Users', LucideIcons.userCog),
          _MenuItem('Properties', LucideIcons.building),
          _MenuItem('Reports', LucideIcons.barChart3),
          _MenuItem('Settings', LucideIcons.settings),
        ];
      default:
        return [
          _MenuItem('My Home', LucideIcons.home),
          _MenuItem('Pay', LucideIcons.wallet),
          _MenuItem('History', LucideIcons.clock),
          _MenuItem('Maintenance', LucideIcons.wrench),
          _MenuItem('Notifications', LucideIcons.bell),
          _MenuItem('Settings', LucideIcons.settings),
        ];
    }
  }

  Widget _bodyFor(String r, int idx) {
    debugPrint('[BaseDashboard] Rendering body for $r index=$idx');
    return Center(
      child: Text(
        '$r → ${_menuForRole(r)[idx].label}',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }

  Future<void> _logout() async {
    debugPrint('[BaseDashboard] Logout pressed.');
    await TokenManager.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final menu = _menuForRole(role);
    final isWide = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (!isWide)
              IconButton(
                icon: const Icon(LucideIcons.menu),
                onPressed: () =>
                    setState(() => isCollapsed = !isCollapsed),
              ),
            const SizedBox(width: 8),
            Text('PropSmart — ${role.isEmpty ? "User" : role.toUpperCase()} Dashboard'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(LucideIcons.bell),
            onPressed: () {
              debugPrint('[BaseDashboard] Notifications clicked');
              setState(() => selectedIndex =
                  menu.indexWhere((m) => m.label == 'Notifications'));
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(LucideIcons.settings),
            onPressed: () {
              debugPrint('[BaseDashboard] Settings clicked');
              Navigator.of(context).pushNamed('/settings');
            },
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(LucideIcons.logOut, size: 18),
            label: const Text('Logout'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            _Sidebar(
              items: menu,
              selectedIndex: selectedIndex,
              collapsed: isCollapsed,
              onToggleCollapse: () =>
                  setState(() => isCollapsed = !isCollapsed),
              onTapIndex: (i) => setState(() => selectedIndex = i),
            ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              child: _bodyFor(role, selectedIndex),
            ),
          ),
        ],
      ),
      drawer: isWide
          ? null
          : Drawer(
              child: SafeArea(
                child: ListView.builder(
                  itemCount: menu.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return DrawerHeader(
                        child: Text('Hello, ${role.toUpperCase()}',
                            style: Theme.of(context).textTheme.titleLarge),
                      );
                    }
                    final idx = i - 1;
                    final item = menu[idx];
                    return ListTile(
                      leading: Icon(item.icon),
                      title: Text(item.label),
                      selected: selectedIndex == idx,
                      onTap: () {
                        debugPrint(
                            '[BaseDashboard] Drawer tap → ${item.label}');
                        setState(() => selectedIndex = idx);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<_MenuItem> items;
  final int selectedIndex;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<int> onTapIndex;

const _Sidebar({
  Key? key,
  required this.items,
  required this.selectedIndex,
  required this.collapsed,
  required this.onToggleCollapse,
  required this.onTapIndex,
}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final w = collapsed ? 70.0 : 240.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: w,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          IconButton(
            tooltip: collapsed ? 'Expand' : 'Collapse',
            icon: Icon(collapsed
                ? LucideIcons.panelRightOpen
                : LucideIcons.panelLeftOpen),
            onPressed: onToggleCollapse,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                final selected = i == selectedIndex;
                return InkWell(
                  onTap: () => onTapIndex(i),
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(item.icon,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).iconTheme.color),
                        if (!collapsed) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String label;
  final IconData icon;
  _MenuItem(this.label, this.icon);
}
