// lib/screens/landlord/landlord_overview.dart
// A clean Overview page with KPIs, per-property breakdown, and arrears list.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property_manager_frontend/services/report_service.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class LandlordOverview extends StatefulWidget {
  const LandlordOverview({super.key});

  @override
  State<LandlordOverview> createState() => _LandlordOverviewState();
}

class _LandlordOverviewState extends State<LandlordOverview> {
  bool _loading = true;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final landlordId = await TokenManager.currentUserId();
      final role = await TokenManager.currentRole();
      if (landlordId == null || role != 'landlord') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid session. Please log in.')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }
      final data = await ReportService.landlordMonthlySummary(
        landlordId: landlordId,
        year: _year,
        month: _month,
      );
      setState(() => _summary = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load overview: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    final d = DateTime(_year, _month, 1);
    final p = DateTime(d.year, d.month - 1, 1);
    setState(() {
      _year = p.year;
      _month = p.month;
    });
    _load();
  }

  void _nextMonth() {
    final d = DateTime(_year, _month, 1);
    final n = DateTime(d.year, d.month + 1, 1);
    setState(() {
      _year = n.year;
      _month = n.month;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ym = DateFormat.yMMMM().format(DateTime(_year, _month, 1));

    return Scaffold(
      appBar: AppBar(
        title: Text('Overview • $ym'),
        actions: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: _prevMonth,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summary == null
              ? const Center(child: Text('No data'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _kpiRow(context, _summary!),
                    const SizedBox(height: 20),
                    _propertiesTable(context, _summary!),
                    const SizedBox(height: 20),
                    _arrearsList(context, _summary!),
                    const SizedBox(height: 28),
                  ],
                ),
    );
  }

  Widget _kpiCard(IconData icon, String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: fg),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: fg.withOpacity(.9))),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiRow(BuildContext context, Map<String, dynamic> s) {
    final t = Theme.of(context);
    final expected = (s['expected_total'] ?? 0).toString();
    final received = (s['received_total'] ?? 0).toString();
    final pending = (s['pending_total'] ?? 0).toString();

    final cards = [
      _kpiCard(Icons.request_quote_rounded, 'Expected', expected,
          t.colorScheme.primaryContainer, t.colorScheme.onPrimaryContainer),
      _kpiCard(Icons.check_circle_rounded, 'Received', received,
          t.colorScheme.secondaryContainer, t.colorScheme.onSecondaryContainer),
      _kpiCard(Icons.hourglass_bottom_rounded, 'Pending', pending,
          t.colorScheme.tertiaryContainer, t.colorScheme.onTertiaryContainer),
    ];

    return LayoutBuilder(
      builder: (_, c) {
        if (c.maxWidth < 680) {
          return Column(
            children: [
              ...cards.map((w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: w)),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
            const SizedBox(width: 12),
            Expanded(child: cards[2]),
          ],
        );
      },
    );
  }

  Widget _propertiesTable(BuildContext context, Map<String, dynamic> s) {
    final t = Theme.of(context);
    final rows = (s['properties'] as List?) ?? [];
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: t.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.dividerColor.withOpacity(.25)),
        ),
        child: const Text('No properties yet.'),
      );
    }

    return Card(
      elevation: 0,
      color: t.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.dividerColor.withOpacity(.25)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Property')),
            DataColumn(label: Text('Expected')),
            DataColumn(label: Text('Received')),
            DataColumn(label: Text('Pending')),
          ],
          rows: rows.map<DataRow>((r) {
            return DataRow(
              cells: [
                DataCell(Text((r['name'] ?? '').toString())),
                DataCell(Text((r['expected'] ?? 0).toString())),
                DataCell(Text((r['received'] ?? 0).toString())),
                DataCell(Text((r['pending'] ?? 0).toString())),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _arrearsList(BuildContext context, Map<String, dynamic> s) {
    final t = Theme.of(context);
    final items = (s['arrears'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top Arrears', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: t.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.dividerColor.withOpacity(.25)),
            ),
            child: const Text('No arrears 🎉'),
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
              children: items.take(10).map<Widget>((a) {
                final name = (a['tenant_name'] ?? 'Tenant').toString();
                final phone = (a['phone'] ?? '').toString();
                final expected = (a['expected'] ?? 0).toString();
                final paid = (a['paid'] ?? 0).toString();
                final balance = (a['balance'] ?? 0).toString();
                return ListTile(
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(phone),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Balance: $balance', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Paid: $paid / $expected'),
                    ],
                  ),
                  onTap: () {
                    // Future: open tenant ledger
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
