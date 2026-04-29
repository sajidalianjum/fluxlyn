import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/widgets/sql_highlighter.dart';
import '../../../connections/models/connection_model.dart';
import '../../../queries/models/query_model.dart';

class ConnectionQueriesTab extends StatelessWidget {
  const ConnectionQueriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final connectionModel = provider.currentConnectionModel;
    final storageService = context.watch<StorageService>();
    final theme = Theme.of(context);

    if (connectionModel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('History')),
        body: const Center(
          child: Text(
            'No connection selected',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final history = storageService.getQueryHistory(connectionModel.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: theme.colorScheme.surface,
                    title: const Text('Clear Query History'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Are you sure you want to clear the query history for "${connectionModel.name}"?',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This action cannot be undone.',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  await storageService.clearHistory(connectionModel.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Query history cleared')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: history.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No query history',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final entry = history[index];

                return _HistoryQueryCard(
                  entry: entry,
                  connectionModel: connectionModel,
                  onTap: () => _loadQuery(context, entry),
                );
              },
            ),
    );
  }

  void _loadQuery(BuildContext context, QueryHistoryEntry entry) {
    final provider = context.read<DashboardProvider>();
    provider.setPendingQuery(entry.query);
    provider.setPendingDatabase(entry.databaseName);
    provider.setTabIndex(1);
  }
}

class _HistoryQueryCard extends StatelessWidget {
  final QueryHistoryEntry entry;
  final ConnectionModel connectionModel;
  final VoidCallback onTap;

  const _HistoryQueryCard({
    required this.entry,
    required this.connectionModel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final queryText = entry.query;
    final executedAt = entry.executedAt;
    final success = entry.success;
    final databaseName = entry.databaseName;

    final relativeTime = _formatRelativeTime(executedAt);
    final dbType = connectionModel.type.name.toUpperCase();

    return Card(
      color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          success ? Icons.check_circle : Icons.error,
                          color: success ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          relativeTime,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            dbType,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.storage, size: 14, color: isDark ? Colors.grey[500] : Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            connectionModel.name,
                            style: TextStyle(
                              color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (databaseName != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '>',
                            style: TextStyle(
                              color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              databaseName,
                              style: TextStyle(
                                color: isDark ? Colors.grey[500] : Colors.grey.shade600,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    SqlHighlighter(
                      sql: queryText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      fontSize: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return days == 1 ? '1 day ago' : '$days days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
