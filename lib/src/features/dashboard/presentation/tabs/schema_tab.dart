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

    return Scaffold(
      appBar: AppBar(
        title: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(connectionName, style: Theme.of(context).textTheme.titleMedium),
             // Start dummy connection status
             Row(
               children: [
                 const Icon(Icons.circle, color: Colors.green, size: 8),
                 const SizedBox(width: 4),
                 Text('CONNECTED', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.green)),
               ],
             ),
           ],
        ),
        actions: [
          IconButton(onPressed: () => provider.refreshTables(), icon: const Icon(Icons.refresh)),
          IconButton(onPressed: () => provider.disconnect(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView.builder(
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
      ),
    );
  }
}
