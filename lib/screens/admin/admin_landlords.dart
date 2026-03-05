// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AdminLandlordsScreen extends StatefulWidget {
  const AdminLandlordsScreen({super.key});

  @override
  State<AdminLandlordsScreen> createState() => _AdminLandlordsScreenState();
}

class _AdminLandlordsScreenState extends State<AdminLandlordsScreen> {
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final headers = await TokenManager.authHeaders();
      final q = _qCtrl.text.trim();

      // supports: GET /landlords?skip=0&limit=100&q=...
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/landlords')
          .replace(queryParameters: {'skip': '0', 'limit': '200', if (q.isNotEmpty) 'q': q});

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

  // Minimal update dialog (admin support)
  Future<void> _editLandlord(Map<String, dynamic> row) async {
    final id = (row['id'] as num?)?.toInt() ?? 0;
    if (id == 0) return;

    final nameCtrl = TextEditingController(text: (row['name'] ?? '').toString());
    final phoneCtrl = TextEditingController(text: (row['phone'] ?? '').toString());
    final emailCtrl = TextEditingController(text: (row['email'] ?? '').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit landlord #$id'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 8),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          ],
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
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/landlords/$id');

      final payload = <String, dynamic>{
        'name': nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
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

  Future<void> _deleteLandlord(Map<String, dynamic> row) async {
    final id = (row['id'] as num?)?.toInt() ?? 0;
    if (id == 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete landlord #$id?'),
        content: const Text('This is permanent. Only do this if you understand the impact.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final headers = await TokenManager.authHeaders();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/landlords/$id');
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
        title: const Text('Admin • Landlords'),
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
                labelText: 'Search (name/phone/email)',
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
              const Expanded(child: Center(child: Text('No landlords')))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = _rows[i];
                    final id = (r['id'] as num?)?.toInt() ?? 0;
                    final name = (r['name'] ?? '-').toString();
                    final phone = (r['phone'] ?? '-').toString();
                    final email = (r['email'] ?? '-').toString();

                    return Card(
                      child: ListTile(
                        leading: const Icon(LucideIcons.user),
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('ID: $id\nPhone: $phone\nEmail: $email'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'copy_id') await _copy('$id', msg: 'Landlord ID copied');
                            if (v == 'copy_phone') await _copy(phone, msg: 'Phone copied');
                            if (v == 'edit') await _editLandlord(r);
                            if (v == 'delete') await _deleteLandlord(r);
                            if (v == 'open_props') {
                              // optional: you can create landlord detail screen later
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Landlord details screen next')),
                              );
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'copy_id', child: Text('Copy landlord ID')),
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