import '../services/schema_service.dart';
import '../services/database_driver.dart';

enum CompletionKind { keyword, table, column, function_, snippet }

class CompletionItem {
  final String word;
  final CompletionKind kind;
  final String? detail;
  final String? description;
  final int sortOrder;

  const CompletionItem({
    required this.word,
    this.kind = CompletionKind.keyword,
    this.detail,
    this.description,
    this.sortOrder = 100,
  });
}

enum SqlClause {
  none,
  select,
  from,
  join,
  on,
  where_,
  groupBy,
  having,
  orderBy,
  limit,
  set_,
  into,
  values_,
  insert,
  update,
  delete_,
  create,
  alterTable,
  drop,
}

class CompletionContext {
  final SqlClause clause;
  final String? dotPrefix;
  final int parenthesisDepth;

  const CompletionContext({
    this.clause = SqlClause.none,
    this.dotPrefix,
    this.parenthesisDepth = 0,
  });

  bool get inSubquery => parenthesisDepth > 0;
  bool get afterDot => dotPrefix != null;
}

class SqlAutocompleteEngine {
  final SchemaService _schemaService;

  String? _currentDatabase;
  List<CompletionItem> _lastSuggestions = [];
  Map<String, String> _tableAliases = {};

  SqlAutocompleteEngine(this._schemaService);

  List<CompletionItem> get lastSuggestions => _lastSuggestions;
  String? get currentDatabase => _currentDatabase;

  static const _allFunctions = [
    'COUNT', 'SUM', 'AVG', 'MIN', 'MAX',
    'COALESCE', 'IFNULL', 'NULLIF', 'CAST', 'CONVERT',
    'CONCAT', 'GROUP_CONCAT', 'SUBSTRING', 'SUBSTR', 'TRIM',
    'UPPER', 'LOWER', 'REPLACE', 'LENGTH', 'CHAR_LENGTH',
    'NOW', 'CURDATE', 'CURTIME', 'SYSDATE',
    'DATE', 'TIME', 'YEAR', 'MONTH', 'DAY', 'HOUR', 'MINUTE', 'SECOND',
    'DATE_FORMAT', 'DATEDIFF', 'DATE_ADD', 'DATE_SUB', 'TIMESTAMPDIFF',
    'ABS', 'ROUND', 'FLOOR', 'CEIL', 'CEILING', 'POWER', 'SQRT', 'MOD',
    'IF', 'CASE', 'WHEN', 'THEN', 'ELSE',
    'JSON_EXTRACT', 'JSON_UNQUOTE', 'JSON_ARRAY', 'JSON_OBJECT',
  ];

