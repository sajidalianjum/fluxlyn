import '../services/schema_service.dart';
import '../services/database_driver.dart';

enum SQLContext {
  none,
  afterSelect,
  afterDistinct,
  afterFrom,
  afterJoin,
  afterInsertInto,
  afterUpdate,
  afterDeleteFrom,
  afterWhere,
  afterHaving,
  afterOn,
  afterGroupBy,
  afterOrderBy,
  afterSet,
}

class SQLContextAnalyzer {
  final SchemaService _schemaService;

  SQLContextAnalyzer(this._schemaService);

  SQLContext getContext(String query, int cursorPosition) {
    final textBeforeCursor = query.substring(0, cursorPosition);
    final textBeforeCursorLower = textBeforeCursor.toLowerCase();

    final patterns = {
      SQLContext.afterFrom: RegExp(r'(?:^|\s)(from)\s+', caseSensitive: false),
      SQLContext.afterJoin: RegExp(
        r'(?:^|\s)(join|inner\s+join|left\s+join|right\s+join|full\s+join)\s+',
        caseSensitive: false,
      ),
      SQLContext.afterWhere: RegExp(
        r'(?:^|\s)(where|on)\s+',
        caseSensitive: false,
      ),
      SQLContext.afterHaving: RegExp(
        r'(?:^|\s)(having)\s+',
        caseSensitive: false,
      ),
      SQLContext.afterGroupBy: RegExp(
        r'(?:^|\s)(group\s+by)\s+',
        caseSensitive: false,
      ),
      SQLContext.afterOrderBy: RegExp(
        r'(?:^|\s)(order\s+by)\s+',
        caseSensitive: false,
      ),
      SQLContext.afterSet: RegExp(r'(?:^|\s)(set)\s+', caseSensitive: false),
      SQLContext.afterSelect: RegExp(
        r'(?:^|\s)(select|distinct)\s+',
        caseSensitive: false,
      ),
      SQLContext.afterInsertInto: RegExp(
        r'(?:^|\s)(insert\s+into)\s+',
        caseSensitive: false,
      ),
      SQLContext.afterUpdate: RegExp(
        r'(?:^|\s)(update)\s+',
        caseSensitive: false,
      ),
      SQLContext.afterDeleteFrom: RegExp(
        r'(?:^|\s)(delete\s+from)\s+',
        caseSensitive: false,
      ),
    };

    int? lastMatchPosition;
    SQLContext? lastMatchContext;

    for (final entry in patterns.entries) {
      final context = entry.key;
      final pattern = entry.value;

      for (final match in pattern.allMatches(textBeforeCursorLower)) {
        if (lastMatchPosition == null || match.start > lastMatchPosition) {
          lastMatchPosition = match.start;
          lastMatchContext = context;
        }
      }
    }

    return lastMatchContext ?? SQLContext.none;
  }

  Future<List<String>> getSuggestions(
    SQLContext context,
    String databaseName,
    String query,
    int cursorPosition, {
    DatabaseDriver? driver,
  }) async {
    switch (context) {
      case SQLContext.afterSelect:
      case SQLContext.afterDistinct:
      case SQLContext.afterWhere:
      case SQLContext.afterHaving:
      case SQLContext.afterOn:
      case SQLContext.afterGroupBy:
      case SQLContext.afterOrderBy:
        return _getColumnsWithContext(
          databaseName, query, cursorPosition, driver: driver,
        );

      case SQLContext.afterFrom:
      case SQLContext.afterJoin:
      case SQLContext.afterInsertInto:
      case SQLContext.afterUpdate:
      case SQLContext.afterDeleteFrom:
        return _getTableNames(databaseName);

      case SQLContext.afterSet:
        return _getColumnsWithContext(
          databaseName, query, cursorPosition, driver: driver,
        );

      case SQLContext.none:
        return [];
    }
  }

  List<String> _getTableNames(String databaseName) {
    return _schemaService.getTableNames(databaseName);
  }

  Future<List<String>> _getColumnsWithContext(
    String databaseName,
    String query,
    int cursorPosition, {
    DatabaseDriver? driver,
  }) async {
    final textBeforeCursor = query.substring(0, cursorPosition);
    final tableRefs = _parseTableReferences(textBeforeCursor);

    final prefixMatch = RegExp(r'(\w+)\.\w*$').firstMatch(textBeforeCursor);
    if (prefixMatch != null) {
      final prefix = prefixMatch.group(1)!;
      final resolvedTable = _resolveAlias(prefix, tableRefs);
      if (resolvedTable != null) {
        return _getColumnsForTable(
          databaseName, resolvedTable, driver: driver,
        );
      }
    }

    if (tableRefs.isNotEmpty) {
      final allColumns = <String>[];
      final seen = <String>{};
      final uniqueTables = <String>{};
      for (final tableName in tableRefs.values) {
        uniqueTables.add(tableName);
      }
      for (final tableName in uniqueTables) {
        final cols = await _getColumnsForTable(
          databaseName, tableName, driver: driver,
        );
        for (final col in cols) {
          if (seen.add(col)) {
            allColumns.add(col);
          }
        }
      }
      if (allColumns.isNotEmpty) return allColumns;
    }

    return _schemaService.getAllColumnNames(databaseName, null);
  }

