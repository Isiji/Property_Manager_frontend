// lib/widgets/maintenance_inbox.dart
// Bottom-sheet inbox for maintenance-related notifications (landlord/manager).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property_manager_frontend/services/notification_service.dart';

class MaintenanceInboxSheet extends StatefulWidget {
  const MaintenanceInboxSheet({super.key});

  @override
  State<MaintenanceInboxSheet> createState() => _MaintenanceInboxSheetState();
}

class _MaintenanceInboxSheetState extends State<MaintenanceInboxSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      // Uses listMe(), which resolves current user and calls /notifications/{id}
      final list = await NotificationService.listMe(limit: 100);
      // keep only maintenance-ish items
      final maint = list.where((e) {
        final m = e.map((k, v) => MapEntry(k.toString(), v));
        final title = (m['title'] ?? '').toString().toLowerCase();
        final msg = (m['message'] ?? '').toString().toLowerCase();
        return title.contains('maintenance') ||
               title.contains('request') ||
               msg.contains('maintenance') ||
               msg.contains('request');
      }).toList();
      setState(() => _items = maint);
    } catch (e) {
      setState(() => _items = const []);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load inbox: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(Icons.build_rounded),
              const SizedBox(width: 8),
              Text('Maintenance Inbox',
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ]),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text('No maintenance notifications yet.',
                    style: t.textTheme.bodyMedium?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                    )),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = _items[i];
                    final title = (m['title'] ?? 'Maintenance').toString();
                    final message = (m['message'] ?? '').toString();
                    final created = (m['created_at'] ?? '').toString();
                    final dt = DateTime.tryParse(created);
                    final ts = dt != null ? DateFormat.yMMMd().add_jm().format(dt) : created;

                    return ListTile(
                      leading: const Icon(Icons.report_problem_rounded),
                      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('$message\n$ts', maxLines: 3, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        // TODO: Deep-link to property/unit screen (parse unit from message).
                      },
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
