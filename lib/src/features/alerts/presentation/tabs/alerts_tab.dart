import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/alert_model.dart';
import '../../providers/alerts_provider.dart';
import '../widgets/alert_card.dart';

class AlertsTab extends StatelessWidget {
  const AlertsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Error: ${provider.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }

        if (provider.alerts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 64,
                  color: Colors.grey.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No alerts yet.\nTap "+" to create your first alert.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.alerts.length,
          itemBuilder: (context, index) {
            final alert = provider.alerts[index];
            return AlertCard(
              alert: alert,
              onToggleEnabled: () => provider.toggleAlertEnabled(alert.id),
              onEdit: () => _showEditDialog(context, provider, alert),
              onDelete: () => _showDeleteDialog(context, provider, alert.id),
            );
          },
        );
      },
    );
  }

  void _showEditDialog(
    BuildContext context,
    AlertsProvider provider,
    AlertModel alert,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Edit Alert'),
        content: const Text('Alert editing is coming soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    AlertsProvider provider,
    String alertId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Alert'),
        content: const Text('Are you sure you want to delete this alert?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await provider.deleteAlert(alertId);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Alert deleted')));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
