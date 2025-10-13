import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:property_manager_frontend/services/property_service.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';
//import 'package:property_manager_frontend/services/unit_service.dart';

class LandlordDashboard extends StatefulWidget {
  const LandlordDashboard({Key? key}) : super(key: key);

  @override
  State<LandlordDashboard> createState() => _LandlordDashboardState();
}

class _LandlordDashboardState extends State<LandlordDashboard> {
  int? landlordId;
  List<dynamic> properties = [];
  bool isLoading = true;
  int? expandedPropertyId;
  Map<int, dynamic> propertyDetails = {};

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    try {
      print('🔹 Loading landlord session...');
      final id = await TokenManager.currentUserId();
      if (id == null) {
        print('⚠️ No landlord ID found in session');
        return;
      }
      setState(() => landlordId = id);
      print('✅ Landlord ID: $id');

      print('🔹 Fetching landlord properties...');
      final props = await PropertyService.getPropertiesByLandlord(id);
      print('✅ Properties fetched: ${props.length}');
      setState(() {
        properties = props;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error initializing landlord dashboard: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleExpandProperty(int propertyId) async {
    if (expandedPropertyId == propertyId) {
      setState(() => expandedPropertyId = null);
      return;
    }

    print('🔹 Expanding property $propertyId...');
    try {
      setState(() => expandedPropertyId = propertyId);
      if (!propertyDetails.containsKey(propertyId)) {
        final details =
            await PropertyService.getPropertyWithUnitsDetailed(propertyId);
        propertyDetails[propertyId] = details;
        print('✅ Property details loaded for $propertyId');
      }
    } catch (e) {
      print('❌ Failed to load property details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load property details: $e')),
      );
    }
  }

  Widget _buildPropertyCard(Map<String, dynamic> property) {
    final id = property['id'];
    final isExpanded = expandedPropertyId == id;
    final details = propertyDetails[id];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        leading: const Icon(LucideIcons.home),
        title: Text(property['name'] ?? 'Unnamed Property',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(property['address'] ?? 'No address provided'),
        trailing: Icon(
          isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
          color: Theme.of(context).colorScheme.primary,
        ),
        onExpansionChanged: (expanded) {
          if (expanded) _toggleExpandProperty(id);
        },
        children: [
          if (details == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            )
          else
            _buildUnitList(details),
        ],
      ),
    );
  }

  Widget _buildUnitList(Map<String, dynamic> propertyDetails) {
    final units = propertyDetails['units'] as List<dynamic>? ?? [];
    if (units.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No units registered yet'),
      );
    }

    return Column(
      children: units.map((u) {
        final status = u['status'] ?? 'vacant';
        final tenant = u['tenant'];
        return ListTile(
          leading: Icon(
            status == 'occupied' ? LucideIcons.userCheck : LucideIcons.home,
            color: status == 'occupied'
                ? Colors.green
                : Theme.of(context).colorScheme.primary,
          ),
          title: Text('Unit ${u['number']}'),
          subtitle: Text(
            status == 'occupied'
                ? 'Tenant: ${tenant?['name'] ?? 'Unknown'}'
                : 'Vacant',
          ),
          trailing: Text('Ksh ${u['rent_amount']}'),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          print('➕ Add Property button tapped');
          // TODO: Navigate to property creation form
        },
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add Property'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: RefreshIndicator(
          onRefresh: _initializeDashboard,
          child: ListView(
            children: [
              const SizedBox(height: 12),
              Text(
                'Your Properties',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (properties.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No properties registered yet'),
                  ),
                )
              else
                ...properties.map((p) => _buildPropertyCard(p)).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
