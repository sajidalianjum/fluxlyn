import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../pages/table_data_page.dart';

class SchemaTab extends StatefulWidget {
  const SchemaTab({super.key});

  @override
  State<SchemaTab> createState() => _SchemaTabState();
}

class _SchemaTabState extends State<SchemaTab> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _needsSearchReset = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final connectionName = provider.currentConnectionModel?.name ?? 'Database';
    final isDbSelected = provider.selectedDatabase != null;

    if (isDbSelected && _needsSearchReset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isSearching = false;
            _searchController.clear();
            _needsSearchReset = false;
          });
        }
      });
    }
    if (!isDbSelected) {
      _needsSearchReset = true;
    }

    return PopScope(
      canPop: !isDbSelected,
      onPopInvokedWithResult: (didPop, result) {
        if (isDbSelected && !didPop) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.clearDatabaseSelection();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? _buildSearchBar()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDbSelected
                          ? provider.selectedDatabase ?? connectionName
                          : connectionName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.green, size: 8),
                        const SizedBox(width: 4),
                        Text(
                          isDbSelected ? 'TABLES' : 'DATABASES',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
          actions: [
            if (_isSearching) ...[
              IconButton(
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                  });
                },
                icon: const Icon(Icons.close),
                tooltip: 'Clear',
              ),
            ] else ...[
              IconButton(
                onPressed: () => setState(() => _isSearching = true),
                icon: const Icon(Icons.search),
                tooltip: 'Search',
              ),
              IconButton(
                onPressed: () => isDbSelected
                    ? provider.refreshTables()
                    : provider.refreshDatabases(),
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ],
        ),
        body: isDbSelected
            ? _buildTableList(context, provider)
            : _buildDatabaseList(context, provider),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        hintText: 'Search...',
        hintStyle: TextStyle(color: Colors.grey),
        border: InputBorder.none,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  List<String> _filterList(List<String> list) {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return list;
    return list.where((item) => item.toLowerCase().contains(query)).toList();
  }

  Widget _buildDatabaseList(BuildContext context, DashboardProvider provider) {
    final filteredDatabases = _filterList(provider.databases);
    return ListView.builder(
      itemCount: filteredDatabases.length,
      itemBuilder: (context, index) {
        final db = filteredDatabases[index];
        return ListTile(
          leading: const Icon(Icons.storage, color: Colors.orangeAccent),
          title: Text(db),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => provider.selectDatabase(db),
        );
      },
    );
  }

  Widget _buildTableList(BuildContext context, DashboardProvider provider) {
    final filteredTables = _filterList(provider.tables);
    if (filteredTables.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No tables found in this database'
                  : 'No tables match "${_searchController.text}"',
            ),
            TextButton(
              onPressed: () => provider.clearDatabaseSelection(),
              child: const Text('View all databases'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: filteredTables.length,
      itemBuilder: (context, index) {
        final table = filteredTables[index];
        return ListTile(
          leading: const Icon(Icons.table_chart, color: Colors.blueGrey),
          title: Text(table),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TableDataPage(tableName: table),
              ),
            );
          },
        );
      },
    );
  }
}
