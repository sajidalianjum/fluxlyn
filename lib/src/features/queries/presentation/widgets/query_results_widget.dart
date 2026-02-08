import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QueryResult {
  final String query;
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final int executionTimeMs;
  final bool success;
  final String? errorMessage;

  QueryResult({
    required this.query,
    required this.columns,
    required this.rows,
    required this.executionTimeMs,
    this.success = true,
    this.errorMessage,
  });
}

class QueryResultsWidget extends StatefulWidget {
  final QueryResult result;

  const QueryResultsWidget({super.key, required this.result});

  @override
  State<QueryResultsWidget> createState() => _QueryResultsWidgetState();
}

class _QueryResultsWidgetState extends State<QueryResultsWidget> {
  int _rowsPerPage = 50;
  int _currentPage = 0;

  void _exportToCsv() {
    final buffer = StringBuffer();

    buffer.writeln(widget.result.columns.join(','));

    for (final row in widget.result.rows) {
      final values = widget.result.columns
          .map((col) {
            final value = row[col];
            if (value == null) return '';
            final stringValue = value.toString();
            if (stringValue.contains(',') || stringValue.contains('"')) {
              return '"${stringValue.replaceAll('"', '""')}"';
            }
            return stringValue;
          })
          .join(',');
      buffer.writeln(values);
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
    }
  }

  void _exportToJson() {
    final jsonData = jsonEncode(widget.result.rows);
    Clipboard.setData(ClipboardData(text: jsonData));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('JSON copied to clipboard')));
    }
  }

  Widget _buildCellContent(dynamic value) {
    if (value == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'NULL',
          style: TextStyle(
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
            fontSize: 12,
          ),
        ),
      );
    }
    return Text(value.toString(), style: const TextStyle(color: Colors.white));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.success) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text('Query Error', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                widget.result.errorMessage ?? 'Unknown error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.result.rows.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              'Query executed successfully',
              style: TextStyle(color: Colors.green),
            ),
            SizedBox(height: 8),
            Text('No rows returned', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final totalRows = widget.result.rows.length;
    final totalPages = (totalRows / _rowsPerPage).ceil();
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, totalRows);
    final pageRows = widget.result.rows.sublist(startIndex, endIndex);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1E293B),
          child: Row(
            children: [
              Text(
                '${widget.result.rows.length} rows',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(width: 16),
              Text(
                '${widget.result.executionTimeMs}ms',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                onPressed: _exportToCsv,
                icon: const Icon(Icons.table_chart, size: 18),
                tooltip: 'Export CSV',
              ),
              IconButton(
                onPressed: _exportToJson,
                icon: const Icon(Icons.code, size: 18),
                tooltip: 'Export JSON',
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ListView(
              scrollDirection: Axis.vertical,
              children: [
                DataTable(
                  headingRowColor: WidgetStateColor.resolveWith(
                    (states) => const Color(0xFF0F172A),
                  ),
                  columns: widget.result.columns.map((col) {
                    return DataColumn(
                      label: Text(
                        col,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                  rows: pageRows.map((row) {
                    return DataRow(
                      cells: widget.result.columns.map((col) {
                        final value = row[col];
                        return DataCell(_buildCellContent(value));
                      }).toList(),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E293B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  'Page ${_currentPage + 1} of $totalPages',
                  style: const TextStyle(color: Colors.white),
                ),
                IconButton(
                  onPressed: _currentPage < totalPages - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: _rowsPerPage,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  items: const [10, 25, 50, 100].map((value) {
                    return DropdownMenuItem(
                      value: value,
                      child: Text('$value rows'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _rowsPerPage = value;
                        _currentPage = 0;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
