// ignore_for_file: use_build_context_synchronously, avoid_print
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/maintenance_service.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class LandlordMaintenanceInbox extends StatefulWidget {
  final bool forManager;
  const LandlordMaintenanceInbox({super.key, this.forManager = false});

  @override
  State<LandlordMaintenanceInbox> createState() => _LMState();
}

class _LMState extends State<LandlordMaintenanceInbox> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirm != true) return;

    await TokenManager.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await MaintenanceService.listMine();
      _items = list.map<Map<String, dynamic>>((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      _items = [];

      final msg = e.toString();
      if (msg.contains('401')) {
        await TokenManager.clearSession();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final title = widget.forManager ? 'Manager • Maintenance' : 'Landlord • Maintenance';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: _goBack,
        ),
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(LucideIcons.refreshCcw),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(LucideIcons.logOut),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No maintenance requests yet.',
                      style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = _items[i];
                    final unit = (m['unit_number'] ?? '—').toString();
                    final prop = (m['property_name'] ?? '').toString();
                    final desc = (m['description'] ?? '').toString();
                    final status = (m['status'] ?? '').toString();
                    final created = (m['created_at'] ?? '').toString();

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.build_rounded),
                        title: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '$prop • $unit\n$created',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          status.toUpperCase(),
                          style: t.textTheme.labelSmall,
                        ),
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            '/maintenance_detail',
                            arguments: {'id': m['id']},
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
