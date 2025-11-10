// Landlord property units screen
// - Remind All + Reports placed in the header card (right), clearer contrast.
// - Derives displayed occupancy from lease.active (wins over server 'status').
// - Handles 409 “tenant already exists (id=XX)” by linking existing tenant.
// - Copy/Call/WhatsApp actions for tenant phone; copy property code.
// - Collections summary card.
// - Backfills tenant name/phone via /units/{id}/tenant when lease is active but tenant is null.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:property_manager_frontend/events/app_events.dart';
import 'package:property_manager_frontend/services/property_service.dart';
import 'package:property_manager_frontend/services/unit_service.dart';
import 'package:property_manager_frontend/services/tenant_service.dart';
import 'package:property_manager_frontend/services/lease_service.dart';
import 'package:property_manager_frontend/services/payment_service.dart';
import 'package:property_manager_frontend/screens/landlord/landlord_reports.dart';

class LandlordPropertyUnits extends StatefulWidget {
  final int propertyId;
  const LandlordPropertyUnits({Key? key, required this.propertyId}) : super(key: key);

  @override
  State<LandlordPropertyUnits> createState() => _LandlordPropertyUnitsState();
}

class _LandlordPropertyUnitsState extends State<LandlordPropertyUnits> {
  bool _loading = true;
  Map<String, dynamic>? _property;
  List<dynamic> _units = [];
  Map<int, Map<String, dynamic>> _rentStatus = {};
  StreamSubscription<void>? _paySub;

  @override
  void initState() {
    super.initState();
    _paySub = AppEvents.I.paymentActivity.stream.listen((_) => _loadRentStatus());
    _loadDetailed();
  }

  @override
  void dispose() {
    _paySub?.cancel();
    super.dispose();
  }

