import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connections_provider.dart';
import '../../models/connection_model.dart';
import 'package:fluxlyn/src/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fluxlyn/src/features/dashboard/providers/dashboard_provider.dart';
import 'package:fluxlyn/src/features/settings/providers/settings_provider.dart';
import '../widgets/connection_card.dart';
import '../dialogs/connection_dialog.dart';

class ConnectionsTab extends StatefulWidget {
  final bool isSortingEnabled;
  final String searchQuery;
  final bool isSelectionMode;
  final Set<String> selectedConnectionIds;
  final VoidCallback onSelectionModeChanged;
  final ValueChanged<String> onSelectionToggled;
  final VoidCallback onSelectionCleared;

  const ConnectionsTab({
    super.key,
    this.isSortingEnabled = false,
    this.searchQuery = '',
    this.isSelectionMode = false,
    required this.selectedConnectionIds,
    required this.onSelectionModeChanged,
    required this.onSelectionToggled,
    required this.onSelectionCleared,
  });

  @override
  State<ConnectionsTab> createState() => _ConnectionsTabState();
}

class _ConnectionsTabState extends State<ConnectionsTab> {
  ConnectionTag _selectedFilterTag = ConnectionTag.none;
  String? _lastSearchQuery;

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
    var filtered = connections;

    if (_selectedFilterTag != ConnectionTag.none) {
      filtered = filtered.where((c) => c.tag == _selectedFilterTag).toList();
    }

    if (widget.searchQuery.isNotEmpty) {
      final query = widget.searchQuery.toLowerCase();
      filtered = filtered
          .where((c) => c.name.toLowerCase().contains(query))
          .toList();
    }

    return filtered;
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

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    ConnectionModel connection,
  ) async {
    final settingsProvider = context.read<SettingsProvider>();
    final requireConfirm = settingsProvider.settings.lock;

    if (!requireConfirm) {
      final provider = context.read<ConnectionsProvider>();
      await provider.removeConnection(connection.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection "${connection.name}" deleted')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${connection.name}"?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'This will permanently remove all connection settings, including:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (connection.password != null &&
                      connection.password!.isNotEmpty)
                    const Text('• Stored password'),
                  if (connection.useSsh) ...[
                    const Text('• SSH credentials'),
                    if (connection.sshPrivateKey != null &&
                        connection.sshPrivateKey!.isNotEmpty)
                      const Text('• SSH private key path'),
                  ],
                  const Text('• Connection preferences'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = context.read<ConnectionsProvider>();
      await provider.removeConnection(connection.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection "${connection.name}" deleted')),
        );
      }
    }
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
            widget.onSelectionCleared();
          });
        }

        if (_lastSearchQuery != widget.searchQuery) {
          _lastSearchQuery = widget.searchQuery;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onSelectionCleared();
          });
        }

        final filteredConnections = _getFilteredConnections(
          provider.connections,
        );
        final showFilterBar = _shouldShowFilterBar(provider.connections);

        final screenWidth = MediaQuery.of(context).size.width;
        final isWideScreen = screenWidth > 1200;

        return Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWideScreen ? 1200 : double.infinity,
                ),
                child: Padding(
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
                                      widget.searchQuery.isEmpty
                                          ? Icons.dns_outlined
                                          : Icons.search_off,
                                      size: 64,
                                      color: Colors.grey.withValues(alpha: 0.2),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _getEmptyStateMessage(
                                        provider.connections.isEmpty,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : _buildConnectionsList(
                                provider,
                                filteredConnections,
                                _selectedFilterTag == ConnectionTag.none &&
                                    widget.searchQuery.isEmpty,
                                isWideScreen,
                              ),
                      ),
                    ],
                  ),
                ),
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
    bool isWideScreen,
  ) {
    if (isWideScreen && !allowReorder) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: connections.length,
        itemBuilder: (context, index) {
          final connection = connections[index];
          return ConnectionCard(
            connection: connection,
            onTap: widget.isSelectionMode
                ? null
                : () async {
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
                          MaterialPageRoute(
                            builder: (_) => const DashboardPage(),
                          ),
                        );
                      }
                    }
                  },
            onEdit: () =>
                _showConnectionDialog(context, connection: connection),
            onDelete: () => _showDeleteConfirmation(context, connection),
            onLongPress: () {
              widget.onSelectionModeChanged();
              widget.onSelectionToggled(connection.id);
            },
            isSelected: widget.selectedConnectionIds.contains(connection.id),
            isSelectionMode: widget.isSelectionMode,
            onSelect: () => widget.onSelectionToggled(connection.id),
          );
        },
      );
    }

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
                    onTap: widget.isSelectionMode
                        ? null
                        : () async {
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
                    onDelete: () =>
                        _showDeleteConfirmation(context, connection),
                    onLongPress: () {
                      widget.onSelectionModeChanged();
                      widget.onSelectionToggled(connection.id);
                    },
                    isSelected: widget.selectedConnectionIds.contains(
                      connection.id,
                    ),
                    isSelectionMode: widget.isSelectionMode,
                    onSelect: () => widget.onSelectionToggled(connection.id),
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
          onTap: widget.isSelectionMode
              ? null
              : () async {
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
                        MaterialPageRoute(
                          builder: (_) => const DashboardPage(),
                        ),
                      );
                    }
                  }
                },
          onEdit: () => _showConnectionDialog(context, connection: connection),
          onDelete: () => _showDeleteConfirmation(context, connection),
          onLongPress: () {
            widget.onSelectionModeChanged();
            widget.onSelectionToggled(connection.id);
          },
          isSelected: widget.selectedConnectionIds.contains(connection.id),
          isSelectionMode: widget.isSelectionMode,
          onSelect: () => widget.onSelectionToggled(connection.id),
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
        widget.onSelectionCleared();
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

  String _getEmptyStateMessage(bool hasNoConnections) {
    if (hasNoConnections) {
      return 'No connections yet.\nTap "+" to add one.';
    }
    if (widget.searchQuery.isNotEmpty) {
      return 'No connections match "${widget.searchQuery}"';
    }
    return 'No connections match selected filter.';
  }
}
