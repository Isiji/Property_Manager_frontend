// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:property_manager_frontend/services/property_service.dart';
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

  Future<void> _loadProperties() async {
    if (_landlordId == null) return;
    try {
      setState(() => _loading = true);
      print('➡️ GET properties for landlordId=$_landlordId');
      final data = await PropertyService.getPropertiesByLandlord(_landlordId!);
      print('✅ properties loaded: ${data.length}');
      setState(() => _properties = data);
      // Lazy fetch unit counts per card, see _ensureUnitCount.
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
    _editNameCtrl.text = p['name'] ?? '';
    _editAddrCtrl.text = p['address'] ?? '';

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
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _editAddrCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(LucideIcons.mapPin),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                print('✏️ update propertyId=${p['id']}');
                await PropertyService.updateProperty(
                  propertyId: p['id'] as int,
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

  /// Lazy-load unit counts from /properties/{id}/with-units-detailed
  void _ensureUnitCount(int propertyId) {
    if (_unitCounts.containsKey(propertyId) || _unitCountLoading.containsKey(propertyId)) return;
    final fut = _loadUnitCount(propertyId);
    _unitCountLoading[propertyId] = fut;
    fut.whenComplete(() {
      _unitCountLoading.remove(propertyId);
    });
  }

  Future<void> _loadUnitCount(int propertyId) async {
    try {
      final detail = await PropertyService.getPropertyWithUnitsDetailed(propertyId);
      final total = (detail['total_units'] as num?)?.toInt() ?? (detail['units'] as List?)?.length ?? 0;
      if (!mounted) return;
      setState(() => _unitCounts[propertyId] = total);
    } catch (e) {
      print('[unit-count] failed for $propertyId: $e');
      // Leave it unset; card will show “—”
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Landlord'),
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
        onPressed: _loadProperties,
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
    final id = p['id'] as int;
    final name = p['name'] ?? '';
    final addr = p['address'] ?? '';
    final code = p['property_code'] ?? '—';

    // Kick off unit count fetch lazily.
    if (!_unitCounts.containsKey(id) && !_unitCountLoading.containsKey(id)) {
      Future.microtask(() => _ensureUnitCount(id));
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
            color: t.colorScheme.primary.withValues(alpha: 0.12),
          ),
          child: Icon(LucideIcons.home, color: t.colorScheme.primary),
        );

        final title = Text(
          name,
          style: t.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

        final subtitle = Text(
          addr,
          style: t.textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

        final unitCount = _unitCounts[id];
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
              Text(
                unitCount == null ? 'Units: —' : 'Units: $unitCount',
                style: t.textTheme.labelMedium,
              ),
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
                onTap: code.toString().trim().isEmpty ? null : () => _copy('Property code', code.toString()),
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.copy_rounded, size: 16),
                ),
              ),
            ],
          ),
        );

        final chips = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [unitBadge, codeChip],
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(LucideIcons.grid, size: 18),
              label: const Text('View Units'),
              onPressed: () {
                print('🧭 Open units for propertyId=$id');
                Navigator.of(context).pushNamed(
                  '/landlord_property_units',
                  arguments: {'propertyId': id},
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
              onPressed: () => _deleteProperty(id),
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

        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: gutter,
            mainAxisSpacing: gutter,
            childAspectRatio: 1.8,
          ),
          itemBuilder: (context, i) => cardBuilder(items[i]),
        );
      },
    );
  }
}
