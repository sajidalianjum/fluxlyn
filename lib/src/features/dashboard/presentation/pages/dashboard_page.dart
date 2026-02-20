import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../tabs/schema_tab.dart';
import '../tabs/query_tab.dart';
import '../tabs/connection_queries_tab.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();

    final List<Widget> pages = [
      const SchemaTab(),
      const QueryTab(),
      const ConnectionQueriesTab(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && provider.selectedDatabase == null) {
          _showDisconnectDialog(context, provider);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(index: provider.selectedTabIndex, children: pages),
            if (provider.isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (provider.isReconnecting) ...[
                        const SizedBox(height: 16),
                        const Text('Reconnecting to DB...'),
                      ],
                    ],
                  ),
                ),
              ),
            if (provider.error != null && !provider.isLoading)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black87,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Error: ${provider.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: provider.currentConnectionModel != null
                            ? () => provider.connect(
                                provider.currentConnectionModel!,
                              )
                            : null,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: provider.selectedTabIndex,
          onDestinationSelected: (index) => provider.setTabIndex(index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dns, semanticLabel: 'View databases'),
              label: 'Databases',
            ),
            NavigationDestination(
              icon: Icon(Icons.code, semanticLabel: 'Query editor'),
              label: 'Editor',
            ),
            NavigationDestination(
              icon: Icon(Icons.history, semanticLabel: 'Query history'),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }

  void _showDisconnectDialog(BuildContext context, DashboardProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Disconnect Database'),
        content: const Text(
          'Are you sure you want to disconnect the database?',
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
                Navigator.of(context).pop();
              }
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}
