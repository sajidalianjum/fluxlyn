import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/sql.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/schema_service.dart';
import '../../../../core/services/sql_context_analyzer.dart';
import '../../../../core/services/sql_formatter.dart';
import '../../../../core/widgets/snackbar_helper.dart';
import '../../../../core/services/query_protection_service.dart';
import '../../providers/dashboard_provider.dart';
import '../../../settings/providers/settings_provider.dart';

typedef OnExecuteQuery =
    Future<List<Map<String, dynamic>>?> Function(String query);
typedef OnShowDatabaseSelector = Future<void> Function();
typedef OnShowAIQueryDialog = Future<void> Function();
typedef OnFormatSQL = VoidCallback;

class QueryEditorWidget extends StatefulWidget {
  final String? initialQuery;
  final bool showDatabaseSelector;
  final bool showAIQuery;
  final bool showSaveQuery;
  final bool showLoadQuery;
  final bool showHistory;
  final OnExecuteQuery onExecuteQuery;
  final OnShowDatabaseSelector? onShowDatabaseSelector;
  final OnShowAIQueryDialog? onShowAIQueryDialog;
  final OnFormatSQL? onFormatSQL;
  final VoidCallback? onSaveQuery;
  final VoidCallback? onLoadQuery;
  final VoidCallback? onShowHistory;
  final VoidCallback? onClear;

  const QueryEditorWidget({
    super.key,
    this.initialQuery,
    this.showDatabaseSelector = true,
    this.showAIQuery = true,
    this.showSaveQuery = true,
    this.showLoadQuery = true,
    this.showHistory = true,
    required this.onExecuteQuery,
    this.onShowDatabaseSelector,
    this.onShowAIQueryDialog,
    this.onFormatSQL,
    this.onSaveQuery,
    this.onLoadQuery,
    this.onShowHistory,
    this.onClear,
  });

  @override
  State<QueryEditorWidget> createState() => _QueryEditorWidgetState();
}

class _QueryEditorWidgetState extends State<QueryEditorWidget> {
  late CodeController _controller;
  final _schemaService = SchemaService();
  late SQLContextAnalyzer _sqlContextAnalyzer;
  bool _isExecuting = false;
  List<String> _autocompleteWords = [];
  String? _lastDatabase;
  final FocusNode _focusNode = FocusNode();
  Timer? _autocompleteDebounce;
  SQLContext _lastContext = SQLContext.none;

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

    _controller = CodeController(
      language: sql,
      text: widget.initialQuery ?? '',
    );

    _setupAutocomplete();
    _controller.addListener(_onTextChange);

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

    if (_lastDatabase != currentDatabase) {
      _lastDatabase = currentDatabase;
      _reloadSchemaOnDatabaseChange();
    }
  }

  void _setupAutocomplete() {
    _autocompleteWords = List.from(_sqlKeywords);
    _controller.autocompleter.setCustomWords(_autocompleteWords);
  }

  void _onTextChange() {
    _autocompleteDebounce?.cancel();

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

    final textBeforeCursor = query.substring(0, cursorPosition);
    final wordMatch = RegExp(r'\w+$').firstMatch(textBeforeCursor);
    final currentWord = wordMatch?.group(0) ?? '';

    final sqlContext = _sqlContextAnalyzer.getContext(query, cursorPosition);

    if (sqlContext == _lastContext && currentWord.isEmpty) return;

    _lastContext = sqlContext;

    if (sqlContext == SQLContext.none) {
      setState(() {
        _autocompleteWords = List.from(_sqlKeywords);
        _controller.autocompleter.setCustomWords(_autocompleteWords);
      });
    } else {
      final suggestions = await _sqlContextAnalyzer.getSuggestions(
        sqlContext,
        database,
        query,
        cursorPosition,
      );

      final filteredSuggestions = await _sqlContextAnalyzer
          .getFilteredSuggestions(suggestions, currentWord);

      final allSuggestions = [..._sqlKeywords, ...filteredSuggestions];

      setState(() {
        _autocompleteWords = allSuggestions;
        _controller.autocompleter.setCustomWords(_autocompleteWords);
      });
    }
  }

  Future<void> _reloadSchemaOnDatabaseChange() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final driver = provider.driver;
    final database = provider.selectedDatabase;

    if (driver != null && database != null) {
      _schemaService.clearCache(database);
      _schemaService.clearTableNamesCache(database);

      final tables = provider.tables;
      if (tables.isEmpty) {
        return;
      }

      _schemaService.setTableNames(database, tables);

      _autocompleteWords = List.from(_sqlKeywords);
      _controller.autocompleter.setCustomWords(_autocompleteWords);

      await _schemaService.preloadColumns(driver, database, tables);

      _lastContext = SQLContext.none;
      _updateContextAwareAutocomplete();
    }
  }

  Future<void> _preloadSchema() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final driver = provider.driver;
    final database = provider.selectedDatabase;

    if (driver != null && database != null) {
      final tables = provider.tables;
      _schemaService.setTableNames(database, tables);

      await _schemaService.preloadColumns(driver, database, tables);

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

    _controller.dismiss();
    _focusNode.unfocus();

    setState(() => _isExecuting = true);

    // Check query protection settings
    final settingsProvider = context.read<SettingsProvider>();
    final settings = settingsProvider.settings;
    final queries = query
        .split(';')
        .map((q) => q.trim())
        .where((q) => q.isNotEmpty)
        .toList();

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

    try {
      final stopwatch = Stopwatch()..start();
      final result = await widget.onExecuteQuery(query);
      stopwatch.stop();

      if (result == null) {
        throw Exception('Failed to execute query');
      }

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
      }
    }
  }

  void _clearEditor() {
    if (widget.onClear != null) {
      widget.onClear!();
    } else {
      setState(() {
        _controller.text = '';
      });
    }
  }

  void _formatSQL() {
    if (widget.onFormatSQL != null) {
      widget.onFormatSQL!();
    } else {
      final sql = _controller.text;
      if (sql.isEmpty) return;

      final formatted = SQLFormatter.format(sql);
      setState(() {
        _controller.text = formatted;
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
          if (widget.showHistory)
            IconButton(
              onPressed: widget.onShowHistory,
              icon: const Icon(Icons.history),
              tooltip: 'Query History',
            ),
          IconButton(
            onPressed: _clearEditor,
            icon: const Icon(Icons.clear_all),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF0F172A),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (widget.showDatabaseSelector)
                      Consumer<DashboardProvider>(
                        builder: (context, provider, _) {
                          return OutlinedButton.icon(
                            onPressed: widget.onShowDatabaseSelector,
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
                    if (widget.showDatabaseSelector) const SizedBox(width: 8),
                    if (widget.showAIQuery)
                      OutlinedButton.icon(
                        onPressed: widget.onShowAIQueryDialog,
                        icon: const Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: Colors.blue,
                        ),
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
                    if (widget.showAIQuery) const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _formatSQL,
                      icon: const Icon(
                        Icons.format_align_left,
                        size: 18,
                        color: Colors.green,
                      ),
                      label: const Text('Format'),
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
                    if (widget.showSaveQuery)
                      OutlinedButton.icon(
                        onPressed: widget.onSaveQuery,
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
                    if (widget.showSaveQuery) const SizedBox(width: 8),
                    if (widget.showLoadQuery)
                      OutlinedButton.icon(
                        onPressed: widget.onLoadQuery,
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
}
