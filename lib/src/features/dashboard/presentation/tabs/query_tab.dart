import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/styles/monokai-sublime.dart';
import 'package:re_highlight/styles/github.dart';
import '../../../../core/widgets/sql_autocomplete_builder.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:mysql_dart/mysql_dart.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/error_reporter.dart';
import '../../../../core/services/schema_service.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../core/services/sql_autocomplete_engine.dart';
import '../../../../core/services/query_protection_service.dart';
import '../../../../core/services/column_type_detector.dart';
import '../../../../core/services/mysql_driver.dart';
import '../../../../core/services/sql_analyzer.dart';
import '../../../../core/widgets/snackbar_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../dashboard/providers/dashboard_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../queries/models/query_model.dart';
import '../../../queries/models/query_result.dart';
import '../../../queries/presentation/pages/query_results_page.dart';
import '../../../connections/models/connection_model.dart';

class QueryTab extends StatefulWidget {
  const QueryTab({super.key});

  @override
  State<QueryTab> createState() => _QueryTabState();
}

class _QueryTabState extends State<QueryTab> {
  late CodeLineEditingController _controller;
  final _schemaService = SchemaService();
  final _aiService = AIService();
  late SqlAutocompleteEngine _autocompleteEngine;
  final _uuid = const Uuid();
  bool _isExecuting = false;
  String? _lastDatabase;
  final FocusNode _focusNode = FocusNode();
  Timer? _enrichDebounce;

