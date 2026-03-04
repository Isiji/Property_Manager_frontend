// lib/screens/admin/admin_notifications.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/notification_api_service.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _rows = [];
  int _unread = 0;

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
      final rows = await NotificationApiService.listMy(limit: 100);
      final unread = await NotificationApiService.unreadCount();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _unread = unread;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
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
                child: Text('Notifications', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              ),
              if (_unread > 0)
                Chip(
                  label: Text('Unread: $_unread'),
                  avatar: const Icon(LucideIcons.bell, size: 18),
                ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  await NotificationApiService.markAllRead();
                  await _load();
                },
                child: const Text('Mark all read'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_rows.isEmpty)
            Text('No notifications.', style: t.textTheme.bodyMedium)
          else
            ..._rows.map((n) {
              final id = (n['id'] as num?)?.toInt() ?? 0;
              final title = (n['title'] ?? '').toString();
              final msg = (n['message'] ?? '').toString();
              final isRead = (n['is_read'] == true);
              final createdAt = (n['created_at'] ?? '').toString();

              return Card(
                child: ListTile(
                  leading: Icon(isRead ? LucideIcons.mailOpen : LucideIcons.mail),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$msg\n$createdAt', maxLines: 3, overflow: TextOverflow.ellipsis),
                  trailing: isRead
                      ? null
                      : TextButton(
                          onPressed: () async {
                            await NotificationApiService.markOneRead(id);
                            await _load();
                          },
                          child: const Text('Read'),
                        ),
                ),
              );
            }),
        ],
      ),
    );
  }
}