import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connections_provider.dart';
import '../../models/connection_model.dart';
import '../dialogs/connection_dialog.dart';
import '../tabs/connections_tab.dart';
import 'package:fluxlyn/src/features/settings/presentation/tabs/settings_tab.dart';
import 'package:fluxlyn/src/features/dashboard/presentation/tabs/queries_tab.dart';
import 'package:fluxlyn/src/features/settings/providers/settings_provider.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isEditMode = false;
  final Set<String> _selectedConnectionIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        _selectedConnectionIds.clear();
      }
    });
  }

  void _toggleConnectionSelection(String id) {
    setState(() {
      if (_selectedConnectionIds.contains(id)) {
        _selectedConnectionIds.remove(id);
      } else {
        _selectedConnectionIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedConnectionIds.clear();
    });
  }

  Future<void> _showBulkDeleteConfirmation(BuildContext context) async {
    final provider = context.read<ConnectionsProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final connectionsToDelete = provider.connections
        .where((c) => _selectedConnectionIds.contains(c.id))
        .toList();

    if (connectionsToDelete.isEmpty) return;

    final requireConfirm = settingsProvider.settings.lock;

    if (!requireConfirm) {
      await provider.removeConnections(_selectedConnectionIds);
      _clearSelection();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${connectionsToDelete.length} connection(s) deleted',
            ),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Connections'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete ${connectionsToDelete.length} connection(s)?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'This will permanently remove:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: connectionsToDelete
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 4),
                          child: Text('• ${c.name}'),
                        ),
                      )
                      .toList(),
                ),
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
                  const Icon(Icons.warning, color: Colors.red, size: 16),
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
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await provider.removeConnections(_selectedConnectionIds);
      _clearSelection();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${connectionsToDelete.length} connection(s) deleted',
            ),
          ),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;

    final List<Widget> tabs = [
      ConnectionsTab(
        isEditMode: _isEditMode,
        searchQuery: _selectedTabIndex == 0 ? _searchController.text : '',
        selectedConnectionIds: _selectedConnectionIds,
        onSelectionToggled: _toggleConnectionSelection,
        onSelectionCleared: _clearSelection,
      ),
      QueriesTab(
        searchQuery: _selectedTabIndex == 1 ? _searchController.text : '',
      ),
      const SettingsTab(),
    ];

    if (isWideScreen) {
      return Scaffold(
        appBar: AppBar(
          title:
              _isSearching && (_selectedTabIndex == 0 || _selectedTabIndex == 1)
              ? _buildSearchBar()
              : Text(_getAppBarTitle()),
          actions: _getAppBarActions(),
        ),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedTabIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedTabIndex = index;
                  if (_isSearching && index != 0 && index != 1) {
                    _isSearching = false;
                    _searchController.clear();
                  }
                });
              },
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dns, semanticLabel: 'View connections'),
                  label: Text('Connections'),
                ),
                NavigationRailDestination(
                  icon: Icon(
                    Icons.saved_search,
                    semanticLabel: 'Saved queries',
                  ),
                  label: Text('Queries'),
                ),
                NavigationRailDestination(
                  icon: Icon(
                    Icons.settings,
                    semanticLabel: 'Application settings',
                  ),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(
              thickness: 1,
              width: 1,
              color: Color(0xFF334155),
            ),
            Expanded(
              child: IndexedStack(index: _selectedTabIndex, children: tabs),
            ),
          ],
        ),
        floatingActionButton: _getFloatingActionButton(),
        bottomNavigationBar:
            _selectedConnectionIds.isNotEmpty && _selectedTabIndex == 0
            ? _buildSelectionActionBar()
            : null,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            _isSearching && (_selectedTabIndex == 0 || _selectedTabIndex == 1)
            ? _buildSearchBar()
            : Text(_getAppBarTitle()),
        actions: _getAppBarActions(),
      ),
      body: IndexedStack(index: _selectedTabIndex, children: tabs),
      floatingActionButton: _getFloatingActionButton(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildBottomNavigation() {
    if (_selectedConnectionIds.isNotEmpty && _selectedTabIndex == 0) {
      return _buildSelectionActionBar();
    }
    return NavigationBar(
      selectedIndex: _selectedTabIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedTabIndex = index;
          if (_isSearching && index != 0 && index != 1) {
            _isSearching = false;
            _searchController.clear();
          }
        });
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dns, semanticLabel: 'View connections'),
          label: 'Connections',
        ),
        NavigationDestination(
          icon: Icon(Icons.saved_search, semanticLabel: 'Saved queries'),
          label: 'Queries',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings, semanticLabel: 'Application settings'),
          label: 'Settings',
        ),
      ],
    );
  }

  Widget _buildSelectionActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Text(
              '${_selectedConnectionIds.length} selected',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const Spacer(),
            TextButton(onPressed: _clearSelection, child: const Text('Clear')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _showBulkDeleteConfirmation(context),
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Delete'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: _selectedTabIndex == 0
            ? 'Search connections...'
            : 'Search queries or databases...',
        hintStyle: const TextStyle(color: Colors.grey),
        border: InputBorder.none,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget? _getFloatingActionButton() {
    if (_selectedTabIndex == 0) {
      return FloatingActionButton(
        onPressed: () => _showConnectionDialog(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      );
    }
    return null;
  }

  String _getAppBarTitle() {
    switch (_selectedTabIndex) {
      case 0:
        return 'Connections';
      case 1:
        return 'Queries';
      case 2:
        return 'Settings';
      default:
        return 'Fluxlyn';
    }
  }

  List<Widget> _getAppBarActions() {
    switch (_selectedTabIndex) {
      case 0:
        if (_isSearching) {
          return [
            IconButton(
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.close),
              tooltip: 'Close',
            ),
          ];
        }
        return [
          TextButton(
            onPressed: _toggleEditMode,
            child: Text(_isEditMode ? 'Done' : 'Edit'),
          ),
          IconButton(
            onPressed: () => setState(() => _isSearching = true),
            icon: const Icon(Icons.search),
            tooltip: 'Search connections',
          ),
        ];
      case 1:
        if (_isSearching) {
          return [
            IconButton(
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.close),
              tooltip: 'Close',
            ),
          ];
        }
        return [
          IconButton(
            onPressed: () => setState(() => _isSearching = true),
            icon: const Icon(Icons.search),
            tooltip: 'Search queries',
          ),
        ];
      default:
        return [];
    }
  }
}
