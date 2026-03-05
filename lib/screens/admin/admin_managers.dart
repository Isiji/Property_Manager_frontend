// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AdminManagersScreen extends StatefulWidget {
  const AdminManagersScreen({super.key});

  @override
  State<AdminManagersScreen> createState() => _AdminManagersScreenState();
}

class _AdminManagersScreenState extends State<AdminManagersScreen> {
  bool _loading = true;
  String? _error;

  final _qCtrl = TextEditingController();
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Future<void> _copy(String text, {String msg = 'Copied'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _displayName(Map<String, dynamic> m) {
    final type = (m['type'] ?? '').toString().toLowerCase();
    if (type == 'agency') {
      final company = (m['company_name'] ?? '').toString().trim();
      if (company.isNotEmpty) return company;
    }
    return (m['name'] ?? '').toString();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final headers = await TokenManager.authHeaders();
      final q = _qCtrl.text.trim();

      final Uri uri;
      if (q.isEmpty) {
        uri = Uri.parse('${AppConfig.apiBaseUrl}/managers?skip=0&limit=200');
      } else {
        uri = Uri.parse('${AppConfig.apiBaseUrl}/managers/search?q=${Uri.encodeComponent(q)}&limit=200');
      }

      final res = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        ...headers,
        'ngrok-skip-browser-warning': 'true',
      });

      if (res.statusCode != 200) {
        throw Exception('Failed: ${res.statusCode} ${res.body}');
      }

      final decoded = jsonDecode(res.body);
      final rows = (decoded as List).map((e) => (e as Map).cast<String, dynamic>()).toList();

      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _editManager(Map<String, dynamic> row) async {
    final id = (row['id'] as num?)?.toInt() ?? 0;
    if (id == 0) return;

    final nameCtrl = TextEditingController(text: (row['name'] ?? '').toString());
    final phoneCtrl = TextEditingController(text: (row['phone'] ?? '').toString());
    final emailCtrl = TextEditingController(text: (row['email'] ?? '').toString());
    final typeCtrl = TextEditingController(text: (row['type'] ?? 'individual').toString());
    final companyCtrl = TextEditingController(text: (row['company_name'] ?? '').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit manager org #$id'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Type (individual/agency)')),
              const SizedBox(height: 8),
              TextField(controller: companyCtrl, decoration: const InputDecoration(labelText: 'Company name (if agency)')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
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

    try {
      final headers = await TokenManager.authHeaders();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/managers/$id');

      final payload = <String, dynamic>{
        'name': nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
        'type': typeCtrl.text.trim().isEmpty ? null : typeCtrl.text.trim(),
        'company_name': companyCtrl.text.trim().isEmpty ? null : companyCtrl.text.trim(),
        'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
      }..removeWhere((k, v) => v == null);

      final res = await http.put(
        uri,
        headers: {'Content-Type': 'application/json', ...headers},
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200) {
        throw Exception('Update failed: ${res.statusCode} ${res.body}');
      }

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _deleteManager(Map<String, dynamic> row) async {
    final id = (row['id'] as num?)?.toInt() ?? 0;
    if (id == 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete manager org #$id?'),
        content: const Text('This deletes the org record. Only do this if you understand the impact.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final headers = await TokenManager.authHeaders();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/managers/$id');
      final res = await http.delete(uri, headers: {'Content-Type': 'application/json', ...headers});

      if (res.statusCode != 204 && res.statusCode != 200) {
        throw Exception('Delete failed: ${res.statusCode} ${res.body}');
      }

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack),
        title: const Text('Admin • Managers/Agencies'),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(LucideIcons.refreshCw), onPressed: _load),
          const SizedBox(width: 6),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _qCtrl,
              decoration: const InputDecoration(
                labelText: 'Search (name/phone/email/company)',
                prefixIcon: Icon(LucideIcons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 10),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(child: Center(child: Text(_error!, style: TextStyle(color: t.colorScheme.error))))
            else if (_rows.isEmpty)
              const Expanded(child: Center(child: Text('No managers/agencies')))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = _rows[i];

                    final id = (r['id'] as num?)?.toInt() ?? 0;
                    final type = (r['type'] ?? 'individual').toString();
                    final name = _displayName(r);
                    final phone = (r['phone'] ?? '-').toString();
                    final email = (r['email'] ?? '-').toString();

                    return Card(
                      child: ListTile(
                        leading: Icon(type.toLowerCase() == 'agency' ? LucideIcons.building : LucideIcons.user),
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('ID: $id • Type: $type\nPhone: $phone\nEmail: $email'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'copy_id') await _copy('$id', msg: 'Manager ID copied');
                            if (v == 'copy_phone') await _copy(phone, msg: 'Phone copied');
                            if (v == 'edit') await _editManager(r);
                            if (v == 'delete') await _deleteManager(r);
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'copy_id', child: Text('Copy manager ID')),
                            PopupMenuItem(value: 'copy_phone', child: Text('Copy phone')),
                            PopupMenuDivider(),
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}