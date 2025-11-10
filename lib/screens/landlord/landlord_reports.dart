import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:property_manager_frontend/services/property_service.dart';
import 'package:property_manager_frontend/services/payment_service.dart';

class LandlordReportsScreen extends StatefulWidget {
  final int propertyId;
  const LandlordReportsScreen({super.key, required this.propertyId});

  @override
  State<LandlordReportsScreen> createState() => _LandlordReportsScreenState();
}

class _LandlordReportsScreenState extends State<LandlordReportsScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic>? _property;
  List<dynamic> _units = [];
  late TabController _tab;
  int _year = DateTime.now().year;

  // month -> list of rent status items [{unit_id, paid, amount_due, ...}]
  final Map<String, List<Map<String, dynamic>>> _monthData = {};

  String _mm(int m) => m.toString().padLeft(2, '0');
  String _period(int y, int m) => '$y-${_mm(m)}';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      setState(() => _loading = true);
      final detail =
          await PropertyService.getPropertyWithUnitsDetailed(widget.propertyId);
      _property = detail;
      _units = (detail['units'] as List<dynamic>? ?? []);
      await _fetchYear(_year);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Load error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchYear(int year) async {
    final pid = _property!['id'] as int;
    final futures = <Future<void>>[];
    for (var m = 1; m <= 12; m++) {
      futures.add(_fetchMonth(pid, _period(year, m)));
    }
    await Future.wait(futures);
  }

  Future<void> _fetchMonth(int propertyId, String period) async {
    try {
      final rs = await PaymentService.getStatusByProperty(
          propertyId: propertyId, period: period);
      final items = (rs['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      _monthData[period] = items.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      _monthData[period] = const [];
    }
  }

  // ---------- Aggregations ----------

  Map<String, num> _monthTotals(String period) {
    num expected = 0;
    num collected = 0;
    num outstanding = 0;
    int paidUnits = 0, unpaidUnits = 0;

    final items = _monthData[period] ?? const [];
    final byUnit = {for (final it in items) (it['unit_id'] as num).toInt(): it};

    for (final u in _units) {
      final unit = u as Map<String, dynamic>;
      final rent = _parseNum(unit['rent_amount']);
      final leaseActive = unit['lease']?['active'];
      final occupied = leaseActive == true || leaseActive == 1 || leaseActive == '1';
      if (!occupied) continue;

      expected += rent;

      final unitId = (unit['id'] as num).toInt();
      final rs = byUnit[unitId];

      if (rs == null) {
        unpaidUnits += 1;
        outstanding += rent;
      } else {
        final paid = rs['paid'] == true;
        if (paid) {
          paidUnits += 1;
          collected += rent;
        } else {
          unpaidUnits += 1;
          final due = _parseNum(rs['amount_due']);
          final got = (rent - (due < 0 ? 0 : due)).clamp(0, rent);
          collected += got;
          outstanding += (due < 0 ? 0 : due).clamp(0, rent);
        }
      }
    }

    return {
      'expected': expected,
      'collected': collected,
      'outstanding': outstanding,
      'paidUnits': paidUnits,
      'unpaidUnits': unpaidUnits,
    };
  }

  Map<String, num> _yearTotals() {
    num expected = 0, collected = 0, outstanding = 0;
    int paidUnits = 0, unpaidUnits = 0;
    for (var m = 1; m <= 12; m++) {
      final mt = _monthTotals(_period(_year, m));
      expected += mt['expected']!;
      collected += mt['collected']!;
      outstanding += mt['outstanding']!;
      paidUnits += (mt['paidUnits'] as num).toInt();
      unpaidUnits += (mt['unpaidUnits'] as num).toInt();
    }
    return {
      'expected': expected,
      'collected': collected,
      'outstanding': outstanding,
      'paidUnits': paidUnits,
      'unpaidUnits': unpaidUnits,
    };
  }

  List<Map<String, dynamic>> _unitAnnual() {
    final List<Map<String, dynamic>> rows = [];
    for (final u in _units) {
      final unit = u as Map<String, dynamic>;
      final id = (unit['id'] as num).toInt();
      final number = (unit['number'] ?? '').toString();
      final rent = _parseNum(unit['rent_amount']);

      int monthsPaid = 0;
      num expected = 0, collected = 0, outstanding = 0;

      for (var m = 1; m <= 12; m++) {
        final period = _period(_year, m);
        final items = _monthData[period] ?? const [];
        final match = items.firstWhere(
          (e) => (e['unit_id'] as num).toInt() == id,
          orElse: () => const {},
        );
        final has = match.isNotEmpty;
        if (has) {
          final paid = match['paid'] == true;
          final due = _parseNum(match['amount_due']);
          expected += rent;
          if (paid) {
            monthsPaid += 1;
            collected += rent;
          } else {
            final got = (rent - (due < 0 ? 0 : due)).clamp(0, rent);
            collected += got;
            outstanding += (due < 0 ? 0 : due).clamp(0, rent);
          }
        }
      }

      rows.add({
        'unit_number': number,
        'rent': rent,
        'months_paid': monthsPaid,
        'expected': expected,
        'collected': collected,
        'outstanding': outstanding,
        'tenant_name': unit['tenant']?['name'],
        'tenant_phone': unit['tenant']?['phone'],
      });
    }
    return rows;
  }

  // ---------- utils ----------

  num _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  String _money(num n) {
    final isInt = (n % 1) == 0;
    return isInt ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
  }

  Future<void> _copyKraText() async {
    final y = _yearTotals();
    final p = _property!;
    final buf = StringBuffer()
      ..writeln('Property: ${p['name']} (${p['property_code']})')
      ..writeln('Address: ${p['address']}')
      ..writeln('Year: $_year')
      ..writeln('--------------------------------')
      ..writeln('Total Expected: KES ${_money(y['expected']!)}')
      ..writeln('Total Collected: KES ${_money(y['collected']!)}')
      ..writeln('Total Outstanding: KES ${_money(y['outstanding']!)}')
      ..writeln('Paid Entries: ${y['paidUnits']}, Unpaid Entries: ${y['unpaidUnits']}')
      ..writeln('\nPer-Unit Annual Summary:')
      ..writeln('Unit, Tenant, Phone, Months Paid, Expected, Collected, Outstanding');
    for (final r in _unitAnnual()) {
      buf.writeln(
          '${r['unit_number']}, ${r['tenant_name'] ?? '-'}, ${r['tenant_phone'] ?? '-'}, ${r['months_paid']}, KES ${_money(r['expected'] as num)}, KES ${_money(r['collected'] as num)}, KES ${_money(r['outstanding'] as num)}');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Summary copied to clipboard')));
  }

  Future<void> _copyCsv() async {
    final headers = [
      'Period',
      'Expected',
      'Collected',
      'Outstanding',
      'Paid Units',
      'Unpaid Units'
    ];
    final rows = <List<String>>[headers];
    for (var m = 1; m <= 12; m++) {
      final period = _period(_year, m);
      final t = _monthTotals(period);
      rows.add([
        period,
        _money(t['expected']!),
        _money(t['collected']!),
        _money(t['outstanding']!),
        '${t['paidUnits']}',
        '${t['unpaidUnits']}',
      ]);
    }
    final csv = rows.map((r) => r.map(_csvEscape).join(',')).join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
  }

  String _csvEscape(String s) {
    final needs = s.contains(',') || s.contains('"') || s.contains('\n');
    return needs ? '"${s.replaceAll('"', '""')}"' : s;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_property == null) {
      return const Scaffold(body: Center(child: Text('Property not found')));
    }

    final years = List<int>.generate(6, (i) => DateTime.now().year - i);
    final yTotals = _yearTotals();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Reports'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _year,
              onChanged: (v) async {
                if (v == null) return;
                setState(() {
                  _year = v;
                  _monthData.clear();
                  _loading = true;
                });
                await _fetchYear(v);
                if (mounted) setState(() => _loading = false);
              },
              items: years
                  .map((y) => DropdownMenuItem<int>(
                        value: y,
                        child: Text('$y'),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Copy KRA-friendly text',
            onPressed: _copyKraText,
            icon: const Icon(Icons.copy_all_rounded),
          ),
          IconButton(
            tooltip: 'Copy CSV',
            onPressed: _copyCsv,
            icon: const Icon(Icons.table_view_rounded),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'By Month'),
            Tab(text: 'By Unit'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // SUMMARY
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(property: _property!),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  _Metric(label: 'Total Expected', value: 'KES ${_money(yTotals['expected']!)}', icon: Icons.request_quote_rounded),
                  _Metric(label: 'Total Collected', value: 'KES ${_money(yTotals['collected']!)}', icon: Icons.payments_rounded),
                  _Metric(label: 'Total Outstanding', value: 'KES ${_money(yTotals['outstanding']!)}', icon: Icons.account_balance_wallet_outlined),
                  _Metric(label: 'Paid Entries', value: '${yTotals['paidUnits']}', icon: Icons.check_circle_rounded),
                  _Metric(label: 'Unpaid Entries', value: '${yTotals['unpaidUnits']}', icon: Icons.error_outline_rounded),
                ],
              ),
            ],
          ),

          // BY MONTH
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(property: _property!),
              const SizedBox(height: 12),
              _MonthTable(
                year: _year,
                monthTotals: (period) => _monthTotals(period),
                money: _money,
              ),
            ],
          ),

          // BY UNIT
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(property: _property!),
              const SizedBox(height: 12),
              _UnitTable(rows: _unitAnnual(), money: _money),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- Widgets ----------

