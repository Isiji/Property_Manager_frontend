// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/manager_service.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class ManagerDashboardRouter extends StatefulWidget {
  const ManagerDashboardRouter({super.key});

  @override
  State<ManagerDashboardRouter> createState() => _ManagerDashboardRouterState();
}

class _ManagerDashboardRouterState extends State<ManagerDashboardRouter> {
  bool _loading = true;
  String _msg = 'Loading…';

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    try {
      final role = await TokenManager.currentRole();
      final id = await TokenManager.currentUserId();

      if (!mounted) return;

      if (role != 'manager' || id == null) {
        await TokenManager.clearSession();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }

      // ✅ Decide landing based on /managers/me
      final me = await ManagerService.getMe();
      final managerType = (me['manager_type'] ?? 'individual').toString().toLowerCase();

      if (!mounted) return;

      if (managerType == 'agency') {
        Navigator.of(context).pushReplacementNamed('/agency_dashboard');
      } else {
        // your existing manager landing
        Navigator.of(context).pushReplacementNamed('/manager_properties');
      }
    } catch (e) {
      print('💥 ManagerDashboardRouter failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _msg = 'Failed to load session.\n$e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.loader, size: 44, color: t.hintColor),
              const SizedBox(height: 12),
              Text(
                _loading ? 'Please wait…' : 'Oops',
                style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                _msg,
                textAlign: TextAlign.center,
                style: t.textTheme.bodySmall?.copyWith(color: t.hintColor, height: 1.3),
              ),
              if (!_loading) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _go,
                  icon: const Icon(LucideIcons.refreshCcw, size: 18),
                  label: const Text('Retry'),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