  static final Map<SqlClause, List<CompletionItem>> _contextKeywords = {
    SqlClause.none: [
      CompletionItem(word: 'SELECT', kind: CompletionKind.keyword, sortOrder: 100, description: 'Retrieve data'),
      CompletionItem(word: 'INSERT', kind: CompletionKind.keyword, sortOrder: 101, description: 'Add rows'),
      CompletionItem(word: 'UPDATE', kind: CompletionKind.keyword, sortOrder: 102, description: 'Modify rows'),
      CompletionItem(word: 'DELETE', kind: CompletionKind.keyword, sortOrder: 103, description: 'Remove rows'),
      CompletionItem(word: 'CREATE', kind: CompletionKind.keyword, sortOrder: 104, description: 'Create objects'),
      CompletionItem(word: 'ALTER', kind: CompletionKind.keyword, sortOrder: 105, description: 'Modify objects'),
      CompletionItem(word: 'DROP', kind: CompletionKind.keyword, sortOrder: 106, description: 'Remove objects'),
      CompletionItem(word: 'EXPLAIN', kind: CompletionKind.keyword, sortOrder: 107, description: 'Show execution plan'),
      CompletionItem(word: 'WITH', kind: CompletionKind.keyword, sortOrder: 108, description: 'Common Table Expression'),
      CompletionItem(word: 'SHOW', kind: CompletionKind.keyword, sortOrder: 109, description: 'Show info'),
      CompletionItem(word: 'DESCRIBE', kind: CompletionKind.keyword, sortOrder: 110, description: 'Show table structure'),
      CompletionItem(word: 'TRUNCATE', kind: CompletionKind.keyword, sortOrder: 111, description: 'Empty table'),
    ],
    SqlClause.select: [
      CompletionItem(word: 'FROM', kind: CompletionKind.keyword, sortOrder: 100, description: 'Specify table'),
      CompletionItem(word: 'DISTINCT', kind: CompletionKind.keyword, sortOrder: 101, description: 'Unique rows'),
      CompletionItem(word: 'ALL', kind: CompletionKind.keyword, sortOrder: 102, description: 'All rows'),
      CompletionItem(word: 'AS', kind: CompletionKind.keyword, sortOrder: 103, description: 'Alias'),
    ],
    SqlClause.from: [
      CompletionItem(word: 'WHERE', kind: CompletionKind.keyword, sortOrder: 100, description: 'Filter rows'),
      CompletionItem(word: 'JOIN', kind: CompletionKind.keyword, sortOrder: 101, description: 'Join tables'),
      CompletionItem(word: 'INNER JOIN', kind: CompletionKind.keyword, sortOrder: 102, description: 'Inner join'),
      CompletionItem(word: 'LEFT JOIN', kind: CompletionKind.keyword, sortOrder: 103, description: 'Left outer join'),
      CompletionItem(word: 'RIGHT JOIN', kind: CompletionKind.keyword, sortOrder: 104, description: 'Right outer join'),
      CompletionItem(word: 'CROSS JOIN', kind: CompletionKind.keyword, sortOrder: 105, description: 'Cross join'),
      CompletionItem(word: 'ON', kind: CompletionKind.keyword, sortOrder: 106, description: 'Join condition'),
      CompletionItem(word: 'AS', kind: CompletionKind.keyword, sortOrder: 107, description: 'Alias'),
      CompletionItem(word: 'GROUP BY', kind: CompletionKind.keyword, sortOrder: 108, description: 'Group rows'),
      CompletionItem(word: 'ORDER BY', kind: CompletionKind.keyword, sortOrder: 109, description: 'Sort rows'),
      CompletionItem(word: 'LIMIT', kind: CompletionKind.keyword, sortOrder: 110, description: 'Limit rows'),
      CompletionItem(word: 'HAVING', kind: CompletionKind.keyword, sortOrder: 111, description: 'Filter groups'),
      CompletionItem(word: 'OFFSET', kind: CompletionKind.keyword, sortOrder: 112, description: 'Skip rows'),
    ],
    SqlClause.join: [
      CompletionItem(word: 'ON', kind: CompletionKind.keyword, sortOrder: 100, description: 'Join condition'),
    ],
    SqlClause.on: [
      CompletionItem(word: 'AND', kind: CompletionKind.keyword, sortOrder: 100),
      CompletionItem(word: 'OR', kind: CompletionKind.keyword, sortOrder: 101),
      CompletionItem(word: 'NOT', kind: CompletionKind.keyword, sortOrder: 102),
    ],
    SqlClause.where_: [
      CompletionItem(word: 'AND', kind: CompletionKind.keyword, sortOrder: 100),
      CompletionItem(word: 'OR', kind: CompletionKind.keyword, sortOrder: 101),
      CompletionItem(word: 'NOT', kind: CompletionKind.keyword, sortOrder: 102),
      CompletionItem(word: 'IN', kind: CompletionKind.keyword, sortOrder: 103, description: 'Check membership'),
      CompletionItem(word: 'BETWEEN', kind: CompletionKind.keyword, sortOrder: 104, description: 'Range check'),
      CompletionItem(word: 'LIKE', kind: CompletionKind.keyword, sortOrder: 105, description: 'Pattern match'),
      CompletionItem(word: 'IS', kind: CompletionKind.keyword, sortOrder: 106),
      CompletionItem(word: 'NULL', kind: CompletionKind.keyword, sortOrder: 107),
      CompletionItem(word: 'EXISTS', kind: CompletionKind.keyword, sortOrder: 108),
      CompletionItem(word: 'TRUE', kind: CompletionKind.keyword, sortOrder: 109),
      CompletionItem(word: 'FALSE', kind: CompletionKind.keyword, sortOrder: 110),
      CompletionItem(word: 'ORDER BY', kind: CompletionKind.keyword, sortOrder: 111),
      CompletionItem(word: 'GROUP BY', kind: CompletionKind.keyword, sortOrder: 112),
      CompletionItem(word: 'LIMIT', kind: CompletionKind.keyword, sortOrder: 113),
    ],
    SqlClause.groupBy: [
      CompletionItem(word: 'HAVING', kind: CompletionKind.keyword, sortOrder: 100),
      CompletionItem(word: 'ORDER BY', kind: CompletionKind.keyword, sortOrder: 101),
      CompletionItem(word: 'LIMIT', kind: CompletionKind.keyword, sortOrder: 102),
    ],
    SqlClause.having: [
      CompletionItem(word: 'AND', kind: CompletionKind.keyword, sortOrder: 100),
      CompletionItem(word: 'OR', kind: CompletionKind.keyword, sortOrder: 101),
      CompletionItem(word: 'ORDER BY', kind: CompletionKind.keyword, sortOrder: 102),
      CompletionItem(word: 'LIMIT', kind: CompletionKind.keyword, sortOrder: 103),
    ],
    SqlClause.orderBy: [
      CompletionItem(word: 'ASC', kind: CompletionKind.keyword, sortOrder: 100, description: 'Ascending'),
      CompletionItem(word: 'DESC', kind: CompletionKind.keyword, sortOrder: 101, description: 'Descending'),
      CompletionItem(word: 'LIMIT', kind: CompletionKind.keyword, sortOrder: 102),
      CompletionItem(word: 'OFFSET', kind: CompletionKind.keyword, sortOrder: 103),
    ],
    SqlClause.limit: [
      CompletionItem(word: 'OFFSET', kind: CompletionKind.keyword, sortOrder: 100),
    ],
    SqlClause.set_: [],
    SqlClause.into: [],
    SqlClause.values_: [],
  };

