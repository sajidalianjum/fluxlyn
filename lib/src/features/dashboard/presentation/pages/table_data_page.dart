import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../dialogs/row_edit_dialog.dart';
import '../dialogs/edit_confirmation_dialog.dart';

class TableDataPage extends StatefulWidget {
  final String tableName;

  const TableDataPage({super.key, required this.tableName});

  @override
  State<TableDataPage> createState() => _TableDataPageState();
}

class _TableDataPageState extends State<TableDataPage> {
  bool _isLoading = true;
  String? _error;
  List<String> _columns = [];
  List<String> _binaryColumns = [];
  List<String> _bitColumns = [];
  List<Map<String, dynamic>> _rows = [];
  String? _primaryKeyColumn;
  bool _isEditable = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final result = await provider.fetchTableData(widget.tableName);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.hasError) {
          _error = result.error;
        } else {
          _columns = result.columns;
          _binaryColumns = result.binaryColumns;
          _bitColumns = result.bitColumns;
          _rows = result.rows;
          _primaryKeyColumn = result.primaryKeyColumn;
          _isEditable = result.isEditable;
        }
      });
    }
  }

  void _openRowEditDialog(int rowIndex) {
    if (rowIndex < 0 || rowIndex >= _rows.length) return;

    showDialog(
      context: context,
      builder: (context) => RowEditDialog(
        tableName: widget.tableName,
        columns: _columns,
        row: Map<String, dynamic>.from(_rows[rowIndex]),
        primaryKeyColumn: _primaryKeyColumn,
        binaryColumns: _binaryColumns,
        bitColumns: _bitColumns,
        currentRowIndex: rowIndex,
        totalRows: _rows.length,
        onPrevious: () {
          Navigator.of(context).pop();
          if (rowIndex > 0) {
            _openRowEditDialog(rowIndex - 1);
          }
        },
        onNext: () {
          Navigator.of(context).pop();
          if (rowIndex < _rows.length - 1) {
            _openRowEditDialog(rowIndex + 1);
          }
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
        onSave: (changes) {
          Navigator.of(context).pop();
          _showConfirmationDialog(rowIndex, changes);
        },
      ),
    );
  }

  void _showConfirmationDialog(int rowIndex, Map<String, dynamic> changes) {
    if (_primaryKeyColumn == null) return;

    final row = _rows[rowIndex];
    final primaryKeyValue = row[_primaryKeyColumn!];

    showDialog(
      context: context,
      builder: (context) => EditConfirmationDialog(
        tableName: widget.tableName,
        primaryKeyColumn: _primaryKeyColumn!,
        primaryKeyValue: primaryKeyValue,
        updates: changes,
        onConfirm: () {
          Navigator.of(context).pop();
          _commitChanges(rowIndex, changes);
        },
        onCancel: () {
          Navigator.of(context).pop();
          // Reopen the edit dialog
          _openRowEditDialog(rowIndex);
        },
      ),
    );
  }

  Future<void> _commitChanges(
    int rowIndex,
    Map<String, dynamic> changes,
  ) async {
    if (_primaryKeyColumn == null) return;

    final row = _rows[rowIndex];
    final primaryKeyValue = row[_primaryKeyColumn!];

    setState(() {
      _isLoading = true;
    });

    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final error = await provider.updateRow(
      widget.tableName,
      _primaryKeyColumn!,
      primaryKeyValue,
      changes,
    );

    if (mounted) {
      if (error != null) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
        // Reopen edit dialog on error
        _openRowEditDialog(rowIndex);
      } else {
        // Refresh data to show updated values
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Row updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _buildCellContent(dynamic value) {
    // Show NULL indicator
    if (value == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
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

    // Show value
    final text = value.toString();
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Table: ${widget.tableName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_isEditable)
              Text(
                'Editable • PK: $_primaryKeyColumn • ${_rows.length} rows',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.green),
              )
            else if (_primaryKeyColumn == null && _rows.isNotEmpty)
              Text(
                'Read-Only • No Primary Key',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.orange),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadData,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error loading data',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_rows.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_chart_outlined, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text('No data found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Instruction bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0F172A),
          child: Row(
            children: [
              Icon(Icons.touch_app, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isEditable
                      ? 'Tap any row to edit'
                      : 'Table is read-only (no primary key)',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Data Grid
        Expanded(
          child: DataTable2(
            columnSpacing: 12,
            horizontalMargin: 12,
            minWidth: 600,
            headingRowColor: WidgetStateColor.resolveWith(
              (states) => const Color(0xFF1E293B),
            ),
            columns: _columns.map((col) {
              final isPK = col == _primaryKeyColumn;
              final isBinary = _binaryColumns.contains(col);
              final isBit = _bitColumns.contains(col);
              return DataColumn2(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPK)
                      Icon(Icons.key, size: 14, color: Colors.yellow[700]),
                    if (isPK) const SizedBox(width: 4),
                    if (isBit)
                      Icon(Icons.toggle_on, size: 14, color: Colors.blue[400]),
                    if (isBit) const SizedBox(width: 4),
                    if (isBinary)
                      Icon(
                        Icons.data_object,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                    if (isBinary) const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        col.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                size: ColumnSize.M,
              );
            }).toList(),
            rows: List<DataRow>.generate(_rows.length, (index) {
              final row = _rows[index];

              return DataRow(
                cells: _columns.map((col) {
                  return DataCell(
                    GestureDetector(
                      onTap: () => _openRowEditDialog(index),
                      child: _buildCellContent(row[col]),
                    ),
                  );
                }).toList(),
              );
            }),
          ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0F172A),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${_rows.length} rows',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
