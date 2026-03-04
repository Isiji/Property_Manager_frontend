// lib/screens/admin/admin_maintenance.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/admin_maintenance_service.dart';

class AdminMaintenanceScreen extends StatefulWidget {
  const AdminMaintenanceScreen({super.key});

  @override
  State<AdminMaintenanceScreen> createState() => _AdminMaintenanceScreenState();
}

class _AdminMaintenanceScreenState extends State<AdminMaintenanceScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _statuses = [];

  String _q = '';
  int? _statusId; // filter
  bool _onlyOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final statuses = await AdminMaintenanceService.listStatuses();
      final rows = await AdminMaintenanceService.listAllRequests();

      if (!mounted) return;
      setState(() {
        _statuses = statuses;
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _statusNameById(int? id) {
    if (id == null) return '';
    final m = _statuses.firstWhere(
      (s) => (s['id'] as num?)?.toInt() == id,
      orElse: () => {},
    );
    return (m['name'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final filtered = _rows.where((r) {
      final desc = (r['description'] ?? '').toString().toLowerCase();
      final unit = (r['unit_id'] ?? '').toString().toLowerCase();
      final tenant = (r['tenant_id'] ?? '').toString().toLowerCase();
      final statusId = (r['status_id'] as num?)?.toInt();

      if (_onlyOpen) {
        // heuristic: status name contains "open"
        final sName = _statusNameById(statusId).toLowerCase();
        if (!sName.contains('open')) return false;
      }

      if (_statusId != null && statusId != _statusId) return false;

      if (_q.trim().isEmpty) return true;
      final q = _q.trim().toLowerCase();
      return desc.contains(q) || unit.contains(q) || tenant.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _goBack,
        ),
        title: const Text('Admin • Maintenance'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _load,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.alertTriangle),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(LucideIcons.search),
                          labelText: 'Search (description / tenant / unit)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _q = v),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              value: _statusId,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(LucideIcons.flag),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('All statuses'),
                                ),
                                ..._statuses.map((s) {
                                  final id = (s['id'] as num?)?.toInt();
                                  final name = (s['name'] ?? '').toString();
                                  return DropdownMenuItem<int?>(
                                    value: id,
                                    child: Text(name.isEmpty ? 'Status $id' : name),
                                  );
                                }),
                              ],
                              onChanged: (v) => setState(() => _statusId = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilterChip(
                            selected: _onlyOpen,
                            label: const Text('Open only'),
                            onSelected: (v) => setState(() => _onlyOpen = v),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      Text('${filtered.length} requests', style: t.textTheme.labelLarge),
                      const SizedBox(height: 8),

                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(LucideIcons.wrench, size: 40, color: t.hintColor),
                              const SizedBox(height: 8),
                              const Text('No maintenance requests match your filter'),
                            ],
                          ),
                        )
                      else
                        ...filtered.map((r) {
                          final id = (r['id'] as num?)?.toInt() ?? 0;
                          final tenantId = (r['tenant_id'] as num?)?.toInt() ?? 0;
                          final unitId = (r['unit_id'] as num?)?.toInt() ?? 0;
                          final statusId = (r['status_id'] as num?)?.toInt();
                          final desc = (r['description'] ?? '').toString();
                          final created = (r['created_at'] ?? '').toString();

                          final sName = _statusNameById(statusId);
                          final subtitle = 'Tenant: $tenantId • Unit: $unitId • ${sName.isEmpty ? 'status_id=$statusId' : sName}';

                          return Card(
                            child: ListTile(
                              leading: const Icon(LucideIcons.wrench),
                              title: Text(
                                desc.isEmpty ? '(No description)' : desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 6),
                                  Text(
                                    created,
                                    style: t.textTheme.labelSmall?.copyWith(color: t.hintColor),
                                  ),
                                ],
                              ),
                              trailing: id == 0
                                  ? null
                                  : IconButton(
                                      tooltip: 'Open details (stub)',
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Open request #$id (details UI next)')),
                                        );
                                      },
                                    ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}