// ignore_for_file: avoid_print, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:property_manager_frontend/services/property_service.dart';

class ManagerTenantsScreen extends StatefulWidget {
  final int propertyId;
  final String? propertyCode;

  const ManagerTenantsScreen({
    super.key,
    required this.propertyId,
    this.propertyCode,
  });

  @override
  State<ManagerTenantsScreen> createState() => _ManagerTenantsScreenState();
}

class _ManagerTenantsScreenState extends State<ManagerTenantsScreen> {
  bool _loading = true;
  Map<String, dynamic> _detail = {};
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final d = await PropertyService.getPropertyWithUnitsDetailed(widget.propertyId);
      if (!mounted) return;
      setState(() => _detail = d);
    } catch (e) {
      print('💥 tenants load failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load tenants: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _units {
    final raw = _detail['units'];
    if (raw is List) {
      return raw.map((e) {
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> get _filteredUnits {
    final s = _search.trim().toLowerCase();
    if (s.isEmpty) return _units;

    return _units.where((u) {
      final numStr = (u['number'] ?? u['unit_number'] ?? '').toString().toLowerCase();
      final tenantObj = u['tenant'];
      final tenantName = (tenantObj is Map ? tenantObj['name'] : u['tenant_name'] ?? '').toString().toLowerCase();
      final tenantPhone = (tenantObj is Map ? tenantObj['phone'] : u['tenant_phone'] ?? '').toString().toLowerCase();
      return numStr.contains(s) || tenantName.contains(s) || tenantPhone.contains(s);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final propName = (_detail['property'] is Map ? _detail['property']['name'] : _detail['name'])?.toString() ?? 'Property';
    final code = widget.propertyCode ?? (_detail['property_code']?.toString());
    final units = _filteredUnits;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tenants • $propName'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: _load,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    child: Icon(LucideIcons.users, color: t.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(propName, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(
                          'Property ID: ${widget.propertyId}${code == null ? '' : ' • Code: $code'}',
                          style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
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

          const SizedBox(height: 12),

          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search unit / tenant name / phone…',
              prefixIcon: const Icon(LucideIcons.search),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 14),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (units.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  const Icon(LucideIcons.folderOpen, size: 52, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(
                    'No units/tenants found.',
                    style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
                  ),
                ],
              ),
            )
          else
            ...units.map((u) {
              final unitNumber = (u['number'] ?? u['unit_number'] ?? '—').toString();

              final tenantObj = u['tenant'];
              final tenantName = (tenantObj is Map ? tenantObj['name'] : u['tenant_name'] ?? 'Not assigned').toString();
              final tenantPhone = (tenantObj is Map ? tenantObj['phone'] : u['tenant_phone'] ?? '').toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                        child: Center(
                          child: Text(
                            unitNumber.length > 4 ? unitNumber.substring(0, 4) : unitNumber,
                            style: t.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Unit $unitNumber', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              tenantPhone.trim().isEmpty ? tenantName : '$tenantName • $tenantPhone',
                              style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
