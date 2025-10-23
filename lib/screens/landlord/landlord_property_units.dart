// lib/screens/landlord/landlord_property_units.dart
// Property detail: shows property info & code, units list,
// add/edit/delete unit, Assign Tenant, and End Lease actions.

import 'package:flutter/material.dart';
import 'package:property_manager_frontend/services/property_service.dart';
import 'package:property_manager_frontend/services/unit_service.dart';
import 'package:property_manager_frontend/services/tenant_service.dart';
import 'package:property_manager_frontend/services/lease_service.dart';

class LandlordPropertyUnits extends StatefulWidget {
  final int propertyId;
  const LandlordPropertyUnits({Key? key, required this.propertyId}) : super(key: key);

  @override
  State<LandlordPropertyUnits> createState() => _LandlordPropertyUnitsState();
}

class _LandlordPropertyUnitsState extends State<LandlordPropertyUnits> {
  bool _loading = true;
  Map<String, dynamic>? _property; // id, name, address, property_code, totals
  List<dynamic> _units = [];

  @override
  void initState() {
    super.initState();
    _loadDetailed();
  }

  Future<void> _loadDetailed() async {
    try {
      debugPrint('➡️ [PropertyUnits] GET /properties/${widget.propertyId}/with-units-detailed');
      final detail = await PropertyService.getPropertyWithUnitsDetailed(widget.propertyId);
      debugPrint('⬅️ [PropertyUnits] OK -> ${detail['name']}');
      if (!mounted) return;
      setState(() {
        _property = detail;
        _units = (detail['units'] as List<dynamic>? ?? []);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[PropertyUnits] load error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load property details: $e')),
      );
    }
  }

  Future<void> _addUnit() async {
    final data = await showDialog<_UnitData>(
      context: context,
      builder: (_) => const _UnitDialog(),
    );
    if (data == null) return;

    try {
      await UnitService.createUnit(
        propertyId: widget.propertyId,
        number: data.number,
        rentAmount: data.rentAmount.toString(),
      );
      await _loadDetailed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit created')),
      );
    } catch (e) {
      debugPrint('[PropertyUnits] add unit error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create unit: $e')),
      );
    }
  }

  Future<void> _editUnit(Map<String, dynamic> unit) async {
    final data = await showDialog<_UnitData>(
      context: context,
      builder: (_) => _UnitDialog(
        initialNumber: unit['number']?.toString() ?? '',
        initialRent: (unit['rent_amount'] ?? '').toString(),
      ),
    );
    if (data == null) return;

    try {
      await UnitService.updateUnit(
        unitId: unit['id'] as int,
        number: data.number,
        rentAmount: data.rentAmount.toString(),
      );
      await _loadDetailed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit updated')),
      );
    } catch (e) {
      debugPrint('[PropertyUnits] update unit error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update unit: $e')),
      );
    }
  }

  Future<void> _deleteUnit(int unitId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Unit'),
        content: const Text('This action cannot be undone. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await UnitService.deleteUnit(unitId);
      await _loadDetailed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unit deleted')),
      );
    } catch (e) {
      debugPrint('[PropertyUnits] delete unit error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete unit: $e')),
      );
    }
  }

  Future<void> _assignTenant(Map<String, dynamic> unit) async {
    final data = await showDialog<_AssignTenantData>(
      context: context,
      builder: (_) => _AssignTenantDialog(
        unitLabel: unit['number']?.toString() ?? '',
        initialRent: (unit['rent_amount'] ?? '').toString(),
      ),
    );
    if (data == null) return;

    try {
      final propertyId = _property?['id'] as int? ?? widget.propertyId;
      final unitId = unit['id'] as int;

      debugPrint("👤 [Tenant] CREATE -> name=${data.name} phone=${data.phone} prop=$propertyId unit=$unitId");
      final tenant = await TenantService.createTenant(
        name: data.name,
        phone: data.phone,
        email: data.email?.trim().isEmpty == true ? null : data.email,
        propertyId: propertyId,
        unitId: unitId,
      );

      final tenantId = (tenant['id'] as num?)?.toInt();
      if (tenantId == null) {
        throw Exception('Backend did not return tenant id');
      }

      // date-only string YYYY-MM-DD
      final today = DateTime.now();
      final String isoDate =
          DateTime(today.year, today.month, today.day).toIso8601String().split('T').first;

      debugPrint("📄 [Lease] CREATE -> tenant=$tenantId unit=$unitId rent=${data.rentAmount}");
      await LeaseService.createLease(
        tenantId: tenantId,
        unitId: unitId,
        rentAmount: data.rentAmount,
        startDate: isoDate, // String (date only)
        active: 1,
      );

      // Mark unit occupied (defensive)
      debugPrint("🏷️ [Unit] mark OCCUPIED -> id=$unitId");
      await UnitService.updateUnit(unitId: unitId, occupied: 1);

      await _loadDetailed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenant assigned and lease created')),
      );
    } catch (e) {
      debugPrint('[PropertyUnits] assign tenant error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign tenant: $e')),
      );
    }
  }

  Future<void> _endLease(Map<String, dynamic> unit) async {
    final leaseId = (unit['lease']?['id'] as num?)?.toInt();
    if (leaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active lease to end')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End Lease'),
        content: const Text('End current lease and mark unit as vacant?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('End Lease')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final today = DateTime.now();
      final String isoDate =
          DateTime(today.year, today.month, today.day).toIso8601String().split('T').first;

      await LeaseService.endLease(leaseId: leaseId, endDate: isoDate);
      await UnitService.updateUnit(unitId: (unit['id'] as num).toInt(), occupied: 0);

      await _loadDetailed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lease ended and unit marked vacant')),
      );
    } catch (e) {
      debugPrint('[PropertyUnits] end lease error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end lease: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_property == null) {
      return const Scaffold(
        body: Center(child: Text('Property not found')),
      );
    }

    final name = _property!['name'] ?? 'Property';
    final address = _property!['address'] ?? '';
    final code = _property!['property_code'] ?? '—';
    final total = _property!['total_units'] ?? _units.length;
    final occupied = _property!['occupied_units'] ?? (_units.where((u) => (u['status'] ?? '') == 'occupied').length);
    final vacant = _property!['vacant_units'] ?? (total - occupied);

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadDetailed,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Property top card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.dividerColor.withValues(alpha: .25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 18, color: t.hintColor),
                    const SizedBox(width: 6),
                    Expanded(child: Text(address, style: t.textTheme.bodyMedium)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _InfoChip(icon: Icons.grid_view_rounded, label: 'Total', value: '$total'),
                    _InfoChip(icon: Icons.person_pin_circle_rounded, label: 'Occupied', value: '$occupied'),
                    _InfoChip(icon: Icons.meeting_room_rounded, label: 'Vacant', value: '$vacant'),
                    _InfoChip(icon: Icons.qr_code_2_rounded, label: 'Property Code', value: code),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Text('Units', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addUnit,
                icon: const Icon(Icons.add),
                label: const Text('Add Unit'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_units.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.dividerColor.withValues(alpha: .25)),
              ),
              child: const Text('No units yet'),
            )
          else
            Card(
              elevation: 0,
              color: t.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: t.dividerColor.withValues(alpha: .25)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Unit')),
                    DataColumn(label: Text('Rent Amount')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Tenant (Name • Phone)')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _units.map((u) {
                    final status = (u['status'] ?? 'vacant').toString().toLowerCase();
                    final rent = (u['rent_amount'] ?? '').toString();
                    final id = (u['id'] as num?)?.toInt() ?? 0;

                    final tenantName = (u['tenant']?['name'] ?? '—').toString();
                    final tenantPhone = (u['tenant']?['phone'] ?? '—').toString();
                    final tenantDisplay = u['tenant'] == null ? '—' : '$tenantName • $tenantPhone';

                    return DataRow(
                      cells: [
                        DataCell(Text(u['number']?.toString() ?? '—')),
                        DataCell(Text(rent)),
                        DataCell(_statusChip(status, t)),
                        DataCell(Text(tenantDisplay)),
                        DataCell(Row(
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'assign':
                                    _assignTenant(u as Map<String, dynamic>);
                                    break;
                                  case 'edit':
                                    _editUnit(u as Map<String, dynamic>);
                                    break;
                                  case 'delete':
                                    _deleteUnit(id);
                                    break;
                                  case 'end_lease':
                                    _endLease(u as Map<String, dynamic>);
                                    break;
                                }
                              },
                              itemBuilder: (context) {
                                final items = <PopupMenuEntry<String>>[];
                                if (status == 'vacant') {
                                  items.add(const PopupMenuItem(value: 'assign', child: Text('👤 Assign Tenant')));
                                } else {
                                  items.add(const PopupMenuItem(value: 'end_lease', child: Text('🔚 End Lease')));
                                }
                                items.addAll(const [
                                  PopupMenuItem(value: 'edit', child: Text('✏️ Edit Unit')),
                                  PopupMenuItem(value: 'delete', child: Text('🗑️ Delete Unit')),
                                ]);
                                return items;
                              },
                            ),
                          ],
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String status, ThemeData t) {
    final isOcc = status == 'occupied';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOcc
            ? t.colorScheme.primaryContainer
            : t.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOcc ? 'Occupied' : 'Vacant',
        style: t.textTheme.labelMedium?.copyWith(
          color: isOcc ? t.colorScheme.onPrimaryContainer : t.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.dividerColor.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: t.hintColor),
          const SizedBox(width: 6),
          Text('$label: ', style: t.textTheme.labelMedium),
          Text(value, style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _UnitDialog extends StatefulWidget {
  final String? initialNumber;
  final String? initialRent;

  const _UnitDialog({Key? key, this.initialNumber, this.initialRent}) : super(key: key);

  @override
  State<_UnitDialog> createState() => _UnitDialogState();
}

class _UnitDialogState extends State<_UnitDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numCtrl = TextEditingController();
  final _rentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _numCtrl.text = widget.initialNumber ?? '';
    _rentCtrl.text = widget.initialRent ?? '';
  }

  @override
  void dispose() {
    _numCtrl.dispose();
    _rentCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final rent = double.tryParse(_rentCtrl.text.trim());
    if (rent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid rent amount')),
      );
      return;
    }
    Navigator.of(context).pop(
      _UnitData(number: _numCtrl.text.trim(), rentAmount: rent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialNumber == null ? 'Add Unit' : 'Edit Unit'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _numCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unit Number/Name',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Unit number is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rent Amount',
                ),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Rent amount is required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _UnitData {
  final String number;
  final double rentAmount;
  _UnitData({required this.number, required this.rentAmount});
}

class _AssignTenantDialog extends StatefulWidget {
  final String unitLabel;
  final String? initialRent;
  const _AssignTenantDialog({Key? key, required this.unitLabel, this.initialRent}) : super(key: key);

  @override
  State<_AssignTenantDialog> createState() => _AssignTenantDialogState();
}

class _AssignTenantDialogState extends State<_AssignTenantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _rentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rentCtrl.text = widget.initialRent ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _rentCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final rent = num.tryParse(_rentCtrl.text.trim());
    if (rent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid rent amount')),
      );
      return;
    }
    Navigator.of(context).pop(
      _AssignTenantData(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text.trim(),
        rentAmount: rent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign Tenant • Unit ${widget.unitLabel}'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Tenant Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Password (optional)'),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rentCtrl,
                decoration: const InputDecoration(labelText: 'Rent Amount'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Rent amount is required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Assign')),
      ],
    );
  }
}

class _AssignTenantData {
  final String name;
  final String phone;
  final String? email;
  final String? password;
  final num rentAmount;
  _AssignTenantData({
    required this.name,
    required this.phone,
    this.email,
    this.password,
    required this.rentAmount,
  });
}
