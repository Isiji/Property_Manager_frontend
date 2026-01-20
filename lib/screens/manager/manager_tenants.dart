// ignore_for_file: avoid_print, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/property_service.dart';

class ManagerTenantsScreen extends StatefulWidget {
  final int propertyId;
  final String? propertyCode;
  final String? propertyName;

  const ManagerTenantsScreen({
    super.key,
    required this.propertyId,
    this.propertyCode,
    this.propertyName,
  });

  @override
  State<ManagerTenantsScreen> createState() => _ManagerTenantsScreenState();
}

class _ManagerTenantsScreenState extends State<ManagerTenantsScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;

  String _search = '';
  bool _onlyOccupied = false;
  bool _onlyVacant = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _copy(String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final d = await PropertyService.getPropertyWithUnitsDetailed(widget.propertyId);
      if (!mounted) return;
      setState(() => _data = d);
    } catch (e) {
      print('💥 tenants load failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _units {
    final raw = _data?['units'];
    if (raw is! List) return [];
    return raw.map((e) => (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final title = (widget.propertyName?.trim().isNotEmpty ?? false)
        ? widget.propertyName!.trim()
        : (_data?['name']?.toString() ?? 'Property ${widget.propertyId}');

    final code = (widget.propertyCode?.trim().isNotEmpty ?? false)
        ? widget.propertyCode!.trim()
        : (_data?['property_code']?.toString() ?? '');

    final landlord = _data?['landlord'];
    final landlordName = (landlord is Map) ? (landlord['name']?.toString() ?? '') : '';
    final totalUnits = _data?['total_units']?.toString() ?? '';

    var list = _units;

    if (_onlyOccupied && !_onlyVacant) {
      list = list.where((u) => (u['status']?.toString() ?? '') == 'occupied').toList();
    }
    if (_onlyVacant && !_onlyOccupied) {
      list = list.where((u) => (u['status']?.toString() ?? '') == 'vacant').toList();
    }

    if (_search.trim().isNotEmpty) {
      final s = _search.toLowerCase();
      list = list.where((u) {
        final numStr = (u['number'] ?? '').toString().toLowerCase();
        final status = (u['status'] ?? '').toString().toLowerCase();
        final tenant = u['tenant'];
        final tenantName = (tenant is Map) ? (tenant['name'] ?? '').toString().toLowerCase() : '';
        final tenantPhone = (tenant is Map) ? (tenant['phone'] ?? '').toString().toLowerCase() : '';
        return numStr.contains(s) || status.contains(s) || tenantName.contains(s) || tenantPhone.contains(s);
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Tenants • $title'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(LucideIcons.refreshCcw),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (code.isNotEmpty)
                        _copyChip(
                          t,
                          icon: LucideIcons.qrCode,
                          label: 'Code: $code',
                          onCopy: () => _copy('Property code', code),
                        ),
                      if (totalUnits.isNotEmpty) _chip(t, icon: LucideIcons.building2, label: 'Units: $totalUnits'),
                      if (landlordName.trim().isNotEmpty) _chip(t, icon: LucideIcons.user, label: 'Landlord: $landlordName'),
                    ],
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      FilterChip(
                        label: const Text('Occupied'),
                        selected: _onlyOccupied,
                        onSelected: (v) => setState(() {
                          _onlyOccupied = v;
                          if (v) _onlyVacant = false;
                        }),
                      ),
                      FilterChip(
                        label: const Text('Vacant'),
                        selected: _onlyVacant,
                        onSelected: (v) => setState(() {
                          _onlyVacant = v;
                          if (v) _onlyOccupied = false;
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                  Text('No units/tenants found.', style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor)),
                ],
              ),
            )
          else
            ...list.map((u) {
              final unitNo = (u['number'] ?? '—').toString();
              final status = (u['status'] ?? '—').toString();
              final rent = u['rent_amount']?.toString();
              final tenant = u['tenant'];
              final tenantName = (tenant is Map) ? (tenant['name'] ?? '—').toString() : '—';
              final tenantPhone = (tenant is Map) ? (tenant['phone'] ?? '—').toString() : '—';
              final lease = u['lease'];
              final leaseActive = (lease is Map) ? (lease['active']?.toString() ?? '0') : '0';

              final occupied = status == 'occupied';

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
                              color: occupied ? Colors.green.withOpacity(.12) : Colors.orange.withOpacity(.12),
                            ),
                            child: Icon(
                              occupied ? LucideIcons.userCheck : LucideIcons.home,
                              color: occupied ? Colors.green : Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Unit: $unitNo', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text(
                                  occupied ? 'Occupied • Lease active=$leaseActive' : 'Vacant',
                                  style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                                ),
                              ],
                            ),
                          ),
                          if (rent != null && rent != 'null')
                            _chip(t, icon: LucideIcons.coins, label: 'Rent: $rent'),
                        ],
                      ),
                      if (occupied) ...[
                        const SizedBox(height: 10),
                        _chip(t, icon: LucideIcons.user, label: 'Tenant: $tenantName'),
                        const SizedBox(height: 8),
                        _copyChip(
                          t,
                          icon: LucideIcons.phone,
                          label: 'Phone: $tenantPhone',
                          onCopy: tenantPhone == '—' ? null : () => _copy('Tenant phone', tenantPhone),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _chip(ThemeData t, {required IconData icon, required String label}) {
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

  Widget _copyChip(ThemeData t, {required IconData icon, required String label, required VoidCallback? onCopy}) {
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
          const SizedBox(width: 6),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(Icons.copy_rounded, size: 16, color: onCopy == null ? t.disabledColor : null),
            ),
          ),
        ],
      ),
    );
  }
}
