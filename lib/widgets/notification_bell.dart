import 'package:flutter/material.dart';
import 'package:property_manager_frontend/services/notification_service.dart';
import 'package:property_manager_frontend/widgets/notifications_sheet.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _count = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final c = await NotificationService.getUnreadCount();
      if (mounted) setState(() => _count = c);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => NotificationsSheet(onChanged: _refreshCount),
    );
    await _refreshCount();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          onPressed: _openSheet,
          icon: const Icon(Icons.notifications_rounded),
          tooltip: 'Notifications',
        ),
        if (_count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$_count',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}
