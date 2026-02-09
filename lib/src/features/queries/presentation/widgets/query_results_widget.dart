import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/data_table2_widget.dart';
import '../../../dashboard/presentation/dialogs/row_edit_dialog.dart';

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
  void _openRowView(int rowIndex) {
    final row = widget.result.rows[rowIndex];
    showDialog(
      context: context,
      builder: (context) => RowEditDialog(
        tableName: 'Query Result',
        columns: widget.result.columns,
        row: row,
        primaryKeyColumn: null,
        binaryColumns: const [],
        bitColumns: const [],
        currentRowIndex: rowIndex,
        totalRows: widget.result.rows.length,
        onPrevious: () {
          Navigator.of(context).pop();
          if (rowIndex > 0) {
            _openRowView(rowIndex - 1);
          }
        },
        onNext: () {
          Navigator.of(context).pop();
          if (rowIndex < widget.result.rows.length - 1) {
            _openRowView(rowIndex + 1);
          }
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
        onSave: (_) {
          Navigator.of(context).pop();
        },
      ),
    );
  }

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

    final dataTableColumns = widget.result.columns.map((col) {
      return DataTableColumn(name: col);
    }).toList();

    return DataTable2Widget(
      columns: dataTableColumns,
      rows: widget.result.rows,
      showPagination: true,
      onRowTap: (index) => _openRowView(index),
      header: Container(
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
    );
  }
}
