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

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionsProvider>(
      builder: (context, provider, child) {
        return Padding(
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Connecting to ${connection.name}...',
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );

                              await dashboardProvider.connect(connection);

                              if (context.mounted) {
                                if (dashboardProvider.error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
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
        );
      },
    );
  }
}
