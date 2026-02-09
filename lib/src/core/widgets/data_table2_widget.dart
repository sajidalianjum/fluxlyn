import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

class DataTableColumn {
  final String name;
  final bool isPrimaryKey;
  final bool isBinary;
  final bool isBit;

  DataTableColumn({
    required this.name,
    this.isPrimaryKey = false,
    this.isBinary = false,
    this.isBit = false,
  });
}

class DataTable2Widget extends StatefulWidget {
  final List<DataTableColumn> columns;
  final List<Map<String, dynamic>> rows;
  final Widget? header;
  final Widget? footer;
  final Function(int rowIndex)? onRowTap;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportJson;
  final bool showPagination;
  final int initialRowsPerPage;
  final List<int> availableRowsPerPage;

  const DataTable2Widget({
    super.key,
    required this.columns,
    required this.rows,
    this.header,
    this.footer,
    this.onRowTap,
    this.onExportCsv,
    this.onExportJson,
    this.showPagination = false,
    this.initialRowsPerPage = 50,
    this.availableRowsPerPage = const [10, 25, 50, 100],
  });

  @override
  State<DataTable2Widget> createState() => _DataTable2WidgetState();
}

class _DataTable2WidgetState extends State<DataTable2Widget> {
  late int _rowsPerPage;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _rowsPerPage = widget.initialRowsPerPage;
    _currentPage = 0;
  }

  List<Map<String, dynamic>> get _currentRows {
    if (!widget.showPagination) {
      return widget.rows;
    }

    final totalRows = widget.rows.length;
    final totalPages = (totalRows / _rowsPerPage).ceil();
    final clampedPage = _currentPage.clamp(0, totalPages - 1);
    final startIndex = clampedPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, totalRows);

    return widget.rows.sublist(startIndex, endIndex);
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

    String text;
    final isBit = widget.columns.any((col) => col.isBit);

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
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildPaginationControls() {
    final totalRows = widget.rows.length;
    final totalPages = (totalRows / _rowsPerPage).ceil();

    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
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
            items: widget.availableRowsPerPage.map((value) {
              return DropdownMenuItem(value: value, child: Text('$value rows'));
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final minColWidth = 120.0;
    final calculatedMinWidth = (widget.columns.length * minColWidth).toDouble();
    final actualMinWidth = calculatedMinWidth < 600
        ? 600.0
        : calculatedMinWidth;
    final currentRows = _currentRows;

    return Column(
      children: [
        if (widget.header != null) widget.header!,
        Expanded(
          child: DataTable2(
            columnSpacing: 12,
            horizontalMargin: 12,
            minWidth: actualMinWidth,
            headingRowColor: WidgetStateColor.resolveWith(
              (states) => const Color(0xFF1E293B),
            ),
            columns: widget.columns.map((col) {
              return DataColumn2(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (col.isPrimaryKey)
                      Icon(Icons.key, size: 14, color: Colors.yellow[700]),
                    if (col.isPrimaryKey) const SizedBox(width: 4),
                    if (col.isBit)
                      Icon(Icons.toggle_on, size: 14, color: Colors.blue[400]),
                    if (col.isBit) const SizedBox(width: 4),
                    if (col.isBinary)
                      Icon(
                        Icons.data_object,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                    if (col.isBinary) const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        col.name.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                size: ColumnSize.M,
              );
            }).toList(),
            rows: List<DataRow>.generate(currentRows.length, (index) {
              final row = currentRows[index];
              final originalIndex = widget.showPagination
                  ? _currentPage * _rowsPerPage + index
                  : index;

              return DataRow(
                cells: widget.columns.map((col) {
                  return DataCell(
                    GestureDetector(
                      onTap: widget.onRowTap != null
                          ? () => widget.onRowTap!(originalIndex)
                          : null,
                      child: _buildCellContent(row[col.name]),
                    ),
                  );
                }).toList(),
              );
            }),
          ),
        ),
        if (widget.footer != null) widget.footer!,
        if (widget.showPagination) _buildPaginationControls(),
      ],
    );
  }
}
