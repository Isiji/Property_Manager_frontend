// lib/widgets/notification_bell.dart
// Reusable bell with unread badge + inbox bottom sheet.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property_manager_frontend/services/notification_service.dart';

class NotificationBell extends StatefulWidget {
  final Duration pollInterval;
  final int listLimit;

  const NotificationBell({
    super.key,
    this.pollInterval = const Duration(seconds: 30),
    this.listLimit = 50,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  Timer? _timer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshUnread();
    _timer = Timer.periodic(widget.pollInterval, (_) => _refreshUnread());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnread() async {
    try {
      final c = await NotificationService.getUnreadCount();
      if (mounted) setState(() => _unread = c);
    } catch (_) {
      // silent
    }
  }

  Future<void> _openInbox() async {
    setState(() => _loading = true);
    List<dynamic> items = const [];
    try {
      items = await NotificationService.listMe(limit: widget.listLimit);
    } catch (_) {}
    setState(() => _loading = false);

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NotificationSheet(
        items: items,
        onMarkedAllRead: () async {
          await NotificationService.markAllRead();
          await _refreshUnread();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final btn = IconButton(
      tooltip: 'Notifications',
      onPressed: _loading ? null : _openInbox,
      icon: const Icon(Icons.notifications_none_rounded),
    );

    if (_unread <= 0) return btn;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        btn,
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _unread > 99 ? '99+' : '$_unread',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onError,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  final List<dynamic> items;
  final Future<void> Function() onMarkedAllRead;

  const _NotificationSheet({required this.items, required this.onMarkedAllRead});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded),
                const SizedBox(width: 8),
                Text('Notifications', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await onMarkedAllRead();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Mark all read'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('You have no notifications yet.',
                            style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = (items[i] is Map) ? (items[i] as Map).cast<String, dynamic>() : <String, dynamic>{};
                        final title = (m['title'] ?? '').toString();
                        final body = (m['message'] ?? '').toString();
                        final created = (m['created_at'] ?? '').toString();
                        final dt = DateTime.tryParse(created);
                        final ts = dt != null ? DateFormat.yMMMd().add_jm().format(dt) : created;

                        return ListTile(
                          leading: const Icon(Icons.notifications_rounded),
                          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('$body\n$ts', maxLines: 3, overflow: TextOverflow.ellipsis),
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
