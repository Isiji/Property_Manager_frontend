// lib/screens/admin/admin_notifications.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/admin_notification_service.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  bool _loading = true;
  String? _error;

  int _unread = 0;
  List<Map<String, dynamic>> _rows = [];

  String _filter = 'all'; // all | maintenance | payment | system

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final unread = await AdminNotificationService.unreadCount();
      final rows = await AdminNotificationService.listMine(
        limit: 100,
        type: _filter == 'all' ? null : _filter,
      );

      if (!mounted) return;
      setState(() {
        _unread = unread;
        _rows = rows;
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

  Future<void> _markAllRead() async {
    try {
      await AdminNotificationService.markAllRead();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked all as read')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _markOneRead(int id) async {
    try {
      await AdminNotificationService.markOneRead(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
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
        title: const Text('Admin • Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _load,
          ),
          IconButton(
            tooltip: 'Mark all read',
            icon: const Icon(LucideIcons.checkCheck),
            onPressed: _rows.isEmpty ? null : _markAllRead,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
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
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          _pill(
                            context,
                            icon: LucideIcons.mail,
                            label: 'Unread',
                            value: '$_unread',
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _filter,
                              decoration: const InputDecoration(
                                labelText: 'Filter',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(LucideIcons.filter),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All')),
                                DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                                DropdownMenuItem(value: 'payment', child: Text('Payments')),
                                DropdownMenuItem(value: 'system', child: Text('System')),
                              ],
                              onChanged: (v) async {
                                if (v == null) return;
                                setState(() => _filter = v);
                                await _load();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (_rows.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(LucideIcons.bellOff, size: 40, color: t.hintColor),
                              const SizedBox(height: 8),
                              const Text('No notifications yet'),
                            ],
                          ),
                        )
                      else
                        ..._rows.map((n) {
                          final id = (n['id'] as num?)?.toInt() ?? 0;
                          final title = (n['title'] ?? '').toString();
                          final msg = (n['message'] ?? '').toString();
                          final isRead = (n['is_read'] == true);
                          final when = (n['created_at'] ?? '').toString();

                          return Card(
                            child: ListTile(
                              leading: Icon(
                                isRead ? LucideIcons.bell : LucideIcons.bellRing,
                              ),
                              title: Text(
                                title.isEmpty ? '(No title)' : title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.textTheme.titleMedium?.copyWith(
                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.w900,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(msg, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 6),
                                  Text(
                                    when,
                                    style: t.textTheme.labelSmall?.copyWith(color: t.hintColor),
                                  ),
                                ],
                              ),
                              trailing: id == 0
                                  ? null
                                  : TextButton(
                                      onPressed: isRead ? null : () => _markOneRead(id),
                                      child: const Text('Read'),
                                    ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }

  Widget _pill(BuildContext context, {required IconData icon, required String label, required String value}) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.dividerColor.withOpacity(.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: t.hintColor),
          const SizedBox(width: 8),
          Text('$label:', style: t.textTheme.labelMedium),
          const SizedBox(width: 6),
          Text(value, style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}