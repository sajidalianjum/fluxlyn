import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/widgets/sql_highlighter.dart';
import '../../../connections/models/connection_model.dart';
import '../../../dashboard/providers/dashboard_provider.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../queries/models/query_model.dart';

class QueriesTab extends StatefulWidget {
  final String searchQuery;

  const QueriesTab({super.key, this.searchQuery = ''});

  @override
  State<QueriesTab> createState() => _QueriesTabState();
}

class _QueriesTabState extends State<QueriesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storageService = context.watch<StorageService>();

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Saved'),
            Tab(text: 'Recent'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSavedQueriesTab(
                storageService,
                searchQuery: widget.searchQuery,
              ),
              _buildRecentQueriesTab(
                storageService,
                searchQuery: widget.searchQuery,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentQueriesTab(
    StorageService storageService, {
    String searchQuery = '',
  }) {
    final history = storageService.getAllQueryHistory();
    final connections = storageService.getAllConnections();
    final connectionMap = {for (var c in connections) c.id: c};

    final filteredHistory = _searchAndSort(
      items: history,
      getQueryText: (entry) => entry.query,
      getDatabaseName: (entry) => entry.databaseName,
      searchQuery: searchQuery,
    );

    if (filteredHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searchQuery.isEmpty ? Icons.history : Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isEmpty
                  ? 'No recent queries'
                  : 'No queries match "$searchQuery"',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredHistory.length,
      itemBuilder: (context, index) {
        final entry = filteredHistory[index];
        final connection = connectionMap[entry.connectionId];

        return _RecentQueryCard(
          entry: entry,
          connection: connection,
          onTap: () =>
              _onQueryTap(context, entry.query, connection, entry.databaseName),
        );
      },
    );
  }

  Widget _buildSavedQueriesTab(
    StorageService storageService, {
    String searchQuery = '',
  }) {
    final queries = storageService.getAllSavedQueries();
    final connections = storageService.getAllConnections();
    final connectionMap = {for (var c in connections) c.id: c};

    final filteredQueries = _searchAndSort(
      items: queries,
      getQueryText: (query) => query.query,
      getQueryName: (query) => query.name,
      getDatabaseName: (query) => query.databaseName,
      searchQuery: searchQuery,
    );

    if (filteredQueries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searchQuery.isEmpty ? Icons.bookmark_border : Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isEmpty
                  ? 'No saved queries'
                  : 'No queries match "$searchQuery"',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredQueries.length,
      itemBuilder: (context, index) {
        final query = filteredQueries[index];
        final connection = connectionMap[query.connectionId];

        return _SavedQueryCard(
          query: query,
          connection: connection,
          onTap: () =>
              _onQueryTap(context, query.query, connection, query.databaseName),
        );
      },
    );
  }

  List<T> _searchAndSort<T>({
    required List<T> items,
    required String Function(T) getQueryText,
    String? Function(T)? getQueryName,
    required String? Function(T) getDatabaseName,
    required String searchQuery,
  }) {
    if (searchQuery.isEmpty) return items;

    final query = searchQuery.toLowerCase();

    // Separate into priority buckets
    final queryTextMatches = <T>[];
    final queryNameMatches = <T>[];
    final databaseNameMatches = <T>[];

    for (var item in items) {
      final qText = getQueryText(item).toLowerCase();
      final qNameGetter = getQueryName;
      final rawName = qNameGetter != null ? qNameGetter(item) : null;
      final qName = rawName?.toLowerCase();
      final dbName = getDatabaseName(item)?.toLowerCase();

      if (qText.contains(query)) {
        queryTextMatches.add(item);
      } else if (qName != null && qName.contains(query)) {
        queryNameMatches.add(item);
      } else if (dbName != null && dbName.contains(query)) {
        databaseNameMatches.add(item);
      }
    }

    // Return query text matches first, then name matches, then database name matches
    return [...queryTextMatches, ...queryNameMatches, ...databaseNameMatches];
  }

  void _onQueryTap(
    BuildContext context,
    String query,
    ConnectionModel? connection,
    String? databaseName,
  ) async {
    if (connection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No connection available for this query')),
      );
      return;
    }

    final dashboardProvider = context.read<DashboardProvider>();
    dashboardProvider.setPendingQuery(query);

    final connectionToUse = databaseName != null && databaseName.isNotEmpty
        ? ConnectionModel(
            id: connection.id,
            name: connection.name,
            host: connection.host,
            port: connection.port,
            username: connection.username,
            password: connection.password,
            type: connection.type,
            sslEnabled: connection.sslEnabled,
            useSsh: connection.useSsh,
            sshHost: connection.sshHost,
            sshPort: connection.sshPort,
            sshUsername: connection.sshUsername,
            sshPassword: connection.sshPassword,
            sshPrivateKey: connection.sshPrivateKey,
            sshKeyPassword: connection.sshKeyPassword,
            databaseName: databaseName,
          )
        : connection;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Consumer<DashboardProvider>(
        builder: (context, provider, _) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _getConnectionMessage(provider.connectionStep),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          );
        },
      ),
    );

    await dashboardProvider.connect(connectionToUse);

    if (context.mounted) {
      Navigator.of(context).pop();

      if (dashboardProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${dashboardProvider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        dashboardProvider.setTabIndex(1);
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const DashboardPage()));
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
}

class _RecentQueryCard extends StatelessWidget {
  final QueryHistoryEntry entry;
  final ConnectionModel? connection;
  final VoidCallback? onTap;

  const _RecentQueryCard({
    required this.entry,
    required this.connection,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final queryText = entry.query;
    final executedAt = entry.executedAt;
    final success = entry.success;
    final databaseName = entry.databaseName;

    final relativeTime = _formatRelativeTime(executedAt);
    final dbType = connection?.type.name.toUpperCase() ?? 'UNKNOWN';

    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    success ? Icons.check_circle : Icons.error,
                    color: success ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    relativeTime,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const Spacer(),
                  if (connection != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dbType,
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (connection != null) ...[
                    Icon(Icons.storage, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        connection!.name,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (databaseName != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '>',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          databaseName,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
              const SizedBox(height: 10),
              SqlHighlighter(
                sql: queryText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                fontSize: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return days == 1 ? '1 day ago' : '$days days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class _SavedQueryCard extends StatelessWidget {
  final QueryModel query;
  final ConnectionModel? connection;
  final VoidCallback? onTap;

  const _SavedQueryCard({
    required this.query,
    required this.connection,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final queryName = query.name;
    final queryText = query.query;
    final modifiedAt = query.modifiedAt;
    final databaseName = query.databaseName;

    final dbType = connection?.type.name.toUpperCase() ?? 'UNKNOWN';

    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bookmark, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      queryName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatDate(modifiedAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  if (connection != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        dbType,
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (connection != null)
                Row(
                  children: [
                    Icon(Icons.storage, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        connection!.name,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (databaseName != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '>',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          databaseName,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              if (connection == null && databaseName != null)
                Row(
                  children: [
                    Text(
                      databaseName,
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              SqlHighlighter(
                sql: queryText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                fontSize: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
