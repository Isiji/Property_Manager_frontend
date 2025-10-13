// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:property_manager_frontend/services/unit_service.dart';

class LandlordPropertyUnits extends StatefulWidget {
  final int propertyId;
  const LandlordPropertyUnits({super.key, required this.propertyId});

  @override
  State<LandlordPropertyUnits> createState() => _LandlordPropertyUnitsState();
}

class _LandlordPropertyUnitsState extends State<LandlordPropertyUnits> {
  bool isLoading = true;
  List<dynamic> units = [];

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    try {
      print("➡️ Fetching units for property ID: ${widget.propertyId}");
      setState(() => isLoading = true);
      final data = await UnitService.getUnitsByProperty(widget.propertyId);
      print("✅ Loaded ${data.length} units");
      setState(() => units = data);
    } catch (e) {
      print("💥 Error loading units: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load units: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteUnit(int unitId) async {
    try {
      print("🗑️ Deleting unit ID: $unitId");
      await UnitService.deleteUnit(unitId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unit deleted successfully")),
      );
      await _loadUnits();
    } catch (e) {
      print("💥 Error deleting unit: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete unit: $e")),
      );
    }
  }

  Future<void> _addUnitDialog() async {
    final numberController = TextEditingController();
    final rentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Unit"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              decoration: const InputDecoration(labelText: "Unit Number"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rentController,
              decoration: const InputDecoration(labelText: "Rent Amount"),
              keyboardType: TextInputType.number,
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
              final number = numberController.text.trim();
              final rent = rentController.text.trim();

              if (number.isEmpty || rent.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("All fields are required")),
                );
                return;
              }

              try {
                print("🏗️ Creating unit for property ID: ${widget.propertyId}");
                await UnitService.createUnit(
                  propertyId: widget.propertyId,
                  number: number,
                  rentAmount: rent,
                );
                Navigator.pop(context);
                await _loadUnits();
              } catch (e) {
                print("💥 Failed to add unit: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to add unit: $e")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitCard(Map<String, dynamic> unit) {
    final number = unit['number'] ?? 'N/A';
    final rent = unit['rent_amount']?.toString() ?? '0';
    final occupied = unit['occupied'] == true || unit['occupied'] == 1;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          occupied ? LucideIcons.userCheck : LucideIcons.userX,
          color: occupied ? Colors.green : Colors.grey,
        ),
        title: Text("Unit $number"),
        subtitle: Text("Rent: KES $rent"),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              _deleteUnit(unit['id']);
            }
          },
          itemBuilder: (context) => [
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
        title: const Text("Units"),
        actions: [
          IconButton(
            onPressed: _addUnitDialog,
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Add Unit',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : units.isEmpty
              ? const Center(child: Text("No units yet. Click + to add."))
              : RefreshIndicator(
                  onRefresh: _loadUnits,
                  child: ListView.builder(
                    itemCount: units.length,
                    itemBuilder: (context, index) =>
                        _buildUnitCard(units[index]),
                  ),
                ),
    );
  }
}
