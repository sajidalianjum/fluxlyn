import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connections_provider.dart';
import '../../models/connection_model.dart';
import '../dialogs/connection_dialog.dart';
import '../tabs/connections_tab.dart';
import 'package:fluxlyn/src/features/settings/presentation/tabs/settings_tab.dart';
import 'package:fluxlyn/src/features/dashboard/presentation/tabs/queries_tab.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final List<Widget> tabs = [
      const ConnectionsTab(),
      QueriesTab(searchQuery: _selectedTabIndex == 1 ? _searchController.text : ''),
      const SettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: _isSearching && _selectedTabIndex == 1
            ? _buildSearchBar()
            : Text(_getAppBarTitle()),
        actions: _getAppBarActions(),
      ),
      body: IndexedStack(index: _selectedTabIndex, children: tabs),
      floatingActionButton: _getFloatingActionButton(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedTabIndex = index;
            // Reset search when switching tabs
            if (_isSearching && index != 1) {
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
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        hintText: 'Search queries or databases...',
        hintStyle: TextStyle(color: Colors.grey),
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
        return [];
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
            tooltip: 'Search',
          ),
        ];
      default:
        return [];
    }
  }
}
