// ignore_for_file: avoid_print, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/agency_service.dart';
import 'package:property_manager_frontend/services/manager_service.dart';
import 'package:property_manager_frontend/services/property_service.dart';

class AgencyAgentsScreen extends StatefulWidget {
  const AgencyAgentsScreen({super.key});

  @override
  State<AgencyAgentsScreen> createState() => _AgencyAgentsScreenState();
}

class _AgencyAgentsScreenState extends State<AgencyAgentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  bool _loadingStaff = true;
  bool _loadingAgents = true;

  String? _staffError;
  String? _agentsError;

  List<dynamic> _staff = [];
  List<dynamic> _agents = []; // link rows: {agent_manager_id, status, ...}

  List<dynamic> _properties = [];
  bool _loadingProperties = false;

  // cache agent org profile by agent_manager_id
  final Map<int, Map<String, dynamic>> _agentOrgCache = {};
  final Set<int> _agentOrgLoading = {};

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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadStaff(),
      _loadAgents(),
      _loadProperties(),
    ]);
  }

  Future<void> _loadStaff() async {
    setState(() {
      _loadingStaff = true;
      _staffError = null;
    });

    try {
      final data = await AgencyService.listStaff();
      if (!mounted) return;
      setState(() => _staff = data);
    } catch (e) {
      final msg = e.toString();
      // Friendly hint for the common 403
      final hint = msg.contains('403')
          ? 'Access denied (403). Only agency admin/owner can view staff.'
          : msg;
      if (!mounted) return;
      setState(() => _staffError = hint);
    } finally {
      if (mounted) setState(() => _loadingStaff = false);
    }
  }

  Future<void> _loadAgents() async {
    setState(() {
      _loadingAgents = true;
      _agentsError = null;
    });

    try {
      final data = await AgencyService.listLinkedAgents();
      if (!mounted) return;
      setState(() => _agents = data);

      // Kick off background fetch of each agent org profile (best-effort)
      for (final raw in data) {
        final m = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final agentId = (m['agent_manager_id'] as num?)?.toInt() ?? 0;
        if (agentId > 0) {
          _prefetchAgentOrg(agentId);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _agentsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingAgents = false);
    }
  }

  Future<void> _loadProperties() async {
    setState(() => _loadingProperties = true);
    try {
      final props = await PropertyService.getMyVisibleProperties(); // uses /properties/me
      if (!mounted) return;
      setState(() => _properties = props);
    } catch (e) {
      print('⚠️ failed to load properties for assignment: $e');
    } finally {
      if (mounted) setState(() => _loadingProperties = false);
    }
  }

  Future<void> _prefetchAgentOrg(int agentManagerId) async {
    if (_agentOrgCache.containsKey(agentManagerId)) return;
    if (_agentOrgLoading.contains(agentManagerId)) return;

    _agentOrgLoading.add(agentManagerId);
    try {
      final org = await ManagerService.getManager(agentManagerId);
      if (!mounted) return;
      setState(() {
        _agentOrgCache[agentManagerId] = org;
      });
    } catch (e) {
      // non-fatal: still show the agentId card
      print('⚠️ failed to load agent org $agentManagerId: $e');
    } finally {
      _agentOrgLoading.remove(agentManagerId);
    }
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
      _snack('Staff created');
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
      _snack('Loading properties… try again shortly.');
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
        title: const Text('Link external agent'),
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
              decoration: const InputDecoration(labelText: 'OR Agent Manager ID'),
            ),
            const SizedBox(height: 8),
            Text('Tip: phone is easiest.', style: Theme.of(context).textTheme.bodySmall),
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
      await AgencyService.linkAgent(
        agentPhone: phone.isEmpty ? null : phone,
        agentManagerId: agentId,
      );
      _snack('Agent linked');
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
        content: const Text('Unlink this agent from your agency?'),
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
      _snack('Loading properties… try again shortly.');
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
          // STAFF TAB
          RefreshIndicator(
            onRefresh: _loadStaff,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _hero(t,
                    icon: LucideIcons.users,
                    title: 'Staff',
                    subtitle: 'Create staff accounts, assign properties, deactivate access.'),
                const SizedBox(height: 12),

                if (_loadingStaff)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_staffError != null)
                  _errorCard(t, _staffError!)
                else if (_staff.isEmpty)
                  _empty(t, icon: LucideIcons.userX, text: 'No staff yet.\nTap “Add staff”.')
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

          // AGENTS TAB
          RefreshIndicator(
            onRefresh: _loadAgents,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _hero(t,
                    icon: LucideIcons.userCheck,
                    title: 'External Agents',
                    subtitle: 'Link existing managers as agents. Assign properties and unlink when needed.'),
                const SizedBox(height: 12),

                if (_loadingAgents)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_agentsError != null)
                  _errorCard(t, _agentsError!)
                else if (_agents.isEmpty)
                  _empty(t, icon: LucideIcons.link2Off, text: 'No linked agents yet.\nTap “Link agent”.')
                else
                  ..._agents.map((raw) {
                    final m = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                    final agentId = (m['agent_manager_id'] as num?)?.toInt() ?? 0;
                    final status = (m['status'] ?? 'active').toString();

                    final org = _agentOrgCache[agentId];
                    final orgType = (org?['type'] ?? '').toString();
                    final displayName = _prettyOrgName(org);
                    final phone = (org?['phone'] ?? org?['office_phone'] ?? '—').toString();
                    final email = (org?['email'] ?? org?['office_email'] ?? '').toString();

                    final isLoadingOrg = _agentOrgLoading.contains(agentId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: t.colorScheme.primary.withOpacity(.12),
                              ),
                              child: Icon(LucideIcons.userCheck, color: t.colorScheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          displayName.isEmpty ? 'Agent Manager #$agentId' : displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                      if (isLoadingOrg)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: t.hintColor),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      if (orgType.isNotEmpty) orgType,
                                      'status: $status',
                                    ].join(' • '),
                                    style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 6,
                                    children: [
                                      _chip(t, LucideIcons.phone, phone),
                                      if (email.isNotEmpty) _chip(t, LucideIcons.mail, email),
                                      _chip(t, LucideIcons.hash, 'id: $agentId'),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: agentId <= 0 ? null : () => _assignPropertyToExternalAgent(agentId),
                                          icon: const Icon(LucideIcons.building2, size: 16),
                                          label: const Text('Assign property'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        tooltip: 'Unlink agent',
                                        onPressed: agentId <= 0 ? null : () => _unlinkAgent(agentId),
                                        icon: const Icon(LucideIcons.unlink),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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

  String _prettyOrgName(Map<String, dynamic>? org) {
    if (org == null) return '';
    final type = (org['type'] ?? '').toString().toLowerCase();
    if (type == 'agency') {
      final company = (org['company_name'] ?? '').toString().trim();
      if (company.isNotEmpty) return company;
    }
    return (org['name'] ?? '').toString().trim();
  }

  Widget _chip(ThemeData t, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.dividerColor.withOpacity(.25)),
        color: t.colorScheme.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: t.hintColor),
          const SizedBox(width: 6),
          Text(text, style: t.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _hero(ThemeData t, {required IconData icon, required String title, required String subtitle}) {
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
              width: 52,
              height: 52,
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

  Widget _empty(ThemeData t, {required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Icon(icon, size: 56, color: Colors.grey),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: t.textTheme.bodyMedium?.copyWith(color: t.hintColor)),
        ],
      ),
    );
  }

  Widget _errorCard(ThemeData t, String message) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.alertTriangle, color: t.colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: t.textTheme.bodyMedium?.copyWith(height: 1.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
