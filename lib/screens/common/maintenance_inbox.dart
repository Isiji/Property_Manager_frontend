import 'package:flutter/material.dart';
import 'package:property_manager_frontend/services/maintenance_service.dart';

class LandlordMaintenanceInbox extends StatefulWidget {
  final bool forManager;
  const LandlordMaintenanceInbox({super.key, this.forManager = false});
  @override
  State<LandlordMaintenanceInbox> createState() => _LMState();
}

class _LMState extends State<LandlordMaintenanceInbox> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await MaintenanceService.listMine();
      _items = list.map<Map<String, dynamic>>((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      _items = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.forManager ? 'Manager • Maintenance' : 'Landlord • Maintenance'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final m = _items[i];
                final unit = (m['unit_number'] ?? '—').toString();
                final prop = (m['property_name'] ?? '').toString();
                final desc = (m['description'] ?? '').toString();
                final status = (m['status'] ?? '').toString();
                final created = (m['created_at'] ?? '').toString();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.build_rounded),
                    title: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('$prop • $unit\n$created', maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text(status.toUpperCase(), style: t.textTheme.labelSmall),
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        '/maintenance_detail',
                        arguments: {'id': m['id']},
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
