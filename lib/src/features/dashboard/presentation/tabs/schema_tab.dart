import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../connections/presentation/pages/connections_page.dart';
import '../../providers/dashboard_provider.dart';
import '../pages/table_data_page.dart';

class SchemaTab extends StatelessWidget {
  const SchemaTab({super.key});

  void _showDisconnectDialog(BuildContext context, DashboardProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.orange),
            SizedBox(width: 8),
            Text('Disconnect?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to disconnect from this database? You will return to the connections list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await provider.disconnect();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ConnectionsPage()),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final connectionName = provider.currentConnectionModel?.name ?? 'Database';
    final isDbSelected = provider.selectedDatabase != null;

    return PopScope(
      canPop:
          !isDbSelected, // Can pop if no database selected, otherwise intercept
      onPopInvokedWithResult: (didPop, result) {
        if (isDbSelected && !didPop) {
          // When in tables view and back pressed, clear database selection
          // but stay in the SchemaTab (don't pop the tab)
          provider.clearDatabaseSelection();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDbSelected ? provider.selectedDatabase! : connectionName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(
                children: [
                  const Icon(Icons.circle, color: Colors.green, size: 8),
                  const SizedBox(width: 4),
                  Text(
                    isDbSelected ? 'TABLES' : 'DATABASES',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Refresh button
            IconButton(
              onPressed: () => isDbSelected
                  ? provider.refreshTables()
                  : provider.refreshDatabases(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
            // Disconnect button
            IconButton(
              onPressed: () => _showDisconnectDialog(context, provider),
              icon: const Icon(Icons.logout),
              tooltip: 'Disconnect',
            ),
          ],
        ),
        body: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : isDbSelected
            ? _buildTableList(context, provider)
            : _buildDatabaseList(context, provider),
      ),
    );
  }

  Widget _buildDatabaseList(BuildContext context, DashboardProvider provider) {
    return ListView.builder(
      itemCount: provider.databases.length,
      itemBuilder: (context, index) {
        final db = provider.databases[index];
        return ListTile(
          leading: const Icon(Icons.storage, color: Colors.orangeAccent),
          title: Text(db),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => provider.selectDatabase(db),
        );
      },
    );
  }

  Widget _buildTableList(BuildContext context, DashboardProvider provider) {
    if (provider.tables.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.table_rows_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No tables found in this database'),
            TextButton(
              onPressed: () => provider.clearDatabaseSelection(),
              child: const Text('View all databases'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: provider.tables.length,
      itemBuilder: (context, index) {
        final table = provider.tables[index];
        return ListTile(
          leading: const Icon(Icons.table_chart, color: Colors.blueGrey),
          title: Text(table),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TableDataPage(tableName: table),
              ),
            );
          },
        );
      },
    );
  }
}
