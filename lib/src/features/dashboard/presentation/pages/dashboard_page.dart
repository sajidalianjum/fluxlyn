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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;
    final theme = Theme.of(context);

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
            if (isWideScreen)
              Row(
                children: [
                  NavigationRail(
                    selectedIndex: provider.selectedTabIndex,
                    onDestinationSelected: (index) =>
                        provider.setTabIndex(index),
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.dns, semanticLabel: 'View databases'),
                        label: Text('Databases'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.code, semanticLabel: 'Query editor'),
                        label: Text('Editor'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(
                          Icons.history,
                          semanticLabel: 'Query history',
                        ),
                        label: Text('History'),
                      ),
                    ],
                  ),
VerticalDivider(
                    thickness: 1,
                    width: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  Expanded(child: _buildContent(pages, provider, theme)),
                ],
              )
            else
              _buildContent(pages, provider, theme),
          ],
        ),
        bottomNavigationBar: isWideScreen
            ? null
            : NavigationBar(
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

  Widget _buildContent(List<Widget> pages, DashboardProvider provider, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Stack(
      children: [
        IndexedStack(index: provider.selectedTabIndex, children: pages),
        if (provider.isLoading)
          Container(
            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.3),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (provider.isReconnecting) ...[
                      const SizedBox(height: 16),
                      Text('Reconnecting to DB...', style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            ),
          ),
        if (provider.error != null && !provider.isLoading)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Error: ${provider.error}',
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: provider.currentConnectionModel != null
                        ? () =>
                              provider.connect(provider.currentConnectionModel!)
                        : null,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showDisconnectDialog(BuildContext context, DashboardProvider provider) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
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
              try {
                await provider.disconnect();
              } catch (_) {
                // Ignore disconnect errors - connection may already be invalid
              }
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
