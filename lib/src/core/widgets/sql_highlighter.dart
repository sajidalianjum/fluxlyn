import 'package:flutter/material.dart';

class SqlHighlighter extends StatelessWidget {
  final String sql;
  final int maxLines;
  final TextOverflow overflow;
  final double fontSize;
  final Color backgroundColor;

  const SqlHighlighter({
    super.key,
    required this.sql,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
    this.fontSize = 12,
    this.backgroundColor = const Color(0xFF1E293B),
  });

  @override
  Widget build(BuildContext context) {
    final preview = sql.replaceAll('\n', ' ');
    final spans = _highlightSql(preview);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text.rich(
        TextSpan(children: spans),
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

  List<InlineSpan> _highlightSql(String sql) {
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
            style: const TextStyle(color: Color(0xFFA6E22E)),
          ),
        );
      } else if (singleLineComment != null) {
        spans.add(
          TextSpan(
            text: singleLineComment,
            style: const TextStyle(color: Color(0xFF75715E)),
          ),
        );
      } else if (multiLineComment != null) {
        spans.add(
          TextSpan(
            text: multiLineComment,
            style: const TextStyle(color: Color(0xFF75715E)),
          ),
        );
      } else if (upperWord != null) {
        final word = upperWord.toUpperCase();
        if (keywords.contains(word)) {
          spans.add(
            TextSpan(
              text: match.group(0),
              style: const TextStyle(color: Color(0xFFF92672)),
            ),
          );
        } else if (functions.contains(word)) {
          spans.add(
            TextSpan(
              text: match.group(0),
              style: const TextStyle(color: Color(0xFF66D9EF)),
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
              style: const TextStyle(color: Color(0xFFF92672)),
            ),
          );
        } else if (functions.contains(word)) {
          spans.add(
            TextSpan(
              text: match.group(0),
              style: const TextStyle(color: Color(0xFF66D9EF)),
            ),
          );
        } else {
          spans.add(TextSpan(text: match.group(0)));
        }
      } else if (number != null) {
        spans.add(
          TextSpan(
            text: number,
            style: const TextStyle(color: Color(0xFFAE81FF)),
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
