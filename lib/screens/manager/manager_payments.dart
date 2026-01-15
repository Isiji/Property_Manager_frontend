// ignore_for_file: avoid_print, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:property_manager_frontend/services/payment_service.dart';

class ManagerPaymentsScreen extends StatefulWidget {
  final int propertyId;
  final String? propertyName;
  final String? propertyCode;
  final String initialPeriod; // YYYY-MM

  const ManagerPaymentsScreen({
    super.key,
    required this.propertyId,
    required this.initialPeriod,
    this.propertyName,
    this.propertyCode,
  });

  @override
  State<ManagerPaymentsScreen> createState() => _ManagerPaymentsScreenState();
}

class _ManagerPaymentsScreenState extends State<ManagerPaymentsScreen> {
  bool _loading = true;
  String _period = '';
  Map<String, dynamic> _status = {};
  String _message = '';

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod;
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
      setState(() {
        _loading = true;
        _message = '';
      });

      final data = await PaymentService.getStatusByProperty(
        propertyId: widget.propertyId,
        period: _period,
      );

      if (!mounted) return;
      setState(() {
        _status = Map<String, dynamic>.from(data);
      });
    } catch (e) {
      print('💥 manager payments load failed: $e');
      if (!mounted) return;
      setState(() => _message = 'Failed to load payments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load payments: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Try to read likely keys without crashing if backend differs
  String _val(dynamic x) => x == null ? '—' : x.toString();

  int _int(dynamic x) {
    if (x is int) return x;
    if (x is num) return x.toInt();
    final s = x?.toString() ?? '';
    return int.tryParse(s) ?? 0;
  }

  num _num(dynamic x) {
    if (x is num) return x;
    final s = x?.toString() ?? '';
    return num.tryParse(s) ?? 0;
  }

  List<Map<String, dynamic>> get _lines {
    // Backend might return: { lines: [...] } or { items: [...] } etc
    final raw = _status['lines'] ?? _status['items'] ?? _status['rows'];
    if (raw is List) {
      return raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
    }
    return [];
  }

  Future<void> _recordCashDialog() async {
    // We need leaseId + amount + paid_date
    // We'll pick from lines list if it contains lease_id.
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payment lines found for this period.')),
      );
      return;
    }

    int? leaseId;
    num amount = 0;
    DateTime paidDate = DateTime.now();

    final leaseController = TextEditingController();
    final amountController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Record cash payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: leaseId,
                items: _lines
                    .map((l) {
                      final id = (l['lease_id'] as num?)?.toInt() ?? (l['leaseId'] as num?)?.toInt();
                      final unit = (l['unit'] ?? l['unit_number'] ?? l['unitNumber'] ?? 'Unit').toString();
                      final tenant = (l['tenant'] ?? l['tenant_name'] ?? l['tenantName'] ?? '').toString();
                      if (id == null) return null;
                      return DropdownMenuItem(
                        value: id,
                        child: Text('$unit • $tenant (lease $id)'),
                      );
                    })
                    .whereType<DropdownMenuItem<int>>()
                    .toList(),
                onChanged: (v) {
                  leaseId = v;
                  leaseController.text = v?.toString() ?? '';
                },
                decoration: const InputDecoration(
                  labelText: 'Lease',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: 'e.g. 12000',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(LucideIcons.calendar, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Paid date: ${paidDate.year}-${paidDate.month.toString().padLeft(2, '0')}-${paidDate.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(DateTime.now().year - 2, 1, 1),
                        lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                        initialDate: paidDate,
                      );
                      if (picked != null) {
                        paidDate = picked;
                        // rebuild dialog
                        Navigator.of(context).pop(false);
                        Future.microtask(_recordCashDialog);
                      }
                    },
                    child: const Text('Change'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final a = num.tryParse(amountController.text.trim()) ?? 0;
                amount = a;
                if (leaseId == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pick a lease and enter a valid amount.')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final paidStr =
        '${paidDate.year}-${paidDate.month.toString().padLeft(2, '0')}-${paidDate.day.toString().padLeft(2, '0')}';

    await PaymentService.recordPayment(
      leaseId: leaseId!,
      period: _period,
      amount: amount,
      paidDate: paidStr,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cash payment recorded')),
    );

    await _load();
  }

  Future<void> _bulkReminderDialog() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send bulk reminders'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This will send reminders for UNPAID tenants for $_period.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Optional message',
                hintText: 'E.g. Kindly pay rent to avoid penalties…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await PaymentService.sendRemindersBulk(
      propertyId: widget.propertyId,
      period: _period,
      message: controller.text.trim().isEmpty ? null : controller.text.trim(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk reminders sent')),
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final propTitle = widget.propertyName ?? 'Property ${widget.propertyId}';

    final paid = _val(_status['paid'] ?? _status['paid_count'] ?? _status['paid_units']);
    final unpaid = _val(_status['unpaid'] ?? _status['unpaid_count'] ?? _status['unpaid_units']);
    final overdue = _val(_status['overdue'] ?? _status['overdue_count'] ?? _status['overdue_units']);

    final expected = _val(_status['expected_amount'] ?? _status['expected']);
    final received = _val(_status['paid_amount'] ?? _status['received_amount'] ?? _status['received']);

    return Scaffold(
      appBar: AppBar(
        title: Text('Payments • $propTitle'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: _load,
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
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.calendar, size: 18),
                      const SizedBox(width: 8),
                      const Text('Period'),
                      const SizedBox(width: 10),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _period,
                          items: _lastMonths(count: 14)
                              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _period = v);
                            _load();
                          },
                        ),
                      ),
                      const Spacer(),
                      if (widget.propertyCode != null && widget.propertyCode!.trim().isNotEmpty)
                        Text(
                          'Code: ${widget.propertyCode}',
                          style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                  else if (_message.isNotEmpty)
                    Text(_message, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.error))
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
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _loading ? null : _recordCashDialog,
                icon: const Icon(LucideIcons.plusCircle, size: 18),
                label: const Text('Record cash'),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _bulkReminderDialog,
                icon: const Icon(LucideIcons.bell, size: 18),
                label: const Text('Bulk reminders'),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            'Payment lines',
            style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_lines.isEmpty)
            Text(
              'No payment lines returned for this period. (We’ll align the UI once you share a sample response.)',
              style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
            )
          else
            ..._lines.map((l) {
              final unit = (l['unit'] ?? l['unit_number'] ?? l['unitNumber'] ?? '—').toString();
              final tenant = (l['tenant'] ?? l['tenant_name'] ?? l['tenantName'] ?? '—').toString();
              final amountDue = _val(l['amount_due'] ?? l['due'] ?? l['rent']);
              final amountPaid = _val(l['amount_paid'] ?? l['paid'] ?? l['paid_amount']);
              final status = _val(l['status'] ?? l['payment_status'] ?? '—');

              final leaseId = (l['lease_id'] as num?)?.toInt() ?? (l['leaseId'] as num?)?.toInt() ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.colorScheme.primary.withOpacity(.12),
                        ),
                        child: Center(
                          child: Text(
                            unit.length > 4 ? unit.substring(0, 4) : unit,
                            style: t.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$unit • $tenant', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              'Status: $status • Due: $amountDue • Paid: $amountPaid${leaseId == 0 ? '' : ' • Lease: $leaseId'}',
                              style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
