// lib/screens/landlord/landlord_dashboard.dart
// Landlord home: stats header + properties grid + add property dialog.

import 'package:flutter/material.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';
import 'package:property_manager_frontend/services/property_service.dart';

class LandlordDashboard extends StatefulWidget {
  const LandlordDashboard({super.key});

  @override
  State<LandlordDashboard> createState() => _LandlordDashboardState();
}

class _LandlordDashboardState extends State<LandlordDashboard> {
  bool _loading = true;
  int? _landlordId;
  List<dynamic> _properties = [];
  int _totalUnits = 0;
  int _occupiedUnits = 0;
  int _vacantUnits = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    debugPrint('[LandlordDashboard] init bootstrap …');
    final session = await TokenManager.loadSession();
    if (!mounted) return;

    if (session == null || session.role != 'landlord') {
      debugPrint('[LandlordDashboard] no landlord session → return');
      setState(() {
        _loading = false;
      });
      return;
    }

    _landlordId = session.userId;

    try {
      await _loadProperties();
    } catch (e) {
      debugPrint('[LandlordDashboard] load error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load properties: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProperties() async {
    if (_landlordId == null) return;
    debugPrint('[LandlordDashboard] fetching properties for landlord=$_landlordId');
    final props = await PropertyService.getPropertiesByLandlord(_landlordId!);
    debugPrint('[LandlordDashboard] fetched ${props.length} properties');

    // Optionally precompute unit stats by fetching detailed for each property
    int total = 0, occupied = 0, vacant = 0;
    for (final p in props) {
      try {
        final detailed = await PropertyService.getPropertyWithUnitsDetailed(p['id'] as int);
        total += (detailed['total_units'] ?? 0) as int;
        occupied += (detailed['occupied_units'] ?? 0) as int;
        vacant += (detailed['vacant_units'] ?? 0) as int;
      } catch (_) {
        // ignore if endpoint not yet wired for some properties
      }
    }

    setState(() {
      _properties = props;
      _totalUnits = total;
      _occupiedUnits = occupied;
      _vacantUnits = vacant;
    });
  }

  Future<void> _createProperty() async {
    final result = await showDialog<_NewPropertyData>(
      context: context,
      builder: (_) => const _AddPropertyDialog(),
    );

    if (result == null) return;

    try {
      if (_landlordId == null) return;
      final created = await PropertyService.createProperty(
        name: result.name,
        address: result.address,
        landlordId: _landlordId!,
        managerId: result.managerId,
      );
      debugPrint('[LandlordDashboard] property created: $created');
      await _loadProperties();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property created')),
      );
    } catch (e) {
      debugPrint('[LandlordDashboard] create property error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create property: $e')),
      );
    }
  }

  void _openProperty(int propertyId) {
    debugPrint('[LandlordDashboard] open property $propertyId');
    Navigator.of(context).pushNamed(
      '/landlord_property_units',
      arguments: {'propertyId': propertyId},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadProperties,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header / Stats
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                title: 'Properties',
                value: _properties.length.toString(),
                icon: Icons.apartment_rounded,
              ),
              _StatCard(
                title: 'Total Units',
                value: _totalUnits.toString(),
                icon: Icons.other_houses_rounded,
              ),
              _StatCard(
                title: 'Occupied',
                value: _occupiedUnits.toString(),
                icon: Icons.person_pin_circle_rounded,
              ),
              _StatCard(
                title: 'Vacant',
                value: _vacantUnits.toString(),
                icon: Icons.meeting_room_rounded,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Actions row
          Row(
            children: [
              FilledButton.icon(
                onPressed: _createProperty,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Property'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _loadProperties,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Properties grid
          if (_properties.isEmpty)
            _EmptyState(
              title: 'No properties yet',
              subtitle: 'Create your first property to get started.',
              actionLabel: 'Add Property',
              onAction: _createProperty,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                int crossAxisCount = 1;
                if (width > 1200) crossAxisCount = 4;
                else if (width > 900) crossAxisCount = 3;
                else if (width > 600) crossAxisCount = 2;

                return GridView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _properties.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.45,
                  ),
                  itemBuilder: (_, i) {
                    final p = _properties[i] as Map<String, dynamic>;
                    return _PropertyCard(
                      name: p['name'] ?? 'Property',
                      address: p['address'] ?? '',
                      onOpen: () => _openProperty(p['id'] as int),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.dividerColor.withValues(alpha: .3)),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 6),
            color: t.shadowColor.withValues(alpha: .06),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: t.colorScheme.primaryContainer,
            child: Icon(icon, color: t.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.textTheme.labelMedium),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: t.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final String name;
  final String address;
  final VoidCallback onOpen;

  const _PropertyCard({
    required this.name,
    required this.address,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.dividerColor.withValues(alpha: .25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: t.hintColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: FilledButton.tonalIcon(
                onPressed: onOpen,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Open'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.dividerColor.withValues(alpha: .25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apartment_rounded, size: 56, color: t.hintColor),
          const SizedBox(height: 12),
          Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, style: t.textTheme.bodyMedium),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _AddPropertyDialog extends StatefulWidget {
  const _AddPropertyDialog({super.key});

  @override
  State<_AddPropertyDialog> createState() => _AddPropertyDialogState();
}

class _AddPropertyDialogState extends State<_AddPropertyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _managerIdCtrl = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _managerIdCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final managerId = _managerIdCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(_managerIdCtrl.text.trim());
    Navigator.of(context).pop(
      _NewPropertyData(
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        managerId: managerId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AlertDialog(
      title: const Text('Add Property'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Property Name',
                  hintText: 'e.g., Riverside Park Apartments',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Address is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _managerIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Manager ID (optional)',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _NewPropertyData {
  final String name;
  final String address;
  final int? managerId;
  _NewPropertyData({required this.name, required this.address, this.managerId});
}
