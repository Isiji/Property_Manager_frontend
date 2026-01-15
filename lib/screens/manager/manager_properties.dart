// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:property_manager_frontend/services/property_service.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class ManagerPropertiesScreen extends StatefulWidget {
  const ManagerPropertiesScreen({super.key});

  @override
  State<ManagerPropertiesScreen> createState() => _ManagerPropertiesScreenState();
}

class _ManagerPropertiesScreenState extends State<ManagerPropertiesScreen> {
  bool _loading = true;
  int? _managerId;
  List<dynamic> _properties = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await TokenManager.currentUserId();
    final role = await TokenManager.currentRole();

    if (!mounted) return;

    if (id == null || role != 'manager') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid session. Please log in again.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    setState(() => _managerId = id);
    await _load();
  }

  Future<void> _load() async {
    if (_managerId == null) return;

    try {
      setState(() => _loading = true);
      final data = await PropertyService.getPropertiesByManager(_managerId!);
      if (!mounted) return;
      setState(() => _properties = data);
    } catch (e) {
      print('💥 manager properties load failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load properties: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    if (_search.trim().isEmpty) return _properties;
    final s = _search.toLowerCase();
    return _properties.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final addr = (p['address'] ?? '').toString().toLowerCase();
      final code = (p['property_code'] ?? '').toString().toLowerCase();
      return name.contains(s) || addr.contains(s) || code.contains(s);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final list = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Properties'),
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
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search properties…',
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
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  const Icon(LucideIcons.folderOpen, size: 52, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(
                    'No properties assigned to you yet.',
                    style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
                  ),
                ],
              ),
            )
          else
            ...list.map((raw) {
              final p = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
              final pid = (p['id'] as num?)?.toInt() ?? 0;
              final name = (p['name'] ?? '—').toString();
              final addr = (p['address'] ?? '—').toString();
              final code = (p['property_code'] ?? '—').toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: t.colorScheme.primary.withOpacity(.12),
                            ),
                            child: Icon(LucideIcons.building2, color: t.colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text(
                                  addr,
                                  style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip(icon: LucideIcons.qrCode, label: 'Code: $code'),
                          _Chip(icon: LucideIcons.hash, label: 'ID: $pid'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              // Reuse landlord units screen for now (same endpoint /with-units-detailed)
                              Navigator.pushNamed(
                                context,
                                '/landlord_property_units',
                                arguments: {'propertyId': pid},
                              );
                            },
                            icon: const Icon(LucideIcons.grid, size: 18),
                            label: const Text('Units'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tenants screen coming next.')),
                              );
                            },
                            icon: const Icon(LucideIcons.users, size: 18),
                            label: const Text('Tenants'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Maintenance screen coming next.')),
                              );
                            },
                            icon: const Icon(LucideIcons.wrench, size: 18),
                            label: const Text('Maintenance'),
                          ),
                        ],
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

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          Text(label, style: t.textTheme.labelMedium),
        ],
      ),
    );
  }
}
