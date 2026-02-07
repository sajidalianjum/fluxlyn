import 'package:flutter/material.dart';
import '../../models/alert_model.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback onToggleEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AlertCard({
    super.key,
    required this.alert,
    required this.onToggleEnabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E293B),
      child: ListTile(
        leading: Icon(
          alert.isEnabled ? Icons.notifications_active : Icons.notifications,
          color: alert.isEnabled ? Colors.green : Colors.grey,
        ),
        title: Text(
          alert.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              alert.getScheduleDisplay(),
              style: const TextStyle(fontSize: 12),
            ),
            if (alert.thresholdColumn != null) ...[
              const SizedBox(height: 2),
              Text(
                alert.getThresholdDisplay(),
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Query: ${_getQueryPreview()}',
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.grey,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (alert.lastRunAt != null) ...[
              const SizedBox(height: 2),
              Text(
                'Last run: ${_formatDate(alert.lastRunAt!)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: alert.isEnabled, onChanged: (_) => onToggleEnabled()),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  String _getQueryPreview() {
    if (alert.query.length <= 50) {
      return alert.query;
    }
    return '${alert.query.substring(0, 50)}...';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
