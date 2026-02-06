import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../pages/table_data_page.dart';

class SchemaTab extends StatelessWidget {
  const SchemaTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final connectionName = provider.currentConnectionModel?.name ?? 'Database';
    final isDbSelected = provider.selectedDatabase != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Row(
               children: [
                 if (isDbSelected)
                   IconButton(
                     icon: const Icon(Icons.arrow_back, size: 20),
                     onPressed: () => provider.clearDatabaseSelection(),
                   ),
                 if (isDbSelected) const SizedBox(width: 8),
                 Text(
                   isDbSelected ? provider.selectedDatabase! : connectionName, 
                   style: Theme.of(context).textTheme.titleMedium,
                 ),
               ],
             ),
             Row(
               children: [
                 const Icon(Icons.circle, color: Colors.green, size: 8),
                 const SizedBox(width: 4),
                 Text(
                   isDbSelected ? 'TABLES' : 'DATABASES', 
                   style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.green),
                 ),
               ],
             ),
           ],
        ),
        actions: [
          IconButton(
            onPressed: () => isDbSelected ? provider.refreshTables() : provider.refreshDatabases(), 
            icon: const Icon(Icons.refresh),
          ),
          IconButton(onPressed: () => provider.disconnect(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: provider.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : isDbSelected 
          ? _buildTableList(context, provider)
          : _buildDatabaseList(context, provider),
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
                onPressed: () => provider.refreshDatabases(), // Use the refresh to go back or something
                child: const Text('Back to Databases'),
              )
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
               MaterialPageRoute(builder: (_) => TableDataPage(tableName: table)),
             );
          },
        );
      },
    );
  }
}
