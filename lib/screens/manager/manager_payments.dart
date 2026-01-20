// ignore_for_file: avoid_print, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:property_manager_frontend/services/payment_service.dart';

class ManagerPaymentsScreen extends StatefulWidget {
  final int propertyId;
  final String? propertyCode;
  final String? propertyName;
  final String? initialPeriod; // YYYY-MM

  const ManagerPaymentsScreen({
    super.key,
    required this.propertyId,
    this.propertyCode,
    this.propertyName,
    this.initialPeriod,
  });

  @override
  State<ManagerPaymentsScreen> createState() => _ManagerPaymentsScreenState();
}

class _ManagerPaymentsScreenState extends State<ManagerPaymentsScreen> {
  bool _loading = true;
  String _period = '';
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _period = widget.initialPeriod ??
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _load();
  }

  List<String> _lastMonths({int count = 12}) {
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

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final s = await PaymentService.getStatusByProperty(
        propertyId: widget.propertyId,
        period: _period,
      );
      if (!mounted) return;
      setState(() => _status = s);
    } catch (e) {
      print('💥 payments load failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load payments: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _val(String k1, String k2, String k3) {
    final s = _status;
    if (s == null) return '—';
    final v = s[k1] ?? s[k2] ?? s[k3];
    if (v == null) return '—';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final title = (widget.propertyName?.trim().isNotEmpty ?? false)
        ? widget.propertyName!.trim()
        : 'Property ${widget.propertyId}';

    final code = widget.propertyCode?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Payments • $title'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _period,
              items: _lastMonths(count: 12)
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                setState(() => _period = v);
                await _load();
              },
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(LucideIcons.refreshCcw),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          if (code.isNotEmpty)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(LucideIcons.qrCode, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Property code: $code')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_status == null || _status!.isEmpty)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'No payment status available for $_period yet.\n'
                  'This is normal if there are no recorded payments.',
                  style: t.textTheme.bodySmall?.copyWith(color: t.hintColor, height: 1.35),
                ),
              ),
            )
          else
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _stat(t, 'Paid', _val('paid', 'paid_count', 'paid_units')),
                    _stat(t, 'Unpaid', _val('unpaid', 'unpaid_count', 'unpaid_units')),
                    _stat(t, 'Overdue', _val('overdue', 'overdue_count', 'overdue_units')),
                    _stat(t, 'Expected', _val('expected_amount', 'expected', 'total_expected')),
                    _stat(t, 'Received', _val('paid_amount', 'received_amount', 'received')),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 14),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Actions', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text(
                    '• Record cash payments (needs lease ID)\n'
                    '• Send reminders (single or bulk)',
                    style: t.textTheme.bodySmall?.copyWith(color: t.hintColor, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Next: record cash payment dialog')),
                          );
                        },
                        icon: const Icon(LucideIcons.plusCircle, size: 18),
                        label: const Text('Record cash'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Next: bulk reminders dialog')),
                          );
                        },
                        icon: const Icon(LucideIcons.bellRing, size: 18),
                        label: const Text('Bulk reminders'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(ThemeData t, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.dividerColor.withOpacity(.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: t.textTheme.labelMedium),
          Text(value, style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
