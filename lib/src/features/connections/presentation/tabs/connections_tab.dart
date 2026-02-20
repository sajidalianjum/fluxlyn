import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connections_provider.dart';
import '../../models/connection_model.dart';
import 'package:fluxlyn/src/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fluxlyn/src/features/dashboard/providers/dashboard_provider.dart';
import '../widgets/connection_card.dart';
import '../dialogs/connection_dialog.dart';

class ConnectionsTab extends StatefulWidget {
  final bool isSortingEnabled;

  const ConnectionsTab({super.key, this.isSortingEnabled = false});

  @override
  State<ConnectionsTab> createState() => _ConnectionsTabState();
}

class _ConnectionsTabState extends State<ConnectionsTab> {
  ConnectionTag _selectedFilterTag = ConnectionTag.none;

  Set<ConnectionTag> _getAvailableTags(List<ConnectionModel> connections) {
    return connections
        .map((c) => c.tag)
        .whereType<ConnectionTag>()
        .where((tag) => tag != ConnectionTag.none)
        .toSet();
  }

  bool _shouldShowFilterBar(List<ConnectionModel> connections) {
    final availableTags = _getAvailableTags(connections);
    return availableTags.length >= 2;
  }

  List<ConnectionModel> _getFilteredConnections(
    List<ConnectionModel> connections,
  ) {
    if (_selectedFilterTag == ConnectionTag.none) {
      return connections;
    }
    return connections.where((c) => c.tag == _selectedFilterTag).toList();
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
        final availableTags = _getAvailableTags(provider.connections);
        if (_selectedFilterTag != ConnectionTag.none &&
            !availableTags.contains(_selectedFilterTag)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _selectedFilterTag = ConnectionTag.none;
            });
          });
        }

        final filteredConnections = _getFilteredConnections(
          provider.connections,
        );
        final showFilterBar = _shouldShowFilterBar(provider.connections);

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  if (showFilterBar) ...[
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildFilterChip(ConnectionTag.none, 'All'),
                          ...availableTags
                              .map(
                                (tag) => [
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    tag,
                                    tag == ConnectionTag.custom
                                        ? 'Custom'
                                        : tag.name[0].toUpperCase() +
                                              tag.name.substring(1),
                                  ),
                                ],
                              )
                              .expand((e) => e),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Expanded(
                    child: filteredConnections.isEmpty
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
                                  provider.connections.isEmpty
                                      ? 'No connections yet.\nTap "+" to add one.'
                                      : 'No connections match selected filter.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : _buildConnectionsList(
                            provider,
                            filteredConnections,
                            _selectedFilterTag == ConnectionTag.none,
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

  Widget _buildConnectionsList(
    ConnectionsProvider provider,
    List<ConnectionModel> connections,
    bool allowReorder,
  ) {
    if (allowReorder) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: connections.length,
        onReorder: (oldIndex, newIndex) {
          provider.reorderConnections(oldIndex, newIndex);
        },
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              return Transform.scale(scale: 1.05, child: child);
            },
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final connection = connections[index];
          return Container(
            key: ValueKey(connection.id),
            child: Row(
              children: [
                if (widget.isSortingEnabled)
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Icon(
                        Icons.drag_handle,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                Expanded(
                  child: ConnectionCard(
                    connection: connection,
                    onTap: () async {
                      final dashboardProvider = context
                          .read<DashboardProvider>();
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
                    onEdit: () =>
                        _showConnectionDialog(context, connection: connection),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return ListView.builder(
      itemCount: connections.length,
      itemBuilder: (context, index) {
        final connection = connections[index];
        return ConnectionCard(
          connection: connection,
          onTap: () async {
            final dashboardProvider = context.read<DashboardProvider>();
            await dashboardProvider.connect(connection);

            if (context.mounted) {
              if (dashboardProvider.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${dashboardProvider.error}'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DashboardPage()),
                );
              }
            }
          },
          onEdit: () => _showConnectionDialog(context, connection: connection),
        );
      },
    );
  }

  Widget _buildFilterChip(ConnectionTag tag, String label) {
    final isSelected = _selectedFilterTag == tag;
    final color = _getTagColor(tag);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilterTag = tag;
        });
      },
      selectedColor: color.withValues(alpha: 0.3),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }

  Color _getTagColor(ConnectionTag tag) {
    switch (tag) {
      case ConnectionTag.none:
        return Colors.grey;
      case ConnectionTag.development:
        return Colors.green;
      case ConnectionTag.production:
        return Colors.red;
      case ConnectionTag.testing:
        return Colors.yellow;
      case ConnectionTag.staging:
        return Colors.orange;
      case ConnectionTag.local:
        return Colors.purple;
      case ConnectionTag.custom:
        return Colors.blue;
    }
  }
}
