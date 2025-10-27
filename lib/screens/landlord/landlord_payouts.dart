// lib/screens/landlord/landlord_payouts.dart
import 'package:flutter/material.dart';
import 'package:property_manager_frontend/services/payout_service.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class LandlordPayoutsScreen extends StatefulWidget {
  const LandlordPayoutsScreen({super.key});

  @override
  State<LandlordPayoutsScreen> createState() => _LandlordPayoutsScreenState();
}

class _LandlordPayoutsScreenState extends State<LandlordPayoutsScreen> {
  bool _loading = true;
  int? _landlordId;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await TokenManager.currentUserId();
    final role = await TokenManager.currentRole();
    if (id == null || role != 'landlord') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid session. Please login as landlord.')),
      );
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    _landlordId = id;
    await _load();
  }

  Future<void> _load() async {
    if (_landlordId == null) return;
    setState(() => _loading = true);
    try {
      final list = await PayoutService.listForLandlord(_landlordId!);
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load payouts: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDialog() async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _PayoutDialog(),
    );
    if (data == null) return;
    data['landlord_id'] = _landlordId;

    try {
      await PayoutService.create(data);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Payout method added')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Create failed: $e')));
    }
  }

  Future<void> _openEditDialog(Map<String, dynamic> item) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PayoutDialog(initial: item),
    );
    if (data == null) return;
    try {
      await PayoutService.update(item['id'] as int, data);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Payout method updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  Future<void> _deleteItem(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete payout method'),
        content: const Text('This action cannot be undone. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await PayoutService.deletePayout(id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Payout method deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout Methods'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add method'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No payout methods yet'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (_, i) {
                    final p = _items[i] as Map<String, dynamic>;
                    final type = (p['payout_type'] ?? '').toString();
                    final isDefault = p['is_default'] == true;
                    final label = p['label'] ?? '';
                    final detail = _formatDetail(type, p);

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(label, style: t.textTheme.titleMedium),
                            const SizedBox(width: 8),
                            if (isDefault)
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: t.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('Default',
                                    style: t.textTheme.labelSmall?.copyWith(
                                        color: t.colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        subtitle: Text('$type • $detail'),
                        trailing: Wrap(spacing: 6, children: [
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => _openEditDialog(p),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _deleteItem(p['id'] as int),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ]),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: _items.length,
                ),
    );
  }

  String _formatDetail(String type, Map<String, dynamic> p) {
    switch (type) {
      case 'mpesa_paybill':
        final pb = p['paybill'] ?? '—';
        final acc = p['paybill_account'] ?? '—';
        return 'Paybill: $pb / Acc: $acc';
      case 'mpesa_till':
        return 'Till: ${p['till_number'] ?? '—'}';
      case 'mpesa_phone':
        return 'Phone: ${p['mpesa_phone'] ?? '—'}';
      case 'bank':
        final bank = p['bank_name'] ?? '—';
        final acc = p['bank_account_number'] ?? '—';
        return 'Bank: $bank / Acc: $acc';
      default:
        return '';
    }
  }
}

class _PayoutDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _PayoutDialog({this.initial});

  @override
  State<_PayoutDialog> createState() => _PayoutDialogState();
}

class _PayoutDialogState extends State<_PayoutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _paybill = TextEditingController();
  final _paybillAcc = TextEditingController();
  final _till = TextEditingController();
  final _phone = TextEditingController();
  final _bank = TextEditingController();
  final _branch = TextEditingController();
  final _accName = TextEditingController();
  final _accNo = TextEditingController();

  String _type = 'mpesa_paybill';
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _type = (i['payout_type'] ?? _type).toString();
      _label.text = i['label'] ?? '';
      _isDefault = i['is_default'] == true;

      _paybill.text = i['paybill'] ?? '';
      _paybillAcc.text = i['paybill_account'] ?? '';
      _till.text = i['till_number'] ?? '';
      _phone.text = i['mpesa_phone'] ?? '';
      _bank.text = i['bank_name'] ?? '';
      _branch.text = i['bank_branch'] ?? '';
      _accName.text = i['bank_account_name'] ?? '';
      _accNo.text = i['bank_account_number'] ?? '';
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _paybill.dispose();
    _paybillAcc.dispose();
    _till.dispose();
    _phone.dispose();
    _bank.dispose();
    _branch.dispose();
    _accName.dispose();
    _accNo.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final payload = <String, dynamic>{
      'payout_type': _type,
      'label': _label.text.trim(),
      'is_default': _isDefault,
    };

    if (_type == 'mpesa_paybill') {
      payload['paybill'] = _paybill.text.trim();
      payload['paybill_account'] = _paybillAcc.text.trim();
    } else if (_type == 'mpesa_till') {
      payload['till_number'] = _till.text.trim();
    } else if (_type == 'mpesa_phone') {
      payload['mpesa_phone'] = _phone.text.trim();
    } else if (_type == 'bank') {
      payload['bank_name'] = _bank.text.trim();
      payload['bank_branch'] = _branch.text.trim();
      payload['bank_account_name'] = _accName.text.trim();
      payload['bank_account_number'] = _accNo.text.trim();
    }

    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Payout Method' : 'Add Payout Method'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'mpesa_paybill', child: Text('M-Pesa Paybill')),
                  DropdownMenuItem(value: 'mpesa_till', child: Text('M-Pesa Till')),
                  DropdownMenuItem(value: 'mpesa_phone', child: Text('M-Pesa Phone')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank Account')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'mpesa_paybill'),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _label,
                decoration: const InputDecoration(labelText: 'Label'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                title: const Text('Set as default'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              ..._typeFields(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }

  List<Widget> _typeFields() {
    switch (_type) {
      case 'mpesa_paybill':
        return [
          TextFormField(
            controller: _paybill,
            decoration: const InputDecoration(labelText: 'Paybill Number'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _paybillAcc,
            decoration: const InputDecoration(labelText: 'Account (Business No. Ref)'),
          ),
        ];
      case 'mpesa_till':
        return [
          TextFormField(
            controller: _till,
            decoration: const InputDecoration(labelText: 'Till Number'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ];
      case 'mpesa_phone':
        return [
          TextFormField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'M-Pesa Phone (2547...)'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ];
      case 'bank':
        return [
          TextFormField(controller: _bank, decoration: const InputDecoration(labelText: 'Bank Name'), validator: _req),
          const SizedBox(height: 8),
          TextFormField(controller: _branch, decoration: const InputDecoration(labelText: 'Branch')),
          const SizedBox(height: 8),
          TextFormField(controller: _accName, decoration: const InputDecoration(labelText: 'Account Name'), validator: _req),
          const SizedBox(height: 8),
          TextFormField(controller: _accNo, decoration: const InputDecoration(labelText: 'Account Number'), validator: _req),
        ];
      default:
        return [];
    }
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
}
