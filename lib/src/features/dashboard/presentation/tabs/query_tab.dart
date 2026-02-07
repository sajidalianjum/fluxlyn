import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/sql.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/schema_service.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/services/sql_context_analyzer.dart';
import '../../../dashboard/providers/dashboard_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../queries/models/query_model.dart';
import '../../../queries/presentation/pages/query_results_page.dart';

class QueryTab extends StatefulWidget {
  const QueryTab({super.key});

  @override
  State<QueryTab> createState() => _QueryTabState();
}

class _QueryTabState extends State<QueryTab> {
  late CodeController _controller;
  final _schemaService = SchemaService();
  final _aiService = AIService();
  late SQLContextAnalyzer _sqlContextAnalyzer;
  final _uuid = const Uuid();
  bool _isExecuting = false;
  List<String> _autocompleteWords = [];
  String? _lastDatabase;
  final FocusNode _focusNode = FocusNode();
  Timer? _autocompleteDebounce;
  SQLContext _lastContext = SQLContext.none;

  // SQL Keywords for autocomplete
  final List<String> _sqlKeywords = [
    'SELECT',
    'FROM',
    'WHERE',
    'AND',
    'OR',
    'NOT',
    'INSERT',
    'INTO',
    'VALUES',
    'UPDATE',
    'SET',
    'DELETE',
    'CREATE',
    'TABLE',
    'ALTER',
    'DROP',
    'INDEX',
    'JOIN',
    'INNER',
    'LEFT',
    'RIGHT',
    'FULL',
    'OUTER',
    'ON',
    'GROUP',
    'BY',
    'ORDER',
    'HAVING',
    'LIMIT',
    'OFFSET',
    'UNION',
    'ALL',
    'DISTINCT',
    'COUNT',
    'SUM',
    'AVG',
    'MIN',
    'MAX',
    'AS',
    'LIKE',
    'IN',
    'BETWEEN',
    'IS',
    'NULL',
    'TRUE',
    'FALSE',
    'ASC',
    'DESC',
    'EXISTS',
    'CASE',
    'WHEN',
    'THEN',
    'ELSE',
    'END',
    'IF',
    'WHILE',
    'FOR',
    'FOREIGN',
    'KEY',
    'PRIMARY',
    'REFERENCES',
    'DEFAULT',
    'AUTO_INCREMENT',
    'UNIQUE',
    'DATABASE',
    'SHOW',
    'TABLES',
    'COLUMNS',
    'DESCRIBE',
    'EXPLAIN',
  ];

  @override
  void initState() {
    super.initState();
    _sqlContextAnalyzer = SQLContextAnalyzer(_schemaService);

    _controller = CodeController(language: sql, text: '');

    // Setup autocomplete
    _setupAutocomplete();

    // Add listener for context-aware autocomplete
    _controller.addListener(_onTextChange);

    // Preload schema info after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      if (provider.tables.isNotEmpty) {
        _preloadSchema();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.removeListener(_onTextChange);
    _autocompleteDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<DashboardProvider>(context, listen: true);
    final currentDatabase = provider.selectedDatabase;

    // Reload schema when database changes
    if (_lastDatabase != currentDatabase) {
      _lastDatabase = currentDatabase;
      _reloadSchemaOnDatabaseChange();
    }
  }

  void _setupAutocomplete() {
    // Start with SQL keywords
    _autocompleteWords = List.from(_sqlKeywords);
    _controller.autocompleter.setCustomWords(_autocompleteWords);
  }

  void _onTextChange() {
    // Cancel any pending autocomplete update
    _autocompleteDebounce?.cancel();

    // Debounce the update to avoid excessive calculations
    _autocompleteDebounce = Timer(const Duration(milliseconds: 200), () {
      _updateContextAwareAutocomplete();
    });
  }

  Future<void> _updateContextAwareAutocomplete() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final database = provider.selectedDatabase;

    if (database == null || !mounted) return;

    final query = _controller.text;
    final cursorPosition = _controller.selection.baseOffset;

    // Get current word being typed
    final textBeforeCursor = query.substring(0, cursorPosition);
    final wordMatch = RegExp(r'\w+$').firstMatch(textBeforeCursor);
    final currentWord = wordMatch?.group(0) ?? '';

    // Get current SQL context
    final sqlContext = _sqlContextAnalyzer.getContext(query, cursorPosition);

