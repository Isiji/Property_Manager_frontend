// lib/screens/admin/admin_finance.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/admin_service.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _rows = [];
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
      final rows = await AdminService.getFinanceSummary(period: _period, limit: 500);
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.alertTriangle),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    double totalExpected = 0;
    double totalReceived = 0;
    for (final r in _rows) {
      totalExpected += (r['expected_rent'] is num) ? (r['expected_rent'] as num).toDouble() : 0;
      totalReceived += (r['received_rent'] is num) ? (r['received_rent'] as num).toDouble() : 0;
    }
    final bal = totalExpected - totalReceived;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Finance', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              ),
              ActionChip(
                label: Text(_period),
                avatar: const Icon(LucideIcons.calendarDays, size: 18),
                onPressed: () async {
                  final picked = await _pickPeriod(context, _period);
                  if (picked == null) return;
                  setState(() => _period = picked);
                  await _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Totals ($_period)', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  _kv('Expected', 'KES ${totalExpected.toStringAsFixed(0)}'),
                  _kv('Received', 'KES ${totalReceived.toStringAsFixed(0)}'),
                  _kv('Balance', 'KES ${bal.toStringAsFixed(0)}'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Text('By property', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),

          ..._rows.map((r) {
            final pid = (r['property_id'] as num?)?.toInt() ?? 0;
            final name = (r['property_name'] ?? '').toString();
            final code = (r['property_code'] ?? '').toString();

            final exp = (r['expected_rent'] is num) ? (r['expected_rent'] as num).toDouble() : 0;
            final rec = (r['received_rent'] is num) ? (r['received_rent'] as num).toDouble() : 0;
            final balance = (r['balance'] is num) ? (r['balance'] as num).toDouble() : (exp - rec);

            final paid = (r['paid_leases'] as num?)?.toInt() ?? 0;
            final unpaid = (r['unpaid_leases'] as num?)?.toInt() ?? 0;

            return Card(
              child: ListTile(
                leading: const Icon(LucideIcons.wallet),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('Code: $code • Paid leases: $paid • Unpaid leases: $unpaid'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('KES ${rec.toStringAsFixed(0)}', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    Text('Bal: ${balance.toStringAsFixed(0)}', style: t.textTheme.labelMedium),
                  ],
                ),
                onTap: pid == 0
                    ? null
                    : () {
                        // Reuse your existing payments screen for now (works for admin too)
                        Navigator.pushNamed(context, '/manager_payments', arguments: {
                          'propertyId': pid,
                          'propertyCode': code,
                          'propertyName': name,
                          'period': _period,
                        });
                      },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(k)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );

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