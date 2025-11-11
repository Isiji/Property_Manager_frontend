// lib/widgets/notifications_sheet.dart
import 'package:flutter/material.dart';
import 'package:property_manager_frontend/services/notification_service.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});
  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  bool _loading = true;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final list = await NotificationService.list(limit: 100);
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationService.markAllRead();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked all as read')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
                Text('Notifications', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _markAllRead,
                  icon: const Icon(Icons.mark_email_read_rounded),
                  label: const Text('Mark all read'),
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
                child: Text('No notifications.'),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final n = (_items[i] as Map).cast<String, dynamic>();
                    final title = (n['title'] ?? '').toString();
                    final msg = (n['message'] ?? '').toString();
                    final isRead = n['is_read'] == true;
                    final ts = (n['created_at'] ?? '').toString();
                    return ListTile(
                      leading: Icon(
                        isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                      ),
                      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('$msg\n$ts', maxLines: 3, overflow: TextOverflow.ellipsis),
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
