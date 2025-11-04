// lib/screens/tenant/tenant_home.dart
// Tenant portal with tabs: Dashboard, Payments, Maintenance, Profile.
// Defensive casting to avoid crashes if backend returns partial/empty data.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property_manager_frontend/services/tenant_portal_service.dart';
import 'package:property_manager_frontend/services/tenant_service.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';
import 'package:property_manager_frontend/services/auth_service.dart';

class TenantHome extends StatefulWidget {
  const TenantHome({super.key});

  @override
  State<TenantHome> createState() => _TenantHomeState();
}

class _TenantHomeState extends State<TenantHome> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = true;

  Map<String, dynamic> _dashboard = const <String, dynamic>{};
  List<dynamic> _payments = const [];
  List<dynamic> _tickets = const [];

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

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _loadAll() async {
    try {
      setState(() => _loading = true);

      final role = await TokenManager.currentRole();
      if (role != 'tenant') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in as a tenant.')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }

      try {
        final dash = await TenantPortalService.getOverview();
        _dashboard = dash is Map ? dash.cast<String, dynamic>() : <String, dynamic>{};
      } catch (e) {
        _dashboard = const <String, dynamic>{};
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Overview unavailable: $e')),
          );
        }
      }

      try {
        final pays = await TenantPortalService.getPayments();
        _payments = pays is List ? pays : const [];
      } catch (_) {
        _payments = const [];
      }

      try {
        final mnts = await TenantPortalService.getMaintenance();
        _tickets = mnts is List ? mnts : const [];
      } catch (_) {
        _tickets = const [];
      }

      try {
        final profile = await TenantPortalService.getProfile();
        final p = profile is Map ? profile.cast<String, dynamic>() : <String, dynamic>{};
        _nameCtrl.text = (p['name'] ?? '').toString();
        _phoneCtrl.text = (p['phone'] ?? '').toString();
        _emailCtrl.text = (p['email'] ?? '').toString();
        _idCtrl.text = (p['id_number'] ?? '').toString();
      } catch (_) {
        // leave fields
      }

      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitMaintenance() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Maintenance Request'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await TenantPortalService.createMaintenance(
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                );
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Request submitted')),
                );
                final m = await TenantPortalService.getMaintenance();
                setState(() => _tickets = m is List ? m : const []);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Submit failed: $e')),
                );
              }
            },
            child: const Text('Submit'),
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final now = DateTime.now();
    final ym = DateFormat.yMMMM().format(DateTime(now.year, now.month, 1));

    return Scaffold(
      appBar: AppBar(
        title: Text('Tenant • $ym'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Dashboard', icon: Icon(Icons.dashboard_customize_rounded)),
            Tab(text: 'Payments',  icon: Icon(Icons.receipt_long_rounded)),
            Tab(text: 'Maintenance', icon: Icon(Icons.build_rounded)),
            Tab(text: 'Profile', icon: Icon(Icons.person_rounded)),
          ],
        ),
        actions: [
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded), tooltip: 'Logout'),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _dashboardTab(context, t),
                _paymentsTab(context, t),
                _maintenanceTab(context, t),
                _profileTab(context, t),
              ],
            ),
    );
  }

  // ---------- helpers ----------
  Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

  // ---------- tabs ----------

  Widget _dashboardTab(BuildContext context, ThemeData t) {
    final d = _asMap(_dashboard);
    final unit = _asMap(d['unit']);
    final lease = _asMap(d['lease']);
    final status = _asMap(d['this_month']);

    final unitLabel = (unit['number'] ?? '—').toString();
    final propertyName = (unit['property_name'] ?? '').toString();
    final rent = (lease['rent_amount'] ?? '').toString();

    final paid = status['paid'] == true;
    final expected = (status['expected'] ?? 0).toString();
    final received = (status['received'] ?? 0).toString();
    final balance = (status['balance'] ?? 0).toString();

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
          child: Row(
            children: [
              Icon(Icons.apartment_rounded, size: 36, color: t.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(propertyName.isEmpty ? 'Your Unit' : propertyName,
                        style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Unit $unitLabel • Rent: $rent'),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: paid ? t.colorScheme.tertiaryContainer : t.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  paid ? 'Paid' : 'Unpaid',
                  style: t.textTheme.labelMedium?.copyWith(
                    color: paid ? t.colorScheme.onTertiaryContainer : t.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpi(t, Icons.request_quote_rounded, 'Expected', expected,
                t.colorScheme.primaryContainer, t.colorScheme.onPrimaryContainer),
            _kpi(t, Icons.payments_rounded, 'Received', received,
                t.colorScheme.secondaryContainer, t.colorScheme.onSecondaryContainer),
            _kpi(t, Icons.account_balance_wallet_rounded, 'Balance', balance,
                t.colorScheme.tertiaryContainer, t.colorScheme.onTertiaryContainer),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            FilledButton.icon(
              onPressed: () async {
                try {
                  final r = await TenantPortalService.payThisMonth();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(r['message'] ?? 'Payment flow started')),
                  );
                  await _loadAll();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Payment failed: $e')),
                  );
                }
              },
              icon: const Icon(Icons.credit_card_rounded),
              label: const Text('Pay Now'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _submitMaintenance,
              icon: const Icon(Icons.build_rounded),
              label: const Text('Maintenance'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kpi(ThemeData t, IconData icon, String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: fg),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: fg.withOpacity(.9))),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentsTab(BuildContext context, ThemeData t) {
    if (_payments.isEmpty) {
      return const Center(child: Text('No payments yet.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = _payments[i] as Map;
        final period = (p['period'] ?? '').toString();
        final amount = (p['amount'] ?? '').toString();
        final date = (p['paid_date'] ?? '').toString();
        final ref = (p['reference'] ?? '').toString();

        return ListTile(
          leading: const Icon(Icons.receipt_long_rounded),
          title: Text('Ksh $amount • $period', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(date.isEmpty ? '—' : date),
          trailing: Text(ref.isEmpty ? '' : ref, style: t.textTheme.labelSmall),
          onTap: () {/* future: open receipt */},
        );
      },
    );
  }

  Widget _maintenanceTab(BuildContext context, ThemeData t) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _submitMaintenance,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Request'),
          ),
        ),
        const SizedBox(height: 12),
        if (_tickets.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: t.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.dividerColor.withOpacity(.25)),
            ),
            child: const Text('No requests yet.'),
          )
        else
          Card(
            elevation: 0,
            color: t.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: t.dividerColor.withOpacity(.25)),
            ),
            child: Column(
              children: _tickets.map<Widget>((it) {
                final m = (it is Map) ? it.cast<String, dynamic>() : <String, dynamic>{};
                final title = (m['title'] ?? 'Request').toString();
                final status = (m['status'] ?? 'open').toString();
                final created = (m['created_at'] ?? '').toString();
                final chip = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: status == 'closed'
                        ? t.colorScheme.tertiaryContainer
                        : t.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: t.textTheme.labelSmall?.copyWith(
                      color: status == 'closed'
                          ? t.colorScheme.onTertiaryContainer
                          : t.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
                return ListTile(
                  leading: const Icon(Icons.build_rounded),
                  title: Text(title),
                  subtitle: Text(created),
                  trailing: chip,
                  onTap: () {},
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _profileTab(BuildContext context, ThemeData t) {
    final formKey = GlobalKey<FormState>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Your Profile', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _idCtrl,
                decoration: const InputDecoration(labelText: 'National ID (optional)', prefixIcon: Icon(Icons.badge)),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    _saveProfile();
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
