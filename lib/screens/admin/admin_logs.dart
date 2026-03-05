// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final url = Uri.parse(
        '${AppConfig.apiBaseUrl}/audit-logs/me?limit=100${q.isEmpty ? '' : '&q=${Uri.encodeComponent(q)}'}',
      );

      final res = await http.get(url, headers: {
        'Content-Type': 'application/json',
        ...headers,
        'ngrok-skip-browser-warning': 'true',
      });

      if (res.statusCode != 200) {
        throw Exception('Failed to load logs: ${res.statusCode} ${res.body}');
      }

      final data = jsonDecode(res.body) as List;
      _rows = data.map((e) => (e as Map).cast<String, dynamic>()).toList();

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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _goBack,
        ),
        title: const Text('Admin • Audit Logs'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(LucideIcons.refreshCw),
          ),
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
                labelText: "Search logs (action/message/property)",
                prefixIcon: Icon(LucideIcons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 10),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Text(_error!, style: TextStyle(color: t.colorScheme.error)),
                ),
              )
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
                    final entityId = (r['entity_id'] ?? '-').toString();

                    final message = (r['message'] ?? '').toString();
                    final at = (r['created_at'] ?? '').toString();

                    final propName = (r['property_name'] ?? '-').toString();
                    final propCode = (r['property_code'] ?? '-').toString();

                    final actorRole = (r['actor_role'] ?? '-').toString();
                    final actorId = (r['actor_id'] ?? '-').toString();

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: t.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: t.dividerColor.withOpacity(.25)),
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
                                  color: t.colorScheme.primary.withOpacity(.10),
                                ),
                                child: Icon(LucideIcons.fileText, size: 18, color: t.colorScheme.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  action,
                                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              Text(at, style: t.textTheme.bodySmall),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Text('Entity: $entityType • $entityId', style: t.textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text('Property: $propName • $propCode', style: t.textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text('Actor: $actorRole • $actorId', style: t.textTheme.bodySmall),

                          if (message.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(message),
                          ],

                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (propCode.trim().isNotEmpty && propCode != '-')
                                TextButton.icon(
                                  onPressed: () => _copy(propCode, msg: 'Property code copied'),
                                  icon: const Icon(LucideIcons.copy, size: 16),
                                  label: const Text('Copy code'),
                                ),
                              TextButton.icon(
                                onPressed: () => _copy(jsonEncode(r), msg: 'Log JSON copied'),
                                icon: const Icon(LucideIcons.copy, size: 16),
                                label: const Text('Copy JSON'),
                              ),
                            ],
                          )
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