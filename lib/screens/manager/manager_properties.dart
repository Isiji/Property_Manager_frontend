// ignore_for_file: avoid_print, use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/property_service.dart';
import 'package:property_manager_frontend/services/manager_service.dart';
import 'package:property_manager_frontend/services/payment_service.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class ManagerPropertiesScreen extends StatefulWidget {
  const ManagerPropertiesScreen({super.key});

  @override
  State<ManagerPropertiesScreen> createState() => _ManagerPropertiesScreenState();
}

class _ManagerPropertiesScreenState extends State<ManagerPropertiesScreen> {
  bool _loading = true;

  int? _staffId;   // manager_user_id (staff)
  int? _managerId; // manager_id (org)

  String _orgName = '—';       // manager_name (agency/company or individual name)
  String _staffName = '—';     // display_name
  String _staffPhone = '';
  String _managerType = 'individual'; // agency | individual

  List<dynamic> _properties = [];
  String _search = '';

  final Map<int, Map<String, Map<String, dynamic>>> _paymentStatusCache = {};
  final Map<String, Future<void>> _paymentLoading = {}; // "$pid|$period"
  final Map<int, String> _selectedPeriod = {}; // pid -> YYYY-MM

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirm != true) return;

    await TokenManager.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _init() async {
    final id = await TokenManager.currentUserId(); // in agency mode: this is STAFF id
    final role = await TokenManager.currentRole();

    if (!mounted) return;

    if (id == null || role != 'manager') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid session. Please log in again.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    setState(() => _staffId = id);

    // Load /managers/me first to resolve manager org id
    await _loadManagerMe();

    // Now load properties using org manager_id
    await _loadProperties();

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    await _loadManagerMe();
    await _loadProperties();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadManagerMe() async {
    try {
      final me = await ManagerService.getMe();

      final orgName = (me['manager_name'] ?? '').toString().trim();
      final staffName = (me['display_name'] ?? '').toString().trim();
      final staffPhone = (me['staff_phone'] ?? '').toString().trim();
      final mType = (me['manager_type'] ?? 'individual').toString().trim();

      final staffId = (me['manager_user_id'] is num) ? (me['manager_user_id'] as num).toInt() : _staffId;
      final managerId = (me['manager_id'] is num) ? (me['manager_id'] as num).toInt() : null;

      if (!mounted) return;
      setState(() {
        _orgName = orgName.isEmpty ? '—' : orgName;
        _staffName = staffName.isEmpty ? '—' : staffName;
        _staffPhone = staffPhone;
        _managerType = mType.isEmpty ? 'individual' : mType;

        _staffId = staffId;
        _managerId = managerId;
      });
    } catch (e) {
      print('💥 manager /me load failed: $e');

      final msg = e.toString();
      if (msg.contains('401')) {
        await TokenManager.clearSession();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }

      if (!mounted) return;
      setState(() {
        _orgName = '—';
        _staffName = '—';
        _staffPhone = '';
        _managerType = 'individual';
        _managerId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load manager session: $e')),
      );
    }
  }

  Future<void> _load_attachDefaultsForPeriods(List<dynamic> data) async {
    final now = DateTime.now();
    final current = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    for (final raw in data) {
      final p = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final pid = (p['id'] as num?)?.toInt();
      if (pid != null) _selectedPeriod.putIfAbsent(pid, () => current);
    }
  }

  Future<void> _loadProperties() async {
    if (_managerId == null) {
      // without org manager_id, properties endpoint can't work
      return;
    }

    try {
      final data = await PropertyService.getPropertiesByManager(_managerId!);
      if (!mounted) return;
      setState(() => _properties = data);
      await _load_attachDefaultsForPeriods(data);
    } catch (e) {
      print('💥 manager properties load failed: $e');

      final msg = e.toString();
      if (msg.contains('401')) {
        await TokenManager.clearSession();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load properties: $e')),
      );
    }
  }

  List<dynamic> get _filtered {
    if (_search.trim().isEmpty) return _properties;
    final s = _search.toLowerCase();
    return _properties.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final addr = (p['address'] ?? '').toString().toLowerCase();
      final code = (p['property_code'] ?? '').toString().toLowerCase();
      return name.contains(s) || addr.contains(s) || code.contains(s);
    }).toList();
  }

  Future<void> _copy(String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  List<String> _lastMonths({int count = 8}) {
    final now = DateTime.now();
    final out = <String>[];
    var y = now.year;
    var m = now.month;
    for (var i = 0; i < count; i++) {
      out.add('$y-${m.toString().padLeft(2, '0')}');
      m -= 1;
      if (m <= 0) {
        m = 12;
        y -= 1;
      }
    }
    return out;
  }

  void _ensurePaymentStatus(int propertyId, String period) {
    final key = '$propertyId|$period';
    final cached = _paymentStatusCache[propertyId]?[period];
    if (cached != null) return;
    if (_paymentLoading.containsKey(key)) return;

    final fut = _loadPaymentStatus(propertyId: propertyId, period: period);
    _paymentLoading[key] = fut;
    fut.whenComplete(() => _paymentLoading.remove(key));
  }

  Future<void> _loadPaymentStatus({required int propertyId, required String period}) async {
    try {
      final status = await PaymentService.getStatusByProperty(propertyId: propertyId, period: period);
      if (!mounted) return;

      setState(() {
        _paymentStatusCache.putIfAbsent(propertyId, () => {});
        _paymentStatusCache[propertyId]![period] = status;
      });
    } catch (e) {
      final msg = e.toString();
      print('💥 payments status failed for $propertyId $period: $msg');

      if (msg.contains('401')) {
        await TokenManager.clearSession();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }

      if (!mounted) return;
      // Keep this quiet-ish; payments can be loaded a lot on scroll
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payments status failed: $e')),
      );
    }
  }

  void _openPayments({
    required int propertyId,
    required String period,
    required String propertyName,
    required String propertyCode,
  }) {
    Navigator.pushNamed(
      context,
      '/manager_payments',
      arguments: {
        'propertyId': propertyId,
        'period': period,
        'propertyName': propertyName,
        'propertyCode': propertyCode,
      },
    );
  }

  Widget _kv(ThemeData t, String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.dividerColor.withOpacity(.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$k: ', style: t.textTheme.labelMedium),
          Flexible(
            child: Text(
              v,
              style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final list = _filtered;

    final headline = _loading
        ? 'Manager • Properties'
        : (_managerType == 'agency' ? '$_orgName • Properties' : 'Manager • Properties');

    final subtitle = _loading
        ? 'Loading…'
        : '${_staffName == '—' ? 'Staff' : _staffName}'
          '${_staffPhone.trim().isEmpty ? '' : ' • $_staffPhone'}'
          ' • Staff ID: ${_staffId ?? "—"}'
          '${_managerId == null ? '' : ' • Org ID: $_managerId'}';

    return Scaffold(
      appBar: AppBar(
        // ✅ Back button that works even when browser back doesn't
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/dashboard');
            }
          },
        ),
        title: Text(headline),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: _refreshAll,
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(LucideIcons.logOut),
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.colorScheme.primary.withOpacity(.12),
                    ),
                    child: Icon(
                      _managerType == 'agency' ? LucideIcons.building2 : LucideIcons.userCog,
                      color: t.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _managerType == 'agency' ? _orgName : (_orgName == '—' ? 'Manager' : _orgName),
                          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _kv(t, 'Properties', '${_properties.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search by property name / address / code…',
              prefixIcon: const Icon(LucideIcons.search),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_managerId == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  const Icon(LucideIcons.shieldAlert, size: 52, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(
                    'Manager org not resolved.\nPlease refresh or log in again.',
                    textAlign: TextAlign.center,
                    style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
                  ),
                ],
              ),
            )
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  const Icon(LucideIcons.folderOpen, size: 52, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(
                    'No properties assigned to this manager yet.',
                    style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
                  ),
                ],
              ),
            )
          else
            ...list.map((raw) {
              final p = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
              final pid = (p['id'] as num?)?.toInt() ?? 0;
              final name = (p['name'] ?? '—').toString();
              final addr = (p['address'] ?? '—').toString();
              final code = (p['property_code'] ?? '—').toString();

              final period = _selectedPeriod[pid] ?? _lastMonths().first;
              _ensurePaymentStatus(pid, period);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: t.colorScheme.primary.withOpacity(.12),
                            ),
                            child: Icon(LucideIcons.building2, color: t.colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  addr,
                                  style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _CopyChip(
                            icon: LucideIcons.qrCode,
                            label: 'Code: $code',
                            onCopy: code.trim().isEmpty || code == '—' ? null : () => _copy('Property code', code),
                          ),
                          _InfoChip(icon: LucideIcons.hash, label: 'ID: $pid'),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: pid == 0
                                ? null
                                : () => Navigator.pushNamed(
                                      context,
                                      '/landlord_property_units',
                                      arguments: {'propertyId': pid},
                                    ),
                            icon: const Icon(LucideIcons.grid, size: 18),
                            label: const Text('Units'),
                          ),
                          OutlinedButton.icon(
                            onPressed: pid == 0
                                ? null
                                : () => Navigator.pushNamed(
                                      context,
                                      '/manager_tenants',
                                      arguments: {'propertyId': pid, 'propertyCode': code},
                                    ),
                            icon: const Icon(LucideIcons.users, size: 18),
                            label: const Text('Tenants'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/manager_maintenance_inbox'),
                            icon: const Icon(LucideIcons.wrench, size: 18),
                            label: const Text('Maintenance'),
                          ),
                          FilledButton.icon(
                            onPressed: pid == 0
                                ? null
                                : () => _openPayments(
                                      propertyId: pid,
                                      period: period,
                                      propertyName: name,
                                      propertyCode: code,
                                    ),
                            icon: const Icon(LucideIcons.wallet, size: 18),
                            label: const Text('Payments'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.dividerColor.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: t.hintColor),
          const SizedBox(width: 6),
          Text(label, style: t.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _CopyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onCopy;

  const _CopyChip({
    required this.icon,
    required this.label,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.dividerColor.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: t.hintColor),
          const SizedBox(width: 6),
          Text(label, style: t.textTheme.labelMedium),
          const SizedBox(width: 6),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.copy_rounded,
                size: 16,
                color: onCopy == null ? t.disabledColor : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
