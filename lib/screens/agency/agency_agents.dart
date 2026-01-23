// ignore_for_file: avoid_print, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/agency_service.dart';

class AgencyAgentsScreen extends StatefulWidget {
  const AgencyAgentsScreen({super.key});

  @override
  State<AgencyAgentsScreen> createState() => _AgencyAgentsScreenState();
}

class _AgencyAgentsScreenState extends State<AgencyAgentsScreen> {
  bool _loading = true;
  List<dynamic> _staff = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await AgencyService.listStaff();
      if (!mounted) return;
      setState(() => _staff = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load staff: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateStaffDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final idCtrl = TextEditingController();

    String role = 'manager_staff';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Staff'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (07.. / +254..)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: idCtrl,
                decoration: const InputDecoration(labelText: 'ID Number (optional)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                items: const [
                  DropdownMenuItem(value: 'manager_staff', child: Text('Staff (Agent)')),
                  DropdownMenuItem(value: 'finance', child: Text('Finance')),
                  DropdownMenuItem(value: 'manager_admin', child: Text('Admin')),
                ],
                onChanged: (v) => role = v ?? 'manager_staff',
                decoration: const InputDecoration(labelText: 'Staff role'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final password = passCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, phone, and password are required.')),
      );
      return;
    }

    try {
      await AgencyService.createStaff(
        name: name,
        phone: phone,
        email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
        password: password,
        idNumber: idCtrl.text.trim().isEmpty ? null : idCtrl.text.trim(),
        staffRole: role,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff created successfully')),
      );
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create staff failed: $e')),
      );
    }
  }

  Future<void> _deactivateStaff(int staffId, String staffName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate staff'),
        content: Text('Deactivate "$staffName"? They won’t be able to log in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await AgencyService.deactivateStaff(staffId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff deactivated')),
      );
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deactivate failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agency • Staff'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: _load,
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateStaffDialog,
        icon: const Icon(LucideIcons.userPlus),
        label: const Text('Add staff'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.colorScheme.primary.withOpacity(.12),
                    ),
                    child: Icon(LucideIcons.users, color: t.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Staff & Agents',
                            style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(
                          'Create staff accounts, manage roles, deactivate access.',
                          style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_staff.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  const Icon(LucideIcons.userX, size: 52, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(
                    'No staff yet.\nTap "Add staff" to create your first agent.',
                    textAlign: TextAlign.center,
                    style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
                  ),
                ],
              ),
            )
          else
            ..._staff.map((raw) {
              final m = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
              final id = (m['id'] as num?)?.toInt() ?? 0;
              final name = (m['name'] ?? '—').toString();
              final phone = (m['phone'] ?? '—').toString();
              final staffRole = (m['staff_role'] ?? 'manager_staff').toString();
              final active = (m['active'] == true);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.colorScheme.primary.withOpacity(.12),
                    ),
                    child: Icon(LucideIcons.user, color: t.colorScheme.primary),
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text('$phone • $staffRole • ${active ? "active" : "inactive"}'),
                  trailing: active
                      ? IconButton(
                          tooltip: 'Deactivate',
                          icon: const Icon(LucideIcons.userMinus),
                          onPressed: id == 0 ? null : () => _deactivateStaff(id, name),
                        )
                      : const Icon(LucideIcons.ban, color: Colors.grey),
                ),
              );
            }),
        ],
      ),
    );
  }
}
