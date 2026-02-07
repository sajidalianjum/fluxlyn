import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connections_provider.dart';
import '../../models/connection_model.dart';
import 'package:fluxlyn/src/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fluxlyn/src/features/dashboard/providers/dashboard_provider.dart';
import 'package:fluxlyn/src/features/settings/presentation/dialogs/settings_dialog.dart';
import '../widgets/connection_card.dart';
import '../dialogs/connection_dialog.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        _isSearching = false;
        _searchQuery = '';
        _searchController.clear();
      } else {
        _isSearching = true;
      }
    });
  }

  List<ConnectionModel> _filterConnections(List<ConnectionModel> connections) {
    if (_searchQuery.isEmpty) {
      return connections;
    }
    final query = _searchQuery.toLowerCase();
    return connections.where((connection) {
      return connection.name.toLowerCase().contains(query) ||
          connection.host.toLowerCase().contains(query) ||
          (connection.username?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

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

  void _showSettingsDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const SettingsDialog());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _toggleSearch,
              )
            : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search connections...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text('Connections'),
        actions: [
          if (!_isSearching)
            IconButton(
              onPressed: _toggleSearch,
              icon: const Icon(Icons.search),
            ),
          IconButton(
            onPressed: () => _showSettingsDialog(context),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<ConnectionsProvider>(
        builder: (context, provider, child) {
          final filteredConnections = _filterConnections(provider.connections);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                // Main List
                Expanded(
                  child: filteredConnections.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isSearching
                                    ? Icons.search_off
                                    : Icons.dns_outlined,
                                size: 64,
                                color: Colors.grey.withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isSearching
                                    ? 'No connections found.'
                                    : 'No connections yet.\nTap "+" to add one.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredConnections.length,
                          itemBuilder: (context, index) {
                            final connection = filteredConnections[index];
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showConnectionDialog(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dns), label: 'Connections'),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_graph),
            label: 'Queries',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}