  void onDatabaseChanged(String? databaseName, List<String> tables, DatabaseDriver? driver) {
    _currentDatabase = databaseName;
    _tableAliases = {};
  }

  CompletionContext getContext(String text, int cursorPosition) {
    final before = cursorPosition < text.length
        ? text.substring(0, cursorPosition)
        : text;
    if (before.trim().isEmpty) {
      return const CompletionContext(clause: SqlClause.none);
    }

    int depth = 0;
    for (int i = 0; i < before.length; i++) {
      if (before[i] == '(' && !_isInStringLiteral(before, i)) depth++;
      if (before[i] == ')' && !_isInStringLiteral(before, i)) depth--;
    }
    final parenDepth = depth < 0 ? 0 : depth;

    final dotPrefix = _extractDotPrefix(before);

    final normalized = _normalize(before);
    final words = normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    SqlClause clause = SqlClause.none;

    for (int i = words.length - 1; i >= 0; i--) {
      final word = words[i];
      SqlClause found = SqlClause.none;

      if (word == 'JOIN' && i > 0) {
        final prev = words[i - 1].toUpperCase();
        if (['INNER', 'LEFT', 'RIGHT', 'FULL', 'CROSS', 'NATURAL'].contains(prev)) {
          found = SqlClause.join;
        } else {
          found = SqlClause.join;
        }
      } else if (word == 'BY' && i > 0) {
        final prev = words[i - 1].toUpperCase();
        if (prev == 'GROUP') {
          found = SqlClause.groupBy;
        } else if (prev == 'ORDER') {
          found = SqlClause.orderBy;
        }
      } else if (word == 'TABLE' && i > 0 && words[i - 1].toUpperCase() == 'ALTER') {
        found = SqlClause.alterTable;
      } else {
        found = _matchClauseByWord(word);
      }

      if (found != SqlClause.none) {
        clause = found;
        break;
      }
    }

    if ((clause == SqlClause.from || clause == SqlClause.join ||
         clause == SqlClause.into || clause == SqlClause.update) &&
        _currentDatabase != null) {
      _parseTableAliases(before);
    }

    return CompletionContext(
      clause: clause,
      dotPrefix: dotPrefix,
      parenthesisDepth: parenDepth,
    );
  }

  SqlClause _matchClauseByWord(String word) {
    final upper = word.toUpperCase().replaceAll(RegExp(r'[(),;]'), '');
    switch (upper) {
      case 'SELECT': return SqlClause.select;
      case 'FROM': return SqlClause.from;
      case 'WHERE': return SqlClause.where_;
      case 'HAVING': return SqlClause.having;
      case 'LIMIT': return SqlClause.limit;
      case 'SET': return SqlClause.set_;
      case 'INTO': return SqlClause.into;
      case 'VALUES':
      case 'VALUE': return SqlClause.values_;
      case 'ON': return SqlClause.on;
      case 'INSERT': return SqlClause.insert;
      case 'UPDATE': return SqlClause.update;
      case 'DELETE': return SqlClause.delete_;
      case 'CREATE': return SqlClause.create;
      case 'ALTER': return SqlClause.alterTable;
      case 'DROP': return SqlClause.drop;
      default: return SqlClause.none;
    }
  }

