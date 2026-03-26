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
  List<Map<String, dynamic>> _rentals = const [];

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
        if (mounted) {
          setState(() => _loading = false);
        }
        _showSnack('Please log in as a tenant.');
        return;
      }

      try {
        final dash = await TenantPortalService.getOverview();
        _dashboard =
            (dash is Map) ? dash.cast<String, dynamic>() : <String, dynamic>{};

        final rentalsRaw = _dashboard['rentals'];
        if (rentalsRaw is List) {
          _rentals = rentalsRaw
              .map<Map<String, dynamic>>(
                (e) => e is Map ? e.cast<String, dynamic>() : <String, dynamic>{},
              )
              .toList();
        } else {
          _rentals = const [];
        }
      } catch (_) {
        _dashboard = const <String, dynamic>{};
        _rentals = const [];
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

        final tenant = _asMap(p['tenant']).isNotEmpty ? _asMap(p['tenant']) : p;

        _nameCtrl.text = (tenant['name'] ?? '').toString();
        _phoneCtrl.text = (tenant['phone'] ?? '').toString();
        _emailCtrl.text = (tenant['email'] ?? '').toString();
        _idCtrl.text = (tenant['id_number'] ?? '').toString();
      } catch (_) {}

      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await TokenManager.clearSession();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
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

  List<String> _asStringList(dynamic v) {
    if (v is! List) return const <String>[];
    return List<String>.from(v.map((e) => e.toString()));
  }

  bool _isTrue(dynamic v) =>
      v == true || v == 1 || v?.toString().toLowerCase() == 'true';

  int? _leaseIdFromMap(Map<String, dynamic> lease) {
    final raw = lease['id'] ?? lease['lease_id'];
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

  Future<void> _submitMaintenance({int? leaseId}) async {
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
                  leaseId: leaseId,
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

  Future<void> _openPayDialogForRental(Map<String, dynamic> rental) async {
    final lease = _asMap(rental['lease']).isNotEmpty
        ? _asMap(rental['lease'])
        : <String, dynamic>{
            'id': rental['lease_id'],
            'rent_amount': rental['rent_amount'],
            'start_date': rental['start_date'],
            'end_date': rental['end_date'],
            'active': rental['active'],
          };

    final planner = _asMap(rental['planner']);
    final thisMonth = _asMap(rental['this_month']);

    final leaseId = _leaseIdFromMap(lease);
    if (leaseId == null) {
      _showSnack('No active lease found');
      return;
    }

    final rows = _asMapList(planner['rows']);
    final suggestedPeriods = _asStringList(planner['suggested_periods']);

    final prompt = (planner['prompt'] ?? '').toString();
    final expected = _toNum(thisMonth['expected'], 0);

    final selected = <String>{...suggestedPeriods};

    final amountCtrl = TextEditingController(
      text: expected > 0 ? expected.toStringAsFixed(2) : '',
    );
    final phoneCtrl = TextEditingController();

    bool processing = false;
    bool amountManuallyEdited = false;

    num calcSuggestedAmount(Set<String> periods) {
      final chosenRows = rows
          .where((r) => periods.contains((r['period'] ?? '').toString()))
          .toList();

      return chosenRows.fold<num>(
        0,
        (sum, r) => sum + _toNum(r['balance'], 0),
      );
    }

    void syncAmountIfNotManual(void Function(void Function()) setLocal) {
      final suggestedAmount = calcSuggestedAmount(selected);
      if (!amountManuallyEdited) {
        setLocal(() {
          amountCtrl.text =
              suggestedAmount > 0 ? suggestedAmount.toStringAsFixed(2) : '';
        });
      }
    }

    Future<void> pollForPaymentUpdate() async {
      for (int i = 0; i < 8; i++) {
        await Future.delayed(const Duration(seconds: 3));
        try {
          await _loadAll();

          final items = List<Map<String, dynamic>>.from(
            _payments.map(
              (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
            ),
          );

          final recent = items.isNotEmpty ? items.first : null;
          if (recent != null) {
            final status = (recent['status'] ?? '').toString().toLowerCase();
            final ref = (recent['reference'] ?? '').toString();
            if (status == 'paid' || ref.isNotEmpty) {
              if (mounted) {
                _showSnack('Payment confirmed successfully.');
              }
              return;
            }
          }
        } catch (_) {}
      }
    }

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
                                            syncAmountIfNotManual(setLocal);
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
                                                    syncAmountIfNotManual(setLocal);
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
                        onChanged: (_) {
                          amountManuallyEdited = true;
                        },
                        decoration: InputDecoration(
                          labelText: 'Amount to pay',
                          hintText: 'Enter amount',
                          helperText: suggestedAmount > 0
                              ? 'Suggested: ${_fmtMoney(suggestedAmount)}'
                              : 'You can enter a partial amount if agreed with landlord',
                          prefixIcon: const Icon(Icons.payments_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Reset to suggested amount',
                            icon: const Icon(Icons.refresh_rounded),
                            onPressed: () {
                              amountManuallyEdited = false;
                              syncAmountIfNotManual(setLocal);
                            },
                          ),
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
                            await pollForPaymentUpdate();
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

  Widget _heroCard({
    required String name,
    required int activeRentals,
    required String expected,
    required String received,
    required String balance,
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
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _heroMeta(Icons.home_work_rounded, 'Active Rentals', '$activeRentals'),
              _heroMeta(Icons.request_quote_rounded, 'Expected', expected),
              _heroMeta(Icons.payments_rounded, 'Received', received),
              _heroMeta(Icons.account_balance_wallet_rounded, 'Balance', balance),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMeta(IconData icon, String label, String value) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
      ),
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

  Widget _rentalCard(BuildContext context, ThemeData t, Map<String, dynamic> rental) {
    final property = _asMap(rental['property']).isNotEmpty
        ? _asMap(rental['property'])
        : _asMap(rental['unit']);
    final unit = _asMap(rental['unit']);
    final thisMonth = _asMap(rental['this_month']);
    final planner = _asMap(rental['planner']);

    final leaseId = _leaseIdFromMap(rental);
    final propertyName =
        (property['name'] ?? property['property_name'] ?? 'Property').toString();
    final propertyCode =
        (property['property_code'] ?? unit['property_code'] ?? '—').toString();
    final unitNumber =
        (unit['number'] ?? unit['unit_number'] ?? '—').toString();
    final rent = _fmtMoney(rental['rent_amount'] ?? thisMonth['expected']);
    final balance = _fmtMoney(thisMonth['balance']);
    final paid = _isTrue(thisMonth['paid']);
    final statusText =
        (thisMonth['status'] ?? (paid ? 'paid' : 'unpaid')).toString();

    final List<String> suggested = _asStringList(planner['suggested_periods']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 10,
            spacing: 10,
            children: [
              SizedBox(
                width: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      propertyName,
                      style: t.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _miniBadge(
                          'Code: $propertyCode',
                          const Color(0xFFF1F5F9),
                          const Color(0xFF334155),
                        ),
                        _miniBadge(
                          'Unit: $unitNumber',
                          const Color(0xFFEFF6FF),
                          const Color(0xFF1D4ED8),
                        ),
                        _miniBadge(
                          statusText.toUpperCase(),
                          paid
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEF2F2),
                          paid
                              ? const Color(0xFF166534)
                              : const Color(0xFF991B1B),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This Month',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expected: ${_fmtMoney(thisMonth['expected'])}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Received: ${_fmtMoney(thisMonth['received'])}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Balance: $balance',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Rent: $rent',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text('Lease Start: ${_fmtDate(rental['start_date'])}'),
          Text('Lease End: ${_fmtDate(rental['end_date'])}'),
          if (suggested.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggested
                  .map<Widget>(
                    (m) => _miniBadge(
                      'Suggested • ${_prettyMonth(m)}',
                      const Color(0xFFEFF6FF),
                      const Color(0xFF1D4ED8),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
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
                onPressed: () => _openPayDialogForRental(rental),
                icon: const Icon(Icons.credit_card_rounded),
                label: const Text('Pay This Rental'),
              ),
              if (leaseId != null)
                OutlinedButton.icon(
                  onPressed: () => _openLeaseView(leaseId),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('View Lease'),
                ),
              if (leaseId != null)
                OutlinedButton.icon(
                  onPressed: () => _downloadLease(leaseId),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
              if (leaseId != null)
                OutlinedButton.icon(
                  onPressed: () => _submitMaintenance(leaseId: leaseId),
                  icon: const Icon(Icons.build_rounded),
                  label: const Text('Maintenance'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(BuildContext context, ThemeData t, Map<String, dynamic> p) {
    final amount = _fmtMoney(p['amount']);
    final date = _fmtDate(p['paid_date']);
    final createdAt = _fmtDateTime(p['created_at']);
    final ref = (p['reference'] ?? '').toString();
    final propertyName = (p['property_name'] ?? '—').toString();
    final unitNumber = (p['unit_number'] ?? '—').toString();
    final status = (p['status'] ?? 'paid').toString().toLowerCase();

    final notes = _paymentNotesMap(p);
    final mpesaReceipt = (notes['mpesa_receipt_number'] ?? ref).toString();

    final allocations = _asMapList(p['allocations']);

    final isPaid = status == 'paid';
    final statusBg = isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final statusFg = isPaid ? const Color(0xFF166534) : const Color(0xFF991B1B);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 10,
            spacing: 10,
            children: [
              Text(
                '$propertyName • Unit $unitNumber',
                style: t.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusFg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Amount: $amount'),
          Text('Paid Date: $date'),
          Text('Created: $createdAt'),
          Text('Reference: ${mpesaReceipt.isEmpty ? "—" : mpesaReceipt}'),
          if (allocations.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allocations.map((a) {
                final period = (a['period'] ?? '').toString();
                final applied = _fmtMoney(a['amount_applied']);
                return _miniBadge(
                  '${_prettyMonth(period)} • $applied',
                  const Color(0xFFF1F5F9),
                  const Color(0xFF334155),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _maintenanceCard(BuildContext context, ThemeData t, Map<String, dynamic> m) {
    final status = (m['status'] ?? 'open').toString();
    final description = (m['description'] ?? '').toString();
    final created = _fmtDateTime(m['created_at']);
    final propertyName = (m['property_name'] ?? '').toString();
    final unitNumber = (m['unit_number'] ?? '').toString();

    Color chipBg;
    Color chipFg;
    switch (status.toLowerCase()) {
      case 'resolved':
        chipBg = const Color(0xFFECFDF5);
        chipFg = const Color(0xFF166534);
        break;
      case 'in_progress':
        chipBg = const Color(0xFFFEF3C7);
        chipFg = const Color(0xFF92400E);
        break;
      default:
        chipBg = const Color(0xFFEFF6FF);
        chipFg = const Color(0xFF1D4ED8);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                if (propertyName.isNotEmpty || unitNumber.isNotEmpty)
                  Text(
                    '${propertyName.isNotEmpty ? propertyName : "Property"}'
                    '${unitNumber.isNotEmpty ? " • Unit $unitNumber" : ""}',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 4),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacementNamed(context, '/dashboard');
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
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
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Logout'),
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
    final summary = _asMap(d['summary']);

    final activeCount = _toNum(
      summary['active_rentals_count'] ?? _rentals.length,
      _rentals.length,
    ).toInt();

    final expected = _fmtMoney(
      summary['this_month_expected'] ?? summary['total_expected'],
    );
    final received = _fmtMoney(
      summary['this_month_received'] ?? summary['total_received'],
    );
    final balance = _fmtMoney(
      summary['this_month_balance'] ?? summary['total_balance'],
    );

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _heroCard(
            name: (tenant['name'] ?? 'Tenant').toString(),
            activeRentals: activeCount,
            expected: expected,
            received: received,
            balance: balance,
          ),
          const SizedBox(height: 16),
          if (_rentals.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text('No active rentals found.'),
            )
          else
            ..._rentals.map<Widget>((r) => _rentalCard(context, t, r)).toList(),
        ],
      ),
    );
  }

  Widget _paymentsTab(BuildContext context, ThemeData t) {
    final items = List<Map<String, dynamic>>.from(
      _payments.map(
        (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
      ),
    );

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text('No payments yet.'),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: items.map((p) => _paymentCard(context, t, p)).toList(),
      ),
    );
  }

  Widget _maintenanceTab(BuildContext context, ThemeData t) {
    final List<Widget> ticketWidgets = List<Map<String, dynamic>>.from(
      _tickets.map(
        (e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{},
      ),
    ).map<Widget>((m) => _maintenanceCard(context, t, m)).toList();

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
              onPressed: () => _submitMaintenance(),
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
            child: const Text('No maintenance requests yet.'),
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
        const SizedBox(height: 16),
        Text(
          'My Rentals',
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (_rentals.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text('No active rentals found.'),
          )
        else
          ..._rentals.map<Widget>((r) => _rentalCard(context, t, r)).toList(),
      ],
    );
  }
}