// ignore_for_file: avoid_print, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/agency_service.dart';
import 'package:property_manager_frontend/services/property_service.dart';

class AgencyAgentsScreen extends StatefulWidget {
  const AgencyAgentsScreen({super.key});

  @override
  State<AgencyAgentsScreen> createState() => _AgencyAgentsScreenState();
}

class _AgencyAgentsScreenState extends State<AgencyAgentsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  bool _loadingStaff = true;
  bool _loadingAgents = true;

  List<dynamic> _staff = [];
  List<dynamic> _agents = []; // links {agent_manager_id, status...}

  List<dynamic> _properties = [];
  bool _loadingProperties = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadStaff(),
      _loadAgents(),
      _loadProperties(),
    ]);
  }

  Future<void> _loadStaff() async {
    setState(() => _loadingStaff = true);
    try {
      final data = await AgencyService.listStaff();
      setState(() => _staff = data);
    } catch (e) {
      _snack('Failed to load staff: $e');
    } finally {
      setState(() => _loadingStaff = false);
    }
  }

  Future<void> _loadAgents() async {
    setState(() => _loadingAgents = true);
    try {
      final data = await AgencyService.listLinkedAgents();
      setState(() => _agents = data);
    } catch (e) {
      _snack('Failed to load agents: $e');
    } finally {
      setState(() => _loadingAgents = false);
    }
  }

  Future<void> _loadProperties() async {
    setState(() => _loadingProperties = true);
    try {
      final props = await PropertyService.getMyVisibleProperties();
      setState(() => _properties = props);
    } catch (e) {
      // not fatal, but assignment dialogs need it
      print('⚠️ failed to load properties for assignment: $e');
    } finally {
      setState(() => _loadingProperties = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -----------------------------
  // STAFF actions
  // -----------------------------
  Future<void> _openCreateStaffDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    String staffRole = 'manager_staff';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add staff'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (07.. / +254..)'),
              ),
              const SizedBox(height: 10),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email (optional)')),
              const SizedBox(height: 10),
              TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'ID Number (optional)')),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: staffRole,
                items: const [
                  DropdownMenuItem(value: 'manager_staff', child: Text('Staff (Agent)')),
                  DropdownMenuItem(value: 'finance', child: Text('Finance')),
                  DropdownMenuItem(value: 'manager_admin', child: Text('Admin')),
                ],
                onChanged: (v) => staffRole = v ?? 'manager_staff',
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
      _snack('Name, phone, and password are required.');
      return;
    }

    try {
      await AgencyService.createStaff(
        name: name,
        phone: phone,
        password: password,
        email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
        idNumber: idCtrl.text.trim().isEmpty ? null : idCtrl.text.trim(),
        staffRole: staffRole,
      );
      _snack('Staff created successfully');
      await _loadStaff();
    } catch (e) {
      _snack('Create staff failed: $e');
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
      _snack('Staff deactivated');
      await _loadStaff();
    } catch (e) {
      _snack('Deactivate failed: $e');
    }
  }

  Future<void> _assignPropertyToStaff(int staffUserId, String staffName) async {
    if (_loadingProperties) {
      _snack('Loading properties… try again in a second.');
      return;
    }
    if (_properties.isEmpty) {
      _snack('No properties found for this agency yet.');
      return;
    }

    int? selectedPropertyId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign property'),
        content: DropdownButtonFormField<int>(
          isExpanded: true,
          value: selectedPropertyId,
          items: _properties.map((p) {
            final m = Map<String, dynamic>.from(p as Map);
            final id = (m['id'] as num?)?.toInt() ?? 0;
            final name = (m['name'] ?? 'Property #$id').toString();
            final code = (m['property_code'] ?? '').toString();
            return DropdownMenuItem(
              value: id,
              child: Text(code.isEmpty ? name : '$name • $code'),
            );
          }).toList(),
          onChanged: (v) => selectedPropertyId = v,
          decoration: const InputDecoration(labelText: 'Select a property'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Assign')),
        ],
      ),
    );

    if (ok != true || selectedPropertyId == null || selectedPropertyId == 0) return;

    try {
      await AgencyService.assignPropertyToStaff(
        propertyId: selectedPropertyId!,
        staffUserId: staffUserId,
      );
      _snack('Assigned property to $staffName');
    } catch (e) {
      _snack('Assign failed: $e');
    }
  }

  // -----------------------------
  // AGENTS actions (external)
  // -----------------------------
  Future<void> _openLinkAgentDialog() async {
    final phoneCtrl = TextEditingController();
    final idCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Link agent (external manager)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Agent phone (07.. / +254..)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: idCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'OR Agent manager ID'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use phone OR id. Phone is easiest.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Link')),
        ],
      ),
    );

    if (ok != true) return;

    final phone = phoneCtrl.text.trim();
    final idText = idCtrl.text.trim();
    final int? agentId = idText.isEmpty ? null : int.tryParse(idText);

    if (phone.isEmpty && agentId == null) {
      _snack('Provide agent phone or agent ID');
      return;
    }

    try {
      await AgencyService.linkAgent(agentPhone: phone.isEmpty ? null : phone, agentManagerId: agentId);
      _snack('Agent linked successfully');
      await _loadAgents();
    } catch (e) {
      _snack('Link failed: $e');
    }
  }

  Future<void> _unlinkAgent(int agentManagerId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unlink agent'),
        content: const Text('Unlink this agent from your agency? They will no longer see your assigned properties.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unlink')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await AgencyService.unlinkAgent(agentManagerId);
      _snack('Agent unlinked');
      await _loadAgents();
    } catch (e) {
      _snack('Unlink failed: $e');
    }
  }

  Future<void> _assignPropertyToExternalAgent(int agentManagerId) async {
    if (_loadingProperties) {
      _snack('Loading properties… try again in a second.');
      return;
    }
    if (_properties.isEmpty) {
      _snack('No properties found for this agency yet.');
      return;
    }

    int? selectedPropertyId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign property to agent'),
        content: DropdownButtonFormField<int>(
          isExpanded: true,
          value: selectedPropertyId,
          items: _properties.map((p) {
            final m = Map<String, dynamic>.from(p as Map);
            final id = (m['id'] as num?)?.toInt() ?? 0;
            final name = (m['name'] ?? 'Property #$id').toString();
            final code = (m['property_code'] ?? '').toString();
            return DropdownMenuItem(
              value: id,
              child: Text(code.isEmpty ? name : '$name • $code'),
            );
          }).toList(),
          onChanged: (v) => selectedPropertyId = v,
          decoration: const InputDecoration(labelText: 'Select a property'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Assign')),
        ],
      ),
    );

    if (ok != true || selectedPropertyId == null || selectedPropertyId == 0) return;

    try {
      await AgencyService.assignPropertyToExternalAgent(
        propertyId: selectedPropertyId!,
        agentManagerId: agentManagerId,
      );
      _snack('Assigned property to agent');
    } catch (e) {
      _snack('Assign failed: $e');
    }
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agency • Staff & Agents'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Staff', icon: Icon(LucideIcons.users)),
            Tab(text: 'Agents', icon: Icon(LucideIcons.userCheck)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCcw),
            onPressed: _loadAll,
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) {
          final idx = _tabs.index;
          if (idx == 0) {
            return FloatingActionButton.extended(
              onPressed: _openCreateStaffDialog,
              icon: const Icon(LucideIcons.userPlus),
              label: const Text('Add staff'),
            );
          }
          return FloatingActionButton.extended(
            onPressed: _openLinkAgentDialog,
            icon: const Icon(LucideIcons.link),
            label: const Text('Link agent'),
          );
        },
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ---------------- STAFF TAB ----------------
          RefreshIndicator(
            onRefresh: _loadStaff,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _heroCard(
                  t,
                  icon: LucideIcons.users,
                  title: 'Staff',
                  subtitle: 'Create staff accounts, assign properties, deactivate access.',
                ),
                const SizedBox(height: 12),
                if (_loadingStaff)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_staff.isEmpty)
                  _emptyState(icon: LucideIcons.userX, text: 'No staff yet.\nTap "Add staff".')
                else
                  ..._staff.map((raw) {
                    final m = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                    final id = (m['id'] as num?)?.toInt() ?? 0;
                    final name = (m['name'] ?? '—').toString();
                    final phone = (m['phone'] ?? '—').toString();
                    final role = (m['staff_role'] ?? 'manager_staff').toString();
                    final active = (m['active'] == true);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        leading: Container(
                          width: 46,
                          height: 46,
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
                        subtitle: Text('$phone • $role • ${active ? "active" : "inactive"}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (key) {
                            if (key == 'assign') _assignPropertyToStaff(id, name);
                            if (key == 'deactivate') _deactivateStaff(id, name);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'assign', child: Text('Assign property')),
                            if (active) const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),

          // ---------------- AGENTS TAB ----------------
          RefreshIndicator(
            onRefresh: _loadAgents,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _heroCard(
                  t,
                  icon: LucideIcons.userCheck,
                  title: 'External Agents',
                  subtitle: 'Link existing managers as agents. Assign properties and unlink when needed.',
                ),
                const SizedBox(height: 12),
                if (_loadingAgents)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_agents.isEmpty)
                  _emptyState(icon: LucideIcons.link2Off, text: 'No linked agents yet.\nTap "Link agent".')
                else
                  ..._agents.map((raw) {
                    final m = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                    final agentId = (m['agent_manager_id'] as num?)?.toInt() ?? 0;
                    final status = (m['status'] ?? 'active').toString();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        leading: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: t.colorScheme.primary.withOpacity(.12),
                          ),
                          child: Icon(LucideIcons.userCheck, color: t.colorScheme.primary),
                        ),
                        title: Text(
                          'Agent Manager ID: $agentId',
                          style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text('status: $status'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (key) {
                            if (key == 'assign') _assignPropertyToExternalAgent(agentId);
                            if (key == 'unlink') _unlinkAgent(agentId);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'assign', child: Text('Assign property')),
                            PopupMenuItem(value: 'unlink', child: Text('Unlink agent')),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(ThemeData t, {required IconData icon, required String title, required String subtitle}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.dividerColor.withOpacity(.18)),
        color: t.colorScheme.primary.withOpacity(.06),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.colorScheme.primary.withOpacity(.14),
              ),
              child: Icon(icon, color: t.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: t.textTheme.bodySmall?.copyWith(
                      color: t.colorScheme.onSurface.withOpacity(.65),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Icon(icon, size: 52, color: Colors.grey),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
