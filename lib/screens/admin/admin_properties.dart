// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';
import 'package:property_manager_frontend/services/landlord_service.dart';
import 'package:property_manager_frontend/services/manager_service.dart';

class AdminPropertiesScreen extends StatefulWidget {
  const AdminPropertiesScreen({super.key});

  @override
  State<AdminPropertiesScreen> createState() => _AdminPropertiesScreenState();
}

class _AdminPropertiesScreenState extends State<AdminPropertiesScreen> {
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _items = [];

  // ✅ simple in-memory caches to avoid repeated requests
  final Map<int, Map<String, dynamic>> _landlordCache = {};
  final Map<int, Map<String, dynamic>> _managerCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Future<void> _copy(String text, {String msg = 'Copied'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final headers = await TokenManager.authHeaders();
      // ✅ your backend already supports listing all properties at /properties (admin sees all).
      final url = Uri.parse('${AppConfig.apiBaseUrl}/properties');

      final res = await http.get(url, headers: {
        'Content-Type': 'application/json',
        ...headers,
        'ngrok-skip-browser-warning': 'true',
      });

      if (res.statusCode != 200) {
        throw Exception('Failed to load properties: ${res.statusCode} ${res.body}');
      }

      final decoded = jsonDecode(res.body);
      final List<Map<String, dynamic>> items = (decoded as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) return;
      setState(() => _items = items);

      // ✅ background enrich (landlord + manager names) with caching
      await _enrichBatch(items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _enrichBatch(List<Map<String, dynamic>> items) async {
    // Gather unique ids
    final landlordIds = <int>{};
    final managerIds = <int>{};

    for (final p in items) {
      final lid = (p['landlord_id'] as num?)?.toInt();
      final mid = (p['manager_id'] as num?)?.toInt();

      if (lid != null && lid > 0 && !_landlordCache.containsKey(lid)) landlordIds.add(lid);
      if (mid != null && mid > 0 && !_managerCache.containsKey(mid)) managerIds.add(mid);
    }

    // Fetch in small parallel batches (avoid blasting server)
    Future<void> fetchLandlords() async {
      final ids = landlordIds.toList();
      const chunk = 8;
      for (var i = 0; i < ids.length; i += chunk) {
        final slice = ids.sublist(i, (i + chunk > ids.length) ? ids.length : i + chunk);
        await Future.wait(slice.map((id) async {
          try {
            final m = await LandlordService.getLandlord(id);
            _landlordCache[id] = m;
          } catch (e) {
            _landlordCache[id] = {'id': id, 'name': 'Landlord #$id'};
          }
        }));
        if (!mounted) return;
        setState(() {}); // repaint as we enrich
      }
    }

    Future<void> fetchManagers() async {
      final ids = managerIds.toList();
      const chunk = 8;
      for (var i = 0; i < ids.length; i += chunk) {
        final slice = ids.sublist(i, (i + chunk > ids.length) ? ids.length : i + chunk);
        await Future.wait(slice.map((id) async {
          try {
            final m = await ManagerService.getManager(id);
            _managerCache[id] = m;
          } catch (e) {
            _managerCache[id] = {'id': id, 'name': 'Manager #$id'};
          }
        }));
        if (!mounted) return;
        setState(() {});
      }
    }

    await Future.wait([fetchLandlords(), fetchManagers()]);
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _items;

    return _items.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final code = (p['property_code'] ?? '').toString().toLowerCase();
      final address = (p['address'] ?? '').toString().toLowerCase();

      final landlordId = (p['landlord_id'] as num?)?.toInt();
      final managerId = (p['manager_id'] as num?)?.toInt();

      final landlordName = landlordId == null ? '' : (_landlordCache[landlordId]?['name'] ?? '').toString().toLowerCase();
      final managerName = managerId == null ? '' : _displayManagerName(_managerCache[managerId]).toLowerCase();

      return name.contains(q) ||
          code.contains(q) ||
          address.contains(q) ||
          landlordName.contains(q) ||
          managerName.contains(q);
    }).toList();
  }

  String _displayManagerName(Map<String, dynamic>? m) {
    if (m == null) return '';
    final type = (m['type'] ?? '').toString().toLowerCase();
    if (type == 'agency') {
      final company = (m['company_name'] ?? '').toString().trim();
      if (company.isNotEmpty) return company;
    }
    return (m['name'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _goBack,
        ),
        title: const Text('Admin • Properties'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(LucideIcons.refreshCw),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: "Search (name / code / address / landlord / manager)",
                prefixIcon: Icon(LucideIcons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Text(
                    _error!,
                    style: TextStyle(color: t.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_filtered.isEmpty)
              const Expanded(child: Center(child: Text('No properties found')))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = _filtered[i];

                    final id = (p['id'] as num?)?.toInt() ?? 0;
                    final name = (p['name'] ?? '-').toString();
                    final code = (p['property_code'] ?? '-').toString();
                    final address = (p['address'] ?? '-').toString();

                    final landlordId = (p['landlord_id'] as num?)?.toInt();
                    final managerId = (p['manager_id'] as num?)?.toInt();

                    final landlord = (landlordId == null) ? null : _landlordCache[landlordId];
                    final landlordName = (landlord?['name'] ?? '').toString();

                    final manager = (managerId == null) ? null : _managerCache[managerId];
                    final managerName = _displayManagerName(manager);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: t.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: t.dividerColor.withOpacity(.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: t.colorScheme.primary.withOpacity(.10),
                            ),
                            child: Icon(LucideIcons.building2, color: t.colorScheme.primary),
                          ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 6),

                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _copyPill(
                                      context,
                                      label: 'Code',
                                      value: code,
                                      icon: LucideIcons.qrCode,
                                      onCopy: () => _copy(code, msg: 'Property code copied'),
                                    ),
                                    _pill(
                                      context,
                                      label: 'Property ID',
                                      value: id == 0 ? '-' : '$id',
                                      icon: LucideIcons.hash,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),
                                Text(address, style: t.textTheme.bodySmall),

                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _infoBlock(
                                      context,
                                      title: 'Landlord',
                                      value: landlordId == null
                                          ? '-'
                                          : '${landlordName.isEmpty ? 'Landlord' : landlordName} • ID $landlordId',
                                      onCopy: landlordId == null
                                          ? null
                                          : () => _copy('$landlordId', msg: 'Landlord ID copied'),
                                      icon: LucideIcons.user,
                                    ),
                                    _infoBlock(
                                      context,
                                      title: 'Manager',
                                      value: managerId == null
                                          ? 'Not assigned'
                                          : '${managerName.isEmpty ? 'Manager' : managerName} • ID $managerId',
                                      onCopy: managerId == null
                                          ? null
                                          : () => _copy('$managerId', msg: 'Manager ID copied'),
                                      icon: LucideIcons.building,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Open property units',
                            icon: const Icon(Icons.chevron_right),
                            onPressed: id == 0
                                ? null
                                : () {
                                    Navigator.pushNamed(
                                      context,
                                      '/landlord_property_units',
                                      arguments: {'propertyId': id},
                                    );
                                  },
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, {required String label, required String value, required IconData icon}) {
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
          const SizedBox(width: 6),
          Text(
            value,
            style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _copyPill(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onCopy,
  }) {
    final t = Theme.of(context);
    return InkWell(
      onTap: value.trim().isEmpty || value == '-' ? null : onCopy,
      borderRadius: BorderRadius.circular(999),
      child: Container(
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
            const SizedBox(width: 6),
            Text(
              value,
              style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.copy_rounded, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoBlock(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onCopy,
  }) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.dividerColor.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: t.hintColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.textTheme.labelSmall?.copyWith(color: t.hintColor)),
              const SizedBox(height: 2),
              Text(
                value,
                style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (onCopy != null) ...[
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(LucideIcons.copy, size: 18),
              onPressed: onCopy,
            ),
          ],
        ],
      ),
    );
  }
}