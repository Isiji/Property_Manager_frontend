// lib/screens/admin/admin_logs.dart
// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final headers = await TokenManager.authHeaders();
      final q = _qCtrl.text.trim();
      final url = Uri.parse('${AppConfig.apiBaseUrl}/audit-logs/me?limit=100${q.isEmpty ? '' : '&q=$q'}');

      final res = await http.get(url, headers: {
        'Content-Type': 'application/json',
        ...headers,
        'ngrok-skip-browser-warning': 'true',
      });

      if (res.statusCode != 200) {
        throw Exception('Failed to load logs: ${res.body}');
      }

      final data = jsonDecode(res.body) as List;
      _rows = data.map((e) => (e as Map).cast<String, dynamic>()).toList();

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(LucideIcons.scrollText, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Audit Logs (Admin)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _qCtrl,
              decoration: const InputDecoration(
                labelText: "Search logs (action/message)",
                prefixIcon: Icon(LucideIcons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 10),

            if (_loading) const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(child: Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))))
            else if (_rows.isEmpty)
              const Expanded(child: Center(child: Text('No logs')))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = _rows[i];
                    final action = (r['action'] ?? '-').toString();
                    final entityType = (r['entity_type'] ?? '-').toString();
                    final message = (r['message'] ?? '').toString();
                    final at = (r['created_at'] ?? '').toString();
                    final propName = (r['property_name'] ?? '-').toString();
                    final propCode = (r['property_code'] ?? '-').toString();
                    final actorRole = (r['actor_role'] ?? '-').toString();
                    final actorId = (r['actor_id'] ?? '-').toString();

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Theme.of(context).colorScheme.primary.withOpacity(.10),
                                ),
                                child: Icon(LucideIcons.fileText, size: 18, color: Theme.of(context).colorScheme.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  action,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              Text(at, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Entity: $entityType', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text('Property: $propName • $propCode', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text('Actor: $actorRole • $actorId', style: Theme.of(context).textTheme.bodySmall),
                          if (message.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(message),
                          ]
                        ],
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