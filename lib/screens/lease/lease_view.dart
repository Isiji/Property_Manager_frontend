// lib/screens/lease/lease_view.dart
// Reusable lease viewer for landlord or tenant. Printable + accept terms + activate.

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing lease id')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat.yMMMd().format(d);
    }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lease'),
        actions: [
          if (_leaseId != null)
            IconButton(
              tooltip: 'Download PDF',
              onPressed: () async {
                try {
                  await LeaseService.downloadLeasePdf(_leaseId!);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download started')));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
                    _row(t, 'Tenant', _lease['tenant_name'] ?? '—'),
                    _row(t, 'Tenant Phone', _lease['tenant_phone'] ?? '—'),
                    _row(t, 'Landlord', _lease['landlord_name'] ?? '—'),
                    _row(t, 'Property', _lease['property_name'] ?? '—'),
                    _row(t, 'Unit', _lease['unit_number'] ?? '—'),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  t,
                  title: 'Terms',
                  children: [
                    _row(t, 'Rent (KSh)', (_lease['rent_amount'] ?? '').toString()),
                    _row(t, 'Start Date', _fmtDate(_lease['start_date']?.toString())),
                    _row(t, 'End Date', _fmtDate(_lease['end_date']?.toString())),
                    _row(t, 'Status', (_lease['status'] ?? '').toString().toUpperCase()),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  t,
                  title: 'Terms & Conditions',
                  children: [
                    Text(
                      (_lease['terms_text'] ?? 'Standard residential lease terms apply.').toString(),
                      style: t.textTheme.bodyMedium,
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
    final accepted = (_lease['terms_accepted'] == true);
    final active = (_lease['active'] == true);
    return Row(
      children: [
        if (!accepted)
          FilledButton(
            onPressed: () async {
              try {
                await LeaseService.acceptTerms(_leaseId!);
                await _load();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terms accepted')));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Accept Terms'),
          ),
        const SizedBox(width: 8),
        if (accepted && !active)
          FilledButton(
            onPressed: () async {
              try {
                await LeaseService.activateLease(_leaseId!);
                await _load();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lease activated')));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Activate Lease'),
          ),
      ],
    );
  }

  Widget _landlordActions(ThemeData t) {
    final active = (_lease['active'] == true);
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

  Widget _sectionCard(ThemeData t, {required String title, required List<Widget> children}) {
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
          Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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
        children: [
          SizedBox(width: 180, child: Text(k, style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
