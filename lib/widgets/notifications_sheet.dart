import 'package:flutter/material.dart';
import 'package:property_manager_frontend/services/notification_service.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class NotificationsSheet extends StatefulWidget {
  final Future<void> Function()? onChanged;
  const NotificationsSheet({super.key, this.onChanged});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await NotificationService.list(limit: 100);
      _items = raw.map<Map<String, dynamic>>((e) => (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{}).toList();
    } catch (e) {
      _items = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      if (widget.onChanged != null) await widget.onChanged!();
    }
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationService.markAllRead();
      setState(() => _items = _items.map((m) => {...m, 'is_read': true}).toList());
      if (widget.onChanged != null) await widget.onChanged!();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mark all failed: $e')));
    }
  }

  Future<void> _openOne(Map<String, dynamic> n) async {
    // instant UI: mark this notification as read
    final id = (n['id'] as num?)?.toInt();
    if (id != null) {
      try {
        await NotificationService.markRead(id);
        setState(() => _items.removeWhere((m) => (m['id'] as num?)?.toInt() == id));
        if (widget.onChanged != null) await widget.onChanged!();
      } catch (_) {}
    }

    // navigate
    final title = (n['title'] ?? '').toString().toLowerCase();
    final msg   = (n['message'] ?? '').toString().toLowerCase();
    final role  = await TokenManager.currentRole();
    final looksMaintenance = title.contains('maint') || msg.contains('maint');

    if (!mounted) return;
    if (looksMaintenance) {
      if (role == 'landlord') {
        Navigator.of(context).pushNamed('/landlord_maintenance_inbox');
      } else if (role == 'property_manager' || role == 'manager') {
        Navigator.of(context).pushNamed('/manager_maintenance_inbox');
      } else {
        Navigator.of(context).pop({"navigate": "tenant_maintenance"});
      }
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('Notifications', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton.icon(onPressed: _markAllRead, icon: const Icon(Icons.done_all_rounded), label: const Text('Mark all read')),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            Flexible(
              child: _items.isEmpty
                  ? const Padding(padding: EdgeInsets.all(24), child: Text('Nothing here…'))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final n = _items[i];
                        final title = (n['title'] ?? '').toString();
                        final msg   = (n['message'] ?? '').toString();
                        final ts    = (n['created_at'] ?? '').toString();
                        final read  = n['is_read'] == true;
                        return ListTile(
                          leading: Icon(read ? Icons.mark_email_read_rounded : Icons.markunread_rounded),
                          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('$msg\n$ts', maxLines: 2, overflow: TextOverflow.ellipsis),
                          isThreeLine: true,
                          onTap: () => _openOne(n),
                          trailing: read ? null : const Icon(Icons.chevron_right_rounded),
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
