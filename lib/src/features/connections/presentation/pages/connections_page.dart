import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connections_provider.dart';
import '../widgets/connection_card.dart';
import '../dialogs/add_connection_dialog.dart';

class ConnectionsPage extends StatelessWidget {
  const ConnectionsPage({super.key});

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddConnectionDialog(
        onAdd: (connection) {
          context.read<ConnectionsProvider>().addConnection(connection);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        actions: [
          IconButton(
            onPressed: () {}, // Search - Future scope
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () {}, // User profile - Future scope
            icon: const Icon(Icons.account_circle),
          ),
        ],
      ),
      body: Consumer<ConnectionsProvider>(
        builder: (context, provider, child) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                // Main List
                Expanded(
                  child: provider.connections.isEmpty
                      ? Center(
                          child: Text(
                            'No connections yet.\nTap "+" to add one.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: provider.connections.length,
                          itemBuilder: (context, index) {
                            final connection = provider.connections[index];
                            return ConnectionCard(
                              connection: connection,
                              onTap: () {
                                // TODO: Implement connection logic
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Connecting to ${connection.name}...')),
                                );
                              },
                            );
                          },
                        ),
                ),
                
                // Recently Disconnected (Mock)
                const SizedBox(height: 24),
                Text(
                  'RECENTLY DISCONNECTED',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                // Hardcoded active/disconnected mock for UI match
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: const Color(0xFF1E293B).withValues(alpha: 0.5), // Slightly dimmer
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                       width: 48,
                       height: 48,
                       decoration: BoxDecoration(
                         color: Colors.grey.withValues(alpha: 0.1),
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: const Icon(Icons.cloud_off, color: Colors.grey),
                    ),
                    title: const Text('Legacy Archive'),
                    subtitle: const Text('archive.db.local'),
                    trailing: const Icon(Icons.more_vert, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 80), // Space for FAB or bottom elements
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      ),
      // Bottom Navigation Bar Placeholder to match screenshot style if needed, 
      // though the screenshot cuts off. Standard nav bar usually.
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dns), label: 'Connections'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_graph), label: 'Queries'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
        ],
      ),
    );
  }
}
