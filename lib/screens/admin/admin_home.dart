// lib/screens/admin/admin_home.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/admin_service.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic> _overview = {};
  String _period = _defaultPeriod();

  static String _defaultPeriod() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    return '${now.year}-$mm';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AdminService.getOverview(period: _period);
      if (!mounted) return;
      setState(() {
        _overview = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    final counts = (_overview['counts'] as Map?)?.cast<String, dynamic>() ?? {};
    final collections = (_overview['collections'] as Map?)?.cast<String, dynamic>() ?? {};
    final propsTop = (_overview['properties_top'] as List?)?.cast<dynamic>() ?? const [];

    int i(String k) => (counts[k] is num) ? (counts[k] as num).toInt() : 0;
    double d(String k, [Map<String, dynamic>? src]) {
      final m = src ?? collections;
      return (m[k] is num) ? (m[k] as num).toDouble() : 0.0;
    }

    final occupied = i('occupied_units');
    final vacant = i('vacant_units');
    final units = i('units');
    final occPct = units == 0 ? 0.0 : (occupied / units) * 100;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Overview',
                  style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _PeriodChip(
                value: _period,
                onTap: () async {
                  final picked = await _pickPeriod(context, _period);
                  if (picked == null) return;
                  setState(() => _period = picked);
                  await _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(icon: LucideIcons.building2, title: 'Properties', value: '${i('properties')}'),
              _StatCard(icon: LucideIcons.doorOpen, title: 'Units', value: '$units'),
              _StatCard(icon: LucideIcons.user, title: 'Tenants', value: '${i('tenants')}'),
              _StatCard(icon: LucideIcons.fileText, title: 'Active leases', value: '${i('active_leases')}'),
            ],
          ),

          const SizedBox(height: 12),

          _BigCard(
            title: 'Occupancy',
            subtitle: 'Occupied: $occupied • Vacant: $vacant',
            trailing: Text('${occPct.toStringAsFixed(1)}%', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            child: LinearProgressIndicator(value: units == 0 ? 0 : occupied / units),
          ),

          const SizedBox(height: 12),

          _BigCard(
            title: 'Collections (${collections['period'] ?? _period})',
            subtitle: 'Paid: ${(collections['paid_count'] ?? 0)} • Unpaid: ${(collections['unpaid_count'] ?? 0)}',
            trailing: Text('KES ${d('collected_total').toStringAsFixed(0)}',
                style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            child: const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),

          _BigCard(
            title: 'Maintenance',
            subtitle: 'Open: ${i('maintenance_open')} • In progress: ${i('maintenance_in_progress')} • Resolved: ${i('maintenance_resolved')}',
            trailing: const Icon(LucideIcons.wrench),
            child: const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Text('Recent properties', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/admin_properties'),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (propsTop.isEmpty)
            Text('No properties yet.', style: t.textTheme.bodyMedium)
          else
            ...propsTop.map((e) {
              final m = (e as Map).cast<String, dynamic>();
              final pid = (m['id'] as num?)?.toInt() ?? 0;
              final name = (m['name'] ?? '').toString();
              final code = (m['property_code'] ?? '').toString();
              final occ = (m['occupied_units'] as num?)?.toInt() ?? 0;
              final tot = (m['units'] as num?)?.toInt() ?? 0;

              return Card(
                child: ListTile(
                  leading: const Icon(LucideIcons.building2),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Code: $code • Units: $occ/$tot'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: pid == 0
                      ? null
                      : () => Navigator.pushNamed(
                            context,
                            '/landlord_property_units',
                            arguments: {'propertyId': pid},
                          ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<String?> _pickPeriod(BuildContext context, String current) async {
    final now = DateTime.now();
    final years = List.generate(5, (i) => now.year - i);
    final months = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));

    String y = current.split('-').first;
    String m = current.split('-').last;

    return showDialog<String>(
      context: context,
      builder: (_) {
        String yy = y;
        String mm = m;
        return AlertDialog(
          title: const Text('Select period'),
          content: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: yy,
                  items: years.map((e) => DropdownMenuItem(value: '$e', child: Text('$e'))).toList(),
                  onChanged: (v) => yy = v ?? yy,
                  decoration: const InputDecoration(labelText: 'Year'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: mm,
                  items: months.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => mm = v ?? mm,
                  decoration: const InputDecoration(labelText: 'Month'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, '$yy-$mm'), child: const Text('Apply')),
          ],
        );
      },
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  const _PeriodChip({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(value),
      avatar: const Icon(LucideIcons.calendarDays, size: 18),
      onPressed: onTap,
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatCard({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 10),
              Text(title, style: t.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(value, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  final Widget child;

  const _BigCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                trailing,
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: t.textTheme.bodyMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertTriangle, size: 28),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}