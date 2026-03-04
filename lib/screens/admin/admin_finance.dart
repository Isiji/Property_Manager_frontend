// lib/screens/admin/admin_finance.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/services/admin_reports_service.dart';
import 'package:property_manager_frontend/services/admin_payout_service.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  bool _loading = false;
  String? _error;

  // Inputs
  final _landlordIdCtrl = TextEditingController();
  final _propertyIdCtrl = TextEditingController();
  final _paymentIdCtrl = TextEditingController();

  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  String _period = _yyyymm(DateTime.now().year, DateTime.now().month);

  // Data
  Map<String, dynamic>? _landlordSummary;
  Map<String, dynamic>? _propertyStatus;
  List<Map<String, dynamic>> _payouts = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _landlordIdCtrl.dispose();
    _propertyIdCtrl.dispose();
    _paymentIdCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  static String _yyyymm(int y, int m) => '$y-${m.toString().padLeft(2, '0')}';

  Future<void> _copy(String text, {String msg = 'Copied'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await job();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _intOf(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  Future<void> _loadLandlordMonthly() async {
    final landlordId = _intOf(_landlordIdCtrl);
    if (landlordId <= 0) {
      setState(() => _error = 'Enter a valid landlord_id');
      return;
    }

    await _run(() async {
      final data = await AdminReportsService.landlordMonthlySummary(
        landlordId: landlordId,
        year: _year,
        month: _month,
      );
      setState(() => _landlordSummary = data);
    });
  }

  Future<void> _loadPropertyStatus() async {
    final propertyId = _intOf(_propertyIdCtrl);
    if (propertyId <= 0) {
      setState(() => _error = 'Enter a valid property_id');
      return;
    }
    final period = _period.trim();
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(period)) {
      setState(() => _error = 'Period must be YYYY-MM');
      return;
    }

    await _run(() async {
      final data = await AdminReportsService.propertyStatus(
        propertyId: propertyId,
        period: period,
      );
      setState(() => _propertyStatus = data);
    });
  }

  Future<void> _loadPayouts() async {
    final landlordId = _intOf(_landlordIdCtrl);
    if (landlordId <= 0) {
      setState(() => _error = 'Enter a valid landlord_id (used for payouts list)');
      return;
    }

    await _run(() async {
      final rows = await AdminPayoutService.listPayoutsForLandlord(landlordId);
      setState(() => _payouts = rows);
    });
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
        title: const Text('Admin • Finance & Reports'),
        actions: [
          IconButton(
            tooltip: 'Copy API Base URL',
            icon: const Icon(LucideIcons.link),
            onPressed: () => _copy(AppConfig.apiBaseUrl, msg: 'API Base URL copied'),
          ),
          const SizedBox(width: 6),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(LucideIcons.barChart3), text: 'Landlord'),
            Tab(icon: Icon(LucideIcons.building2), text: 'Property'),
            Tab(icon: Icon(LucideIcons.fileText), text: 'Receipt'),
            Tab(icon: Icon(LucideIcons.arrowLeftRight), text: 'Payouts'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_loading)
            const LinearProgressIndicator(minHeight: 3),

          if (_error != null)
            Material(
              color: t.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertTriangle, color: t.colorScheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onErrorContainer),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      onPressed: () => setState(() => _error = null),
                      icon: Icon(Icons.close, color: t.colorScheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _tabLandlord(context),
                _tabProperty(context),
                _tabReceipt(context),
                _tabPayouts(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabLandlord(BuildContext context) {
    final t = Theme.of(context);

    final expected = (_landlordSummary?['expected_total'] as num?)?.toDouble() ?? 0.0;
    final received = (_landlordSummary?['received_total'] as num?)?.toDouble() ?? 0.0;
    final pending = (_landlordSummary?['pending_total'] as num?)?.toDouble() ?? 0.0;

    final props = (_landlordSummary?['properties'] as List?)?.cast<dynamic>() ?? [];
    final arrears = (_landlordSummary?['arrears'] as List?)?.cast<dynamic>() ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Monthly Summary (Landlord)', style: t.textTheme.titleLarge),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _landlordIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Landlord ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.user),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _year,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.calendar),
                ),
                items: List.generate(6, (i) => DateTime.now().year - i)
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (v) => setState(() => _year = v ?? _year),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _month,
                decoration: const InputDecoration(
                  labelText: 'Month',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.calendarDays),
                ),
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0'))))
                    .toList(),
                onChanged: (v) {
                  final m = v ?? _month;
                  setState(() {
                    _month = m;
                    _period = _yyyymm(_year, _month);
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _loadLandlordMonthly,
          icon: const Icon(LucideIcons.play),
          label: const Text('Load Monthly Summary'),
        ),

        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metricPill(context, label: 'Expected', value: 'KES ${expected.toStringAsFixed(2)}'),
            _metricPill(context, label: 'Received', value: 'KES ${received.toStringAsFixed(2)}'),
            _metricPill(context, label: 'Pending', value: 'KES ${pending.toStringAsFixed(2)}'),
          ],
        ),

        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(LucideIcons.download),
            title: const Text('Export'),
            subtitle: const Text('Copies the CSV/XLSX endpoint link to clipboard'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                final landlordId = _intOf(_landlordIdCtrl);
                if (landlordId <= 0) {
                  setState(() => _error = 'Enter a valid landlord_id first');
                  return;
                }
                final base = AppConfig.apiBaseUrl;
                final q = 'year=$_year&month=$_month';
                if (v == 'csv') {
                  await _copy('$base/reports/landlord/$landlordId/monthly-summary.csv?$q', msg: 'CSV link copied');
                } else {
                  await _copy('$base/reports/landlord/$landlordId/monthly-summary.xlsx?$q', msg: 'XLSX link copied');
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'csv', child: Text('Copy CSV link')),
                PopupMenuItem(value: 'xlsx', child: Text('Copy XLSX link')),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        Text('Per-Property Breakdown', style: t.textTheme.titleMedium),
        const SizedBox(height: 6),
        if (props.isEmpty)
          Text('No property rows yet.', style: t.textTheme.bodySmall?.copyWith(color: t.hintColor))
        else
          ...props.map((p) {
            final m = (p as Map).cast<String, dynamic>();
            return Card(
              child: ListTile(
                leading: const Icon(LucideIcons.building2),
                title: Text((m['name'] ?? '-').toString()),
                subtitle: Text(
                  'Expected: ${m['expected']} • Received: ${m['received']} • Pending: ${m['pending']}',
                ),
              ),
            );
          }),

        const SizedBox(height: 16),
        Text('Arrears (by lease)', style: t.textTheme.titleMedium),
        const SizedBox(height: 6),
        if (arrears.isEmpty)
          Text('No arrears found for this month.', style: t.textTheme.bodySmall?.copyWith(color: t.hintColor))
        else
          ...arrears.map((a) {
            final m = (a as Map).cast<String, dynamic>();
            return Card(
              child: ListTile(
                leading: const Icon(LucideIcons.alertCircle),
                title: Text((m['tenant_name'] ?? '-').toString()),
                subtitle: Text('Phone: ${m['phone']} • Balance: ${m['balance']} • Lease: ${m['lease_id']}'),
                trailing: IconButton(
                  tooltip: 'Copy Lease ID',
                  icon: const Icon(LucideIcons.copy),
                  onPressed: () => _copy('${m['lease_id']}', msg: 'Lease ID copied'),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _tabProperty(BuildContext context) {
    final t = Theme.of(context);

    final totals = (_propertyStatus?['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final expected = (totals['expected'] as num?)?.toDouble() ?? 0.0;
    final received = (totals['received'] as num?)?.toDouble() ?? 0.0;
    final pending = (totals['pending'] as num?)?.toDouble() ?? 0.0;

    final items = (_propertyStatus?['items'] as List?)?.cast<dynamic>() ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Property Monthly Status', style: t.textTheme.titleLarge),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _propertyIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Property ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.building2),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: _period)
                  ..selection = TextSelection.fromPosition(TextPosition(offset: _period.length)),
                decoration: const InputDecoration(
                  labelText: 'Period (YYYY-MM)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.calendar),
                ),
                onChanged: (v) => _period = v.trim(),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _loadPropertyStatus,
          icon: const Icon(LucideIcons.play),
          label: const Text('Load Property Status'),
        ),

        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metricPill(context, label: 'Expected', value: 'KES ${expected.toStringAsFixed(2)}'),
            _metricPill(context, label: 'Received', value: 'KES ${received.toStringAsFixed(2)}'),
            _metricPill(context, label: 'Pending', value: 'KES ${pending.toStringAsFixed(2)}'),
          ],
        ),

        const SizedBox(height: 16),
        Text('Units', style: t.textTheme.titleMedium),
        const SizedBox(height: 6),

        if (items.isEmpty)
          Text('No unit rows yet.', style: t.textTheme.bodySmall?.copyWith(color: t.hintColor))
        else
          ...items.map((it) {
            final m = (it as Map).cast<String, dynamic>();

            final unit = (m['unit_number'] ?? m['unit_id'] ?? '-').toString();
            final tenant = (m['tenant_name'] ?? '-').toString();
            final phone = (m['tenant_phone'] ?? '-').toString();
            final status = (m['status'] ?? 'pending').toString();
            final expected = (m['expected'] ?? 0).toString();
            final paid = (m['amount_paid'] ?? 0).toString();
            final due = (m['amount_due'] ?? 0).toString();

            final isPaid = status.toLowerCase() == 'paid';

            return Card(
              child: ListTile(
                leading: Icon(isPaid ? LucideIcons.badgeCheck : LucideIcons.clock),
                title: Text('Unit $unit • ${isPaid ? "PAID" : "PENDING"}'),
                subtitle: Text(
                  'Tenant: $tenant ($phone)\nExpected: $expected • Paid: $paid • Due: $due',
                ),
                isThreeLine: true,
              ),
            );
          }),
      ],
    );
  }

  Widget _tabReceipt(BuildContext context) {
    final t = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Payment Receipt PDF', style: t.textTheme.titleLarge),
        const SizedBox(height: 10),

        TextField(
          controller: _paymentIdCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Payment ID',
            border: OutlineInputBorder(),
            prefixIcon: Icon(LucideIcons.fileText),
          ),
        ),

        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () async {
            final pid = _intOf(_paymentIdCtrl);
            if (pid <= 0) {
              setState(() => _error = 'Enter a valid payment_id');
              return;
            }
            final url = '${AppConfig.apiBaseUrl}/payments/receipt/$pid.pdf';
            await _copy(url, msg: 'Receipt link copied (paste in browser)');
          },
          icon: const Icon(LucideIcons.copy),
          label: const Text('Copy Receipt PDF Link'),
        ),

        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: const Icon(LucideIcons.info),
            title: const Text('How to use'),
            subtitle: const Text(
              'Paste the copied link in a browser. Your backend requires auth for tenant/landlord; admin should be allowed by default.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabPayouts(BuildContext context) {
    final t = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Payouts (Landlord)', style: t.textTheme.titleLarge),
        const SizedBox(height: 10),

        TextField(
          controller: _landlordIdCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Landlord ID (used here)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(LucideIcons.user),
          ),
        ),

        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _loadPayouts,
          icon: const Icon(LucideIcons.play),
          label: const Text('Load Payouts'),
        ),

        const SizedBox(height: 14),
        if (_payouts.isEmpty)
          Text('No payouts loaded.', style: t.textTheme.bodySmall?.copyWith(color: t.hintColor))
        else
          ..._payouts.map((p) {
            final id = (p['id'] as num?)?.toInt() ?? 0;
            final status = (p['status'] ?? 'unknown').toString();
            final amount = (p['amount'] ?? 0).toString();
            final created = (p['created_at'] ?? '').toString();

            return Card(
              child: ListTile(
                leading: const Icon(LucideIcons.arrowLeftRight),
                title: Text('Payout #$id • $status'),
                subtitle: Text('Amount: $amount\nCreated: $created'),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Copy Payout JSON',
                  icon: const Icon(LucideIcons.copy),
                  onPressed: () => _copy(jsonEncode(p), msg: 'Payout JSON copied'),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _metricPill(BuildContext context, {required String label, required String value}) {
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
          Text('$label:', style: t.textTheme.labelMedium),
          const SizedBox(width: 8),
          Text(value, style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}