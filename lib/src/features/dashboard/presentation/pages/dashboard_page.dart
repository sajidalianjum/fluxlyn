import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../tabs/schema_tab.dart';
import '../tabs/query_tab.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();

    final List<Widget> pages = [
      const SchemaTab(),
      const QueryTab(),
      const Center(child: Text('History (Coming Soon)')),
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
                child: const Center(child: CircularProgressIndicator()),
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
                        onPressed: () =>
                            provider.connect(provider.currentConnectionModel!),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: provider.selectedTabIndex,
          onTap: (index) => provider.setTabIndex(index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dns), label: 'Databases'),
            BottomNavigationBarItem(icon: Icon(Icons.code), label: 'Editor'),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}
