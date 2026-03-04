// lib/screens/admin/admin_maintenance.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AdminMaintenanceScreen extends StatefulWidget {
  const AdminMaintenanceScreen({super.key});

  @override
  State<AdminMaintenanceScreen> createState() => _AdminMaintenanceScreenState();
}

class _AdminMaintenanceScreenState extends State<AdminMaintenanceScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _statuses = [];
  int? _statusIdFilter;

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
      await _loadStatuses();
      await _loadRequests();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadStatuses() async {
    final headers = await TokenManager.authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/maintenance/status');
    final res = await http.get(uri, headers: {'Content-Type': 'application/json', ...headers});
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is List) {
        _statuses = data.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
      return;
    }
    throw Exception('Failed to load statuses: ${res.statusCode} ${res.body}');
  }

  Future<void> _loadRequests() async {
    final headers = await TokenManager.authHeaders();

    final q = <String, String>{};
    if (_statusIdFilter != null) q['status_id'] = '${_statusIdFilter!}';

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/maintenance').replace(queryParameters: q);

    final res = await http.get(uri, headers: {'Content-Type': 'application/json', ...headers});
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data is List) {
        _rows = data.map((e) => (e as Map).cast<String, dynamic>()).toList();
      } else {
        _rows = [];
      }
      return;
    }
    throw Exception('Failed to load maintenance: ${res.statusCode} ${res.body}');
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Maintenance', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              ),
              DropdownButton<int?>(
                value: _statusIdFilter,
                hint: const Text('All'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All')),
                  ..._statuses.map((s) {
                    final id = (s['id'] as num?)?.toInt();
                    final name = (s['name'] ?? '').toString();
                    return DropdownMenuItem<int?>(
                      value: id,
                      child: Text(name),
                    );
                  }),
                ],
                onChanged: (v) async {
                  setState(() => _statusIdFilter = v);
                  setState(() => _loading = true);
                  try {
                    await _loadRequests();
                    if (!mounted) return;
                    setState(() => _loading = false);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _error = '$e';
                      _loading = false;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_rows.isEmpty)
            Text('No maintenance requests found.', style: t.textTheme.bodyMedium)
          else
            ..._rows.map((m) {
              final id = (m['id'] as num?)?.toInt() ?? 0;
              final desc = (m['description'] ?? '').toString();
              final statusId = (m['status_id'] as num?)?.toInt();
              final createdAt = (m['created_at'] ?? '').toString();
              final unitId = (m['unit_id'] as num?)?.toInt();

              return Card(
                child: ListTile(
                  leading: const Icon(LucideIcons.wrench),
                  title: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('ID: $id • Unit: ${unitId ?? '-'} • Status ID: ${statusId ?? '-'}\nCreated: $createdAt'),
                ),
              );
            }),
        ],
      ),
    );
  }
}