class SqlAnalyzer {
  /// Extract table names from a SELECT query
  /// Returns list of table names that might appear in query
  static List<String> extractTableNames(String sql) {
    final normalizedSql = _normalizeSql(sql);

    if (!normalizedSql.startsWith('select')) {
      return [];
    }

    final fromIndex = normalizedSql.indexOf('from');
    if (fromIndex == -1) {
      return [];
    }

    var afterFrom = normalizedSql.substring(fromIndex + 4);

    final joinIndex = afterFrom.indexOf('join');
    final whereIndex = afterFrom.indexOf('where');
    final groupByIndex = afterFrom.indexOf('group by');
    final havingIndex = afterFrom.indexOf('having');
    final orderByIndex = afterFrom.indexOf('order by');
    final limitIndex = afterFrom.indexOf('limit');

    final endIndices = <int>[];
    if (joinIndex != -1) endIndices.add(joinIndex);
    if (whereIndex != -1) endIndices.add(whereIndex);
    if (groupByIndex != -1) endIndices.add(groupByIndex);
    if (havingIndex != -1) endIndices.add(havingIndex);
    if (orderByIndex != -1) endIndices.add(orderByIndex);
    if (limitIndex != -1) endIndices.add(limitIndex);

    final firstEnd = endIndices.isEmpty
        ? afterFrom.length
        : endIndices.reduce((a, b) => a < b ? a : b);

    var fromClause = afterFrom.substring(0, firstEnd).trim();

    final tableNames = <String>{};
    tableNames.addAll(_parseTableReferences(fromClause));

    if (joinIndex != -1) {
      var remainingSql = afterFrom.substring(joinIndex);
      final joinMatches = RegExp(
        r'join\s+([^\s(,]+)',
        caseSensitive: false,
      ).allMatches(remainingSql);
      for (final match in joinMatches) {
        tableNames.add(match.group(1) ?? '');
      }
    }

    final result = tableNames.where((name) => name.isNotEmpty).toList();
    return result;
  }

  /// Parse table references from a FROM clause
  static List<String> _parseTableReferences(String fromClause) {
    final tables = <String>{};

    final subqueryMatches = RegExp(
      r'\(select.*?\)',
      dotAll: true,
      caseSensitive: false,
    ).allMatches(fromClause);
    for (final match in subqueryMatches) {
      fromClause = fromClause.replaceRange(match.start, match.end, '');
    }

    final tableMatches = RegExp(
      r'([a-zA-Z_][a-zA-Z0-9_]*)',
      caseSensitive: false,
    ).allMatches(fromClause);
    for (final match in tableMatches) {
      final tableName = match.group(1);
      if (tableName != null && !_isSqlKeyword(tableName)) {
        tables.add(tableName);
      }
    }

    return tables.toList();
  }

  /// Extract column names from SELECT clause
  static List<String> extractColumnNames(String sql) {
    final normalizedSql = _normalizeSql(sql);

    if (!normalizedSql.startsWith('select')) {
      return [];
    }

    final fromIndex = normalizedSql.indexOf('from');
    if (fromIndex == -1) return [];

    var selectClause = normalizedSql.substring(6, fromIndex).trim();

    if (selectClause == '*') {
      return [];
    }

    var selectClauseProcessed = selectClause;

    final subqueryMatches = RegExp(
      r'\(select.*?\)',
      dotAll: true,
      caseSensitive: false,
    ).allMatches(selectClauseProcessed);
    for (final match in subqueryMatches) {
      final replacement = ' ' * (match.end - match.start);
      final start = selectClauseProcessed.substring(0, match.start);
      final end = selectClauseProcessed.substring(match.end);
      selectClauseProcessed = start + replacement + end;
    }

    final functionMatches = RegExp(
      r'\b[a-z_]+\(',
      caseSensitive: false,
    ).allMatches(selectClauseProcessed);
    final functionPositions = <int>[];
    for (final match in functionMatches) {
      functionPositions.add(match.start);
    }

    final parts = selectClauseProcessed.split(',');

    final columnNames = <String>[];

    for (final part in parts) {
      final trimmedPart = part.trim();

      final asIndex = trimmedPart.toLowerCase().indexOf(' as ');
      if (asIndex != -1) {
        final alias = trimmedPart.substring(asIndex + 4).trim();
        if (alias.isNotEmpty) {
          columnNames.add(alias);
          continue;
        }
      }

      final lastSpaceIndex = trimmedPart.lastIndexOf(' ');
      if (lastSpaceIndex > 0) {
        final potentialAlias = trimmedPart.substring(lastSpaceIndex + 1).trim();
        if (!_isSqlKeyword(potentialAlias)) {
          columnNames.add(potentialAlias);
          continue;
        }
      }

      final columnRef = _extractColumnReference(trimmedPart);
      if (columnRef != null && columnRef.isNotEmpty) {
        final refParts = columnRef.split('.');
        final columnName = refParts.last;
        if (!_isSqlKeyword(columnName)) {
          columnNames.add(columnName);
        }
      }
    }

    return columnNames.where((name) => name.isNotEmpty).toList();
  }

