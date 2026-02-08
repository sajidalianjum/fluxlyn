import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connections_provider.dart';
import '../../models/connection_model.dart';
import 'package:fluxlyn/src/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fluxlyn/src/features/dashboard/providers/dashboard_provider.dart';
import '../widgets/connection_card.dart';
import '../dialogs/connection_dialog.dart';

class ConnectionsTab extends StatefulWidget {
  const ConnectionsTab({super.key});

  @override
  State<ConnectionsTab> createState() => _ConnectionsTabState();
}

class _ConnectionsTabState extends State<ConnectionsTab> {
  void _showConnectionDialog(
    BuildContext context, {
    ConnectionModel? connection,
  }) {
    showDialog(
      context: context,
      builder: (context) => ConnectionDialog(
        connection: connection,
        onSave: (newConnection) {
          final provider = context.read<ConnectionsProvider>();
          if (connection == null) {
            provider.addConnection(newConnection);
          } else {
            provider.updateConnection(newConnection);
          }
        },
      ),
    );
  }

  String _getConnectionMessage(ConnectionStep step) {
    switch (step) {
      case ConnectionStep.initializing:
        return 'Initializing connection...';
      case ConnectionStep.connectingSsh:
        return 'Establishing SSH tunnel...';
      case ConnectionStep.authenticatingSsh:
        return 'Authenticating SSH...';
      case ConnectionStep.connectingDatabase:
        return 'Connecting to database...';
      case ConnectionStep.loadingDatabases:
        return 'Loading databases...';
      case ConnectionStep.loadingTables:
        return 'Loading tables...';
      case ConnectionStep.completed:
        return 'Connection established!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionsProvider>(
      builder: (context, provider, child) {
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Expanded(
                    child: provider.connections.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.dns_outlined,
                                  size: 64,
                                  color: Colors.grey.withValues(alpha: 0.2),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No connections yet.\nTap "+" to add one.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: provider.connections.length,
                            itemBuilder: (context, index) {
                              final connection = provider.connections[index];
                              return ConnectionCard(
                                connection: connection,
                                onTap: () async {
                                  final dashboardProvider = context
                                      .read<DashboardProvider>();
                                  await dashboardProvider.connect(connection);

                                  if (context.mounted) {
                                    if (dashboardProvider.error != null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error: ${dashboardProvider.error}',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    } else {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const DashboardPage(),
                                        ),
                                      );
                                    }
                                  }
                                },
                                onEdit: () => _showConnectionDialog(
                                  context,
                                  connection: connection,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            Consumer<DashboardProvider>(
              builder: (context, dashboardProvider, child) {
                if (dashboardProvider.isLoading) {
                  return Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 24),
                            Text(
                              _getConnectionMessage(
                                dashboardProvider.connectionStep,
                              ),
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        );
      },
    );
  }
}
