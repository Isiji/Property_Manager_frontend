// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/property_service.dart';
import 'package:property_manager_frontend/services/landlord_service.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';
import 'package:property_manager_frontend/widgets/notification_bell.dart';
import 'package:property_manager_frontend/widgets/maintenance_inbox.dart';

class LandlordHome extends StatefulWidget {
  const LandlordHome({super.key});

  @override
  State<LandlordHome> createState() => _LandlordHomeState();
}

class _LandlordHomeState extends State<LandlordHome> {
  bool _loading = true;
  List<dynamic> _properties = [];
  int? _landlordId;

  // ✅ Landlord name (visible in header)
  String _landlordName = '—';

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();

  final _editFormKey = GlobalKey<FormState>();
  final _editNameCtrl = TextEditingController();
  final _editAddrCtrl = TextEditingController();

  String _search = '';

  /// Cache for unit counts per property id
  final Map<int, int> _unitCounts = {};
  /// Tracks in-flight fetches so we don’t duplicate calls
  final Map<int, Future<void>> _unitCountLoading = {};

  /// Cache assigned manager per property id (single manager)
  /// propertyId -> manager map or null
  final Map<int, Map<String, dynamic>?> _assignedManager = {};
  final Map<int, Future<void>> _assignedManagerLoading = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _editNameCtrl.dispose();
    _editAddrCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      setState(() => _loading = true);
      final id = await TokenManager.currentUserId();
      final role = await TokenManager.currentRole();
      print("🔐 landlord home init => id=$id role=$role");

