import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property_manager_frontend/services/lease_service.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class LeaseViewScreen extends StatefulWidget {
  const LeaseViewScreen({super.key});

  @override
  State<LeaseViewScreen> createState() => _LeaseViewScreenState();
}

class _LeaseViewScreenState extends State<LeaseViewScreen> {
  bool _loading = true;
  Map<String, dynamic> _lease = {};
  int? _leaseId;
  String _role = 'tenant';

  @override
  void initState() {
    super.initState();
    Future.microtask(_init);
  }

  Future<void> _init() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['leaseId'] != null) {
      _leaseId = (args['leaseId'] as num).toInt();
    }
    _role = await TokenManager.currentRole() ?? 'tenant';

    if (_leaseId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing lease id')),
        );
        Navigator.pop(context);
      }
      return;
    }

    await _load();
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final res = await LeaseService.getLease(_leaseId!);
      if (!mounted) return;
      setState(() => _lease = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Load failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat.yMMMd().format(d);
  }

  String _fmtMoney(dynamic value) {
    if (value == null) return '—';
    final n = num.tryParse(value.toString());
    if (n == null) return value.toString();
    return 'KES ${n.toStringAsFixed(2)}';
  }

  String _v(dynamic value) {
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? '—' : s;
  }

  bool _isTrue(dynamic v) =>
      v == true || v == 1 || v?.toString().toLowerCase() == 'true';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Lease Details'),
        actions: [
          if (_leaseId != null)
            IconButton(
              tooltip: 'Download PDF',
              onPressed: () async {
                try {
                  await LeaseService.downloadLeasePdf(_leaseId!);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lease download started')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              },
              icon: const Icon(Icons.picture_as_pdf_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard(
                  t,
                  title: 'Parties',
                  children: [
                    _row(t, 'Tenant', _v(_lease['tenant_name'])),
                    _row(t, 'Tenant Phone', _v(_lease['tenant_phone'])),
                    _row(t, 'Tenant Email', _v(_lease['tenant_email'])),
                    _row(t, 'Tenant ID No.', _v(_lease['tenant_id_number'])),
                    const Divider(height: 20),
                    _row(t, 'Landlord', _v(_lease['landlord_name'])),
                    _row(t, 'Landlord Phone', _v(_lease['landlord_phone'])),
                    _row(t, 'Landlord Email', _v(_lease['landlord_email'])),
                    if ((_lease['manager_name'] ?? '').toString().isNotEmpty ||
                        (_lease['manager_company_name'] ?? '').toString().isNotEmpty) ...[
                      const Divider(height: 20),
                      _row(
                        t,
                        'Manager / Agency',
                        _v(
                          (_lease['manager_company_name'] ?? '').toString().isNotEmpty
                              ? _lease['manager_company_name']
                              : _lease['manager_name'],
                        ),
                      ),
                      _row(t, 'Manager Phone', _v(_lease['manager_phone'])),
                      _row(t, 'Manager Email', _v(_lease['manager_email'])),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  t,
                  title: 'Premises',
                  children: [
                    _row(t, 'Property', _v(_lease['property_name'])),
                    _row(t, 'Property Code', _v(_lease['property_code'])),
                    _row(t, 'Property Address', _v(_lease['property_address'])),
                    _row(t, 'Unit', _v(_lease['unit_number'])),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  t,
                  title: 'Lease Terms',
                  children: [
                    _row(t, 'Rent', _fmtMoney(_lease['rent_amount'])),
                    _row(t, 'Start Date', _fmtDate(_lease['start_date']?.toString())),
                    _row(t, 'End Date', _fmtDate(_lease['end_date']?.toString())),
                    _row(t, 'Status', _v(_lease['status']).toUpperCase()),
                    _row(
                      t,
                      'Terms Accepted',
                      _isTrue(_lease['terms_accepted']) ? 'YES' : 'NO',
                    ),
                    _row(
                      t,
                      'Accepted At',
                      _fmtDate(_lease['terms_accepted_at']?.toString()),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  t,
                  title: 'Terms & Conditions',
                  children: [
                    Text(
                      _v(_lease['terms_text']),
                      style: t.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_role == 'tenant') _tenantActions(t),
                if (_role == 'landlord') _landlordActions(t),
              ],
            ),
    );
  }

  Widget _tenantActions(ThemeData t) {
    final accepted = _isTrue(_lease['terms_accepted']);
    final active = _isTrue(_lease['active']);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!accepted)
          FilledButton(
            onPressed: () async {
              try {
                await LeaseService.acceptTerms(_leaseId!);
                await _load();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Terms accepted')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            },
            child: const Text('Accept Terms'),
          ),
        if (accepted && !active)
          FilledButton(
            onPressed: () async {
              try {
                await LeaseService.activateLease(_leaseId!);
                await _load();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lease activated')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            },
            child: const Text('Activate Lease'),
          ),
      ],
    );
  }

  Widget _landlordActions(ThemeData t) {
    final active = _isTrue(_lease['active']);
    return Row(
      children: [
        if (!active)
          OutlinedButton(
            onPressed: () => LeaseService.downloadLeasePdf(_leaseId!),
            child: const Text('Print Draft'),
          ),
      ],
    );
  }

  Widget _sectionCard(
    ThemeData t, {
    required String title,
    required List<Widget> children,
  }) {
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
            title,
            style: t.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _row(ThemeData t, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              k,
              style: t.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}