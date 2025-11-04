// lib/screens/tenant/tenant_list_screen.dart
// Uses TenantService.fetchTenants() which returns List<TenantDto>.
// Safe nulls + simple actions (call/copy).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:property_manager_frontend/services/tenant_service.dart';
import 'package:url_launcher/url_launcher.dart';

class TenantListScreen extends StatefulWidget {
  const TenantListScreen({super.key});

  @override
  State<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends State<TenantListScreen> {
  final _searchCtrl = TextEditingController();
  Future<List<TenantDto>>? _futureTenants;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load({String? q}) {
    setState(() {
      _futureTenants = TenantService.fetchTenants(query: q);
    });
  }

  Future<void> _refresh() async {
    _load(q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim());
    await _futureTenants;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot launch phone dialer')),
      );
    }
  }

  Widget _tile(TenantDto t) {
    final subtitle = <String>[
      if (t.propertyName != null && t.propertyName!.isNotEmpty) 'Property: ${t.propertyName}',
      if (t.unitLabel != null && t.unitLabel!.isNotEmpty) 'House: ${t.unitLabel}',
      if (t.email != null && t.email!.isNotEmpty) 'Email: ${t.email}',
      if (t.idNumber != null && t.idNumber!.isNotEmpty) 'ID: ${t.idNumber}',
    ].join('  •  ');

    final balanceText = t.currentBalance == null
        ? ''
        : (t.currentBalance! > 0
            ? 'Balance: KES ${t.currentBalance!.toStringAsFixed(2)}'
            : t.currentBalance! < 0
                ? 'Credit: KES ${(-t.currentBalance!).toStringAsFixed(2)}'
                : 'Cleared');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        title: Row(
          children: [
            Expanded(
              child: Text(
                t.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: _statusColor(t.rentStatus).withOpacity(0.12),
                border: Border.all(color: _statusColor(t.rentStatus).withOpacity(0.35)),
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                (t.rentStatus ?? 'UNKNOWN').toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _statusColor(t.rentStatus),
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subtitle),
            ],
            if (balanceText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(balanceText, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ],
        ),
        leading: CircleAvatar(
          child: Text(t.name.isNotEmpty ? t.name[0].toUpperCase() : '?'),
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              tooltip: 'Call ${t.phone}',
              icon: const Icon(Icons.phone),
              onPressed: () => _call(t.phone),
            ),
            PopupMenuButton<String>(
              tooltip: 'Copy…',
              icon: const Icon(Icons.copy_all),
              onSelected: (key) {
                switch (key) {
                  case 'name':
                    _copy('Name', t.name);
                    break;
                  case 'phone':
                    _copy('Phone', t.phone);
                    break;
                  case 'id':
                    _copy('ID Number', t.idNumber ?? '');
                    break;
                  case 'house':
                    _copy('House Number', t.unitLabel ?? t.unitId.toString());
                    break;
                }
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'name', child: Text('Copy name')),
                PopupMenuItem(value: 'phone', child: Text('Copy phone')),
                PopupMenuItem(value: 'id', child: Text('Copy ID number')),
                PopupMenuItem(value: 'house', child: Text('Copy house number')),
              ],
            ),
          ],
        ),
        onLongPress: () => _copy('Phone', t.phone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by name, phone, house…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (v) => _load(q: v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _load(q: _searchCtrl.text.trim()),
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<TenantDto>>(
              future: _futureTenants,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting || _loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final tenants = snapshot.data ?? const <TenantDto>[];
                if (tenants.isEmpty) {
                  return const Center(child: Text('No tenants found.'));
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    itemCount: tenants.length,
                    itemBuilder: (ctx, i) => _tile(tenants[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
