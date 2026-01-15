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

  int? _managerId;
  String _managerName = '—';
  String _managerPhone = '';

  List<dynamic> _properties = [];
  String _search = '';

  // Payments caching: propertyId -> period -> status map
  final Map<int, Map<String, Map<String, dynamic>>> _paymentStatusCache = {};
  final Map<String, Future<void>> _paymentLoading = {}; // key: "$pid|$period"
  final Map<int, String> _selectedPeriod = {}; // propertyId -> YYYY-MM

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await TokenManager.currentUserId();
    final role = await TokenManager.currentRole();

    if (!mounted) return;

    if (id == null || role != 'manager') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid session. Please log in again.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    _managerId = id;

    await Future.wait([
      _loadManagerProfile(),
      _loadProperties(),
    ]);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadManagerProfile() async {
    if (_managerId == null) return;
    try {
      final m = await ManagerService.getManager(_managerId!);
      final name = (m['name'] ?? '').toString().trim();
      final phone = (m['phone'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() {
        _managerName = name.isEmpty ? '—' : name;
        _managerPhone = phone;
      });
    } catch (e) {
      print('💥 manager profile load failed: $e');
      if (!mounted) return;
      setState(() {
        _managerName = '—';
        _managerPhone = '';
      });
    }
  }

  Future<void> _loadProperties() async {
    if (_managerId == null) return;

    try {
      final data = await PropertyService.getPropertiesByManager(_managerId!);
      if (!mounted) return;
      setState(() => _properties = data);

      // default period for each property: current YYYY-MM
      final now = DateTime.now();
      final current = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      for (final raw in data) {
        final p = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final pid = (p['id'] as num?)?.toInt();
        if (pid != null) {
          _selectedPeriod.putIfAbsent(pid, () => current);
        }
      }
    } catch (e) {
      print('💥 manager properties load failed: $e');
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
      print('💥 payments status failed for $propertyId $period: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payments status failed: $e')),
      );
    }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager • Properties'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: () async {
              setState(() => _loading = true);
              await Future.wait([_loadManagerProfile(), _loadProperties()]);
              if (!mounted) return;
              setState(() => _loading = false);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          // -------- Summary header --------
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
                    child: Icon(LucideIcons.userCog, color: t.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _managerName,
                          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _managerPhone.trim().isEmpty ? 'Manager ID: ${_managerId ?? "—"}' : '$_managerPhone • ID: ${_managerId ?? "—"}',
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

          // -------- How to use (quick helper) --------
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.info, size: 18),
                      const SizedBox(width: 8),
                      Text('How to use', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '• Units: view all units for the property.\n'
                    '• Tenants: see tenants per unit (assigned/not assigned).\n'
                    '• Maintenance: view requests inbox.\n'
                    '• Payments: pick a month and see payment status summary.',
                    style: t.textTheme.bodySmall?.copyWith(color: t.hintColor, height: 1.35),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // -------- Search --------
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
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  const Icon(LucideIcons.folderOpen, size: 52, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(
                    'No properties assigned to you yet.',
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

              // Preload payment status when card is built (safe / cached)
              // only if card will show expansion later; this makes UI feel faster
              _ensurePaymentStatus(pid, period);

              final status = _paymentStatusCache[pid]?[period];
              final periodLoading = _paymentLoading.containsKey('$pid|$period');

              // Try to read common keys safely (works even if backend structure differs)
              String val(dynamic x) => (x == null) ? '—' : x.toString();

              final paid = val(status?['paid'] ?? status?['paid_count'] ?? status?['paid_units']);
              final unpaid = val(status?['unpaid'] ?? status?['unpaid_count'] ?? status?['unpaid_units']);
              final overdue = val(status?['overdue'] ?? status?['overdue_count'] ?? status?['overdue_units']);
              final expected = val(status?['expected_amount'] ?? status?['expected']);
              final received = val(status?['paid_amount'] ?? status?['received_amount'] ?? status?['received']);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // top header
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

                      // chips with copyable property code
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

                      // actions
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
                                      arguments: {
                                        'propertyId': pid,
                                        'propertyCode': code,
                                      },
                                    ),
                            icon: const Icon(LucideIcons.users, size: 18),
                            label: const Text('Tenants'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/manager_maintenance_inbox'),
                            icon: const Icon(LucideIcons.wrench, size: 18),
                            label: const Text('Maintenance'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // payments section (per property)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: t.dividerColor.withOpacity(.22)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.wallet, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Payments summary',
                                    style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: period,
                                    items: _lastMonths(count: 10)
                                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() => _selectedPeriod[pid] = v);
                                      _ensurePaymentStatus(pid, v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (periodLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else if (status == null)
                              Text(
                                'No payment data yet for $period.',
                                style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _MiniStat(label: 'Paid', value: paid),
                                  _MiniStat(label: 'Unpaid', value: unpaid),
                                  _MiniStat(label: 'Overdue', value: overdue),
                                  _MiniStat(label: 'Expected', value: expected),
                                  _MiniStat(label: 'Received', value: received),
                                ],
                              ),
                          ],
                        ),
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
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
          Text('$label: ', style: t.textTheme.labelMedium),
          Text(
            value,
            style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
