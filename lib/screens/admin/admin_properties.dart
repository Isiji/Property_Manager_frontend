// lib/screens/admin/admin_properties.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/admin_service.dart';

class AdminPropertiesScreen extends StatefulWidget {
  const AdminPropertiesScreen({super.key});

  @override
  State<AdminPropertiesScreen> createState() => _AdminPropertiesScreenState();
}

class _AdminPropertiesScreenState extends State<AdminPropertiesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await AdminService.getProperties(limit: 500);
      if (!mounted) return;
      setState(() {
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
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
      );
    }

    final filtered = _rows.where((r) {
      if (_q.trim().isEmpty) return true;
      final s = '${r['name'] ?? ''} ${r['property_code'] ?? ''} ${r['address'] ?? ''}'.toLowerCase();
      return s.contains(_q.trim().toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(LucideIcons.search),
              labelText: 'Search properties',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 12),
          Text('${filtered.length} properties', style: t.textTheme.labelLarge),
          const SizedBox(height: 8),

          ...filtered.map((r) {
            final pid = (r['id'] as num?)?.toInt() ?? 0;
            final name = (r['name'] ?? '').toString();
            final code = (r['property_code'] ?? '').toString();
            final units = (r['units'] as num?)?.toInt() ?? 0;
            final occ = (r['occupied_units'] as num?)?.toInt() ?? 0;

            return Card(
              child: ListTile(
                leading: const Icon(LucideIcons.building2),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('Code: $code • Units: $occ/$units'),
                trailing: const Icon(Icons.chevron_right),
                onTap: pid == 0
                    ? null
                    : () => Navigator.pushNamed(
                          context,
                          '/landlord_property_units',
                          arguments: {'propertyId': pid},
                        ),
              ),
            );
          }),
        ],
      ),
    );
  }
}