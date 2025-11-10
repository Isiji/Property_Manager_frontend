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
  List<dynamic> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final res = await NotificationService.list(limit: 100);
      if (!mounted) return;
      setState(() => _items = res);
      await NotificationService.markAllRead();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notifications failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SafeArea(
      child: Material(
        color: t.colorScheme.background,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .8,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (_, i) {
                    final n = (_items[i] as Map).cast<String, dynamic>();
                    final title = (n['title'] ?? 'Notification').toString();
                    final body = (n['body'] ?? '').toString();
                    final ts = (n['created_at'] ?? '').toString();
                    return ListTile(
                      leading: const Icon(Icons.notifications_active_rounded),
                      title: Text(title, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      subtitle: Text(body.isEmpty ? ts : '$body\n$ts'),
                      isThreeLine: body.isNotEmpty,
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: _items.length,
                ),
        ),
      ),
    );
  }
}