  String? _extractDotPrefix(String textBeforeCursor) {
    final match = RegExp(r"""([a-zA-Z_][a-zA-Z0-9_]*)\.\w*$""").firstMatch(textBeforeCursor);
    if (match != null) return match.group(1);
    final backtickMatch = RegExp(r"""`([^`]+)`\.\w*$""").firstMatch(textBeforeCursor);
    if (backtickMatch != null) return backtickMatch.group(1);
    return null;
  }

  void _parseTableAliases(String textBeforeCursor) {
    _tableAliases = {};
    final pattern = RegExp(
      r"""(?:FROM|JOIN|INNER\s+JOIN|LEFT\s+JOIN|RIGHT\s+JOIN|FULL\s+JOIN|CROSS\s+JOIN|NATURAL\s+JOIN|,)\s+[`"]?([a-zA-Z_][a-zA-Z0-9_]*)[`"]?(?:\s+(?:AS\s+)?[`"]?([a-zA-Z_][a-zA-Z0-9_]*)[`"]?)?""",
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(textBeforeCursor)) {
      final tableName = match.group(1);
      final alias = match.group(2);
      if (tableName != null && !_isSqlKeyword(tableName)) {
        _tableAliases[tableName.toLowerCase()] = tableName;
        if (alias != null && !_isSqlKeyword(alias)) {
          _tableAliases[alias.toLowerCase()] = tableName;
        }
      }
    }
  }

  List<String> _parseTableNamesFromQuery(String text) {
    final names = <String>{};
    final pattern = RegExp(
      r"""(?:FROM|JOIN|INNER\s+JOIN|LEFT\s+JOIN|RIGHT\s+JOIN|FULL\s+JOIN|CROSS\s+JOIN|NATURAL\s+JOIN|,)\s+[`"]?([a-zA-Z_][a-zA-Z0-9_]*)[`"]?""",
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(text)) {
      final name = match.group(1);
      if (name != null && !_isSqlKeyword(name)) {
        names.add(name);
      }
    }
    return names.toList();
  }

  List<CompletionItem> getSyncSuggestions({
    required String text,
    required int cursorPosition,
    required String? databaseName,
  }) {
    final clampedOffset = cursorPosition.clamp(0, text.length);
    final textBeforeCursor = text.substring(0, clampedOffset);

    final dotMatch = RegExp(r"""([a-zA-Z_][a-zA-Z0-9_]*)\.([a-zA-Z0-9_]*)$""").firstMatch(textBeforeCursor);
    if (dotMatch != null) {
      final partial = dotMatch.group(2) ?? '';
      return _getDotCompletionSuggestions(dotMatch.group(1)!, partial, databaseName);
    }

    final wordMatch = RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*$').firstMatch(textBeforeCursor);
    final currentWord = wordMatch?.group(0) ?? '';

    final context = getContext(text, cursorPosition);

    final suggestions = <CompletionItem>[];

    if (_isTableContext(context.clause)) {
      suggestions.addAll(_getTableSuggestions(databaseName));
    }

    if (_isColumnContext(context.clause)) {
      final tableRefs = _parseTableNamesFromQuery(textBeforeCursor);
      suggestions.addAll(_getColumnSuggestions(databaseName, tableRefs));
      suggestions.addAll(_getFunctionSuggestions());
    }

    suggestions.addAll(_getContextKeywords(context.clause));

    if (!_isTableContext(context.clause) && !_isColumnContext(context.clause)) {
      suggestions.addAll(_getFunctionSuggestions());
    }

    return _filterAndRank(suggestions, currentWord);
  }

  bool _isColumnContext(SqlClause clause) {
    return [
      SqlClause.select, SqlClause.where_, SqlClause.having,
      SqlClause.on, SqlClause.groupBy, SqlClause.orderBy, SqlClause.set_,
    ].contains(clause);
  }

