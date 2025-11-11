// lib/widgets/notification_bell.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:property_manager_frontend/services/notification_service.dart';
import 'package:property_manager_frontend/widgets/notifications_sheet.dart';
import 'package:property_manager_frontend/widgets/maintenance_inbox.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tick();
    // Poll every 30s so the badge reflects new activity
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    try {
      final n = await NotificationService.getUnreadCount();
      if (mounted) setState(() => _unread = n);
    } catch (_) {}
  }

  Future<void> _open() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const NotificationsSheet(),
    );
    // Refresh badge when sheet closes
    await _tick();

    // Deep-link to Maintenance Inbox if requested by the sheet
    if (result == NotificationsSheet.resultOpenMaintenance && mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const MaintenanceInboxSheet(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: _open,
          icon: const Icon(Icons.notifications_rounded),
          tooltip: 'Notifications',
        ),
        if (_unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _unread > 99 ? '99+' : '$_unread',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}
