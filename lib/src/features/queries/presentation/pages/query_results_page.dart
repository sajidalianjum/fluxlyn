import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/data_table2_widget.dart';

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

class QueryResultsPage extends StatefulWidget {
  final List<QueryResult> results;

  const QueryResultsPage({super.key, required this.results});

  @override
  State<QueryResultsPage> createState() => _QueryResultsPageState();
}

class _QueryResultsPageState extends State<QueryResultsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.results.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _exportToCsv(QueryResult result) {
    final buffer = StringBuffer();

    buffer.writeln(result.columns.join(','));

    for (final row in result.rows) {
      final values = result.columns
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
  }

  void _exportToJson(QueryResult result) {
    final jsonData = jsonEncode(result.rows);
    Clipboard.setData(ClipboardData(text: jsonData));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('JSON copied to clipboard')));
  }

  Widget _buildResultView(QueryResult result) {
    if (!result.success) {
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
                result.errorMessage ?? 'Unknown error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    if (result.rows.isEmpty) {
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

    final dataTableColumns = result.columns.map((col) {
      return DataTableColumn(name: col);
    }).toList();

    return DataTable2Widget(
      columns: dataTableColumns,
      rows: result.rows,
      showPagination: true,
      header: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF1E293B),
        child: Row(
          children: [
            Text(
              '${result.rows.length} rows',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(width: 16),
            Text(
              '${result.executionTimeMs}ms',
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _exportToCsv(result),
              icon: const Icon(Icons.table_chart, size: 18),
              tooltip: 'Export CSV',
            ),
            IconButton(
              onPressed: () => _exportToJson(result),
              icon: const Icon(Icons.code, size: 18),
              tooltip: 'Export JSON',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Query Results'),
        bottom: widget.results.length > 1
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: widget.results.asMap().entries.map((entry) {
                  final index = entry.key;
                  final result = entry.value;
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          result.success ? Icons.check_circle : Icons.error,
                          color: result.success ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text('Query ${index + 1}'),
                      ],
                    ),
                  );
                }).toList(),
              )
            : null,
      ),
      body: widget.results.length > 1
          ? TabBarView(
              controller: _tabController,
              children: widget.results
                  .asMap()
                  .entries
                  .map((entry) => _buildResultView(entry.value))
                  .toList(),
            )
          : _buildResultView(widget.results.first),
    );
  }
}