      if (id == null || role != 'landlord') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid session. Please log in again.')),
        );
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }

      _landlordId = id;

      // ✅ Load landlord name from DB
      await _loadLandlordName();

      await _loadProperties();
    } catch (e) {
      print('💥 init error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Init error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLandlordName() async {
    if (_landlordId == null) return;
    try {
      final ll = await LandlordService.getLandlord(_landlordId!);
      final name = (ll['name'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() => _landlordName = name.isEmpty ? '—' : name);
    } catch (e) {
      print('[LandlordHome] landlord name load failed: $e');
      if (!mounted) return;
      setState(() => _landlordName = '—');
    }
  }

  Future<void> _loadProperties() async {
    if (_landlordId == null) return;
    try {
      setState(() => _loading = true);
      print('➡️ GET properties for landlordId=$_landlordId');
      final data = await PropertyService.getPropertiesByLandlord(_landlordId!);
      print('✅ properties loaded: ${data.length}');
      if (!mounted) return;
      setState(() => _properties = data);
    } catch (e) {
      print('💥 load properties error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load properties: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitCreate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_landlordId == null) return;
    try {
      final name = _nameCtrl.text.trim();
      final address = _addrCtrl.text.trim();
      print('🏗️ create property => $name @ $address (landlordId=$_landlordId)');

      await PropertyService.createProperty(
        name: name,
        address: address,
        landlordId: _landlordId!,
      );

      _nameCtrl.clear();
      _addrCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property created')),
      );
      await _loadProperties();
    } catch (e) {
      print('💥 create property error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create: $e')),
      );
    }
  }

  Future<void> _openEdit(Map<String, dynamic> p) async {
    _editNameCtrl.text = (p['name'] ?? '').toString();
    _editAddrCtrl.text = (p['address'] ?? '').toString();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Property'),
        content: Form(
          key: _editFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _editNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Property name',
                  prefixIcon: Icon(LucideIcons.building2),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _editAddrCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(LucideIcons.mapPin),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!_editFormKey.currentState!.validate()) return;
              try {
                final pid = (p['id'] as num).toInt();
                print('✏️ update propertyId=$pid');
                await PropertyService.updateProperty(
                  propertyId: pid,
                  name: _editNameCtrl.text.trim(),
                  address: _editAddrCtrl.text.trim(),
                );
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Property updated')),
                );
                await _loadProperties();
              } catch (e) {
                print('💥 update error: $e');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProperty(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Property'),
        content: const Text('Are you sure? This will remove the property and its dependent data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      print('🗑️ delete propertyId=$id');
      await PropertyService.deleteProperty(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property deleted')),
      );

      setState(() {
        _unitCounts.remove(id);
        _unitCountLoading.remove(id);
        _assignedManager.remove(id);
        _assignedManagerLoading.remove(id);
      });

      await _loadProperties();
    } catch (e) {
      print('💥 delete error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  List<dynamic> get _filtered {
    if (_search.isEmpty) return _properties;
    final s = _search.toLowerCase();
    return _properties.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final addr = (p['address'] ?? '').toString().toLowerCase();
      final code = (p['property_code'] ?? '').toString().toLowerCase();
      return name.contains(s) || addr.contains(s) || code.contains(s);
    }).toList();
  }

  Future<void> _copy(String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  // ---------------------------
  // Unit counts
  // ---------------------------
  void _ensureUnitCount(int propertyId) {
    if (_unitCounts.containsKey(propertyId)) return;
    if (_unitCountLoading.containsKey(propertyId)) return;

    final fut = _loadUnitCount(propertyId);
    _unitCountLoading[propertyId] = fut;
    fut.whenComplete(() => _unitCountLoading.remove(propertyId));
  }

  Future<void> _loadUnitCount(int propertyId) async {
    try {
      final detail = await PropertyService.getPropertyWithUnitsDetailed(propertyId);
      final total = (detail['total_units'] as num?)?.toInt() ?? (detail['units'] as List?)?.length ?? 0;
      if (!mounted) return;
      setState(() => _unitCounts[propertyId] = total);
    } catch (e) {
      print('[unit-count] failed for $propertyId: $e');
    }
  }

  // ---------------------------
  // Assigned Property Manager (single)
  // ---------------------------
  void _ensureAssignedManager(int propertyId) {
    if (_assignedManager.containsKey(propertyId)) return;
    if (_assignedManagerLoading.containsKey(propertyId)) return;

    final fut = _loadAssignedManager(propertyId);
    _assignedManagerLoading[propertyId] = fut;
    fut.whenComplete(() => _assignedManagerLoading.remove(propertyId));
  }

  Future<void> _loadAssignedManager(int propertyId) async {
    try {
      // If you have /properties/{id}/property-manager it will work.
      // If not, this will just set null safely.
      final mgr = await PropertyService.getAssignedPropertyManager(propertyId);
      if (!mounted) return;
      setState(() => _assignedManager[propertyId] = mgr);
    } catch (e) {
      print('[assigned-manager] failed for $propertyId: $e');
      if (!mounted) return;
      setState(() => _assignedManager[propertyId] = null);
    }
  }

  Future<void> _openAssignManagerDialog(int propertyId) async {
    final selected = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => _AssignPropertyManagerDialog(
        searchFn: PropertyService.searchPropertyManagers,
      ),
    );

    if (selected == null) return;

    try {
      final managerId = (selected['id'] as num).toInt();
      await PropertyService.assignPropertyManager(propertyId: propertyId, managerId: managerId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Property manager assigned: ${selected['name']}')),
      );

      setState(() => _assignedManager[propertyId] = selected);
    } catch (e) {
      print('[assign-manager] failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign property manager: $e')),
      );
    }
  }

  Future<void> _unassignManager(int propertyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unassign Property Manager'),
        content: const Text('Remove the current property manager from this property?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unassign')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await PropertyService.assignPropertyManager(propertyId: propertyId, managerId: null);
      if (!mounted) return;
      setState(() => _assignedManager[propertyId] = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property manager unassigned')),
      );
    } catch (e) {
      print('[unassign-manager] failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unassign property manager: $e')),
      );
    }
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_landlordName.trim().isEmpty ? '—' : _landlordName), // ✅ real landlord name
        actions: [
          IconButton(
            tooltip: 'Maintenance Inbox',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const MaintenanceInboxSheet(),
            ),
            icon: const Icon(Icons.build_circle_outlined),
          ),
          const NotificationBell(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _loadLandlordName();
          await _loadProperties();
        },
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isNarrow = width < 560;

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // header card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: t.colorScheme.surface,
                  border: Border.all(color: t.dividerColor.withOpacity(.18)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.05),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.colorScheme.primary.withOpacity(.12),
                      ),
                      child: Icon(LucideIcons.user, color: t.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Landlord', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(
                            'Name: $_landlordName',
                            style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              _addPropertyPanel(isNarrow: isNarrow),
              _searchBar(),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.folderOpen, size: 56, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No properties found.'),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _loadProperties,
                        icon: const Icon(LucideIcons.refreshCcw),
                        label: const Text('Reload'),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _PropertyGrid(
                    items: list.cast<Map<String, dynamic>>(),
                    cardBuilder: (p) => _propertyCard(p),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search properties…',
          prefixIcon: const Icon(LucideIcons.search),
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  Widget _addPropertyPanel({required bool isNarrow}) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.plusCircle, size: 20),
                  const SizedBox(width: 8),
                  Text('Add Property', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              if (isNarrow)
                Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Property name',
                        hintText: 'e.g. Palm Heights',
                        prefixIcon: Icon(LucideIcons.building2),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addrCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        hintText: 'e.g. 45 Sunset Blvd',
                        prefixIcon: Icon(LucideIcons.mapPin),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Property name',
                          hintText: 'e.g. Palm Heights',
                          prefixIcon: Icon(LucideIcons.building2),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _addrCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          hintText: 'e.g. 45 Sunset Blvd',
                          prefixIcon: Icon(LucideIcons.mapPin),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(LucideIcons.save),
                  label: const Text('Create'),
                  onPressed: _submitCreate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _propertyCard(Map<String, dynamic> p) {
    final pid = (p['id'] as num).toInt();
    final name = (p['name'] ?? '').toString();
    final addr = (p['address'] ?? '').toString();
    final code = (p['property_code'] ?? '—').toString();

    if (!_unitCounts.containsKey(pid) && !_unitCountLoading.containsKey(pid)) {
      Future.microtask(() => _ensureUnitCount(pid));
    }
    if (!_assignedManager.containsKey(pid) && !_assignedManagerLoading.containsKey(pid)) {
      Future.microtask(() => _ensureAssignedManager(pid));
    }

    return LayoutBuilder(
      builder: (context, c) {
        final t = Theme.of(context);
        final isNarrow = c.maxWidth < 560;

        final avatar = Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.colorScheme.primary.withOpacity(0.12),
          ),
          child: Icon(LucideIcons.home, color: t.colorScheme.primary),
        );

        final title = Text(name, style: t.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis);
        final subtitle = Text(addr, style: t.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis);

        final unitCount = _unitCounts[pid];
        final unitBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: t.colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: t.dividerColor.withOpacity(.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.grid, size: 16),
              const SizedBox(width: 6),
              Text(unitCount == null ? 'Units: —' : 'Units: $unitCount', style: t.textTheme.labelMedium),
            ],
          ),
        );

        final codeChip = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: t.colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: t.dividerColor.withOpacity(.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.keyRound, size: 16),
              const SizedBox(width: 6),
              Text('Code: $code', style: t.textTheme.labelMedium, overflow: TextOverflow.ellipsis),
              const SizedBox(width: 6),
              InkWell(
                onTap: code.trim().isEmpty ? null : () => _copy('Property code', code),
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.copy_rounded, size: 16),
                ),
              ),
            ],
          ),
        );

        final chips = Wrap(spacing: 8, runSpacing: 8, children: [unitBadge, codeChip]);

        // Property Managers panel (single assignment)
        final mgr = _assignedManager[pid];
        final mgrName = (mgr?['name'] ?? 'Not assigned').toString();
        final mgrPhone = (mgr?['phone'] ?? '').toString();

        final pmPanel = Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.dividerColor.withOpacity(.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.users, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Property Managers',
                      style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                mgr == null ? 'Not assigned' : '$mgrName${mgrPhone.trim().isEmpty ? '' : ' • $mgrPhone'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openAssignManagerDialog(pid),
                    icon: const Icon(LucideIcons.userPlus, size: 18),
                    label: Text(mgr == null ? 'Assign' : 'Change'),
                  ),
                  if (mgr != null)
                    FilledButton.icon(
                      onPressed: () => _unassignManager(pid),
                      icon: const Icon(LucideIcons.userMinus, size: 18),
                      label: const Text('Unassign'),
                    ),
                ],
              ),
            ],
          ),
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(LucideIcons.grid, size: 18),
              label: const Text('View Units'),
              onPressed: () {
                Navigator.of(context).pushNamed(
                  '/landlord_property_units',
                  arguments: {'propertyId': pid},
                );
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(LucideIcons.pencil, size: 18),
              label: const Text('Edit'),
              onPressed: () => _openEdit(p),
            ),
            FilledButton.icon(
              icon: const Icon(LucideIcons.trash2, size: 18),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              label: const Text('Delete'),
              onPressed: () => _deleteProperty(pid),
            ),
          ],
        );

        return Card(
          margin: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 1.5,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          avatar,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                const SizedBox(height: 4),
                                subtitle,
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      chips,
                      pmPanel,
                      const SizedBox(height: 10),
                      actions,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      avatar,
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            title,
                            const SizedBox(height: 4),
                            subtitle,
                            const SizedBox(height: 8),
                            chips,
                            pmPanel,
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: actions,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _PropertyGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Widget Function(Map<String, dynamic>) cardBuilder;

  const _PropertyGrid({required this.items, required this.cardBuilder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final width = c.maxWidth;
        final gutter = width < 480 ? 8.0 : 12.0;
        final minCardWidth = width < 480 ? 320.0 : 360.0;
        final cols = (width ~/ (minCardWidth + gutter)).clamp(1, 3);

        if (cols == 1) {
          return Column(children: [for (final p in items) cardBuilder(p)]);
        }

        // ✅ Taller cards when we have property manager panel + buttons
        final aspect = cols == 3 ? 1.35 : 1.25;

        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: gutter,
            mainAxisSpacing: gutter,
            childAspectRatio: aspect,
          ),
          itemBuilder: (context, i) => cardBuilder(items[i]),
        );
      },
    );
  }
}

