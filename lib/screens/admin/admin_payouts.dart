// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/admin_payout_service.dart';

class AdminPayoutsScreen extends StatefulWidget {
  const AdminPayoutsScreen({super.key});

  @override
  State<AdminPayoutsScreen> createState() => _AdminPayoutsScreenState();
}

class _AdminPayoutsScreenState extends State<AdminPayoutsScreen> {
  final _landlordIdCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _rows = [];

  @override
  void dispose() {
    _landlordIdCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  int _landlordId() => int.tryParse(_landlordIdCtrl.text.trim()) ?? 0;

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await job();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    final lid = _landlordId();
    if (lid <= 0) {
      setState(() => _error = 'Enter a valid landlord_id');
      return;
    }

    await _run(() async {
      final rows = await AdminPayoutService.listPayoutsForLandlord(lid);
      setState(() => _rows = rows);
    });
  }

  Future<void> _create() async {
    final lid = _landlordId();
    if (lid <= 0) {
      setState(() => _error = 'Enter a valid landlord_id');
      return;
    }

    final amountCtrl = TextEditingController();
    final statusCtrl = TextEditingController(text: 'pending');
    final refCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create payout (admin)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Landlord ID: $lid'),
              const SizedBox(height: 8),
              TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount')),
              const SizedBox(height: 8),
              TextField(controller: statusCtrl, decoration: const InputDecoration(labelText: 'Status')),
              const SizedBox(height: 8),
              TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference (optional)')),
              const SizedBox(height: 8),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;

    final amount = num.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Amount must be > 0');
      return;
    }

    await _run(() async {
      await AdminPayoutService.createPayout({
        'landlord_id': lid,
        'amount': amount,
        'status': statusCtrl.text.trim().isEmpty ? 'pending' : statusCtrl.text.trim(),
        'reference': refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
        'notes': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      });
      await _load();
    });
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    final id = (row['id'] as num?)?.toInt() ?? 0;
    if (id == 0) return;

    final amountCtrl = TextEditingController(text: (row['amount'] ?? '').toString());
    final statusCtrl = TextEditingController(text: (row['status'] ?? 'pending').toString());
    final refCtrl = TextEditingController(text: (row['reference'] ?? '').toString());
    final noteCtrl = TextEditingController(text: (row['notes'] ?? '').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Update payout #$id'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount')),
              const SizedBox(height: 8),
              TextField(controller: statusCtrl, decoration: const InputDecoration(labelText: 'Status')),
              const SizedBox(height: 8),
              TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference')),
              const SizedBox(height: 8),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Notes')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;

    await _run(() async {
      await AdminPayoutService.updatePayout(
        id,
        {
          'amount': num.tryParse(amountCtrl.text.trim()),
          'status': statusCtrl.text.trim().isEmpty ? null : statusCtrl.text.trim(),
          'reference': refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
          'notes': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        }..removeWhere((k, v) => v == null),
      );
      await _load();
    });
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = (row['id'] as num?)?.toInt() ?? 0;
    if (id == 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete payout #$id?'),
        content: const Text('Permanent. Only do this if needed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    await _run(() async {
      await AdminPayoutService.deletePayout(id);
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack),
        title: const Text('Admin • Payouts'),
        actions: [
          IconButton(tooltip: 'Create payout', icon: const Icon(LucideIcons.plus), onPressed: _create),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 3),
          if (_error != null)
            Material(
              color: t.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertTriangle, color: t.colorScheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onErrorContainer),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      onPressed: () => setState(() => _error = null),
                      icon: Icon(Icons.close, color: t.colorScheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _landlordIdCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Landlord ID',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(LucideIcons.user),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(LucideIcons.play),
                      label: const Text('Load'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_rows.isEmpty)
                  Text('No payouts loaded.', style: t.textTheme.bodySmall?.copyWith(color: t.hintColor))
                else
                  ..._rows.map((p) {
                    final id = (p['id'] as num?)?.toInt() ?? 0;
                    final status = (p['status'] ?? 'unknown').toString();
                    final amount = (p['amount'] ?? 0).toString();
                    final created = (p['created_at'] ?? '').toString();

                    return Card(
                      child: ListTile(
                        leading: const Icon(LucideIcons.arrowLeftRight),
                        title: Text('Payout #$id • $status'),
                        subtitle: Text('Amount: $amount\nCreated: $created'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') await _edit(p);
                            if (v == 'delete') await _delete(p);
                            if (v == 'copy_json') {
                              final s = jsonEncode(p);
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                              // we keep it simple; AdminLogs already has copy util
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}