class _HeaderCard extends StatelessWidget {
  final Map<String, dynamic> property;
  const _HeaderCard({required this.property});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
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
          Text(property['name'] ?? 'Property', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: t.hintColor),
              const SizedBox(width: 6),
              Expanded(child: Text(property['address'] ?? '', style: t.textTheme.bodyMedium)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _Metric(label: 'Code', value: property['property_code'] ?? '—', icon: Icons.qr_code_2_rounded),
              _Metric(label: 'Total Units', value: '${property['total_units'] ?? '—'}', icon: Icons.grid_view_rounded),
              _Metric(label: 'Occupied', value: '${property['occupied_units'] ?? '—'}', icon: Icons.person_pin_circle_rounded),
              _Metric(label: 'Vacant', value: '${property['vacant_units'] ?? '—'}', icon: Icons.meeting_room_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Metric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.dividerColor.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: t.hintColor),
          const SizedBox(width: 8),
          Text('$label: ', style: t.textTheme.labelMedium),
          Text(value, style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MonthTable extends StatelessWidget {
  final int year;
  final Map<String, num> Function(String period) monthTotals;
  final String Function(num) money;

  const _MonthTable({required this.year, required this.monthTotals, required this.money});

  String _mm(int m) => m.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
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
            DataColumn(label: Text('Month')),
            DataColumn(label: Text('Expected (KES)')),
            DataColumn(label: Text('Collected (KES)')),
            DataColumn(label: Text('Outstanding (KES)')),
            DataColumn(label: Text('Paid Units')),
            DataColumn(label: Text('Unpaid Units')),
          ],
          rows: List.generate(12, (index) {
            final m = index + 1;
            final period = '$year-${_mm(m)}';
            final totals = monthTotals(period);
            return DataRow(
              cells: [
                DataCell(Text(period)),
                DataCell(Text(money(totals['expected']!))),
                DataCell(Text(money(totals['collected']!))),
                DataCell(Text(money(totals['outstanding']!))),
                DataCell(Text('${totals['paidUnits']}')),
                DataCell(Text('${totals['unpaidUnits']}')),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _UnitTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String Function(num) money;
  const _UnitTable({required this.rows, required this.money});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
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
            DataColumn(label: Text('Unit')),
            DataColumn(label: Text('Tenant')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Months Paid')),
            DataColumn(label: Text('Expected (KES)')),
            DataColumn(label: Text('Collected (KES)')),
            DataColumn(label: Text('Outstanding (KES)')),
          ],
          rows: rows.map((r) {
            return DataRow(
              cells: [
                DataCell(Text('${r['unit_number']}')),
                DataCell(Text('${r['tenant_name'] ?? '—'}')),
                DataCell(Text('${r['tenant_phone'] ?? '—'}')),
                DataCell(Text('${r['months_paid']}')),
                DataCell(Text(money(r['expected'] as num))),
                DataCell(Text(money(r['collected'] as num))),
                DataCell(Text(money(r['outstanding'] as num))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
