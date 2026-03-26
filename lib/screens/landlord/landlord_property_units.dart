// lib/screens/landlord/landlord_property_units.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:property_manager_frontend/events/app_events.dart';
import 'package:property_manager_frontend/screens/landlord/landlord_reports.dart';
import 'package:property_manager_frontend/services/lease_service.dart';
import 'package:property_manager_frontend/services/payment_service.dart';
import 'package:property_manager_frontend/services/property_service.dart';
import 'package:property_manager_frontend/services/tenant_service.dart';
import 'package:property_manager_frontend/services/unit_service.dart';

class LandlordPropertyUnits extends StatefulWidget {
  final int propertyId;

  const LandlordPropertyUnits({super.key, required this.propertyId});

  @override
  State<LandlordPropertyUnits> createState() => _LandlordPropertyUnitsState();
}

class _LandlordPropertyUnitsState extends State<LandlordPropertyUnits> {
  bool _loading = true;
  Map<String, dynamic>? _property;
  List<Map<String, dynamic>> _units = [];
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

  Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  List<dynamic> _asList(dynamic v) {
    if (v is List) return v;
    return const [];
  }

  String _asString(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    return v.toString();
  }

  int _asInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  num _asNum(dynamic v, [num fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? fallback;
  }

  bool _asBool(dynamic v) {
    if (v == true || v == 1 || v == '1' || v == 'true') return true;
    return false;
  }

  String _currentPeriod() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    return '${now.year}-$mm';
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _todayDate() {
    return _today().toIso8601String().split('T').first;
  }

  String _fmtMoney(num? n) {
    if (n == null) return '0';
    final isInt = (n % 1) == 0;
    return isInt ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
  }

  bool _isLeaseActive(dynamic leaseObj) {
    final lease = _asMap(leaseObj);
    if (lease == null) return false;
    return _asBool(lease['active']);
  }

  String _displayedStatus(Map<String, dynamic> unit) {
    final leaseObj = unit['lease'];
    if (_isLeaseActive(leaseObj)) return 'occupied';
    return _asString(unit['status'], 'vacant').toLowerCase();
  }

  Map<String, num> _computeCollections() {
    num expected = 0, collected = 0;
    int paidCount = 0, unpaidCount = 0, occUnits = 0;

    for (final unit in _units) {
      final status = _displayedStatus(unit);
      final rent = _asNum(unit['rent_amount'], 0);
      final unitId = _asInt(unit['id'], 0);
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
            final due = _asNum(rs['amount_due'], rent);
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
      final prop = _asMap(detail) ?? <String, dynamic>{};

      final rawUnits = _asList(prop['units']);
      final parsedUnits = <Map<String, dynamic>>[];
      for (final u in rawUnits) {
        final m = _asMap(u);
        if (m != null) parsedUnits.add(m);
      }

      if (!mounted) return;
      setState(() {
        _property = prop;
        _units = parsedUnits;
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
      final u = _units[i];
      final status = _displayedStatus(u);

      final tenant = _asMap(u['tenant']);
      final hasTenant = tenant != null && _asString(tenant['phone']).trim().isNotEmpty;

      if (status == 'occupied' && !hasTenant) {
        final unitId = _asInt(u['id'], 0);
        if (unitId > 0) futures.add(_loadAndPatchTenant(i, unitId));
      }
    }

    await Future.wait(futures);
    if (mounted) setState(() {});
  }

  Future<void> _loadAndPatchTenant(int index, int unitId) async {
    try {
      final tnt = await UnitService.getUnitTenant(unitId);
      final tMap = _asMap(tnt);
      if (tMap == null) return;

      final u = Map<String, dynamic>.from(_units[index]);
      u['tenant'] = {
        'id': tMap['id'],
        'name': tMap['name'],
        'phone': tMap['phone'],
        'email': tMap['email'],
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
        propertyId: _asInt(_property!['id'], widget.propertyId),
        period: period,
      );

      final rsMap = _asMap(rs) ?? <String, dynamic>{};
      final items = _asList(rsMap['items']);

      final Map<int, Map<String, dynamic>> m = {};
      for (final it in items) {
        final map = _asMap(it);
        if (map == null) continue;
        final unitId = _asInt(map['unit_id'], 0);
        if (unitId > 0) m[unitId] = map;
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
        initialNumber: _asString(unit['number']),
        initialRent: _asString(unit['rent_amount']),
      ),
    );
    if (data == null) return;

    try {
      await UnitService.updateUnit(
        unitId: _asInt(unit['id']),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
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
        SnackBar(content: Text('$e')),
      );
    }
  }

  bool _looksNotFound(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('404') || msg.contains('tenant not found');
  }

  Future<void> _assignTenant(Map<String, dynamic> unit) async {
    final data = await showDialog<_AssignTenantData>(
      context: context,
      builder: (_) => _AssignTenantDialog(
        unitLabel: _asString(unit['number']),
        initialRent: _asString(unit['rent_amount']),
      ),
    );
    if (data == null) return;

    try {
      final propertyId = _asInt(_property?['id'], widget.propertyId);
      final unitId = _asInt(unit['id']);

      try {
        final existing = await TenantService.getByPhone(data.phone);
        final existingId = _asInt(existing['id'], 0);

        await TenantService.assignExistingTenant(
          phone: data.phone,
          unitId: unitId,
          rentAmount: data.rentAmount,
          startDate: _today(),
        );

        await _loadDetailed();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existingId > 0
                  ? 'Existing tenant linked successfully'
                  : 'Existing tenant assigned successfully',
            ),
          ),
        );
        return;
      } catch (existingErr) {
        if (!_looksNotFound(existingErr)) {
          rethrow;
        }
      }

      await TenantService.createTenant(
        name: data.name,
        phone: data.phone,
        email: (data.email?.trim().isEmpty == true) ? null : data.email,
        password: (data.password?.trim().isEmpty == true) ? null : data.password,
        propertyId: propertyId,
        unitId: unitId,
        idNumber: data.idNumber,
      );

      await _loadDetailed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New tenant created and assigned')),
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
    final lease = _asMap(unit['lease']);
    final leaseId = _asInt(lease?['id'], 0);

    if (leaseId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active lease or invalid unit')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End Lease'),
        content: const Text(
          'End current lease and mark this unit vacant?\n\n'
          'The tenant record will be kept for history and future reassignment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Lease'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final today = _todayDate();
      await LeaseService.endLease(leaseId: leaseId, endDate: today);

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

  Future<void> _recordPayment(Map<String, dynamic> unit) async {
    final lease = _asMap(unit['lease']);
    final leaseId = _asInt(lease?['id'], 0);

    if (leaseId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active lease to record payment against')),
      );
      return;
    }

    final rent = _asString(unit['rent_amount']);
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
    final lease = _asMap(unit['lease']);
    final leaseId = _asInt(lease?['id'], 0);

    if (leaseId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active lease for reminder')),
      );
      return;
    }

    final msgCtrl = TextEditingController(
      text: 'Friendly reminder to clear your rent. Thank you!',
    );

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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await PaymentService.sendReminder(
        leaseId: leaseId,
        message: msgCtrl.text.trim(),
      );
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
    if (_property == null) return;

    final msgCtrl = TextEditingController(
      text: 'Kindly clear your rent for the month. Thank you.',
    );

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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await PaymentService.sendRemindersBulk(
        propertyId: _asInt(_property!['id'], widget.propertyId),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open dialer')),
      );
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    final uri = Uri.parse('https://wa.me/$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open WhatsApp')),
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

    final name = _asString(_property!['name'], 'Property');
    final address = _asString(_property!['address'], '');
    final code = _asString(_property!['property_code'], '—');
    final landlord = _asMap(_property!['landlord']);
    final landlordName = _asString(landlord?['name'], '');

    final total = _asInt(_property!['total_units'], _units.length);
    final occupiedCount = _units.where((u) => _displayedStatus(u) == 'occupied').length;
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUnit,
        icon: const Icon(Icons.add),
        label: const Text('Add Unit'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runSpacing: 12,
                      spacing: 12,
                      children: [
                        SizedBox(
                          width: isWide ? constraints.maxWidth * .45 : double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: t.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (landlordName.trim().isNotEmpty)
                                Text(
                                  'Landlord: $landlordName',
                                  style: t.textTheme.bodyMedium?.copyWith(
                                    color: t.colorScheme.onSurface.withOpacity(.75),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 18, color: t.hintColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(address, style: t.textTheme.bodyMedium),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LandlordReportsScreen(
                                      propertyId: _asInt(_property!['id'], widget.propertyId),
                                    ),
                                  ),
                                );
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
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        _InfoChip(
                          icon: Icons.grid_view_rounded,
                          label: 'Total',
                          value: '$total',
                        ),
                        _InfoChip(
                          icon: Icons.person_pin_circle_rounded,
                          label: 'Occupied',
                          value: '$occupiedCount',
                        ),
                        _InfoChip(
                          icon: Icons.meeting_room_rounded,
                          label: 'Vacant',
                          value: '$vacant',
                        ),
                        _CopyableChip(
                          icon: Icons.qr_code_2_rounded,
                          label: 'Property Code',
                          value: code,
                          onCopy: () => _copyText('Property code', code),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _CollectionsReportCard(
                periodLabel: _currentPeriod(),
                expected: summary['expected'] ?? 0,
                collected: summary['collected'] ?? 0,
                outstanding: summary['outstanding'] ?? 0,
                paidCount: (summary['paidCount'] ?? 0).toInt(),
                unpaidCount: (summary['unpaidCount'] ?? 0).toInt(),
                occupancyPct: (summary['occupancyPct'] ?? 0).toDouble(),
              ),
              const SizedBox(height: 16),
              if (_units.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: t.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.dividerColor.withOpacity(.25)),
                  ),
                  child: const Center(
                    child: Text('No units yet. Tap "Add Unit" to create one.'),
                  ),
                )
              else
                ..._units.map((unit) {
                  final tenant = _asMap(unit['tenant']);
                  final lease = _asMap(unit['lease']);
                  final unitId = _asInt(unit['id']);
                  final unitLabel = _asString(unit['number'], 'Unit');
                  final rent = _fmtMoney(_asNum(unit['rent_amount'], 0));
                  final status = _displayedStatus(unit);
                  final rs = _rentStatus[unitId];

                  final tenantName = _asString(tenant?['name'], '—');
                  final tenantPhone = _asString(tenant?['phone'], '');
                  final paid = rs?['paid'] == true;
                  final due = _asNum(rs?['amount_due'], 0);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _UnitCard(
                      unitLabel: unitLabel,
                      rent: 'KES $rent',
                      statusChip: _StatusChip(
                        label: status == 'occupied' ? 'Occupied' : 'Vacant',
                        isPositive: status == 'occupied',
                      ),
                      tenant: tenant == null
                          ? const Text('No tenant assigned')
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tenantName,
                                  style: t.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (tenantPhone.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _launchPhone(tenantPhone),
                                        icon: const Icon(Icons.call_outlined, size: 16),
                                        label: const Text('Call'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _launchWhatsApp(tenantPhone),
                                        icon: const Icon(Icons.chat_outlined, size: 16),
                                        label: const Text('WhatsApp'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _copyText('Phone', tenantPhone),
                                        icon: const Icon(Icons.copy_rounded, size: 16),
                                        label: const Text('Copy'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                      monthChip: _StatusChip(
                        label: paid
                            ? 'Paid ${_currentPeriod()}'
                            : (status == 'occupied'
                                ? 'Unpaid ${_currentPeriod()}${due > 0 ? ' · Due KES ${_fmtMoney(due)}' : ''}'
                                : 'No active rent'),
                        isPositive: paid,
                      ),
                      actionsBuilder: () {
                        return PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'assign':
                                _assignTenant(unit);
                                break;
                              case 'edit':
                                _editUnit(unit);
                                break;
                              case 'delete':
                                _deleteUnit(unitId);
                                break;
                              case 'pay':
                                _recordPayment(unit);
                                break;
                              case 'remind':
                                _sendReminder(unit);
                                break;
                              case 'endLease':
                                _endLease(unit);
                                break;
                              case 'copyUnit':
                                _copyText('Unit', unitLabel);
                                break;
                              case 'copyTenantPhone':
                                if (tenantPhone.isNotEmpty) {
                                  _copyText('Tenant phone', tenantPhone);
                                }
                                break;
                            }
                          },
                          itemBuilder: (_) => [
                            if (status != 'occupied')
                              const PopupMenuItem(
                                value: 'assign',
                                child: Text('Assign Tenant'),
                              ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit Unit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete Unit'),
                            ),
                            const PopupMenuItem(
                              value: 'copyUnit',
                              child: Text('Copy Unit Number'),
                            ),
                            if (status == 'occupied' && lease != null)
                              const PopupMenuItem(
                                value: 'pay',
                                child: Text('Record Payment'),
                              ),
                            if (status == 'occupied' && lease != null)
                              const PopupMenuItem(
                                value: 'remind',
                                child: Text('Send Reminder'),
                              ),
                            if (status == 'occupied' && lease != null)
                              const PopupMenuItem(
                                value: 'endLease',
                                child: Text('End Lease'),
                              ),
                            if (tenantPhone.isNotEmpty)
                              const PopupMenuItem(
                                value: 'copyTenantPhone',
                                child: Text('Copy Tenant Phone'),
                              ),
                          ],
                        );
                      },
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest.withOpacity(.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
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

  const _CopyableChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.colorScheme.surfaceContainerHighest.withOpacity(.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(value),
            const SizedBox(width: 6),
            const Icon(Icons.copy_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isPositive;

  const _StatusChip({
    required this.label,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final bg = isPositive
        ? Colors.green.withOpacity(.12)
        : Colors.orange.withOpacity(.12);
    final fg = isPositive ? Colors.green.shade800 : Colors.orange.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: t.textTheme.bodySmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
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
  final double occupancyPct;

  const _CollectionsReportCard({
    required this.periodLabel,
    required this.expected,
    required this.collected,
    required this.outstanding,
    required this.paidCount,
    required this.unpaidCount,
    required this.occupancyPct,
  });

  String _fmt(num n) => (n % 1 == 0) ? n.toStringAsFixed(0) : n.toStringAsFixed(2);

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
          Text(
            'Collections · $periodLabel',
            style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(title: 'Expected', value: 'KES ${_fmt(expected)}'),
              _MetricCard(title: 'Collected', value: 'KES ${_fmt(collected)}'),
              _MetricCard(title: 'Outstanding', value: 'KES ${_fmt(outstanding)}'),
              _MetricCard(title: 'Paid Units', value: '$paidCount'),
              _MetricCard(title: 'Unpaid Units', value: '$unpaidCount'),
              _MetricCard(title: 'Occupancy', value: '${occupancyPct.toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;

  const _MetricCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest.withOpacity(.28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final String unitLabel;
  final String rent;
  final Widget statusChip;
  final Widget tenant;
  final Widget monthChip;
  final Widget Function() actionsBuilder;

  const _UnitCard({
    required this.unitLabel,
    required this.rent,
    required this.statusChip,
    required this.tenant,
    required this.monthChip,
    required this.actionsBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
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
                  unitLabel,
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              actionsBuilder(),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MiniPill(
                icon: Icons.request_quote_rounded,
                label: 'Rent',
                value: rent,
              ),
              statusChip,
              monthChip,
            ],
          ),
          const SizedBox(height: 12),
          tenant,
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest.withOpacity(.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _UnitData {
  final String number;
  final num rentAmount;

  const _UnitData({
    required this.number,
    required this.rentAmount,
  });
}

class _UnitDialog extends StatefulWidget {
  final String? initialNumber;
  final String? initialRent;

  const _UnitDialog({
    this.initialNumber,
    this.initialRent,
  });

  @override
  State<_UnitDialog> createState() => _UnitDialogState();
}

class _UnitDialogState extends State<_UnitDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numberCtrl;
  late final TextEditingController _rentCtrl;

  @override
  void initState() {
    super.initState();
    _numberCtrl = TextEditingController(text: widget.initialNumber ?? '');
    _rentCtrl = TextEditingController(text: widget.initialRent ?? '');
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _rentCtrl.dispose();
    super.dispose();
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
                controller: _numberCtrl,
                decoration: const InputDecoration(labelText: 'Unit Number'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Unit number is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rentCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Rent Amount'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Rent amount is required';
                  if (num.tryParse(v.trim()) == null) return 'Enter a valid amount';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _UnitData(
                number: _numberCtrl.text.trim(),
                rentAmount: num.parse(_rentCtrl.text.trim()),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AssignTenantData {
  final String name;
  final String phone;
  final String? email;
  final String? password;
  final String? idNumber;
  final num rentAmount;

  const _AssignTenantData({
    required this.name,
    required this.phone,
    this.email,
    this.password,
    this.idNumber,
    required this.rentAmount,
  });
}

class _AssignTenantDialog extends StatefulWidget {
  final String unitLabel;
  final String? initialRent;

  const _AssignTenantDialog({
    required this.unitLabel,
    this.initialRent,
  });

  @override
  State<_AssignTenantDialog> createState() => _AssignTenantDialogState();
}

class _AssignTenantDialogState extends State<_AssignTenantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  late final TextEditingController _rentCtrl;

  @override
  void initState() {
    super.initState();
    _rentCtrl = TextEditingController(text: widget.initialRent ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _idNumberCtrl.dispose();
    _rentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign Tenant • ${widget.unitLabel}'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tenant Name',
                    helperText: 'Required for new tenant creation',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    helperText: 'If this phone exists, the existing tenant will be assigned',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Password (optional)'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _idNumberCtrl,
                  decoration: const InputDecoration(labelText: 'ID Number (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rentCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Rent Amount'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Rent amount is required';
                    if (num.tryParse(v.trim()) == null) return 'Enter a valid amount';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _AssignTenantData(
                name: _nameCtrl.text.trim(),
                phone: _phoneCtrl.text.trim(),
                email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
                password: _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text.trim(),
                idNumber: _idNumberCtrl.text.trim().isEmpty ? null : _idNumberCtrl.text.trim(),
                rentAmount: num.parse(_rentCtrl.text.trim()),
              ),
            );
          },
          child: const Text('Assign'),
        ),
      ],
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final String initialAmount;

  const _PaymentDialog({required this.initialAmount});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.initialAmount);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Payment'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 380,
          child: TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Amount is required';
              if (num.tryParse(v.trim()) == null) return 'Enter a valid amount';
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, num.parse(_amountCtrl.text.trim()));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}