// ---------------------------
// Dialog: Assign Property Manager
// ---------------------------
class _AssignPropertyManagerDialog extends StatefulWidget {
  final Future<List<dynamic>> Function(String query) searchFn;
  const _AssignPropertyManagerDialog({required this.searchFn});

  @override
  State<_AssignPropertyManagerDialog> createState() => _AssignPropertyManagerDialogState();
}

class _AssignPropertyManagerDialogState extends State<_AssignPropertyManagerDialog> {
  final _qCtrl = TextEditingController();
  bool _loading = false;
  List<dynamic> _results = [];

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _qCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await widget.searchFn(q);
      if (!mounted) return;
      setState(() => _results = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Property Manager'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _qCtrl,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search by name / phone / email…',
                prefixIcon: const Icon(LucideIcons.search),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(LucideIcons.arrowRightCircle),
                  onPressed: _search,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('No results'),
              )
            else
              SizedBox(
                height: 280,
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final raw = _results[i];
                    final m = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

                    final name = (m['name'] ?? '').toString();
                    final phone = (m['phone'] ?? '').toString();
                    final email = (m['email'] ?? '').toString();

                    return ListTile(
                      leading: const Icon(LucideIcons.userCog),
                      title: Text(name.isEmpty ? '—' : name),
                      subtitle: Text([phone, email].where((x) => x.trim().isNotEmpty).join(' • ')),
                      onTap: () => Navigator.pop(context, m),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
      ],
    );
  }
}