  bool _isTableContext(SqlClause clause) {
    return [
      SqlClause.from, SqlClause.join, SqlClause.into, SqlClause.update,
    ].contains(clause);
  }

  List<CompletionItem> _getDotCompletionSuggestions(
    String prefix,
    String partial,
    String? databaseName,
  ) {
    if (databaseName == null) return [];

    String resolvedTable = _tableAliases[prefix.toLowerCase()] ?? prefix;
    final tableNames = _schemaService.getTableNames(databaseName);

    final exactMatch = tableNames.where((t) => t.toLowerCase() == resolvedTable.toLowerCase()).firstOrNull;
    if (exactMatch != null) {
      resolvedTable = exactMatch;
    } else {
      final fuzzy = tableNames.where((t) => t.toLowerCase().contains(resolvedTable.toLowerCase())).firstOrNull;
      if (fuzzy != null) resolvedTable = fuzzy;
    }

    final columns = _schemaService.getCachedColumns(databaseName, resolvedTable);
    if (columns.isEmpty) {
      final colNames = _schemaService.getAllColumnNames(databaseName, resolvedTable);
      return colNames
          .where((c) => c.toLowerCase().startsWith(partial.toLowerCase()))
          .map((c) => CompletionItem(word: c, kind: CompletionKind.column, detail: resolvedTable, sortOrder: 0))
          .toList();
    }

    return columns
        .where((c) => c.name.toLowerCase().startsWith(partial.toLowerCase()))
        .map((c) => CompletionItem(word: c.name, kind: CompletionKind.column, detail: c.type, sortOrder: 0))
        .toList();
  }

  List<CompletionItem> _getTableSuggestions(String? databaseName) {
    if (databaseName == null) return [];
    return _schemaService
        .getTableNames(databaseName)
        .map((t) => CompletionItem(word: t, kind: CompletionKind.table, sortOrder: 10))
        .toList();
  }

  List<CompletionItem> _getColumnSuggestions(String? databaseName, List<String> tableRefs) {
    if (databaseName == null) return [];

    final seen = <String>{};
    final items = <CompletionItem>[];

    if (tableRefs.isNotEmpty) {
      for (final ref in tableRefs) {
        String? tableName = _tableAliases[ref.toLowerCase()];
        if (tableName == null) {
          final tables = _schemaService.getTableNames(databaseName);
          tableName = tables.where((t) => t.toLowerCase() == ref.toLowerCase()).firstOrNull;
        }
        if (tableName == null) continue;

        final columns = _schemaService.getCachedColumns(databaseName, tableName);
        for (final col in columns) {
          if (seen.add(col.name.toLowerCase())) {
            final detail = tableRefs.length > 1 ? tableName : col.type;
            items.add(CompletionItem(word: col.name, kind: CompletionKind.column, detail: detail, sortOrder: 5));
          }
        }
      }
    }

    if (items.isEmpty) {
      final allColumns = _schemaService.getCachedColumns(databaseName, null);
      final tableColumns = _schemaService.getAllColumnNames(databaseName, null);
      for (final col in tableColumns) {
        if (seen.add(col.toLowerCase())) {
          items.add(CompletionItem(word: col, kind: CompletionKind.column, sortOrder: 15));
        }
      }
      for (final col in allColumns) {
        if (seen.add(col.name.toLowerCase())) {
          items.add(CompletionItem(word: col.name, kind: CompletionKind.column, detail: col.type, sortOrder: 15));
        }
      }
    }

    return items;
  }

  List<CompletionItem> _getFunctionSuggestions() {
    return _allFunctions
        .map((f) => CompletionItem(word: f, kind: CompletionKind.function_, sortOrder: 50))
        .toList();
  }

  List<CompletionItem> _getContextKeywords(SqlClause clause) {
    return List.from(_contextKeywords[clause] ?? _contextKeywords[SqlClause.none]!);
  }

  List<CompletionItem> _filterAndRank(List<CompletionItem> items, String currentWord) {
    if (currentWord.isEmpty) {
      items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return items;
    }

    final lowerWord = currentWord.toLowerCase();

    final exact = <CompletionItem>[];
    final startsWith = <CompletionItem>[];
    final contains = <CompletionItem>[];

    for (final item in items) {
      final lower = item.word.toLowerCase();
      if (lower == lowerWord) {
        exact.add(item);
      } else if (lower.startsWith(lowerWord)) {
        startsWith.add(item);
      } else if (lower.contains(lowerWord)) {
        contains.add(item);
      }
    }

    startsWith.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    contains.sort((a, b) => b.sortOrder.compareTo(a.sortOrder));

    return [...exact, ...startsWith, ...contains];
  }