    // Only update if context changed significantly
    if (sqlContext == _lastContext && currentWord.isEmpty) return;

    _lastContext = sqlContext;

    // Get appropriate suggestions based on context
    if (sqlContext == SQLContext.none) {
      // Show only SQL keywords
      setState(() {
        _autocompleteWords = List.from(_sqlKeywords);
        _controller.autocompleter.setCustomWords(_autocompleteWords);
      });
    } else {
      // Show context-aware suggestions
      final suggestions = await _sqlContextAnalyzer.getSuggestions(
        sqlContext,
        database,
        query,
        cursorPosition,
      );

      // Filter suggestions based on current word (case-insensitive)
      final filteredSuggestions = await _sqlContextAnalyzer
          .getFilteredSuggestions(suggestions, currentWord);

      // Combine with SQL keywords for better UX
      final allSuggestions = [..._sqlKeywords, ...filteredSuggestions];

      setState(() {
        _autocompleteWords = allSuggestions;
        _controller.autocompleter.setCustomWords(_autocompleteWords);
      });
    }
  }

  Future<void> _reloadSchemaOnDatabaseChange() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final connection = provider.currentConnection;
    final database = provider.selectedDatabase;

    if (connection != null && database != null) {
      // Clear cache for previous database and load new one
      _schemaService.clearCache(database);
      _schemaService.clearTableNamesCache(database);

      // Wait for tables to be loaded, then cache them
      final tables = provider.tables;
      if (tables.isEmpty) {
        // Tables not loaded yet, they'll be cached when loaded via didChangeDependencies
        return;
      }

      // Cache table names in SchemaService
      _schemaService.setTableNames(database, tables);

      // Reset autocomplete to only SQL keywords
      _autocompleteWords = List.from(_sqlKeywords);
      _controller.autocompleter.setCustomWords(_autocompleteWords);

      // Preload columns for all tables in background
      await _schemaService.preloadColumns(connection, database, tables);

      // Trigger context-aware autocomplete update
      _lastContext = SQLContext.none;
      _updateContextAwareAutocomplete();
    }
  }

  Future<void> _preloadSchema() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final connection = provider.currentConnection;
    final database = provider.selectedDatabase;

    if (connection != null && database != null) {
      // Cache table names in SchemaService
      final tables = provider.tables;
      _schemaService.setTableNames(database, tables);

      // Preload columns for all tables in background
      await _schemaService.preloadColumns(connection, database, tables);

      // Trigger initial autocomplete update
      _lastContext = SQLContext.none;
      _updateContextAwareAutocomplete();
    }
  }

  Future<void> _executeQuery() async {
    if (_isExecuting) return;

    final query = _controller.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a query')));
      return;
    }

    // Dismiss autocomplete dropdown
    _controller.dismiss();
    _focusNode.unfocus();

    setState(() => _isExecuting = true);

    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      final storageService = Provider.of<StorageService>(
        context,
        listen: false,
      );
      final connectionModel = provider.currentConnectionModel;

      if (connectionModel == null) {
        throw Exception('Not connected to database');
      }

      // Split multiple queries by semicolon
      final queries = query
          .split(';')
          .map((q) => q.trim())
          .where((q) => q.isNotEmpty)
          .toList();

      final results = <QueryResult>[];

      for (final singleQuery in queries) {
        final stopwatch = Stopwatch()..start();

        try {
          final result = await provider.executeQuery(singleQuery);
          stopwatch.stop();

          if (result == null) {
            throw Exception('Failed to execute query');
          }

          // Parse results with safe binary handling
          final columns = result.rows.isNotEmpty
              ? result.rows.first.assoc().keys.toList()
              : <String>[];

          final rows = result.rows.map((row) {
            final rowMap = <String, dynamic>{};
            for (final col in columns) {
              try {
                final value = row.colByName(col);
                // Handle potential binary data
                if (value != null) {
                  // Try to convert to string safely
                  rowMap[col] = value.toString();
                } else {
                  rowMap[col] = null;
                }
              } catch (e) {
                // If conversion fails, show as binary
                rowMap[col] = '<binary>';
              }
            }
            return rowMap;
          }).toList();

          results.add(
            QueryResult(
              query: singleQuery,
              columns: columns,
              rows: rows,
              executionTimeMs: stopwatch.elapsedMilliseconds,
              success: true,
            ),
          );

          // Add to history
          await storageService.addToHistory(
            QueryHistoryEntry(
              id: _uuid.v4(),
              query: singleQuery,
              executedAt: DateTime.now(),
              executionTimeMs: stopwatch.elapsedMilliseconds,
              rowCount: rows.length,
              success: true,
              connectionId: connectionModel.id,
              databaseName: provider.selectedDatabase,
            ),
          );
        } catch (e) {
          stopwatch.stop();

          results.add(
            QueryResult(
              query: singleQuery,
              columns: [],
              rows: [],
              executionTimeMs: stopwatch.elapsedMilliseconds,
              success: false,
              errorMessage: e.toString(),
            ),
          );

          // Add failed query to history
          await storageService.addToHistory(
            QueryHistoryEntry(
              id: _uuid.v4(),
              query: singleQuery,
              executedAt: DateTime.now(),
              executionTimeMs: stopwatch.elapsedMilliseconds,
              rowCount: 0,
              success: false,
              errorMessage: e.toString(),
              connectionId: connectionModel.id,
              databaseName: provider.selectedDatabase,
            ),
          );
        }
      }

      // Navigate to results page
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => QueryResultsPage(results: results)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
      }
    }
  }

  void _saveQuery() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot save empty query')));
      return;
    }

    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final connectionModel = provider.currentConnectionModel;

    if (connectionModel == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No connection selected')));
      return;
    }

    final titleController = TextEditingController();
    final storageService = Provider.of<StorageService>(context, listen: false);

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Save Query'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter query title',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              Navigator.of(context).pop(title);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final now = DateTime.now();
      final queryModel = QueryModel(
        id: _uuid.v4(),
        name: result,
        query: query,
        createdAt: now,
        modifiedAt: now,
        connectionId: connectionModel.id,
        databaseName: provider.selectedDatabase,
      );

      await storageService.saveQuery(queryModel);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Query saved successfully')),
        );
      }
    }
  }

  void _loadQuery() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final storageService = Provider.of<StorageService>(context, listen: false);
    final connectionModel = provider.currentConnectionModel;

    if (connectionModel == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No connection selected')));
      return;
    }

    final queries = storageService.getSavedQueries(connectionModel.id);

    if (queries.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No saved queries')));
      return;
    }

    final searchController = TextEditingController();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved Queries',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search queries...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => setModalState(() {}),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: queries.length,
                    itemBuilder: (context, index) {
                      final query = queries[index];
                      final matchesSearch =
                          searchController.text.isEmpty ||
                          query.name.toLowerCase().contains(
                            searchController.text.toLowerCase(),
                          );

                      if (!matchesSearch) return const SizedBox.shrink();

                      return Card(
                        color: const Color(0xFF0F172A),
                        child: ListTile(
                          title: Text(
                            query.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                query.query.length > 60
                                    ? '${query.query.substring(0, 60)}...'
                                    : query.query,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(query.modifiedAt),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await storageService.deleteQuery(query.id);
                              setModalState(() {});
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Query deleted'),
                                  ),
                                );
                              }
                            },
                          ),
                          onTap: () async {
                            Navigator.of(context).pop();
                            setState(() {
                              _controller.text = query.query;
                            });

                            // If no database is selected, load the database from the query
                            if (provider.selectedDatabase == null &&
                                query.databaseName != null) {
                              await provider.selectDatabase(query.databaseName!);
                            }
                          },
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
    );
  }

  void _showDatabaseSelector(DashboardProvider provider) async {
    final databases = provider.databases;

    if (databases.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No databases available')));
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Select DB'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: databases.length,
            itemBuilder: (context, index) {
              final db = databases[index];
              return ListTile(
                title: Text(db),
                trailing: db == provider.selectedDatabase
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => Navigator.of(context).pop(db),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected != null) {
      await provider.selectDatabase(selected);
    }
  }

  void _clearEditor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Clear Editor?'),
        content: const Text(
          'Are you sure you want to clear the current query?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _controller.text = '';
              });
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showAIQueryDialog() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final database = provider.selectedDatabase;
    final connection = provider.currentConnection;

    if (database == null || connection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a database first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (settingsProvider.apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set your AI API key in Settings'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final promptController = TextEditingController();
    bool isGenerating = false;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('AI Query Assistant'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Describe what you want to query in natural language:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: promptController,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Show all users who signed up last week',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                  enabled: !isGenerating,
                ),
                if (isGenerating) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Generating SQL...', style: TextStyle(fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isGenerating ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isGenerating
                    ? null
                    : () async {
                        final prompt = promptController.text.trim();
                        if (prompt.isEmpty) return;

                        setDialogState(() => isGenerating = true);

                        try {
                          // Gather schema
                          final tables = provider.tables;
                          final schemaBuffer = StringBuffer();

                          for (final table in tables) {
                            final columns = await _schemaService.getColumns(
                              connection,
                              database,
                              table,
                            );
                            schemaBuffer.writeln('Table: $table');
                            schemaBuffer.writeln(
                              'Columns: ${columns.map((c) => "${c.name} (${c.dataType})").join(", ")}',
                            );
                            schemaBuffer.writeln();
                          }

                          final sql = await _aiService.generateSQL(
                            prompt: prompt,
                            schema: schemaBuffer.toString(),
                            settings: settingsProvider.settings,
                          );

                          if (context.mounted) {
                            Navigator.of(context).pop(sql);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isGenerating = false);
                          }
                        }
                      },
                child: const Text('Generate'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _controller.text = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('SQL Editor'),
        actions: [
          // History button
          IconButton(
            onPressed: _showHistory,
            icon: const Icon(Icons.history),
            tooltip: 'Query History',
          ),
          // Clear button
          IconButton(
            onPressed: _clearEditor,
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear Editor',
          ),
          // Run button
          IconButton(
            onPressed: _isExecuting ? null : _executeQuery,
            icon: _isExecuting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            tooltip: 'Run Query (Ctrl+Enter)',
          ),
        ],
      ),
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              _executeQuery,
          const SingleActivator(LogicalKeyboardKey.enter, meta: true):
              _executeQuery,
        },
        child: Column(
          children: [
            // Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF0F172A),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Consumer<DashboardProvider>(
                      builder: (context, provider, _) {
                        return OutlinedButton.icon(
                          onPressed: () => _showDatabaseSelector(provider),
                          icon: const Icon(Icons.storage, size: 18),
                          label: Text(
                            provider.selectedDatabase ?? 'Select DB',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF334155)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _showAIQueryDialog,
                      icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.blue),
                      label: const Text('AI Query'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF334155)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _saveQuery,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save Query'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF334155)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _loadQuery,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Load Query'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF334155)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Editor
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _focusNode.requestFocus();
                },
                child: CodeTheme(
                  data: CodeThemeData(styles: monokaiSublimeTheme),
                  child: CodeField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                    gutterStyle: const GutterStyle(
                      textStyle: TextStyle(color: Colors.grey),
                      width: 48,
                      margin: 0,
                    ),
                    cursorColor: Colors.blue,
                    background: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),

            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  Icon(Icons.keyboard, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Ctrl+Enter to run',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    '${_controller.text.length} chars',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isExecuting ? null : _executeQuery,
        icon: _isExecuting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_arrow),
        label: Text(_isExecuting ? 'Running...' : 'Run Query'),
      ),
    );
  }

  void _showHistory() async {
    final storageService = Provider.of<StorageService>(context, listen: false);
    final provider = Provider.of<DashboardProvider>(context, listen: false);

    if (provider.currentConnectionModel == null) return;

    final history = storageService.getQueryHistory(
      provider.currentConnectionModel!.id,
    );

    if (history.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No query history')));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Query History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () async {
                    await storageService.clearHistory(
                      provider.currentConnectionModel!.id,
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: history.length > 20 ? 20 : history.length,
                itemBuilder: (context, index) {
                  final entry = history[index];
                  return ListTile(
                    leading: Icon(
                      entry.success ? Icons.check_circle : Icons.error,
                      color: entry.success ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      entry.query.length > 50
                          ? '${entry.query.substring(0, 50)}...'
                          : entry.query,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    subtitle: Text(
                      '${entry.executionTimeMs}ms • ${entry.rowCount} rows • ${_formatDate(entry.executedAt)}',
                    ),
                    onTap: () async {
                      Navigator.of(context).pop();
                      setState(() {
                        _controller.text = entry.query;
                      });

                      // If no database is selected, load the database from the history entry
                      if (provider.selectedDatabase == null &&
                          entry.databaseName != null) {
                        await provider.selectDatabase(entry.databaseName!);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
