// lib/widgets/maintenance_inbox.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class MaintenanceInboxSheet extends StatefulWidget {
  const MaintenanceInboxSheet({super.key});
  @override
  State<MaintenanceInboxSheet> createState() => _MaintenanceInboxSheetState();
}

class _MaintenanceInboxSheetState extends State<MaintenanceInboxSheet> {
  bool _loading = true;
  List<dynamic> _items = [];
  int? _statusFilter; // null = all
  Map<int, String> _statusIdToName = {};
  Map<String, int> _statusNameToId = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, String>> _auth() => TokenManager.authHeaders();

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      await _loadStatuses();
      final qs = <String, String>{};
      if (_statusFilter != null) qs['status_id'] = '${_statusFilter!}';

      final h = await _auth();
      final url = Uri.parse('${AppConfig.apiBaseUrl}/maintenance/my').replace(queryParameters: qs);
      final r = await http.get(url, headers: {'Content-Type': 'application/json', ...h});
      if (r.statusCode == 200) {
        final b = jsonDecode(r.body);
        setState(() => _items = (b is List) ? b : const []);
      } else {
        throw Exception('${r.statusCode} ${r.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStatuses() async {
    final h = await _auth();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/maintenance/status/');
    final r = await http.get(url, headers: {'Content-Type': 'application/json', ...h});
    if (r.statusCode == 200) {
      final b = jsonDecode(r.body);
      if (b is List) {
        _statusIdToName = {for (final s in b) (s['id'] as num).toInt(): (s['name'] ?? '').toString()};
        _statusNameToId = {for (final s in b) (s['name'] ?? '').toString(): (s['id'] as num).toInt()};
      }
    }
  }

  String _statusName(int? id) => _statusIdToName[id ?? -1] ?? 'open';

  Future<void> _advanceStatus(Map<String, dynamic> m) async {
    final id = (m['id'] as num?)?.toInt();
    final currentId = (m['status_id'] as num?)?.toInt();
    if (id == null || currentId == null) return;

    final seq = ['open', 'in_progress', 'resolved'];
    final nowName = _statusName(currentId);
    final nextName = () {
      final i = seq.indexOf(nowName);
      return (i < 0 || i == seq.length - 1) ? 'resolved' : seq[i + 1];
    }();
    final nextId = _statusNameToId[nextName] ?? currentId;

    try {
      final h = await _auth();
      final url = Uri.parse('${AppConfig.apiBaseUrl}/maintenance/$id');
      final body = jsonEncode({'status_id': nextId});
      final r = await http.put(url, headers: {'Content-Type': 'application/json', ...h}, body: body);
      if (r.statusCode == 200) {
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marked $nextName')));
      } else {
        throw Exception('${r.statusCode} ${r.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('Maintenance Inbox', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                DropdownButton<int?>(
                  value: _statusFilter,
                  hint: const Text('All'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    for (final e in _statusIdToName.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reload'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No tickets found.'),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = (_items[i] as Map).cast<String, dynamic>();
                    final desc = (m['description'] ?? '').toString();
                    final created = (m['created_at'] ?? '').toString();
                    final statusId = (m['status_id'] as num?)?.toInt();
                    final statusName = _statusName(statusId);
                    final chip = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusName == 'resolved'
                            ? t.colorScheme.tertiaryContainer
                            : t.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusName.toUpperCase(),
                        style: t.textTheme.labelSmall?.copyWith(
                          color: statusName == 'resolved'
                              ? t.colorScheme.onTertiaryContainer
                              : t.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );

                    final unit = (m['unit'] ?? {}) as Map? ?? {};
                    final prop = (unit['property'] ?? {}) as Map? ?? {};
                    final unitLabel = (unit['number'] ?? '—').toString();
                    final propName = (prop['name'] ?? '').toString();

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: t.dividerColor.withOpacity(.25)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.build_rounded),
                        title: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('$propName • Unit $unitLabel • $created'),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            chip,
                            OutlinedButton(
                              onPressed: () => _advanceStatus(m),
                              child: const Text('Advance'),
                            ),
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
