import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/data_table2_widget.dart';
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
        _openRowEditDialog(rowIndex);
      } else {
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

  // Get the best columns to display on a card (ID + first 2-3 data columns)
  List<String> _getCardDisplayColumns() {
    final displayCols = <String>[];

    // Always show primary key first if exists
    if (_primaryKeyColumn != null && _columns.contains(_primaryKeyColumn!)) {
      displayCols.add(_primaryKeyColumn!);
    }

    // Add up to 3 more non-binary columns
    for (final col in _columns) {
      if (displayCols.length >= 4) break;
      if (displayCols.contains(col)) continue;
      if (_binaryColumns.contains(col)) continue; // Skip binary in card preview
      displayCols.add(col);
    }

    return displayCols;
  }

  // Get a title column (first non-PK string column)
  String? _getTitleColumn() {
    for (final col in _columns) {
      if (col == _primaryKeyColumn) continue;
      if (_binaryColumns.contains(col)) continue;
      final firstValue = _rows.isNotEmpty ? _rows[0][col] : null;
      if (firstValue is String) return col;
    }
    return null;
  }

  Widget _buildCardView() {
    final displayCols = _getCardDisplayColumns();
    final titleCol = _getTitleColumn();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rows.length,
      itemBuilder: (context, index) {
        final row = _rows[index];
        final title = titleCol != null ? row[titleCol]?.toString() : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: const Color(0xFF1E293B),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _openRowEditDialog(index),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row (if we have a good title column)
                  if (title != null && title.isNotEmpty) ...[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFF334155)),
                    const SizedBox(height: 12),
                  ],

                  // Display key fields
                  ...displayCols.map((col) {
                    final isPK = col == _primaryKeyColumn;
                    final isBit = _bitColumns.contains(col);
                    final value = row[col];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Column name
                          Container(
                            constraints: const BoxConstraints(minWidth: 80),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPK)
                                  Icon(
                                    Icons.key,
                                    size: 12,
                                    color: Colors.yellow[700],
                                  ),
                                if (isBit)
                                  Icon(
                                    Icons.toggle_on,
                                    size: 12,
                                    color: Colors.blue[400],
                                  ),
                                if (isPK || isBit) const SizedBox(width: 4),
                                Text(
                                  col,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                    fontWeight: isPK
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Value
                          Expanded(child: _buildCardValue(value, isBit: isBit)),
                        ],
                      ),
                    );
                  }),

                  // Edit hint
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.edit, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _isEditable ? 'Tap to edit' : 'View details',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardValue(dynamic value, {bool isBit = false}) {
    if (value == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

    String text;
    if (isBit && value is List<int>) {
      text = value.isNotEmpty ? value.first.toString() : '0';
    } else if (isBit &&
        value is String &&
        value.startsWith('[') &&
        value.endsWith(']')) {
      final inner = value.substring(1, value.length - 1);
      final intValue = int.tryParse(inner.trim());
      text = (intValue ?? 0).toString();
    } else {
      text = value.toString();
    }

    return Text(
      text,
      style: const TextStyle(fontSize: 14, color: Colors.white),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTableView() {
    final dataTableColumns = _columns.map((col) {
      return DataTableColumn(
        name: col,
        isPrimaryKey: col == _primaryKeyColumn,
        isBinary: _binaryColumns.contains(col),
        isBit: _bitColumns.contains(col),
      );
    }).toList();

    return DataTable2Widget(
      columns: dataTableColumns,
      rows: _rows,
      header: Container(
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
      footer: Container(
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
      onRowTap: (index) => _openRowEditDialog(index),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
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
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (_rows.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.table_chart_outlined,
                    color: Colors.grey,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text('No data found', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Responsive layout switch
          if (constraints.maxWidth < 600) {
            // Mobile: Card view
            return _buildCardView();
          } else {
            // Desktop: Table view
            return _buildTableView();
          }
        },
      ),
    );
  }
}
