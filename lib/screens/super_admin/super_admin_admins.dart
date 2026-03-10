// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class SuperAdminAdminsScreen extends StatefulWidget {
  const SuperAdminAdminsScreen({super.key});

  @override
  State<SuperAdminAdminsScreen> createState() => _SuperAdminAdminsScreenState();
}

class _SuperAdminAdminsScreenState extends State<SuperAdminAdminsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, String>> _headers() async {
    final headers = await TokenManager.authHeaders();
    return {
      'Content-Type': 'application/json',
      ...headers,
      'ngrok-skip-browser-warning': 'true',
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/admins?skip=0&limit=200'),
        headers: await _headers(),
      );

      if (res.statusCode != 200) {
        throw Exception('Failed to load admins: ${res.statusCode} ${res.body}');
      }

      final decoded = jsonDecode(res.body) as List;
      _rows = decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _createAdmin() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final idCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create admin'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 8),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 8),
              TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'ID Number (optional)')),
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

    try {
      final payload = {
        'name': nameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'password': passwordCtrl.text.trim(),
        'id_number': idCtrl.text.trim().isEmpty ? null : idCtrl.text.trim(),
      };

      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/admins'),
        headers: await _headers(),
        body: jsonEncode(payload),
      );

      if (res.statusCode != 201) {
        throw Exception('Create failed: ${res.statusCode} ${res.body}');
      }

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin created')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e')),
      );
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> row) async {
    final id = (row['id'] as num?)?.toInt() ?? 0;
    final active = (row['active'] as bool?) ?? true;
    if (id == 0) return;

    try {
      final endpoint = active ? 'deactivate' : 'activate';
      final res = await http.patch(
        Uri.parse('${AppConfig.apiBaseUrl}/admins/$id/$endpoint'),
        headers: await _headers(),
      );

      if (res.statusCode != 200) {
        throw Exception('Failed: ${res.statusCode} ${res.body}');
      }

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(active ? 'Admin deactivated' : 'Admin activated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  Future<void> _deleteAdmin(Map<String, dynamic> row) async {
    final id = (row['id'] as num?)?.toInt() ?? 0;
    if (id == 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete admin #$id?'),
        content: const Text('This permanently deletes the admin record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final res = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/admins/$id'),
        headers: await _headers(),
      );

      if (res.statusCode != 204) {
        throw Exception('Delete failed: ${res.statusCode} ${res.body}');
      }

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin • Admin Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(LucideIcons.refreshCw),
          ),
          IconButton(
            tooltip: 'Create admin',
            onPressed: _createAdmin,
            icon: const Icon(LucideIcons.plus),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: t.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _rows.isEmpty
                  ? const Center(child: Text('No admins found'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final row = _rows[i];
                        final id = (row['id'] as num?)?.toInt() ?? 0;
                        final name = (row['name'] ?? '-').toString();
                        final email = (row['email'] ?? '-').toString();
                        final phone = (row['phone'] ?? '-').toString();
                        final active = (row['active'] as bool?) ?? true;

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              active ? LucideIcons.badgeCheck : LucideIcons.badgeX,
                            ),
                            title: Text(name),
                            subtitle: Text(
                              'ID: $id\nEmail: $email\nPhone: $phone',
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'toggle') await _toggleActive(row);
                                if (v == 'delete') await _deleteAdmin(row);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(active ? 'Deactivate' : 'Activate'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createAdmin,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Create admin'),
      ),
    );
  }
}