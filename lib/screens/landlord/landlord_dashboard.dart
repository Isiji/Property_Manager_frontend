// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:property_manager_frontend/services/property_service.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class LandlordDashboard extends StatefulWidget {
  const LandlordDashboard({super.key});

  @override
  State<LandlordDashboard> createState() => _LandlordDashboardState();
}

class _LandlordDashboardState extends State<LandlordDashboard> {
  bool isLoading = true;
  List<dynamic> properties = [];
  int? landlordId;

  @override
  void initState() {
    super.initState();
    _loadLandlordProperties();
  }

  Future<void> _loadLandlordProperties() async {
    try {
      setState(() => isLoading = true);

      landlordId = await TokenManager.currentUserId();
      if (landlordId == null) {
        print("❌ Landlord ID missing. Redirecting to login...");
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      print("➡️ Fetching properties for landlord ID: $landlordId");
      final props = await PropertyService.getPropertiesByLandlord(landlordId!);
      print("✅ Loaded ${props.length} properties");
      setState(() => properties = props);
    } catch (e) {
      print("💥 Error loading properties: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load properties: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteProperty(int propertyId) async {
    try {
      print("🗑️ Deleting property ID: $propertyId");
      await PropertyService.deleteProperty(propertyId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Property deleted successfully")),
      );
      await _loadLandlordProperties();
    } catch (e) {
      print("💥 Failed to delete property: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete property: $e")),
      );
    }
  }

  Future<void> _addPropertyDialog() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Property"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Property Name"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: "Address"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final address = addressController.text.trim();

              if (name.isEmpty || address.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("All fields are required")),
                );
                return;
              }

              try {
                print("🏗️ Creating property for landlord ID: $landlordId");
                await PropertyService.createProperty(
                  name: name,
                  address: address,
                  landlordId: landlordId!,
                );
                Navigator.pop(context);
                await _loadLandlordProperties();
              } catch (e) {
                print("💥 Failed to add property: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to add property: $e")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property) {
    final name = property['name'] ?? 'Unnamed';
    final address = property['address'] ?? 'No address';
    final propertyId = property['id'] ?? 0;
    final code = property['property_code'] ?? 'N/A';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        leading: const Icon(LucideIcons.building2, color: Colors.indigo),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("Address: $address\nCode: $code"),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'view_units') {
              Navigator.pushNamed(context, '/landlord_property_units',
                  arguments: propertyId);
            } else if (value == 'delete') {
              _deleteProperty(propertyId);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view_units',
              child: Row(
                children: [
                  Icon(LucideIcons.layoutGrid, size: 18),
                  SizedBox(width: 8),
                  Text('View Units'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(LucideIcons.trash2, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Landlord Dashboard"),
        actions: [
          IconButton(
            onPressed: _addPropertyDialog,
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Add Property',
          ),
          IconButton(
            onPressed: () async {
              await TokenManager.clearSession();
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(LucideIcons.logOut),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : properties.isEmpty
              ? const Center(
                  child: Text(
                    "No properties yet. Click + to add one.",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLandlordProperties,
                  child: ListView.builder(
                    itemCount: properties.length,
                    itemBuilder: (context, index) =>
                        _buildPropertyCard(properties[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPropertyDialog,
        child: const Icon(LucideIcons.plus),
      ),
    );
  }
}
