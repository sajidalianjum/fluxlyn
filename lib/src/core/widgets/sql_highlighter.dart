import 'package:flutter/material.dart';

class SqlHighlighter extends StatelessWidget {
  final String sql;
  final int maxLines;
  final TextOverflow overflow;
  final double fontSize;

  const SqlHighlighter({
    super.key,
    required this.sql,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final syntaxColors = isDark ? _darkSyntaxColors : _lightSyntaxColors;
    
    final preview = sql.replaceAll('\n', ' ');
    final spans = _highlightSql(preview, syntaxColors);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text.rich(
        TextSpan(children: spans, style: TextStyle(color: theme.colorScheme.onSurface)),
        maxLines: maxLines,
        overflow: overflow,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize,
          height: 1.3,
        ),
      ),
    );
  }

  static const _darkSyntaxColors = _SyntaxColors(
    string: Color(0xFFA6E22E),
    comment: Color(0xFF75715E),
    keyword: Color(0xFFF92672),
    function: Color(0xFF66D9EF),
    number: Color(0xFFAE81FF),
  );

  static const _lightSyntaxColors = _SyntaxColors(
    string: Color(0xFF0A8F4A),
    comment: Color(0xFF6A737D),
    keyword: Color(0xFFD73A49),
    function: Color(0xFF0066CC),
    number: Color(0xFF005CC5),
  );

  List<InlineSpan> _highlightSql(String sql, _SyntaxColors colors) {
    final spans = <InlineSpan>[];
    final regex = RegExp(
      r"""('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")|"""
      r"""(--[^\n]*)|"""
      r"""(/\*[\s\S]*?\*/)|"""
      r"""(\b[A-Z_][A-Z0-9_]*\b)|"""
      r"""(\b[a-z_][a-z0-9_]*\b)|"""
      r"""(\d+(?:\.\d+)?)|"""
      r"""([(),.;])|""",
      caseSensitive: false,
    );

    final keywords = {
      'SELECT',
      'FROM',
      'WHERE',
      'JOIN',
      'LEFT',
      'RIGHT',
      'INNER',
      'OUTER',
      'ON',
      'AND',
      'OR',
      'NOT',
      'IN',
      'IS',
      'NULL',
      'LIKE',
      'BETWEEN',
      'ORDER',
      'BY',
      'GROUP',
      'HAVING',
      'LIMIT',
      'OFFSET',
      'DISTINCT',
      'INSERT',
      'INTO',
      'VALUES',
      'UPDATE',
      'SET',
      'DELETE',
      'CREATE',
      'TABLE',
      'DATABASE',
      'INDEX',
      'VIEW',
      'DROP',
      'ALTER',
      'TRUNCATE',
      'UNION',
      'ALL',
      'EXISTS',
      'CASE',
      'WHEN',
      'THEN',
      'ELSE',
      'END',
      'ASC',
      'DESC',
      'AS',
      'WITH',
      'RECURSIVE',
      'PRIMARY',
      'KEY',
      'FOREIGN',
      'REFERENCES',
      'UNIQUE',
      'CONSTRAINT',
      'DEFAULT',
      'AUTO_INCREMENT',
      'TRUE',
      'FALSE',
      'CURRENT_TIMESTAMP',
      'CURRENT_DATE',
      'CURRENT_TIME',
    };

    final functions = {
      'COUNT',
      'SUM',
      'AVG',
      'MIN',
      'MAX',
      'ROUND',
      'ABS',
      'CEIL',
      'FLOOR',
      'SQRT',
      'POWER',
      'CONCAT',
      'SUBSTRING',
      'TRIM',
      'LOWER',
      'UPPER',
      'LENGTH',
      'REPLACE',
      'COALESCE',
      'NULLIF',
      'CAST',
      'CONVERT',
      'NOW',
      'DATE',
      'TIME',
      'YEAR',
      'MONTH',
      'DAY',
      'HOUR',
      'MINUTE',
      'SECOND',
      'IFNULL',
      'IF',
      'ISNULL',
    };

    int lastIndex = 0;
    for (final match in regex.allMatches(sql)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: sql.substring(lastIndex, match.start)));
      }

      final stringOrComment = match.group(1);
      final singleLineComment = match.group(2);
      final multiLineComment = match.group(3);
      final upperWord = match.group(4);
      final lowerWord = match.group(5);
      final number = match.group(6);
      final punctuation = match.group(7);

      if (stringOrComment != null) {
        spans.add(
          TextSpan(
            text: stringOrComment,
            style: TextStyle(color: colors.string),
          ),
        );
      } else if (singleLineComment != null) {
        spans.add(
          TextSpan(
            text: singleLineComment,
            style: TextStyle(color: colors.comment),
          ),
        );
      } else if (multiLineComment != null) {
        spans.add(
          TextSpan(
            text: multiLineComment,
            style: TextStyle(color: colors.comment),
          ),
        );
      } else if (upperWord != null) {
        final word = upperWord.toUpperCase();
        if (keywords.contains(word)) {
          spans.add(
            TextSpan(
              text: match.group(0),
              style: TextStyle(color: colors.keyword),
            ),
          );
        } else if (functions.contains(word)) {
          spans.add(
            TextSpan(
              text: match.group(0),
              style: TextStyle(color: colors.function),
            ),
          );
        } else {
          spans.add(TextSpan(text: match.group(0)));
        }
      } else if (lowerWord != null) {
        final word = lowerWord.toUpperCase();
        if (keywords.contains(word)) {
          spans.add(
            TextSpan(
              text: match.group(0),
              style: TextStyle(color: colors.keyword),
            ),
          );
        } else if (functions.contains(word)) {
          spans.add(
            TextSpan(
              text: match.group(0),
              style: TextStyle(color: colors.function),
            ),
          );
        } else {
          spans.add(TextSpan(text: match.group(0)));
        }
      } else if (number != null) {
        spans.add(
          TextSpan(
            text: number,
            style: TextStyle(color: colors.number),
          ),
        );
      } else if (punctuation != null) {
        spans.add(TextSpan(text: punctuation));
      } else {
        spans.add(TextSpan(text: match.group(0)));
      }

      lastIndex = match.end;
    }

    if (lastIndex < sql.length) {
      spans.add(TextSpan(text: sql.substring(lastIndex)));
    }

    return spans;
  }
}

class _SyntaxColors {
  final Color string;
  final Color comment;
  final Color keyword;
  final Color function;
  final Color number;

  const _SyntaxColors({
    required this.string,
    required this.comment,
    required this.keyword,
    required this.function,
    required this.number,
  });
}