  /// Extract column reference from a SELECT expression
  static String? _extractColumnReference(String expression) {
    final normalizedExpr = expression.toLowerCase();

    if (normalizedExpr.contains('(') ||
        normalizedExpr.contains('+') ||
        normalizedExpr.contains('-') ||
        normalizedExpr.contains('*') ||
        normalizedExpr.contains('/') ||
        normalizedExpr.contains('=') ||
        normalizedExpr.contains('<') ||
        normalizedExpr.contains('>')) {
      return null;
    }

    final parts = expression.split(' ');
    for (var i = parts.length - 1; i >= 0; i--) {
      final part = parts[i].trim();
      if (part.isEmpty) continue;

      if (_isSqlKeyword(part)) continue;

      final dotIndex = part.indexOf('.');
      if (dotIndex != -1) {
        return part;
      }

      return part;
    }

    return null;
  }

  /// Check if a word is a SQL keyword
  static bool _isSqlKeyword(String word) {
    final lowerWord = word.toLowerCase();
    const keywords = {
      'select',
      'from',
      'where',
      'and',
      'or',
      'not',
      'in',
      'between',
      'like',
      'is',
      'null',
      'join',
      'inner',
      'left',
      'right',
      'outer',
      'on',
      'group',
      'by',
      'having',
      'order',
      'limit',
      'offset',
      'union',
      'all',
      'distinct',
      'as',
      'asc',
      'desc',
      'exists',
      'case',
      'when',
      'then',
      'else',
      'end',
      'count',
      'sum',
      'avg',
      'min',
      'max',
      'coalesce',
      'if',
      'ifnull',
      'nullif',
      'cast',
      'convert',
      'date',
      'time',
      'datetime',
      'timestamp',
      'year',
      'month',
      'day',
      'hour',
      'minute',
      'second',
      'now',
      'current_date',
      'current_time',
      'current_timestamp',
      'concat',
      'substring',
      'trim',
      'upper',
      'lower',
      'replace',
      'length',
      'char_length',
      'md5',
      'sha1',
      'sha2',
      'hex',
      'unhex',
      'bin',
      'oct',
      'ascii',
      'ord',
    };
    return keywords.contains(lowerWord);
  }

  /// Normalize SQL for parsing
  static String _normalizeSql(String sql) {
    var normalized = sql.trim();

    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    normalized = normalized.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ');

    normalized = normalized.replaceAll(RegExp(r'--.*'), ' ');

    final stringLiterals = <String>[];
    normalized = normalized.replaceAllMapped(RegExp(r"'[^']*'"), (match) {
      stringLiterals.add(match.group(0)!);
      return '__STRING_${stringLiterals.length - 1}__';
    });

    return normalized.trim();
  }

  /// Check if query is a SELECT query
  static bool isSelectQuery(String sql) {
    return _normalizeSql(sql).startsWith('select');
  }
}