  @override
  void initState() {
    super.initState();
    _autocompleteEngine = SqlAutocompleteEngine(_schemaService);
    _controller = CodeLineEditingController();
    _controller.addListener(_onTextChange);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
    _enrichDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<DashboardProvider>(context, listen: true);
    final currentDatabase = provider.selectedDatabase;

    if (_lastDatabase != currentDatabase) {
      _lastDatabase = currentDatabase;
      _reloadSchemaOnDatabaseChange();
    }

    final pendingQuery = provider.pendingQuery;
    final pendingDatabase = provider.pendingDatabase;
    if (pendingQuery != null && pendingQuery.isNotEmpty) {
      _controller.text = pendingQuery;
      provider.clearPendingQuery();

      if (pendingDatabase != null &&
          (provider.selectedDatabase == null ||
              provider.selectedDatabase != pendingDatabase)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          provider.selectDatabase(pendingDatabase);
        });
      }
    }
  }

  void _onTextChange() {
    _enrichDebounce?.cancel();
    _enrichDebounce = Timer(const Duration(milliseconds: 150), () {
      _enrichSuggestions();
    });
  }

  Future<void> _enrichSuggestions() async {
    if (!mounted) return;
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final database = provider.selectedDatabase;
    if (database == null) return;

    final query = _controller.text;
    final cursorPos = _getCursorGlobalOffset();

    await _autocompleteEngine.enrichSuggestions(
      text: query,
      cursorPosition: cursorPos,
      databaseName: database,
      driver: provider.driver,
    );
  }

  Future<void> _reloadSchemaOnDatabaseChange() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final driver = provider.driver;
    final database = provider.selectedDatabase;

    if (driver != null && database != null) {
      final tables = provider.tables;
      if (tables.isEmpty) return;

      _schemaService.clearCache(database);
      _schemaService.clearTableNamesCache(database);
      _schemaService.setTableNames(database, tables);

      _autocompleteEngine.onDatabaseChanged(database, tables, driver);

      await _schemaService.preloadColumns(driver, database, tables);

      _enrichSuggestions();
    }
  }

  Future<void> _preloadSchema() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final driver = provider.driver;
    final database = provider.selectedDatabase;

    if (driver != null && database != null) {
      final tables = provider.tables;
      _schemaService.setTableNames(database, tables);

      _autocompleteEngine.onDatabaseChanged(database, tables, driver);

      await _schemaService.preloadColumns(driver, database, tables);

      _enrichSuggestions();
    }
  }

  Future<void> _executeQuery() async {
    if (_isExecuting) return;

    final provider = Provider.of<DashboardProvider>(context, listen: false);

    if (provider.selectedDatabase == null) {
      SnackbarHelper.showWarning(context, 'Please select a database first');
      return;
    }

    final query = _controller.text.trim();
    if (query.isEmpty) {
      SnackbarHelper.showWarning(context, 'Please enter a query');
      return;
    }

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

      final queries = query
          .split(';')
          .map((q) => q.trim())
          .where((q) => q.isNotEmpty)
          .toList();

      final settingsProvider = context.read<SettingsProvider>();
      final settings = settingsProvider.settings;

      for (final singleQuery in queries) {
        final protectionError = QueryProtectionService.checkQuery(
          singleQuery,
          settings.readOnlyMode,
          settings.lock,
        );
        if (protectionError != null) {
          setState(() => _isExecuting = false);
          if (mounted) {
            SnackbarHelper.showWarning(context, protectionError);
          }
          return;
        }
      }

      final results = <QueryResult>[];

      for (final singleQuery in queries) {
        final stopwatch = Stopwatch()..start();

        try {
          final result = await provider.executeQuery(singleQuery);
          stopwatch.stop();

          if (result == null) {
            throw Exception('Failed to execute query');
          }

          List<String> columns;
          List<Map<String, dynamic>> rawRows;
          int? affectedRows;

          if (provider.currentConnectionModel!.type == ConnectionType.mysql) {
            final mysqlResult = result as IResultSet;
            columns = mysqlResult.rows.isNotEmpty
                ? mysqlResult.rows.first.assoc().keys.toList()
                : <String>[];

            rawRows = mysqlResult.rows.map((row) {
              final rowMap = <String, dynamic>{};
              for (final col in columns) {
                rowMap[col] = row.colByName(col);
              }
              return rowMap;
            }).toList();

            if (rawRows.isEmpty) {
              affectedRows = mysqlResult.affectedRows.toInt();
            }
          } else {
            final pgResult = result as dynamic;
            columns = pgResult.rows.isNotEmpty
                ? pgResult.rows.first.keys.toList()
                : <String>[];
            rawRows = pgResult.rows;

            if (rawRows.isEmpty && pgResult.affectedRowCount != null) {
              affectedRows = pgResult.affectedRowCount;
            }
          }

          final queryType = SqlAnalyzer.getQueryType(singleQuery);

          final driver = provider.driver;
          final database = provider.selectedDatabase;
          final connectionModel = provider.currentConnectionModel;

          MySQLConnection? mysqlConnection;
          if (connectionModel?.type == ConnectionType.mysql &&
              driver is MySQLDriver) {
            mysqlConnection = driver.connection;
          }

          final columnTypes = await ColumnTypeDetector.detectTypes(
            query: singleQuery,
            resultColumns: columns,
            connection: mysqlConnection,
            databaseName: database,
            sampleRows: rawRows.isNotEmpty ? rawRows : null,
          );

          final binaryColumns = <String>[];
          final bitColumns = <String>[];
          final enumColumns = <String, List<String>>{};
          final setColumns = <String, List<String>>{};

          for (final entry in columnTypes.entries) {
            final info = entry.value;
            if (info.isBinary) {
              binaryColumns.add(entry.key);
            } else if (info.isBit) {
              bitColumns.add(entry.key);
            } else if (info.isEnum) {
              enumColumns[entry.key] = info.enumValues;
            } else if (info.isSet) {
              setColumns[entry.key] = info.setValues;
            }
          }

          final rows = rawRows.map((rowMap) {
            final formattedRow = <String, dynamic>{};
            for (final col in columns) {
              final value = rowMap[col];
              final info = columnTypes[col];
              formattedRow[col] = ColumnTypeDetector.formatValue(value, info);
            }
            return formattedRow;
          }).toList();

          String? primaryKeyColumn;
          String? tableName;
          final tableNames = SqlAnalyzer.extractTableNames(singleQuery);
          if (tableNames.length == 1 && driver != null) {
            tableName = tableNames.first;
            try {
              final pk = await driver.getPrimaryKeyColumn(tableNames.first);
              if (pk != null && columns.contains(pk)) {
                primaryKeyColumn = pk;
              }
            } catch (e, stackTrace) {
              ErrorReporter.warning(
                'Error detecting primary key: $e',
                stackTrace,
                'QueryTab._executeQuery',
                'query_tab.dart:460',
              );
            }
          }

          results.add(
            QueryResult(
              query: singleQuery,
              columns: columns,
              rows: rows,
              executionTimeMs: stopwatch.elapsedMilliseconds,
              success: true,
              binaryColumns: binaryColumns,
              bitColumns: bitColumns,
              enumColumns: enumColumns,
              setColumns: setColumns,
              primaryKeyColumn: primaryKeyColumn,
              tableName: tableName,
              affectedRows: affectedRows,
              queryType: queryType,
            ),
          );

          await storageService.addToHistory(
            QueryHistoryEntry(
              id: _uuid.v4(),
              query: singleQuery,
              executedAt: DateTime.now(),
              executionTimeMs: stopwatch.elapsedMilliseconds,
              rowCount: affectedRows ?? rows.length,
              success: true,
              connectionId: connectionModel!.id,
              databaseName: provider.selectedDatabase,
            ),
          );
        } catch (e) {
          stopwatch.stop();
          final queryType = SqlAnalyzer.getQueryType(singleQuery);

          results.add(
            QueryResult(
              query: singleQuery,
              columns: [],
              rows: [],
              executionTimeMs: stopwatch.elapsedMilliseconds,
              success: false,
              errorMessage: e.toString(),
              affectedRows: null,
              queryType: queryType,
            ),
          );

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

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => QueryResultsPage(results: results)),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
      }
    }
  }

  void _saveQuery() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      SnackbarHelper.showWarning(context, 'Cannot save empty query');
      return;
    }

    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final connectionModel = provider.currentConnectionModel;

    if (connectionModel == null) {
      SnackbarHelper.showInfo(context, 'No connection selected');
      return;
    }

    final titleController = TextEditingController();
    final storageService = Provider.of<StorageService>(context, listen: false);

    if (!mounted) return;

    final theme = Theme.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: const Text('Save Query'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter query title',
            border: OutlineInputBorder(),
          ),
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
        SnackbarHelper.showSuccess(context, 'Query saved successfully');
      }
    }
  }

  void _loadQuery() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final storageService = Provider.of<StorageService>(context, listen: false);
    final connectionModel = provider.currentConnectionModel;
    final theme = Theme.of(context);

    if (connectionModel == null) {
      SnackbarHelper.showInfo(context, 'No connection selected');
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
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
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
                        color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest,
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
                                  color: isDark ? Colors.grey[500] : Colors.grey.shade600,
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
                                SnackbarHelper.showInfo(
                                  this.context,
                                  'Query deleted',
                                );
                              }
                            },
                          ),
                          onTap: () async {
                            Navigator.of(context).pop();
                            setState(() {
                              _controller.text = query.query;
                            });

                            if (provider.selectedDatabase == null &&
                                query.databaseName != null) {
                              await provider.selectDatabase(
                                query.databaseName!,
                              );
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
        backgroundColor: Theme.of(context).colorScheme.surface,
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
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
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
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final database = provider.selectedDatabase;
    final driver = provider.driver;

    if (database == null || driver == null) {
      SnackbarHelper.showWarning(context, 'Please select a database first');
      return;
    }

    if (settingsProvider.apiKey.isEmpty) {
      SnackbarHelper.showWarning(
        context,
        'Please set your AI API key in Settings',
      );
      return;
    }

    final promptController = TextEditingController();
    bool isGenerating = false;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: const Text('AI Query Assistant'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Describe what you want to query in natural language:',
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: promptController,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Show all users who signed up last week',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !isGenerating,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : Colors.blue.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: isDark ? Colors.blue : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your database schema (table/column names) will be sent to the AI API to generate SQL queries. No actual data will be transmitted.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isGenerating) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    'Generating SQL...',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isGenerating
                    ? null
                    : () => Navigator.of(context).pop(),
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
                          final tables = provider.tables;
                          final schemaBuffer = StringBuffer();

                          for (final table in tables) {
                            final columns = await _schemaService.getColumns(
                              driver,
                              database,
                              table,
                            );
                            schemaBuffer.writeln('Table: $table');
                            schemaBuffer.writeln(
                              'Columns: ${columns.map((c) => "${c.name} (${c.type})").join(", ")}',
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
                            SnackbarHelper.showError(context, e.toString());
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

  void _showDisconnectDialog(BuildContext context, DashboardProvider provider) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: const Text('Disconnect Database'),
        content: const Text(
          'Are you sure you want to disconnect the database?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await provider.disconnect();
              } catch (_) {}
              if (mounted) {
                Navigator.of(this.context).pop();
              }
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  int _getCursorGlobalOffset() {
    final sel = _controller.selection;
    int offset = 0;
    final lines = _controller.codeLines;
    for (int i = 0; i < sel.baseIndex && i < lines.length; i++) {
      offset += lines[i].text.length + 1;
    }
    offset += sel.baseOffset;
    return offset;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 1200;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => _showDisconnectDialog(context, provider),
        ),
        title: const Text('SQL Editor'),
        actions: [
          IconButton(
            onPressed: _clearEditor,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Editor',
          ),
          IconButton(
            onPressed: _isExecuting ? null : _executeQuery,
            icon: _isExecuting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow, size: 28),
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
        child: isWideScreen
            ? Row(
                children: [
                  Expanded(flex: 3, child: _buildEditorPanel(provider)),
                  Container(width: 1, color: theme.dividerColor),
                  Expanded(flex: 2, child: _buildResultsPanel(provider)),
                ],
              )
            : _buildEditorPanel(provider),
      ),
    );
  }

  Widget _buildEditorPanel(DashboardProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Consumer<DashboardProvider>(
                builder: (context, provider, _) {
                  return _buildToolbarButton(
                    icon: Icons.storage,
                    label: provider.selectedDatabase ?? 'Select DB',
                    onPressed: () => _showDatabaseSelector(provider),
                  );
                },
              ),
              _buildToolbarButton(
                icon: Icons.auto_awesome,
                label: 'AI Query',
                onPressed: _showAIQueryDialog,
                isAccent: true,
              ),
              _buildToolbarButton(
                icon: Icons.save,
                label: 'Save',
                onPressed: _saveQuery,
              ),
              _buildToolbarButton(
                icon: Icons.folder_open,
                label: 'Load',
                onPressed: _loadQuery,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppConstants.colorCardBackgroundDark
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? AppConstants.colorBorderDarkStrong
                    : AppConstants.colorBorderLight,
                width: 1,
              ),
              boxShadow: AppTheme.getShadows(1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: () {
                  _focusNode.requestFocus();
                },
                child: CodeAutocomplete(
                  promptsBuilder: SqlAutocompletePromptsBuilder(
                    controller: _controller,
                    engine: _autocompleteEngine,
                  ),
                  viewBuilder: (context, notifier, onSelected) {
                    return SqlAutocompleteListView(
                      notifier: notifier,
                      onSelected: onSelected,
                      engine: _autocompleteEngine,
                    );
                  },
                  child: CodeEditor(
                    controller: _controller,
                    focusNode: _focusNode,
                    padding: const EdgeInsets.all(16),
                    style: CodeEditorStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      cursorColor: theme.colorScheme.primary,
                      codeTheme: CodeHighlightTheme(
                        languages: {
                          'sql': CodeHighlightThemeMode(mode: langSql),
                        },
                        theme: isDark ? monokaiSublimeTheme : githubTheme,
                      ),
                    ),
                    wordWrap: true,
                    indicatorBuilder: null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isAccent = false,
  }) {
    if (isAccent) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }

    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildResultsPanel(DashboardProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: isDark ? AppConstants.colorBackgroundDark : theme.colorScheme.surface,
      padding: const EdgeInsets.only(left: 16, top: 12, right: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppConstants.colorSurfaceElevatedDark
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? AppConstants.colorBorderDarkStrong
                    : AppConstants.colorBorderLight,
                width: 1,
              ),
              boxShadow: AppTheme.getShadows(1),
            ),
            child: Row(
              children: [
                Icon(Icons.assessment, size: 20, color: isDark ? Colors.grey[400] : Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Results Preview',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppConstants.colorCardBackgroundDark
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? AppConstants.colorBorderDarkStrong
                      : AppConstants.colorBorderLight,
                  width: 1,
                ),
                boxShadow: AppTheme.getShadows(1),
              ),
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      size: 64,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Run a query to see results',
                      style: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Results will appear here on wide screens',
                      style: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
