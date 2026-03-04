// lib/screens/admin/admin_finance.dart
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AdminFinanceScreen extends StatelessWidget {
  const AdminFinanceScreen({super.key});

  void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => _goBack(context),
        ),
        title: const Text('Admin • Finance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.wallet),
              title: const Text('Collections (Today/Month)'),
              subtitle: const Text('Hook this to your payments reports endpoints'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Collections report UI next')),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.fileText),
              title: const Text('Receipts'),
              subtitle: const Text('View/download receipts by payment reference'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Receipts UI next')),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.arrowLeftRight),
              title: const Text('Payout approvals'),
              subtitle: const Text('Landlord/Manager payouts approvals + audit trail'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payout approvals UI next')),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.badgeDollarSign),
              title: const Text('Service fees'),
              subtitle: const Text('Your KES 50 cut, provider charges, reconciliation'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Service fee dashboard UI next')),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Note: This Finance hub is ready. Paste your report endpoints (report_router / property status reports) and I’ll wire these cards to real data.',
            style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
          ),
        ],
      ),
    );
  }
}