  Map<String, String> _parseTableReferences(String textBeforeCursor) {
    final refs = <String, String>{};

    final tablePattern = RegExp(
      r"""\b(?:FROM|JOIN|INNER\s+JOIN|LEFT\s+JOIN|RIGHT\s+JOIN|UPDATE)\s+[`"]?(\w+)[`"]?(?:\s+AS\s+[`"]?(\w+)[`"]?)?""",
      caseSensitive: false,
    );

    for (final match in tablePattern.allMatches(textBeforeCursor)) {
      final tableName = _stripQuotes(match.group(1)!);
      if (_isSqlKeyword(tableName)) continue;

      refs[tableName] = tableName;

      final alias = match.group(2);
      if (alias != null && !_isSqlKeyword(alias)) {
        refs[_stripQuotes(alias)] = tableName;
        continue;
      }

      final afterTable = textBeforeCursor.substring(match.end).trimLeft();
      final implicitMatch = RegExp(r'^(\w+)').firstMatch(afterTable);
      if (implicitMatch != null) {
        final possibleAlias = implicitMatch.group(1)!;
        if (!_isSqlKeyword(possibleAlias)) {
          refs[possibleAlias] = tableName;
        }
      }
    }

    return refs;
  }

  String? _resolveAlias(String prefix, Map<String, String> tableRefs) {
    if (tableRefs.containsKey(prefix)) return tableRefs[prefix];
    for (final entry in tableRefs.entries) {
      if (entry.key.toLowerCase() == prefix.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  Future<List<String>> _getColumnsForTable(
    String databaseName,
    String tableName, {
    DatabaseDriver? driver,
  }) async {
    if (driver != null) {
      final tableNames = _schemaService.getTableNames(databaseName);
      final matchedTable = tableNames.firstWhere(
        (t) => t.toLowerCase() == tableName.toLowerCase(),
        orElse: () => tableName,
      );
      final cols = await _schemaService.getColumnNamesWithFallback(
        driver, databaseName, matchedTable,
      );
      if (cols.isNotEmpty) return cols;
    }
    final cols = _schemaService.getAllColumnNames(databaseName, tableName);
    if (cols.isNotEmpty) return cols;
    return _schemaService.getAllColumnNames(databaseName, null);
  }

  String _stripQuotes(String name) {
    if (name.length >= 2 &&
        ((name.startsWith('`') && name.endsWith('`')) ||
         (name.startsWith('"') && name.endsWith('"')) ||
         (name.startsWith("'") && name.endsWith("'")))) {
      return name.substring(1, name.length - 1);
    }
    return name;
  }

  static const _sqlKeywordSet = {
    'select', 'from', 'where', 'and', 'or', 'not', 'insert', 'into',
    'values', 'update', 'set', 'delete', 'create', 'table', 'alter',
    'drop', 'index', 'join', 'inner', 'left', 'right', 'full', 'outer',
    'on', 'group', 'by', 'order', 'having', 'limit', 'offset', 'union',
    'all', 'distinct', 'as', 'like', 'in', 'between', 'is', 'null',
    'true', 'false', 'asc', 'desc', 'exists', 'case', 'when', 'then',
    'else', 'end', 'if', 'while', 'for', 'foreign', 'key', 'primary',
    'references', 'default', 'auto_increment', 'unique', 'database',
    'show', 'tables', 'columns', 'describe', 'explain',
    'count', 'sum', 'avg', 'min', 'max', 'cross', 'natural',
  };

  bool _isSqlKeyword(String word) {
    return _sqlKeywordSet.contains(word.toLowerCase());
  }

  Future<List<String>> getFilteredSuggestions(
    List<String> suggestions,
    String currentWord,
  ) async {
    if (currentWord.isEmpty) {
      return suggestions;
    }

    final lowerCurrentWord = currentWord.toLowerCase();
    return suggestions
        .where((s) => s.toLowerCase().contains(lowerCurrentWord))
        .toList();
  }

  bool isColumnContext(SQLContext context) {
    return [
      SQLContext.afterSelect,
      SQLContext.afterDistinct,
      SQLContext.afterWhere,
      SQLContext.afterHaving,
      SQLContext.afterOn,
      SQLContext.afterGroupBy,
      SQLContext.afterOrderBy,
      SQLContext.afterSet,
    ].contains(context);
  }

  bool isTableContext(SQLContext context) {
    return [
      SQLContext.afterFrom,
      SQLContext.afterJoin,
      SQLContext.afterInsertInto,
      SQLContext.afterUpdate,
      SQLContext.afterDeleteFrom,
    ].contains(context);
  }
}