  String _currentPeriod() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    return '${now.year}-$mm';
  }

  String _todayDate() {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    return d.toIso8601String().split('T').first;
  }

  String _fmtMoney(num? n) {
    if (n == null) return '0';
    final isInt = (n % 1) == 0;
    return isInt ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
  }

  num _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  bool _isLeaseActive(dynamic leaseActive) {
    return leaseActive == true || leaseActive == 1 || leaseActive == '1';
  }

  String _displayedStatus(Map<String, dynamic> unit) {
    final leaseActive = unit['lease']?['active'];
    if (_isLeaseActive(leaseActive)) return 'occupied';
    return (unit['status'] ?? 'vacant').toString().toLowerCase();
  }

  Map<String, num> _computeCollections() {
    num expected = 0, collected = 0;
    int paidCount = 0, unpaidCount = 0, occUnits = 0;

    for (final u in _units) {
      final unit = u as Map<String, dynamic>;
      final status = _displayedStatus(unit);
      final rent = _parseNum(unit['rent_amount']);
      final unitId = (unit['id'] as num).toInt();
      final rs = _rentStatus[unitId];

      if (status == 'occupied') {
        occUnits += 1;
        expected += rent;
        if (rs != null) {
          final isPaid = rs['paid'] == true;
          if (isPaid) {
            paidCount += 1;
            collected += rent;
          } else {
            unpaidCount += 1;
            final due = _parseNum(rs['amount_due']);
            final got = rent - (due > rent ? rent : due);
            if (got > 0) collected += got;
          }
        } else {
          unpaidCount += 1;
        }
      }
    }
    final outstanding = expected - collected;
    final tot = _units.isEmpty ? 1 : _units.length;

    return {
      'expected': expected,
      'collected': collected < 0 ? 0 : collected,
      'outstanding': outstanding < 0 ? 0 : outstanding,
      'paidCount': paidCount,
      'unpaidCount': unpaidCount,
      'occupancyPct': (occUnits * 100) / tot,
    };
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
      await _backfillTenants();
      await _loadRentStatus();
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

  Future<void> _backfillTenants() async {
    final futures = <Future<void>>[];
    for (var i = 0; i < _units.length; i++) {
      final u = _units[i] as Map<String, dynamic>;
      final status = _displayedStatus(u);
      final hasTenant = u['tenant'] != null && (u['tenant']['phone']?.toString().trim().isNotEmpty == true);
      if (status == 'occupied' && !hasTenant) {
        final unitId = (u['id'] as num).toInt();
        futures.add(_loadAndPatchTenant(i, unitId));
      }
    }
    await Future.wait(futures);
    if (mounted) setState(() {});
  }

  Future<void> _loadAndPatchTenant(int index, int unitId) async {
    try {
      final tnt = await UnitService.getUnitTenant(unitId);
      if (tnt == null) return;
      final u = Map<String, dynamic>.from(_units[index] as Map<String, dynamic>);
      u['tenant'] = {
        'id': tnt['id'],
        'name': tnt['name'],
        'phone': tnt['phone'],
        'email': tnt['email'],
      };
      _units[index] = u;
    } catch (e) {
      debugPrint('[PropertyUnits] backfill tenant failed for unit $unitId: $e');
    }
  }

  Future<void> _loadRentStatus() async {
    try {
      if (_property == null) return;
      final period = _currentPeriod();
      final rs = await PaymentService.getStatusByProperty(
        propertyId: _property!['id'] as int,
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  int? _extractTenantIdFrom409(Object err) {
    final msg = err.toString();
    final re = RegExp(r'id=(\d+)');
    final m = re.firstMatch(msg);
    if (m != null) return int.tryParse(m.group(1)!);
    try {
      final json = jsonDecode(msg);
      final detail = json['detail']?.toString() ?? '';
      final m2 = re.firstMatch(detail);
      if (m2 != null) return int.tryParse(m2.group(1)!);
    } catch (_) {}
    return null;
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

      final tenant = await TenantService.createTenant(
        name: data.name,
        phone: data.phone,
        email: data.email?.trim().isEmpty == true ? null : data.email,
        propertyId: propertyId,
        unitId: unitId,
        idNumber: data.idNumber,
      );
      final tenantId = (tenant['id'] as num?)?.toInt();
      if (tenantId == null) throw Exception('Backend did not return tenant id');

      final today = _todayDate();
      await LeaseService.createLease(
        tenantId: tenantId,
        unitId: unitId,
        rentAmount: data.rentAmount,
        startDate: today,
        active: 1,
      );

      await _loadDetailed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenant assigned and lease created')),
      );
    } catch (e) {
      final existingId = _extractTenantIdFrom409(e);
      if (existingId != null) {
        try {
          final unitId = unit['id'] as int;
          final today = _todayDate();
          await LeaseService.createLease(
            tenantId: existingId,
            unitId: unitId,
            rentAmount: data!.rentAmount,
            startDate: today,
            active: 1,
          );
          await _loadDetailed();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Linked existing tenant (ID=$existingId) and created lease')),
          );
          return;
        } catch (inner) {
          debugPrint('[PropertyUnits] link existing tenant failed: $inner');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to link existing tenant: $inner')),
          );
          return;
        }
      }
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
    if (leaseId == null) {
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
      final today = _todayDate();
      await LeaseService.endLease(leaseId: leaseId, endDate: today);

      if (tenantId != null) {
        await TenantService.deleteTenant(tenantId);
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

  Future<void> _sendReminder(Map<String, dynamic> unit) async {
    final leaseId = (unit['lease']?['id'] as num?)?.toInt();
    if (leaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active lease for reminder')),
      );
      return;
    }

    final msgCtrl = TextEditingController(text: 'Friendly reminder to clear your rent. Thank you!');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send Reminder'),
        content: TextField(
          controller: msgCtrl,
          decoration: const InputDecoration(labelText: 'Message (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await PaymentService.sendReminder(leaseId: leaseId, message: msgCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder queued')),
      );
    } catch (e) {
      debugPrint('[PropertyUnits] reminder error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reminder: $e')),
      );
    }
  }

  Future<void> _sendBulkReminders() async {
    final msgCtrl = TextEditingController(text: 'Kindly clear your rent for the month. Thank you.');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send Reminders to All Unpaid'),
        content: TextField(
          controller: msgCtrl,
          decoration: const InputDecoration(labelText: 'Message (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await PaymentService.sendRemindersBulk(
        propertyId: _property!['id'] as int,
        period: _currentPeriod(),
        message: msgCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bulk reminders queued')),
      );
    } catch (e) {
      debugPrint('[PropertyUnits] bulk reminders error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send bulk reminders: $e')),
      );
    }
  }

  Future<void> _copyText(String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open dialer')));
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    final uri = Uri.parse('https://wa.me/$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open WhatsApp')));
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
    final occupiedCount = _units.where((u) => _displayedStatus(u as Map<String, dynamic>) == 'occupied').length;
    final vacant = total - occupiedCount;
    final summary = _computeCollections();

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            onPressed: _loadDetailed,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== Header card (buttons here) =====
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
                // Title + Actions (right)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => LandlordReportsScreen(propertyId: _property!['id'] as int),
                            ));
                          },
                          icon: const Icon(Icons.analytics_outlined, size: 18),
                          label: const Text('Reports'),
                        ),
                        FilledButton.icon(
                          onPressed: _sendBulkReminders,
                          icon: const Icon(Icons.campaign_rounded, size: 18),
                          label: const Text('Remind All Unpaid'),
                        ),
                      ],
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
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _InfoChip(icon: Icons.grid_view_rounded, label: 'Total', value: '$total'),
                    _InfoChip(icon: Icons.person_pin_circle_rounded, label: 'Occupied', value: '$occupiedCount'),
                    _InfoChip(icon: Icons.meeting_room_rounded, label: 'Vacant', value: '$vacant'),
                    _CopyableChip(
                      icon: Icons.qr_code_2_rounded,
                      label: 'Property Code',
                      value: code,
                      onCopy: () => _copyText('Property code', code.toString()),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Collections summary
          _CollectionsReportCard(
            periodLabel: _currentPeriod(),
            expected: summary['expected'] ?? 0,
            collected: summary['collected'] ?? 0,
            outstanding: summary['outstanding'] ?? 0,
            paidCount: (summary['paidCount'] ?? 0).toInt(),
            unpaidCount: (summary['unpaidCount'] ?? 0).toInt(),
            occupancyPct: summary['occupancyPct'] ?? 0,
            formatter: _fmtMoney,
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Text('Units • ${_currentPeriod()}',
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
                    final unitMap = u as Map<String, dynamic>;
                    final unitId = (unitMap['id'] as num).toInt();
                    final status = _displayedStatus(unitMap);
                    final rent = (unitMap['rent_amount'] ?? '').toString();

                    final tenantName = (unitMap['tenant']?['name'] ?? '—').toString();
                    final tenantPhone = (unitMap['tenant']?['phone'] ?? '—').toString();

                    final rs = _rentStatus[unitId];
                    final paid = rs?['paid'] == true;
                    final amountDue = rs?['amount_due'];

                    return DataRow(
                      cells: [
                        DataCell(Text(unitMap['number']?.toString() ?? '—')),
                        DataCell(Text(rent)),
                        DataCell(_statusChip(status, t)),
                        DataCell(_TenantCell(
                          name: tenantName,
                          phone: tenantPhone,
                          onCopy: tenantPhone.trim().isEmpty || tenantPhone == '—'
                              ? null
                              : () => _copyText('Phone', tenantPhone),
                          onCall: tenantPhone.trim().isEmpty || tenantPhone == '—'
                              ? null
                              : () => _launchPhone(tenantPhone),
                          onWhatsApp: tenantPhone.trim().isEmpty || tenantPhone == '—'
                              ? null
                              : () => _launchWhatsApp(tenantPhone),
                        )),
                        DataCell(_rentChip(paid, amountDue, t)),
                        DataCell(Row(
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'assign':
                                    _assignTenant(unitMap);
                                    break;
                                  case 'end_lease':
                                    _endLease(unitMap);
                                    break;
                                  case 'edit':
                                    _editUnit(unitMap);
                                    break;
                                  case 'delete':
                                    _deleteUnit(unitId);
                                    break;
                                  case 'record':
                                    _recordPayment(unitMap);
                                    break;
                                  case 'remind':
                                    _sendReminder(unitMap);
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

class _CopyableChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onCopy;
  const _CopyableChip({required this.icon, required this.label, required this.value, required this.onCopy});

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
          const SizedBox(width: 6),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.copy_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantCell extends StatelessWidget {
  final String name;
  final String phone;
  final VoidCallback? onCopy;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;

  const _TenantCell({required this.name, required this.phone, this.onCopy, this.onCall, this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    final isUnknown = phone.trim().isEmpty || phone == '—';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(name == '—' ? '—' : '$name • $phone', overflow: TextOverflow.ellipsis),
        ),
        if (!isUnknown) const SizedBox(width: 6),
        if (!isUnknown)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(tooltip: 'Copy phone', onPressed: onCopy, icon: const Icon(Icons.copy_rounded, size: 18), splashRadius: 18),
              IconButton(tooltip: 'Call', onPressed: onCall, icon: const Icon(Icons.call_rounded, size: 18), splashRadius: 18),
              IconButton(tooltip: 'WhatsApp', onPressed: onWhatsApp, icon: const Icon(Icons.chat_rounded, size: 18), splashRadius: 18),
            ],
          ),
      ],
    );
  }
}

class _CollectionsReportCard extends StatelessWidget {
  final String periodLabel;
  final num expected;
  final num collected;
  final num outstanding;
  final int paidCount;
  final int unpaidCount;
  final num occupancyPct;
  final String Function(num) formatter;

  const _CollectionsReportCard({
    required this.periodLabel,
    required this.expected,
    required this.collected,
    required this.outstanding,
    required this.paidCount,
    required this.unpaidCount,
    required this.occupancyPct,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.dividerColor.withOpacity(.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Collections Report • $periodLabel', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _MetricPill(label: 'Expected', value: 'KES ${formatter(expected)}', icon: Icons.request_quote_rounded),
              _MetricPill(label: 'Collected', value: 'KES ${formatter(collected)}', icon: Icons.payments_rounded),
              _MetricPill(label: 'Outstanding', value: 'KES ${formatter(outstanding)}', icon: Icons.account_balance_wallet_outlined),
              _MetricPill(label: 'Paid Units', value: '$paidCount', icon: Icons.check_circle_rounded),
              _MetricPill(label: 'Unpaid Units', value: '$unpaidCount', icon: Icons.error_outline_rounded),
              _MetricPill(label: 'Occupancy', value: '${occupancyPct.toStringAsFixed(0)}%', icon: Icons.apartment_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MetricPill({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.dividerColor.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: t.hintColor),
          const SizedBox(width: 8),
          Text('$label: ', style: t.textTheme.labelMedium),
          Text(value, style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ---- Dialogs ----

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
  @override void initState() { super.initState(); _numCtrl.text = widget.initialNumber ?? ''; _rentCtrl.text = widget.initialRent ?? ''; }
  @override void dispose() { _numCtrl.dispose(); _rentCtrl.dispose(); super.dispose(); }
  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final rent = double.tryParse(_rentCtrl.text.trim());
    if (rent == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid rent amount'))); return; }
    Navigator.of(context).pop(_UnitData(number: _numCtrl.text.trim(), rentAmount: rent));
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
            mainAxisSize: MainAxisSize.min, // <-- fixed here
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
  @override void initState() { super.initState(); _amountCtrl.text = widget.initialAmount ?? ''; }
  @override void dispose() { _amountCtrl.dispose(); super.dispose(); }
  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amt = num.tryParse(_amountCtrl.text.trim());
    if (amt == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount'))); return; }
    Navigator.of(context).pop(amt);
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Payment'),
      content: Form(
        key: _formKey,
        child: SizedBox(width: 360, child: TextFormField(
          controller: _amountCtrl, decoration: const InputDecoration(labelText: 'Amount'),
          keyboardType: TextInputType.number, validator: (v) => (v == null || v.trim().isEmpty) ? 'Amount is required' : null,
        )),
      ),
      actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
  @override void initState() { super.initState(); _rentCtrl.text = widget.initialRent ?? ''; }
  @override void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose(); _idCtrl.dispose(); _passwordCtrl.dispose(); _rentCtrl.dispose(); super.dispose(); }
  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final rent = num.tryParse(_rentCtrl.text.trim());
    if (rent == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid rent amount'))); return; }
    Navigator.of(context).pop(_AssignTenantData(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      password: _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text.trim(),
      rentAmount: rent,
      idNumber: _idCtrl.text.trim().isEmpty ? null : _idCtrl.text.trim(),
    ));
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
              TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email (optional)')),
              const SizedBox(height: 10),
              TextFormField(controller: _idCtrl, decoration: const InputDecoration(labelText: 'National ID (optional)')),
              const SizedBox(height: 10),
              TextFormField(controller: _passwordCtrl, decoration: const InputDecoration(labelText: 'Password (optional)'), obscureText: true),
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
  _AssignTenantData({required this.name, required this.phone, this.email, this.password, required this.rentAmount, this.idNumber});
}

class _UnitData {
  final String number;
  final double rentAmount;
  _UnitData({required this.number, required this.rentAmount});
}
