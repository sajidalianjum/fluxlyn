import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/data_table2_widget.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/table_search_result.dart';
import '../dialogs/row_edit_dialog.dart';
import '../dialogs/edit_confirmation_dialog.dart';
import '../dialogs/table_search_dialog.dart';

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
  TableSearchResult? _searchResult;
  int _offset = 0;
  final int _limit = 100;
  bool _hasNextPage = false;

  int get _currentPage => _offset ~/ _limit + 1;
  bool get _hasPreviousPage => _offset > 0;

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
    TableDataResult result;

    if (_searchResult != null &&
        (_searchResult!.hasFilters || _searchResult!.hasSort)) {
      result = await provider.fetchTableDataWithFilter(
        tableName: widget.tableName,
        searchColumn: _searchResult!.searchColumn,
        searchText: _searchResult!.searchText,
        sortColumn: _searchResult!.sortColumn,
        sortDirection: _searchResult!.sortDirection,
        limit: _limit,
        offset: _offset,
      );
    } else {
      result = await provider.fetchTableData(
        widget.tableName,
        limit: _limit,
        offset: _offset,
      );
    }

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
          _hasNextPage = result.hasNextPage;
        }
      });
    }
  }

  void _openSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => TableSearchDialog(
        columns: _columns,
        initialResult: _searchResult,
        onApply: (result) {
          setState(() {
            _searchResult = result.hasFilters || result.hasSort ? result : null;
            _offset = 0;
          });
          _loadData();
        },
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _searchResult = null;
      _offset = 0;
    });
    _loadData();
  }

  void _goToNextPage() {
    if (!_hasNextPage) return;
    setState(() {
      _offset += _limit;
    });
    _loadData();
  }

  void _goToPreviousPage() {
    if (!_hasPreviousPage) return;
    setState(() {
      _offset = (_offset - _limit).clamp(0, _offset);
    });
    _loadData();
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

  String _getFilterLabel() {
    final parts = <String>[];
    if (_searchResult!.hasFilters) {
      parts.add('${_searchResult!.searchColumn}');
    }
    if (_searchResult!.hasSort) {
      final direction = _searchResult!.sortDirection == SortDirection.asc
          ? '↑'
          : '↓';
      parts.add('${_searchResult!.sortColumn}$direction');
    }
    return parts.join(' • ');
  }

  Widget _buildDataView() {
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
              'Showing ${_rows.length} rows • Page $_currentPage',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Row(
              children: [
                if (_hasPreviousPage)
                  IconButton(
                    onPressed: _isLoading ? null : _goToPreviousPage,
                    icon: const Icon(Icons.chevron_left, size: 20),
                    tooltip: 'Previous page',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                if (_hasNextPage)
                  IconButton(
                    onPressed: _isLoading ? null : _goToNextPage,
                    icon: const Icon(Icons.chevron_right, size: 20),
                    tooltip: 'Next page',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
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
            Tooltip(
              message: _isEditable
                  ? 'Primary Key: $_primaryKeyColumn • ${_rows.length} rows'
                  : 'Read-Only • No Primary Key',
              child: Text(
                _isEditable
                    ? 'PK: $_primaryKeyColumn • ${_rows.length} rows'
                    : 'Read-Only • No PK',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _isEditable ? Colors.green : Colors.orange,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openSearchDialog,
            icon: const Icon(Icons.filter_list),
            tooltip: 'Search & Filter',
          ),
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
        bottom:
            _searchResult != null &&
                (_searchResult!.hasFilters || _searchResult!.hasSort)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    border: Border(
                      top: BorderSide(color: Colors.grey, width: 0.5),
                    ),
                  ),
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getFilterLabel(),
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _clearFilters,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: Builder(
        builder: (context) {
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.table_chart_outlined,
                    color: Colors.grey,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No data found',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return _buildDataView();
        },
      ),
    );
  }
}
