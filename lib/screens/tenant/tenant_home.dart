// tenant_home.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property_manager_frontend/services/tenant_portal_service.dart';
import 'package:property_manager_frontend/services/tenant_service.dart';
import 'package:property_manager_frontend/services/payment_service.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';
import 'package:property_manager_frontend/services/lease_service.dart';

class TenantHome extends StatefulWidget {
  const TenantHome({super.key});

  @override
  State<TenantHome> createState() => _TenantHomeState();
}

class _TenantHomeState extends State<TenantHome>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = true;

  Map<String, dynamic> _dashboard = const <String, dynamic>{};
  List<dynamic> _payments = const [];
  List<dynamic> _tickets = const [];
  List<dynamic> _myLeases = const [];

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _idCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      if (mounted) setState(() => _loading = true);

      final role = await TokenManager.currentRole();
      if (role != 'tenant') {
        _showSnack('Please log in as a tenant.');
        return;
      }

      try {
        final dash = await TenantPortalService.getOverview();
        _dashboard =
            (dash is Map) ? dash.cast<String, dynamic>() : <String, dynamic>{};
      } catch (_) {
        _dashboard = const <String, dynamic>{};
      }

      try {
        final pays = await TenantPortalService.getPayments();
        _payments = pays;
      } catch (_) {
        _payments = const [];
      }

      try {
        final mnts = await TenantPortalService.getMaintenance();
        _tickets = mnts;
      } catch (_) {
        _tickets = const [];
      }

      try {
        final leases = await LeaseService.listLeasesForCurrentUser();
        _myLeases = leases;
      } catch (_) {
        _myLeases = const [];
      }

      try {
        final profile = await TenantPortalService.getProfile();
        final p = (profile is Map)
            ? profile.cast<String, dynamic>()
            : <String, dynamic>{};

        _nameCtrl.text = (p['name'] ?? '').toString();
        _phoneCtrl.text = (p['phone'] ?? '').toString();
        _emailCtrl.text = (p['email'] ?? '').toString();
        _idCtrl.text = (p['id_number'] ?? '').toString();
      } catch (_) {}

      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) {
        debugPrint('[TenantHome] Snack skipped: no ScaffoldMessenger -> $message');
        return;
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    });
  }

  Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

  List<Map<String, dynamic>> _asMapList(dynamic v) {
    if (v is! List) return const <Map<String, dynamic>>[];
    return v
        .map<Map<String, dynamic>>(
          (e) => e is Map ? e.cast<String, dynamic>() : <String, dynamic>{},
        )
        .toList();
  }

  bool _isTrue(dynamic v) =>
      v == true || v == 1 || v?.toString().toLowerCase() == 'true';

  int? _leaseIdFromMap(Map<String, dynamic> lease) {
    final raw = lease['id'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  num _toNum(dynamic v, [num fallback = 0]) {
    if (v == null) return fallback;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? fallback;
  }

  String _fmtMoney(dynamic v) {
    if (v == null) return 'KES 0.00';
    final n = num.tryParse(v.toString());
    if (n == null) return v.toString();
    return 'KES ${n.toStringAsFixed(2)}';
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    if (s.isEmpty) return '—';
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    return DateFormat.yMMMd().format(d);
  }

  String _fmtDateTime(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    if (s.isEmpty) return '—';
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    return DateFormat('dd MMM yyyy • HH:mm').format(d.toLocal());
  }

  String _prettyMonth(String yyyymm) {
    try {
      final parts = yyyymm.split('-');
      final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
      return DateFormat.yMMM().format(d);
    } catch (_) {
      return yyyymm;
    }
  }

  Map<String, dynamic> _paymentNotesMap(Map<String, dynamic> payment) {
    final raw = payment['notes'];
    if (raw == null) return <String, dynamic>{};

    if (raw is Map) {
      return raw.cast<String, dynamic>();
    }

    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } catch (_) {}
    }

    return <String, dynamic>{};
  }

  Future<void> _openLeaseView(int leaseId) async {
    await Navigator.pushNamed(
      context,
      '/lease-view',
      arguments: {'leaseId': leaseId},
    );
    await _loadAll();
  }

  Future<void> _downloadLease(int leaseId) async {
    try {
      await LeaseService.downloadLeasePdf(leaseId);
      _showSnack('Lease download started');
    } catch (e) {
      _showSnack('Lease download failed: $e');
    }
  }

  Future<void> _submitMaintenance() async {
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Maintenance Request'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 440,
            child: TextFormField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Describe the issue',
                hintText: 'e.g. kitchen sink leaking, power socket fault',
              ),
              maxLines: 5,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await TenantPortalService.createMaintenance(
                  description: descCtrl.text.trim(),
                );
                if (!mounted) return;
                Navigator.pop(context);
                _showSnack('Request submitted');
                final m = await TenantPortalService.getMaintenance();
                setState(() => _tickets = m);
              } catch (e) {
                _showSnack('Submit failed: $e');
              }
            },
            icon: const Icon(Icons.send_rounded),
            label: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    try {
      final id = await TokenManager.currentUserId();
      if (id == null) throw Exception('Missing user id');

      await TenantService.updateTenant(
        tenantId: id,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        idNumber: _idCtrl.text.trim().isEmpty ? null : _idCtrl.text.trim(),
      );

      _showSnack('Profile updated');
    } catch (e) {
      _showSnack('Update failed: $e');
    }
  }

  Future<void> _openPayDialog() async {
    final d = _asMap(_dashboard);
    final lease = _asMap(d['lease']);
    final planner = _asMap(d['planner']);
    final thisMonth = _asMap(d['this_month']);

    final leaseId = _leaseIdFromMap(lease);
    if (leaseId == null) {
      _showSnack('No active lease found');
      return;
    }

    final rows = _asMapList(planner['rows']);
    final suggestedPeriods =
        (planner['suggested_periods'] is List ? planner['suggested_periods'] : [])
            .map((e) => e.toString())
            .toList();

    final prompt = (planner['prompt'] ?? '').toString();
    final expected = _toNum(thisMonth['expected'], 0);

    final selected = <String>{...suggestedPeriods};

    final amountCtrl = TextEditingController(
      text: expected > 0 ? expected.toStringAsFixed(2) : '',
    );
    final phoneCtrl = TextEditingController();
    bool processing = false;

    await showDialog(
      context: context,
      barrierDismissible: !processing,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final chosenRows = rows
                .where((r) => selected.contains((r['period'] ?? '').toString()))
                .toList();

            final suggestedAmount = chosenRows.fold<num>(
              0,
              (sum, r) => sum + _toNum(r['balance'], 0),
            );

            if ((amountCtrl.text.isEmpty || amountCtrl.text == '0.00') &&
                suggestedAmount > 0) {
              amountCtrl.text = suggestedAmount.toStringAsFixed(2);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text('Make Rent Payment'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (prompt.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lightbulb_rounded,
                                color: Color(0xFF1E88E5),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  prompt,
                                  style: const TextStyle(height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Select the month(s) you want to pay for',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 280),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: rows.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('No planner periods available.'),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: rows.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final row = rows[i];
                                  final period =
                                      (row['period'] ?? '').toString();
                                  final status =
                                      (row['status'] ?? '').toString();
                                  final balance = _toNum(row['balance'], 0);
                                  final received = _toNum(row['received'], 0);
                                  final expected = _toNum(row['expected'], 0);
                                  final checked = selected.contains(period);
                                  final selectable = balance > 0 || checked;

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: selectable
                                        ? () {
                                            setLocal(() {
                                              if (checked) {
                                                selected.remove(period);
                                              } else {
                                                selected.add(period);
                                              }
                                            });
                                          }
                                        : null,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: checked
                                            ? const Color(0xFFEFF6FF)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: checked
                                              ? const Color(0xFF93C5FD)
                                              : const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: checked,
                                            onChanged: selectable
                                                ? (_) {
                                                    setLocal(() {
                                                      if (checked) {
                                                        selected.remove(period);
                                                      } else {
                                                        selected.add(period);
                                                      }
                                                    });
                                                  }
                                                : null,
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _prettyMonth(period),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: <Widget>[
                                                    _miniBadge(
                                                      'Expected ${_fmtMoney(expected)}',
                                                      const Color(0xFFF1F5F9),
                                                      const Color(0xFF334155),
                                                    ),
                                                    _miniBadge(
                                                      'Paid ${_fmtMoney(received)}',
                                                      const Color(0xFFECFDF5),
                                                      const Color(0xFF166534),
                                                    ),
                                                    _miniBadge(
                                                      balance > 0
                                                          ? 'Balance ${_fmtMoney(balance)}'
                                                          : 'Cleared',
                                                      balance > 0
                                                          ? const Color(0xFFFEF2F2)
                                                          : const Color(0xFFEFF6FF),
                                                      balance > 0
                                                          ? const Color(0xFF991B1B)
                                                          : const Color(0xFF1D4ED8),
                                                    ),
                                                    _miniBadge(
                                                      status.toUpperCase(),
                                                      const Color(0xFFF8FAFC),
                                                      const Color(0xFF475569),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Summary',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text('Months selected: ${selected.length}'),
                            const SizedBox(height: 4),
                            Text(
                              'Suggested amount: ${_fmtMoney(suggestedAmount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              selected.isEmpty
                                  ? 'No periods selected'
                                  : selected.map(_prettyMonth).join(', '),
                              style: const TextStyle(color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Amount to pay',
                          hintText: 'Enter amount',
                          helperText: suggestedAmount > 0
                              ? 'Suggested: ${_fmtMoney(suggestedAmount)}'
                              : 'You can enter a partial amount if agreed with landlord',
                          prefixIcon: const Icon(Icons.payments_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'M-Pesa phone (optional)',
                          hintText: 'Uses your account phone if left empty',
                          prefixIcon: Icon(Icons.phone_android_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: processing ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: processing
                      ? null
                      : () async {
                          final amount =
                              num.tryParse(amountCtrl.text.trim()) ?? 0;
                          final periods = selected.toList()..sort();

                          if (periods.isEmpty) {
                            _showSnack('Select at least one month');
                            return;
                          }
                          if (amount <= 0) {
                            _showSnack('Enter a valid amount');
                            return;
                          }

                          final confirmed = await showDialog<bool>(
                            context: dialogCtx,
                            builder: (confirmCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: const Text('Confirm Payment'),
                              content: Text(
                                'You are about to pay ${_fmtMoney(amount)} for '
                                '${periods.length} month(s):\n\n'
                                '${periods.map(_prettyMonth).join(', ')}\n\n'
                                'Continue with M-Pesa STK push?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(confirmCtx, false),
                                  child: const Text('No'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(confirmCtx, true),
                                  child: const Text('Yes, Continue'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed != true) return;

                          setLocal(() => processing = true);
                          try {
                            final res = await PaymentService.initiateMpesa(
                              leaseId: leaseId,
                              amount: amount,
                              phone: phoneCtrl.text.trim().isEmpty
                                  ? null
                                  : phoneCtrl.text.trim(),
                              periods: periods,
                            );

                            if (!mounted) return;
                            Navigator.pop(dialogCtx);
                            _showSnack(
                              'STK sent. Ref: ${res['checkout_request_id'] ?? '—'}',
                            );
                            await _loadAll();
                          } catch (e) {
                            setLocal(() => processing = false);
                            _showSnack('Payment start failed: $e');
                          }
                        },
                  icon: processing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.credit_card_rounded),
                  label: Text(processing ? 'Processing...' : 'Proceed'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _miniBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final now = DateTime.now();
    final ym = DateFormat.yMMMM().format(DateTime(now.year, now.month, 1));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tenant Portal',
                              style: t.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ym,
                              style: t.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _loadAll,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TabBar(
                        controller: _tab,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: const Color(0xFF0F172A),
                        unselectedLabelColor: Colors.white70,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        tabs: const [
                          Tab(
                            text: 'Dashboard',
                            icon: Icon(Icons.dashboard_customize_rounded, size: 18),
                          ),
                          Tab(
                            text: 'Payments',
                            icon: Icon(Icons.receipt_long_rounded, size: 18),
                          ),
                          Tab(
                            text: 'Maintenance',
                            icon: Icon(Icons.build_rounded, size: 18),
                          ),
                          Tab(
                            text: 'Profile',
                            icon: Icon(Icons.person_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tab,
                      children: <Widget>[
                        _dashboardTab(context, t),
                        _paymentsTab(context, t),
                        _maintenanceTab(context, t),
                        _profileTab(context, t),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardTab(BuildContext context, ThemeData t) {
    final d = _asMap(_dashboard);
    final tenant = _asMap(d['tenant']);
    final unit = _asMap(d['unit']);
    final lease = _asMap(d['lease']);
    final thisMonth = _asMap(d['this_month']);
    final planner = _asMap(d['planner']);

    final unitLabel = (unit['number'] ?? '—').toString();
    final propertyName = (unit['property_name'] ?? 'Your Property').toString();
    final rentAmount = _fmtMoney(lease['rent_amount']);
    final paid = _isTrue(thisMonth['paid']);
    final statusText =
        (thisMonth['status'] ?? (paid ? 'paid' : 'unpaid')).toString();

    final activeLease = _myLeases.isNotEmpty
        ? _asMap(_myLeases.first)
        : (lease.isNotEmpty ? lease : <String, dynamic>{});
    final activeLeaseId = _leaseIdFromMap(activeLease);

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _heroCard(
            name: (tenant['name'] ?? 'Tenant').toString(),
            propertyName: propertyName,
            unitLabel: unitLabel,
            rentAmount: rentAmount,
            paid: paid,
            statusText: statusText,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _kpiCard(
                icon: Icons.request_quote_rounded,
                label: 'Expected',
                value: _fmtMoney(thisMonth['expected']),
                accent: const Color(0xFF1D4ED8),
                soft: const Color(0xFFDBEAFE),
              ),
              _kpiCard(
                icon: Icons.payments_rounded,
                label: 'Received',
                value: _fmtMoney(thisMonth['received']),
                accent: const Color(0xFF047857),
                soft: const Color(0xFFD1FAE5),
              ),
              _kpiCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Balance',
                value: _fmtMoney(thisMonth['balance']),
                accent: const Color(0xFFB45309),
                soft: const Color(0xFFFEF3C7),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _plannerCard(t, planner),
          const SizedBox(height: 16),
          if (activeLease.isNotEmpty)
            _leaseCard(
              context: context,
              theme: t,
              activeLease: activeLease,
              activeLeaseId: activeLeaseId,
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _openPayDialog,
                icon: const Icon(Icons.credit_card_rounded),
                label: const Text('Pay Rent'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _submitMaintenance,
                icon: const Icon(Icons.build_rounded),
                label: const Text('Request Maintenance'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroCard({
    required String name,
    required String propertyName,
    required String unitLabel,
    required String rentAmount,
    required bool paid,
    required String statusText,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withOpacity(.12),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  runSpacing: 12,
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: paid
                      ? Colors.greenAccent.withOpacity(.18)
                      : Colors.orangeAccent.withOpacity(.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: paid
                        ? Colors.greenAccent.withOpacity(.25)
                        : Colors.orangeAccent.withOpacity(.25),
                  ),
                ),
                child: Text(
                  statusText.toUpperCase(),
                  style: TextStyle(
                    color: paid ? Colors.greenAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Wrap(
              spacing: 18,
              runSpacing: 14,
              children: [
                _heroMeta(
                  Icons.domain_rounded,
                  'Property',
                  propertyName,
                ),
                _heroMeta(
                  Icons.meeting_room_rounded,
                  'Unit',
                  unitLabel,
                ),
                _heroMeta(
                  Icons.payments_rounded,
                  'Monthly Rent',
                  rentAmount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroMeta(IconData icon, String label, String value) {
    return SizedBox(
      width: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
    required Color soft,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            color: Colors.black.withOpacity(.04),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _plannerCard(ThemeData t, Map<String, dynamic> planner) {
    final rows = _asMapList(planner['rows']);
    final suggested = (planner['suggested_periods'] is List
            ? planner['suggested_periods']
            : <dynamic>[])
        .map<String>((e) => e.toString())
        .toList();

    final prompt = (planner['prompt'] ?? '').toString();

    final List<Widget> suggestedWidgets = suggested
        .map<Widget>(
          (m) => _miniBadge(
            'Suggested • ${_prettyMonth(m)}',
            const Color(0xFFEFF6FF),
            const Color(0xFF1D4ED8),
          ),
        )
        .toList();

    final List<Widget> rowWidgets = rows
        .take(6)
        .map<Widget>((r) {
          final period = (r['period'] ?? '').toString();
          final status = (r['status'] ?? '').toString();
          final expected = _fmtMoney(r['expected']);
          final received = _fmtMoney(r['received']);
          final balance = _fmtMoney(r['balance']);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFCFCFD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _prettyMonth(period),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: <Widget>[
                        _miniBadge(
                          expected,
                          const Color(0xFFF1F5F9),
                          const Color(0xFF334155),
                        ),
                        _miniBadge(
                          'Paid $received',
                          const Color(0xFFECFDF5),
                          const Color(0xFF166534),
                        ),
                        _miniBadge(
                          'Balance $balance',
                          const Color(0xFFFEF2F2),
                          const Color(0xFF991B1B),
                        ),
                        _miniBadge(
                          status.toUpperCase(),
                          const Color(0xFFF8FAFC),
                          const Color(0xFF475569),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        })
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            color: Colors.black.withOpacity(.04),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Payment Planner',
                  style: t.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openPayDialog,
                icon: const Icon(Icons.credit_card_rounded),
                label: const Text('Pay'),
              ),
            ],
          ),
          if (prompt.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_rounded,
                    color: Color(0xFF1E88E5),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      prompt,
                      style: const TextStyle(
                        height: 1.4,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (suggestedWidgets.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestedWidgets,
            ),
          if (rowWidgets.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            ...rowWidgets,
          ],
        ],
      ),
    );
  }

  Widget _leaseCard({
    required BuildContext context,
    required ThemeData theme,
    required Map<String, dynamic> activeLease,
    required int? activeLeaseId,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            color: Colors.black.withOpacity(.04),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: Color(0xFF1E40AF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Active Lease',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isTrue(activeLease['active'])
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isTrue(activeLease['active']) ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _isTrue(activeLease['active'])
                        ? const Color(0xFF166534)
                        : const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _leaseMetaChip(
                theme,
                Icons.payments_rounded,
                'Rent: ${_fmtMoney(activeLease['rent_amount'])}',
              ),
              _leaseMetaChip(
                theme,
                Icons.event_rounded,
                'Start: ${_fmtDate(activeLease['start_date'])}',
              ),
              _leaseMetaChip(
                theme,
                Icons.event_busy_rounded,
                'End: ${_fmtDate(activeLease['end_date'])}',
              ),
            ],
          ),
          if (activeLeaseId != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _openLeaseView(activeLeaseId),
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('View Lease'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _downloadLease(activeLeaseId),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Download PDF'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _leaseMetaChip(ThemeData t, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest.withOpacity(.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: t.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: t.textTheme.labelMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentsTab(BuildContext context, ThemeData t) {
    if (_payments.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Text(
            'No payments yet — your rent history will appear here once you start paying.',
          ),
        ),
      );
    }

    final items = List<Map<String, dynamic>>.from(
      _payments.map(
        (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
      ),
    )..sort((a, b) {
        final aCreated =
            DateTime.tryParse((a['created_at'] ?? '').toString()) ??
                DateTime(1970);
        final bCreated =
            DateTime.tryParse((b['created_at'] ?? '').toString()) ??
                DateTime(1970);
        return bCreated.compareTo(aCreated);
      });

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final p = items[i];
          final period = (p['period'] ?? '').toString();
          final amount = _fmtMoney(p['amount']);
          final date = _fmtDate(p['paid_date']);
          final createdAt = _fmtDateTime(p['created_at']);
          final ref = (p['reference'] ?? '').toString();
          final method = (p['payment_method'] ?? 'Payment').toString();
          final status = (p['status'] ?? 'paid').toString().toLowerCase();
          final id = (p['id'] as num?)?.toInt();
          final allocations = _asMapList(p['allocations']);

          final notes = _paymentNotesMap(p);
          final mpesaReceipt = (notes['mpesa_receipt_number'] ?? ref).toString();
          final mpesaPhone = (notes['mpesa_phone_number'] ?? '').toString();
          final mpesaTxTime = (notes['mpesa_transaction_date_iso'] ?? '').toString();
          final merchantRequestId =
              (notes['merchant_request_id'] ?? p['merchant_request_id'] ?? '').toString();
          final checkoutRequestId =
              (notes['checkout_request_id'] ?? p['checkout_request_id'] ?? '').toString();

          final isPaid = status == 'paid';
          final statusBg = isPaid
              ? const Color(0xFFECFDF5)
              : const Color(0xFFFEF2F2);
          final statusFg = isPaid
              ? const Color(0xFF166534)
              : const Color(0xFF991B1B);

          final List<Widget> allocationWidgets = allocations
              .map<Widget>(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _prettyMonth((a['period'] ?? '').toString()),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          _fmtMoney(a['amount_applied']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList();

          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                  color: Colors.black.withOpacity(.04),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 24,
                        color: Color(0xFF1E88E5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            amount,
                            style: t.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_prettyMonth(period)} • $method',
                            style: t.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusFg,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _metaChip(
                      Icons.event_available_rounded,
                      'Paid: $date',
                    ),
                    _metaChip(
                      Icons.schedule_rounded,
                      'Logged: $createdAt',
                    ),
                    _metaChip(
                      Icons.numbers_rounded,
                      'Ref: ${mpesaReceipt.isEmpty ? '—' : mpesaReceipt}',
                    ),
                    if (mpesaPhone.isNotEmpty)
                      _metaChip(
                        Icons.phone_android_rounded,
                        'Phone: $mpesaPhone',
                      ),
                    if (mpesaTxTime.isNotEmpty)
                      _metaChip(
                        Icons.access_time_rounded,
                        'Tx Time: ${_fmtDateTime(mpesaTxTime)}',
                      ),
                  ],
                ),
                if (merchantRequestId.isNotEmpty || checkoutRequestId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'M-Pesa Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (merchantRequestId.isNotEmpty)
                          Text('Merchant Request ID: $merchantRequestId'),
                        if (checkoutRequestId.isNotEmpty)
                          Text('Checkout Request ID: $checkoutRequestId'),
                      ],
                    ),
                  ),
                ],
                if (allocationWidgets.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    'Allocation Breakdown',
                    style: t.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...allocationWidgets,
                ],
                if (isPaid && id != null) ...<Widget>[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      try {
                        final bytes =
                            await PaymentService.downloadReceiptPdf(id);
                        _showSnack(
                          'Receipt downloaded: ${bytes.length} bytes',
                        );
                      } catch (e) {
                        _showSnack('Receipt download failed: $e');
                      }
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Receipt (PDF)'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _maintenanceTab(BuildContext context, ThemeData t) {
    final List<Widget> ticketWidgets = _tickets.map<Widget>((it) {
      final m =
          (it is Map) ? it.cast<String, dynamic>() : <String, dynamic>{};
      final description =
          (m['description'] ?? 'Maintenance request').toString();
      final status = (m['status'] ?? 'open').toString().toLowerCase();
      final created = _fmtDateTime(m['created_at']);

      final chipBg = (status == 'resolved' || status == 'closed')
          ? const Color(0xFFECFDF5)
          : const Color(0xFFEFF6FF);
      final chipFg = (status == 'resolved' || status == 'closed')
          ? const Color(0xFF166534)
          : const Color(0xFF1D4ED8);

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                color: Colors.black.withOpacity(.04),
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.build_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      created,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: chipFg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: [
            Expanded(
              child: Text(
                'Maintenance Requests',
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _submitMaintenance,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Request'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (ticketWidgets.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text('No maintenance requests yet.')
          )
        else
          ...ticketWidgets,
      ],
    );
  }

  Widget _profileTab(BuildContext context, ThemeData t) {
    final formKey = GlobalKey<FormState>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Profile & Contact Information',
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                color: Colors.black.withOpacity(.04),
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    prefixIcon: Icon(Icons.email_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _idCtrl,
                  decoration: const InputDecoration(
                    labelText: 'National ID (optional)',
                    prefixIcon: Icon(Icons.badge_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      _saveProfile();
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}