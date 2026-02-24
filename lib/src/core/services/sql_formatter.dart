import 'package:characters/characters.dart';

class SQLFormatter {
  static const List<String> _keywordsToUppercase = [
    'SELECT', 'FROM', 'WHERE', 'GROUP', 'BY', 'ORDER', 'HAVING', 'LIMIT',
    'JOIN', 'LEFT', 'RIGHT', 'INNER', 'OUTER', 'ON', 'UNION', 'ALL', 'SET',
    'UPDATE', 'INSERT', 'INTO', 'VALUES', 'DELETE', 'CREATE', 'TABLE',
    'ALTER', 'DROP', 'AS', 'AND', 'OR', 'NOT', 'NULL', 'IS', 'LIKE', 'BETWEEN',
    'EXISTS', 'CASE', 'WHEN', 'THEN', 'ELSE', 'END',
  ];

  static const List<String> _newlineBefore = [
    'SELECT', 'FROM', 'WHERE', 'GROUP', 'ORDER', 'HAVING', 'LIMIT',
    'UNION', 'SET', 'AND', 'OR', 'JOIN', 'LEFT', 'RIGHT', 'INNER', 'OUTER',
  ];

  static const String _indentString = '  ';

  static String format(String sql) {
    if (sql.isEmpty) return sql;

    List<String> tokens = _tokenize(sql);
    StringBuffer formattedSql = StringBuffer();
    int indentLevel = 0;

    void append(String text, {bool addNewline = false, bool addSpace = true, bool indent = true}) {
      if (formattedSql.isEmpty) {
        if (indent) formattedSql.write(_indentString * indentLevel);
        formattedSql.write(text);
        return;
      }

      String lastChar = '';
      if (formattedSql.isNotEmpty) {
        lastChar = formattedSql.toString().characters.last;
      }

      if (addNewline) {
        if (lastChar != '\n') formattedSql.writeln();
        if (indent) formattedSql.write(_indentString * indentLevel);
      } else if (addSpace) {
        if (lastChar != ' ' && lastChar != '\n' && text != ')' && text != ',' && text != ';') {
          formattedSql.write(' ');
        }
      }
      formattedSql.write(text);
    }

    for (int i = 0; i < tokens.length; i++) {
      String token = tokens[i];
      String upperToken = token.toUpperCase();

      // Capitalize keywords
      if (_keywordsToUppercase.contains(upperToken)) {
        token = upperToken;
      }

      // Handle indentation for ')'
      if (token == ')') {
        indentLevel = indentLevel > 0 ? indentLevel - 1 : 0;
        append(token, addNewline: true, addSpace: true, indent: true);
        continue;
      }

      // Add newline and indent if necessary
      if (_newlineBefore.contains(upperToken)) {
        append(token, addNewline: true, addSpace: true, indent: true);
      } else if (token == ',') {
        append(token, addNewline: true, addSpace: false, indent: true);
      } else if (token == '(') {
        append(token, addNewline: false, addSpace: false, indent: false);
        indentLevel++;
        append('', addNewline: true, addSpace: false, indent: true); // Newline and indent after (
      } else if (token == ';') {
        append(token, addNewline: true, addSpace: false, indent: false);
        append('', addNewline: true, addSpace: false, indent: false); // Extra newline after ;
      }
      else {
        append(token, addNewline: false, addSpace: true, indent: false);
      }
    }

    return formattedSql.toString().trim();
  }

  static List<String> _tokenize(String sql) {
    List<String> tokens = [];
    RegExp regex = RegExp(
      r"""(--[^\n]*)|(/\*[^*]*\*+(?:[^/*][^*]*\*+)*/)|('[^']*'|""[^""]*""|`[^`]*`)|(\b\d+(\.\d+)?\b)|(\b[a-zA-Z_][a-zA-Z_0-9]*\b)|([+\-*/=<>!%&|~^#@]+)|([.,;()\[\]{}])|\s+""",
      caseSensitive: false,
      multiLine: true,
    );

    for (RegExpMatch match in regex.allMatches(sql)) {
      String? token = match.group(0);
      if (token != null) {
        if (token.trim().isNotEmpty && !RegExp(r'^\s+$').hasMatch(token)) {
          tokens.add(token.trim());
        }
      }
    }
    return tokens;
  }
}