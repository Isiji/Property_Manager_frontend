// lib/screens/landlord/landlord_property_units.dart
// Units table + assign/end lease + per/bulk reminders + notifications + lease actions.
// One-shot rent-status refresh via AppEvents.paymentActivity.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:property_manager_frontend/events/app_events.dart';
import 'package:property_manager_frontend/services/property_service.dart';
import 'package:property_manager_frontend/services/unit_service.dart';
import 'package:property_manager_frontend/services/tenant_service.dart';
import 'package:property_manager_frontend/services/lease_service.dart';
import 'package:property_manager_frontend/services/payment_service.dart';
import 'package:property_manager_frontend/services/notification_service.dart';
import 'package:property_manager_frontend/widgets/notifications_sheet.dart';

class LandlordPropertyUnits extends StatefulWidget {
  final int propertyId;
  const LandlordPropertyUnits({Key? key, required this.propertyId}) : super(key: key);

  @override
  State<LandlordPropertyUnits> createState() => _LandlordPropertyUnitsState();
}

class _LandlordPropertyUnitsState extends State<LandlordPropertyUnits> {
  bool _loading = true;
  Map<String, dynamic>? _property; // detail
  List<dynamic> _units = [];
  Map<int, Map<String, dynamic>> _rentStatus = {}; // unit_id -> rent status
  StreamSubscription<void>? _paySub;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _paySub = AppEvents.I.paymentActivity.stream.listen((_) {
      _loadRentStatus();
    });
    _loadAll();
  }

  @override
  void dispose() {
    _paySub?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadDetailed();
    await _loadRentStatus();
    await _loadNotificationsCount();
  }

  Future<void> _loadNotificationsCount() async {
    try {
      final res = await NotificationService.getUnreadCount();
      if (!mounted) return;
      setState(() => _unread = res);
    } catch (_) {
      // ignore
    }
  }

  String _currentPeriod() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    return '${now.year}-$mm'; // YYYY-MM
  }

  String _todayDate() {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    return d.toIso8601String().split('T').first; // YYYY-MM-DD
  }

  Future<void> _loadDetailed() async {
    try {
      setState(() => _loading = true);
      final detail = await PropertyService.getPropertyWithUnitsDetailed(widget.propertyId);
      if (!mounted) return;
      setState(() {
        _property = detail;
        _units = (detail['units'] as List<dynamic>? ?? []);
      });
    } catch (e) {
      debugPrint('[PropertyUnits] load error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load property details: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRentStatus() async {
    try {
      if (_property == null) return;
      final period = _currentPeriod();
      final rs = await PaymentService.getStatusByProperty(
        propertyId: (_property!['id'] as num).toInt(),
        period: period,
      );
      final Map<int, Map<String, dynamic>> m = {};
      for (final it in (rs['items'] as List<dynamic>? ?? [])) {
        final map = Map<String, dynamic>.from(it as Map<String, dynamic>);
        final unitId = (map['unit_id'] as num).toInt();
        m[unitId] = map;
      }
      if (!mounted) return;
      setState(() => _rentStatus = m);
    } catch (e) {
      debugPrint('[PropertyUnits] rent status error: $e');
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
        propertyId: (_property?['id'] as num? ?? widget.propertyId).toInt(),
        number: data.number,
        rentAmount: data.rentAmount.toString(),
      );
      await _loadAll();
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
        unitId: (unit['id'] as num).toInt(),
        number: data.number,
        rentAmount: data.rentAmount.toString(),
      );
      await _loadAll();
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
      await _loadAll();
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
      final propertyId = (_property?['id'] as num? ?? widget.propertyId).toInt();
      final unitId = (unit['id'] as num).toInt();

      final tenant = await TenantService.createTenant(
        name: data.name,
        phone: data.phone,
        email: data.email?.trim().isEmpty == true ? null : data.email,
        propertyId: propertyId,
        unitId: unitId,
        idNumber: data.idNumber,
        password: data.password,
      );

      final tenantId = (tenant['id'] as num?)?.toInt();
      if (tenantId == null) {
        throw Exception('Backend did not return tenant id');
      }

      final today = _todayDate();
      await LeaseService.createLease(
        tenantId: tenantId,
        unitId: unitId,
        rentAmount: data.rentAmount,
        startDate: today,
        active: 0, // start as DRAFT until tenant accepts terms
      );

      await UnitService.updateUnit(unitId: unitId, occupied: 1);

      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenant assigned. Draft lease created (awaiting tenant acceptance).')),
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
  final tenantId = (unit['tenant']?['id'] as num?)?.toInt();
  final unitId = (unit['id'] as num?)?.toInt();

  if (leaseId == null || unitId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No active lease or invalid unit')),
    );
    return;
  }

  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('End Lease'),
      content: const Text('End current lease, mark unit vacant, and delete the tenant?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('End Lease')),
      ],
    ),
  );
  if (confirm != true) return;

  try {
    final today = _todayDate(); // YYYY-MM-DD

    // 1) End the lease
    await LeaseService.endLease(leaseId: leaseId, endDate: today);

    // 2) Mark unit vacant
    await UnitService.updateUnit(unitId: unitId, occupied: 0);

    // 3) Delete tenant (POSitional argument — no named parameter!)
    if (tenantId != null) {
      await TenantService.deleteTenant(tenantId); // <- FIXED
    }

    await _loadDetailed();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lease ended, unit vacated, tenant deleted')),
    );
  } catch (e) {
    debugPrint('[PropertyUnits] end lease error: $e');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to end lease: $e')),
    );
  }
}

  Future<void> _recordPayment(Map<String, dynamic> unit) async {
    final leaseId = (unit['lease']?['id'] as num?)?.toInt();
    if (leaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active lease to record payment against')),
      );
      return;
    }
    final rent = (unit['rent_amount'] ?? '').toString();
    final amount = await showDialog<num?>(
      context: context,
      builder: (_) => _PaymentDialog(initialAmount: rent),
    );
    if (amount == null) return;

    try {
      final period = _currentPeriod();
      final paidDate = _todayDate();
      await PaymentService.recordPayment(
        leaseId: leaseId,
        period: period,
        amount: amount,
        paidDate: paidDate,
      );
      await _loadRentStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded')),
      );
    } catch (e) {
      debugPrint('[PropertyUnits] record payment error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record payment: $e')),
      );
    }
  }

  Future<void> _sendReminderUnit(Map<String, dynamic> unit) async {
    final leaseId = (unit['lease']?['id'] as num?)?.toInt();
    if (leaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active lease for reminder')),
      );
      return;
    }
    final msg = await showDialog<String?>(
      context: context,
      builder: (_) => const _MessageDialog(title: 'Send Reminder', hint: 'Optional message (e.g., kindly clear rent)'),
    );
    try {
      await PaymentService.sendReminder(leaseId: leaseId, message: msg);
      await _loadNotificationsCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder sent')),
      );
    } catch (e) {
      debugPrint('[PropertyUnits] reminder error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reminder: $e')),
      );
    }
  }

  Future<void> _sendRemindersBulk() async {
    final msg = await showDialog<String?>(
      context: context,
      builder: (_) => const _MessageDialog(
        title: 'Remind All Unpaid',
        hint: 'Optional message to all unpaid tenants this month…',
      ),
    );
    try {
      await PaymentService.sendRemindersBulk(
        propertyId: (_property?['id'] as num? ?? widget.propertyId).toInt(),
        period: _currentPeriod(),
        message: msg,
      );
      await _loadNotificationsCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bulk reminders queued')),
      );
    } catch (e) {
      debugPrint('[PropertyUnits] bulk reminders error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to queue reminders: $e')),
      );
    }
  }

  void _openNotifications() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const NotificationsSheet(),
    );
    await _loadNotificationsCount();
  }

  void _openLease(Map<String, dynamic> unit) {
    final leaseId = (unit['lease']?['id'] as num?)?.toInt();
    if (leaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No lease to view')),
      );
      return;
    }
    Navigator.of(context).pushNamed('/lease_view', arguments: {'leaseId': leaseId});
  }

  Future<void> _printLease(Map<String, dynamic> unit) async {
    final leaseId = (unit['lease']?['id'] as num?)?.toInt();
    if (leaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No lease to print')),
      );
      return;
    }
    try {
      await LeaseService.downloadLeasePdf(leaseId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lease PDF download started')),
      );
    } catch (e) {
      debugPrint('[PropertyUnits] lease pdf error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download lease: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_property == null) {
      return const Scaffold(body: Center(child: Text('Property not found')));
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
          // Notifications bell with unread badge
          IconButton(
            onPressed: _openNotifications,
            tooltip: 'Notifications',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_rounded),
                if (_unread > 0)
                  Positioned(
                    top: -2, right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: t.colorScheme.error,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _unread > 99 ? '99+' : '$_unread',
                        style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onError),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadAll,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card with Payout + Remind All
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.dividerColor.withOpacity(.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed('/landlord_payouts'),
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('Payout Methods'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _sendRemindersBulk,
                      icon: const Icon(Icons.campaign_rounded),
                      label: const Text('Remind All (Unpaid)'),
                    ),
                  ],
                ),
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
                    _InfoChip(icon: Icons.calendar_month_rounded, label: 'Period', value: _currentPeriod()),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Text('Units',
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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
                border: Border.all(color: t.dividerColor.withOpacity(.25)),
              ),
              child: const Text('No units yet'),
            )
          else
            Card(
              elevation: 0,
              color: t.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: t.dividerColor.withOpacity(.25)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Unit')),
                    DataColumn(label: Text('Rent')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Tenant (Name • Phone)')),
                    DataColumn(label: Text('This Month')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _units.map((u) {
                    final unitId = (u['id'] as num).toInt();
                    final status = (u['status'] ?? 'vacant').toString().toLowerCase();
                    final rent = (u['rent_amount'] ?? '').toString();

                    final tenantName = (u['tenant']?['name'] ?? '—').toString();
                    final tenantPhone = (u['tenant']?['phone'] ?? '—').toString();
                    final tenantDisplay = u['tenant'] == null ? '—' : '$tenantName • $tenantPhone';

                    final rs = _rentStatus[unitId];
                    final paid = rs?['paid'] == true;
                    final amountDue = rs?['amount_due'];

                    return DataRow(
                      cells: [
                        DataCell(Text(u['number']?.toString() ?? '—')),
                        DataCell(Text(rent)),
                        DataCell(_statusChip(status, t)),
                        DataCell(Text(tenantDisplay)),
                        DataCell(_rentChip(paid, amountDue, t)),
                        DataCell(Row(
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'assign':
                                    _assignTenant(u as Map<String, dynamic>);
                                    break;
                                  case 'end_lease':
                                    _endLease(u as Map<String, dynamic>);
                                    break;
                                  case 'edit':
                                    _editUnit(u as Map<String, dynamic>);
                                    break;
                                  case 'delete':
                                    _deleteUnit(unitId);
                                    break;
                                  case 'record':
                                    _recordPayment(u as Map<String, dynamic>);
                                    break;
                                  case 'remind':
                                    _sendReminderUnit(u as Map<String, dynamic>);
                                    break;
                                  case 'view_lease':
                                    _openLease(u as Map<String, dynamic>);
                                    break;
                                  case 'print_lease':
                                    _printLease(u as Map<String, dynamic>);
                                    break;
                                }
                              },
                              itemBuilder: (context) {
                                final items = <PopupMenuEntry<String>>[];
                                if (status == 'vacant') {
                                  items.add(const PopupMenuItem(value: 'assign', child: Text('👤 Assign Tenant')));
                                  items.add(const PopupMenuItem(value: 'edit', child: Text('✏️ Edit Unit')));
                                  items.add(const PopupMenuItem(value: 'delete', child: Text('🗑️ Delete Unit')));
                                } else {
                                  items.add(const PopupMenuItem(value: 'view_lease', child: Text('📄 View Lease')));
                                  items.add(const PopupMenuItem(value: 'print_lease', child: Text('🖨️ Print Lease (PDF)')));
                                  items.add(const PopupMenuItem(value: 'end_lease', child: Text('🔚 End Lease')));
                                  if (!(rs?['paid'] == true)) {
                                    items.add(const PopupMenuItem(value: 'record', child: Text('💵 Record Payment')));
                                    items.add(const PopupMenuItem(value: 'remind', child: Text('📣 Send Reminder')));
                                  }
                                  items.add(const PopupMenuItem(value: 'edit', child: Text('✏️ Edit Unit')));
                                  items.add(const PopupMenuItem(value: 'delete', child: Text('🗑️ Delete Unit')));
                                }
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
        color: isOcc ? t.colorScheme.primaryContainer : t.colorScheme.secondaryContainer,
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

  Widget _rentChip(bool paid, dynamic amountDue, ThemeData t) {
    final isPaid = paid == true;
    final label = isPaid ? 'Paid' : (amountDue != null ? 'Unpaid • $amountDue' : 'Unpaid');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPaid ? t.colorScheme.tertiaryContainer : t.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: t.textTheme.labelMedium?.copyWith(
          color: isPaid ? t.colorScheme.onTertiaryContainer : t.colorScheme.onErrorContainer,
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
        border: Border.all(color: t.dividerColor.withOpacity(.25)),
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
                decoration: const InputDecoration(labelText: 'Unit Number/Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Unit number is required' : null,
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
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final String? initialAmount;
  const _PaymentDialog({Key? key, this.initialAmount}) : super(key: key);

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.initialAmount ?? '';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amt = num.tryParse(_amountCtrl.text.trim());
    if (amt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    Navigator.of(context).pop(amt);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Payment'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: TextFormField(
            controller: _amountCtrl,
            decoration: const InputDecoration(labelText: 'Amount'),
            keyboardType: TextInputType.number,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Amount is required' : null,
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
  final _idCtrl = TextEditingController();
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
    _idCtrl.dispose();
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
        idNumber: _idCtrl.text.trim().isEmpty ? null : _idCtrl.text.trim(),
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
                controller: _idCtrl,
                decoration: const InputDecoration(labelText: 'National ID (optional)'),
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
  final String? idNumber;
  _AssignTenantData({
    required this.name,
    required this.phone,
    this.email,
    this.password,
    required this.rentAmount,
    this.idNumber,
  });
}

class _UnitData {
  final String number;
  final double rentAmount;
  _UnitData({required this.number, required this.rentAmount});
}

class _MessageDialog extends StatefulWidget {
  final String title;
  final String hint;
  const _MessageDialog({super.key, required this.title, required this.hint});
  @override
  State<_MessageDialog> createState() => _MessageDialogState();
}

class _MessageDialogState extends State<_MessageDialog> {
  final _ctrl = TextEditingController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: _ctrl,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Message (optional)',
            hintText: widget.hint,
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Skip')),
        FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text.trim()), child: const Text('Send')),
      ],
    );
  }
}