  Future<List<CompletionItem>> enrichSuggestions({
    required String text,
    required int cursorPosition,
    required String? databaseName,
    DatabaseDriver? driver,
  }) async {
    if (databaseName == null || driver == null) return _lastSuggestions;

    final targetText = cursorPosition < text.length
        ? text.substring(0, cursorPosition)
        : text;

    final tableRefs = _parseTableNamesFromQuery(targetText);

    for (final ref in tableRefs) {
      final tables = _schemaService.getTableNames(databaseName);
      final matched = tables.where((t) => t.toLowerCase() == ref.toLowerCase()).firstOrNull;
      if (matched != null && !_schemaService.isLoaded(databaseName, matched)) {
        await _schemaService.getColumns(driver, databaseName, matched);
      }
    }

    return getSyncSuggestions(
      text: text,
      cursorPosition: cursorPosition,
      databaseName: databaseName,
    );
  }

  List<String> getMatchingWords({
    required String text,
    required int cursorPosition,
    String? databaseName,
  }) {
    databaseName ??= _currentDatabase;
    final clampedOffset = cursorPosition.clamp(0, text.length);
    final textBeforeCursor = text.substring(0, clampedOffset);

    final wordMatch = RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*$').firstMatch(textBeforeCursor);
    final currentWord = wordMatch?.group(0) ?? '';

    var suggestions = getSyncSuggestions(
      text: text,
      cursorPosition: cursorPosition,
      databaseName: databaseName,
    );

    if (currentWord.isNotEmpty && suggestions.isEmpty) {
      final fallback = <CompletionItem>[];
      final seen = <String>{};
      for (final entry in _contextKeywords.entries) {
        for (final item in entry.value) {
          if (seen.add(item.word) && item.word.toLowerCase().startsWith(currentWord.toLowerCase())) {
            fallback.add(item);
          }
        }
      }
      if (fallback.isNotEmpty) suggestions = fallback;
    }

    if (currentWord.isEmpty && suggestions.isEmpty) {
      suggestions = _getContextKeywords(SqlClause.none);
    }

    _lastSuggestions = suggestions;

    return suggestions.map((s) => s.word).toList();
  }

  String _normalize(String sql) {
    var result = sql;
    result = result.replaceAll(RegExp(r'--[^\n]*'), ' ');
    result = result.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ');
    result = result.replaceAll(RegExp(r"'[^']*'"), "''");
    result = result.replaceAll(RegExp(r'"[^"]*"'), '""');
    return result;
  }

  bool _isInStringLiteral(String text, int index) {
    int singleQuotes = 0;
    int doubleQuotes = 0;
    for (int i = 0; i < index && i < text.length; i++) {
      if (text[i] == "'") {
        if (i > 0 && text[i - 1] == '\\') continue;
        singleQuotes++;
      } else if (text[i] == '"') {
        if (i > 0 && text[i - 1] == '\\') continue;
        doubleQuotes++;
      }
    }
    return singleQuotes % 2 == 1 || doubleQuotes % 2 == 1;
  }

  static const _keywordSet = {
    'select', 'from', 'where', 'and', 'or', 'not', 'in', 'between',
    'like', 'is', 'null', 'join', 'inner', 'left', 'right', 'outer',
    'on', 'group', 'by', 'having', 'order', 'limit', 'offset', 'union',
    'all', 'distinct', 'as', 'asc', 'desc', 'exists', 'case', 'when',
    'then', 'else', 'end', 'insert', 'into', 'values', 'update', 'set',
    'delete', 'create', 'table', 'alter', 'drop', 'index', 'true', 'false',
    'primary', 'key', 'foreign', 'references', 'default', 'unique',
    'cross', 'natural', 'full', 'if', 'while', 'for', 'show', 'tables',
    'columns', 'describe', 'explain', 'truncate', 'with',
    'count', 'sum', 'avg', 'min', 'max', 'cast', 'coalesce', 'concat',
  };

  bool _isSqlKeyword(String word) {
    return _keywordSet.contains(word.toLowerCase());
  }
}
