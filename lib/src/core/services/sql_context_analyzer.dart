import '../services/schema_service.dart';

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

    // Define patterns to find the last (most recent) matching keyword
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

    // Find the last (most recent) matching keyword
    int? lastMatchPosition;
    SQLContext? lastMatchContext;

    for (final entry in patterns.entries) {
      final context = entry.key;
      final pattern = entry.value;

      // Find all matches and get the last one
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
    int cursorPosition,
  ) async {
    switch (context) {
      case SQLContext.afterSelect:
      case SQLContext.afterDistinct:
      case SQLContext.afterWhere:
      case SQLContext.afterHaving:
      case SQLContext.afterOn:
      case SQLContext.afterGroupBy:
      case SQLContext.afterOrderBy:
        return _getColumnsWithContext(databaseName, query, cursorPosition);

      case SQLContext.afterFrom:
      case SQLContext.afterJoin:
      case SQLContext.afterInsertInto:
      case SQLContext.afterUpdate:
      case SQLContext.afterDeleteFrom:
        return _getTableNames(databaseName);

      case SQLContext.afterSet:
        return _getColumnsWithContext(databaseName, query, cursorPosition);

      case SQLContext.none:
        return [];
    }
  }

  List<String> _getTableNames(String databaseName) {
    return _schemaService.getTableNames(databaseName);
  }

  List<String> _getColumnsWithContext(
    String databaseName,
    String query,
    int cursorPosition,
  ) {
    // Try to find table name before cursor
    final textBeforeCursor = query.substring(0, cursorPosition);
    final tableMatch = RegExp(
      r'\b(FROM|JOIN|INNER\s+JOIN|LEFT\s+JOIN|RIGHT\s+JOIN|UPDATE)\s+(\w+)',
      caseSensitive: false,
    ).firstMatch(textBeforeCursor);

    if (tableMatch != null && tableMatch.groupCount >= 2) {
      final tableName = tableMatch.group(2);
      if (tableName != null) {
        // Try to match table name case-insensitively
        final tableNames = _schemaService.getTableNames(databaseName);
        final matchedTable = tableNames.firstWhere(
          (t) => t.toLowerCase() == tableName.toLowerCase(),
          orElse: () => tableName,
        );
        return _schemaService.getAllColumnNames(databaseName, matchedTable);
      }
    }

    // If no specific table found, return all columns
    return _schemaService.getAllColumnNames(databaseName, null);
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
        .where((s) => s.toLowerCase().startsWith(lowerCurrentWord))
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
