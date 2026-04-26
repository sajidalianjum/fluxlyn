import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path/path.dart' as path;
import '../../../../core/widgets/data_table2_widget.dart';
import '../../../../core/services/sql_analyzer.dart';
import '../../../dashboard/presentation/dialogs/row_edit_dialog.dart';
import '../../../dashboard/providers/dashboard_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../models/query_result.dart';

class QueryResultsPage extends StatefulWidget {
  final List<QueryResult> results;

  const QueryResultsPage({super.key, required this.results});

  @override
  State<QueryResultsPage> createState() => _QueryResultsPageState();
}

class _QueryResultsPageState extends State<QueryResultsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  Text _getSuccessMessage(QueryResult result) {
    switch (result.queryType) {
      case SqlQueryType.select:
        return const Text(
          'No rows returned',
          style: TextStyle(color: Colors.grey),
        );
      case SqlQueryType.dml:
        if (result.affectedRows != null) {
          return Text(
            '${result.affectedRows} row${result.affectedRows == 1 ? '' : 's'} affected',
            style: const TextStyle(color: Colors.grey),
          );
        }
        return const Text(
          'Query executed successfully',
          style: TextStyle(color: Colors.grey),
        );
      case SqlQueryType.ddl:
        return const Text(
          'Schema updated successfully',
          style: TextStyle(color: Colors.grey),
        );
      default:
        return const Text(
          'Query executed successfully',
          style: TextStyle(color: Colors.grey),
        );
    }
  }

  String _getRowInfo(QueryResult result) {
    switch (result.queryType) {
      case SqlQueryType.select:
        return '${result.rows.length} rows';
      case SqlQueryType.dml:
        if (result.affectedRows != null) {
          return '${result.affectedRows} row${result.affectedRows == 1 ? '' : 's'} affected';
        }
        return 'Query executed';
      case SqlQueryType.ddl:
        return 'Schema updated';
      default:
        return 'Query executed';
    }
  }

  void _openRowView(int rowIndex, QueryResult result) {
    final row = result.rows[rowIndex];
    final primaryKeyValue = result.primaryKeyColumn != null
        ? row[result.primaryKeyColumn!]
        : null;

    showDialog(
      context: context,
      builder: (context) => RowEditDialog(
        tableName: result.tableName ?? 'Query Result',
        columns: result.columns,
        row: row,
        primaryKeyColumn: result.primaryKeyColumn,
        primaryKeyValue: primaryKeyValue,
        binaryColumns: result.binaryColumns,
        bitColumns: result.bitColumns,
        enumColumns: result.enumColumns,
        setColumns: result.setColumns,
        currentRowIndex: rowIndex,
        totalRows: result.rows.length,
        onPrevious: () {
          Navigator.of(context).pop();
          if (rowIndex > 0) {
            _openRowView(rowIndex - 1, result);
          }
        },
        onNext: () {
          Navigator.of(context).pop();
          if (rowIndex < result.rows.length - 1) {
            _openRowView(rowIndex + 1, result);
          }
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
        onSave: (changes) {
          Navigator.of(context).pop();
          _commitChanges(rowIndex, result, changes);
        },
      ),
    );
  }

  Future<void> _commitChanges(
    int rowIndex,
    QueryResult result,
    Map<String, dynamic> changes,
  ) async {
    if (result.primaryKeyColumn == null || result.tableName == null) return;

    final row = result.rows[rowIndex];
    final primaryKeyValue = row[result.primaryKeyColumn!];

    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final error = await provider.updateRow(
      result.tableName!,
      result.primaryKeyColumn!,
      primaryKeyValue,
      changes,
    );

    if (mounted) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
      } else {
        for (final entry in changes.entries) {
          result.rows[rowIndex][entry.key] = entry.value;
        }
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Row updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

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

  Future<void> _exportToCsvFile(QueryResult result) async {
    String savePath;

    if (Platform.isAndroid) {
      final directoryPath = await getDirectoryPath();
      if (directoryPath == null) return;
      savePath = path.join(directoryPath, 'export.csv');
    } else {
      final FileSaveLocation? resultLocation = await getSaveLocation(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
        suggestedName: 'export.csv',
      );
      if (resultLocation == null) return;
      savePath = resultLocation.path;
    }

    final buffer = StringBuffer();
    // Add UTF-8 BOM
    buffer.write('\uFEFF');
    buffer.writeln(result.columns.join(','));

    for (final row in result.rows) {
      final values = result.columns
          .map((col) {
            final value = row[col];
            if (value == null) return '';
            final stringValue = value.toString();
            if (stringValue.contains(',') ||
                stringValue.contains('"') ||
                stringValue.contains('\n')) {
              return '"${stringValue.replaceAll('"', '""')}"';
            }
            return stringValue;
          })
          .join(',');
      buffer.writeln(values);
    }

    final Uint8List fileData = Uint8List.fromList(
      utf8.encode(buffer.toString()),
    );
    final XFile file = XFile.fromData(
      fileData,
      mimeType: 'text/csv',
      name: 'export.csv',
    );
    await file.saveTo(savePath);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exported to $savePath')));
    }
  }

  Future<void> _exportToXlsxFile(QueryResult result) async {
    String savePath;

    if (Platform.isAndroid) {
      final directoryPath = await getDirectoryPath();
      if (directoryPath == null) return;
      savePath = path.join(directoryPath, 'export.xlsx');
    } else {
      final FileSaveLocation? resultLocation = await getSaveLocation(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Excel', extensions: ['xlsx']),
        ],
        suggestedName: 'export.xlsx',
      );
      if (resultLocation == null) return;
      savePath = resultLocation.path;
    }

    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    // Add header
    sheet.appendRow(result.columns.map((col) => TextCellValue(col)).toList());

    // Add rows
    for (final row in result.rows) {
      sheet.appendRow(
        result.columns.map((col) {
          final value = row[col];
          if (value == null) return TextCellValue('');
          if (value is int) return IntCellValue(value);
          if (value is double) return DoubleCellValue(value);
          if (value is bool) return BoolCellValue(value);
          return TextCellValue(value.toString());
        }).toList(),
      );
    }

    final List<int>? fileBytes = excel.save();
    if (fileBytes != null) {
      final XFile file = XFile.fromData(
        Uint8List.fromList(fileBytes),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        name: 'export.xlsx',
      );
      await file.saveTo(savePath);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Exported to $savePath')));
      }
    }
  }

  Widget _buildResultView(QueryResult result) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
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
      final message = _getSuccessMessage(result);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Query executed successfully',
              style: TextStyle(color: Colors.green),
            ),
            const SizedBox(height: 8),
            message,
          ],
        ),
      );
    }

    final dataTableColumns = result.columns.map((col) {
      return DataTableColumn(
        name: col,
        isBinary: result.binaryColumns.contains(col),
        isBit: result.bitColumns.contains(col),
      );
    }).toList();

    return DataTable2Widget(
      columns: dataTableColumns,
      rows: result.rows,
      showPagination: true,
      onRowTap: (index) => _openRowView(index, result),
      header: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: theme.colorScheme.surface,
        child: Row(
          children: [
            Consumer<SettingsProvider>(
              builder: (context, settingsProvider, _) {
                final settings = settingsProvider.settings;

                if (settings.readOnlyMode) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Chip(
                      avatar: const Icon(Icons.lock, size: 16),
                      label: const Text(
                        'Read-Only',
                        style: TextStyle(fontSize: 11),
                      ),
                      backgroundColor: Colors.red.withValues(alpha: 0.2),
                      labelStyle: const TextStyle(color: Colors.red),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Text(
              _getRowInfo(result),
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(width: 16),
            Text(
              '${result.executionTimeMs}ms',
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
            const Spacer(),
            PopupMenuButton<String>(
              icon: const Icon(Icons.download, size: 18),
              tooltip: 'Export',
              onSelected: (value) {
                if (value == 'csv') {
                  _exportToCsvFile(result);
                } else if (value == 'xlsx') {
                  _exportToXlsxFile(result);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'csv',
                  child: Text('Export as CSV'),
                ),
                const PopupMenuItem<String>(
                  value: 'xlsx',
                  child: Text('Export as XLSX'),
                ),
              ],
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
