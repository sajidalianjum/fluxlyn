class SQLFormatter {
  static final Set<String> _keywords = {
    'SELECT',
    'FROM',
    'WHERE',
    'GROUP',
    'HAVING',
    'ORDER',
    'LIMIT',
    'OFFSET',
    'UNION',
    'INTERSECT',
    'EXCEPT',
    'WITH',
    'INSERT',
    'UPDATE',
    'DELETE',
    'SET',
    'VALUES',
    'INTO',
    'RETURNING',
    'CASE',
    'WHEN',
    'THEN',
    'ELSE',
    'END',
    'JOIN',
    'INNER',
    'LEFT',
    'RIGHT',
    'FULL',
    'CROSS',
    'NATURAL',
    'ON',
    'AS',
    'OVER',
    'PARTITION',
    'WINDOW',
    'AND',
    'OR',
    'NOT',
    'IN',
    'IS',
    'NULL',
  };

  static bool _isKeyword(String word) {
    return _keywords.contains(word.toUpperCase());
  }

  static List<String> _tokenizeSQL(String sql) {
    final tokens = <String>[];
    int i = 0;
    final n = sql.length;

    while (i < n) {
      final ch = sql[i];

      if (_isWhitespace(ch)) {
        i++;
        continue;
      }

      if (ch == '-' && i + 1 < n && sql[i + 1] == '-') {
        int end = i;
        while (end < n && sql[end] != '\n') {
          end++;
        }
        tokens.add(sql.substring(i, end));
        i = end;
        continue;
      }

      if (ch == '/' && i + 1 < n && sql[i + 1] == '*') {
        int end = i + 2;
        while (end < n &&
            !(sql[end] == '*' && end + 1 < n && sql[end + 1] == '/')) {
          end++;
        }
        end += 2;
        tokens.add(sql.substring(i, end.min(n)));
        i = end;
        continue;
      }

      if ("'\"`".contains(ch)) {
        final quote = ch;
        int end = i + 1;
        while (end < n) {
          if (sql[end] == '\\') {
            end += 2;
          } else if (sql[end] == quote) {
            end++;
            break;
          } else {
            end++;
          }
        }
        tokens.add(sql.substring(i, end));
        i = end;
        continue;
      }

      if (_isDigit(ch) || (ch == '.' && i + 1 < n && _isDigit(sql[i + 1]))) {
        int end = i;
        while (end < n && _isNumberChar(sql[end])) {
          end++;
        }
        tokens.add(sql.substring(i, end));
        i = end;
        continue;
      }

      if (_isLetter(ch)) {
        int end = i;
        while (end < n && _isIdentifierChar(sql[end])) {
          end++;
        }
        tokens.add(sql.substring(i, end));
        i = end;
        continue;
      }

      if ('(),;[]{}'.contains(ch)) {
        tokens.add(ch);
        i++;
        continue;
      }

      if (i + 1 < n) {
        final two = sql.substring(i, i + 2);
        if (const ['<=', '>=', '!=', '<>', '==', '||', '&&'].contains(two)) {
          tokens.add(two);
          i += 2;
        } else {
          tokens.add(ch);
          i++;
        }
      } else {
        tokens.add(ch);
        i++;
      }
    }

    return tokens;
  }

  static String format(String sql, {int indent = 2, bool uppercase = true}) {
    if (sql.isEmpty) return '';

    final indentStr = ' ' * indent;
    final tokens = _tokenizeSQL(sql);

    final result = <String>[];
    int level = 0;
    int parenLevel = 0;
    int i = 0;

    while (i < tokens.length) {
      String token = tokens[i];
      final upper = token.toUpperCase();

      bool isMajor = false;

      if (const [
        'SELECT',
        'FROM',
        'WHERE',
        'HAVING',
        'LIMIT',
        'OFFSET',
        'UNION',
        'VALUES',
        'SET',
        'ON',
      ].contains(upper)) {
        isMajor = true;
      } else if ((upper == 'GROUP' || upper == 'ORDER') &&
          i + 1 < tokens.length &&
          tokens[i + 1].toUpperCase() == 'BY') {
        isMajor = true;
      } else if (upper.endsWith('JOIN')) {
        isMajor = true;
      }

      if (isMajor) {
        if (result.isNotEmpty) {
          result.add('\n${indentStr * level}');
        }
        if (uppercase && _isKeyword(token)) {
          token = upper;
        }
      } else if ((upper == 'AND' || upper == 'OR') && parenLevel <= 1) {
        result.add('\n${indentStr * (level + 1)}');
        if (uppercase) token = upper;
      } else if (upper == 'CASE') {
        if (result.isNotEmpty) {
          result.add(' ');
        }
        if (uppercase) token = 'CASE';
      } else if (const ['WHEN', 'THEN', 'ELSE'].contains(upper)) {
        result.add('\n${indentStr * (level + 1)}');
        if (uppercase) token = upper;
      } else if (upper == 'END') {
        level = level.max(0) - 1;
        result.add('\n${indentStr * level}');
        if (uppercase) token = 'END';
      }

      if (token == '(') {
        parenLevel++;
        result.add(' (');
        if (i + 1 < tokens.length && tokens[i + 1].toUpperCase() == 'SELECT') {
          level++;
          result.add('\n${indentStr * level}');
        }
        i++;
        continue;
      }

      if (token == ')') {
        parenLevel = parenLevel.max(0) - 1;
        level = level.max(0) - 1;
        result.add('\n${indentStr * level})');
        i++;
        continue;
      }

      if (token == ',') {
        result.add(',');
        i++;
        continue;
      }

      if (token == ';') {
        result.add(';');
        if (i < tokens.length - 1) {
          result.add('\n\n');
        }
        i++;
        continue;
      }

      if (result.isNotEmpty) {
        final last = result.last;
        if (!const ['(', '.', '\n'].any((c) => last.endsWith(c))) {
          result.add(' ');
        }
      }

      if (uppercase && _isKeyword(token)) {
        token = upper;
      }

      result.add(token);
      i++;
    }

    String formatted = result.join('').trim();
    formatted = formatted.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');
    formatted = formatted.replaceAll(RegExp(r' +'), ' ');

    return formatted;
  }

  static bool _isWhitespace(String ch) {
    return RegExp(r'\s').hasMatch(ch);
  }

  static bool _isDigit(String ch) {
    return RegExp(r'\d').hasMatch(ch);
  }

  static bool _isLetter(String ch) {
    return RegExp(r'[a-zA-Z_]').hasMatch(ch);
  }

  static bool _isIdentifierChar(String ch) {
    return RegExp(r'[a-zA-Z0-9_.]').hasMatch(ch);
  }

  static bool _isNumberChar(String ch) {
    return RegExp(r'[\d.eE+\-]').hasMatch(ch);
  }
}

extension _IntExtension on int {
  int min(int other) => this < other ? this : other;
  int max(int other) => this > other ? this : other;
}
