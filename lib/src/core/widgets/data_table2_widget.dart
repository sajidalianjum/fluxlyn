import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

class DataTableColumn {
  final String name;
  final bool isPrimaryKey;
  final bool isBinary;
  final bool isBit;
  final bool isEnum;
  final bool isSet;

  DataTableColumn({
    required this.name,
    this.isPrimaryKey = false,
    this.isBinary = false,
    this.isBit = false,
    this.isEnum = false,
    this.isSet = false,
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

  List<DataTableColumn> _getCardDisplayColumns() {
    final displayCols = <DataTableColumn>[];

    for (final col in widget.columns) {
      if (displayCols.length >= 6) break;
      if (col.isBinary) continue;
      displayCols.add(col);
    }

    return displayCols;
  }

  String? _getTitleColumn() {
    for (final col in widget.columns) {
      if (col.isPrimaryKey) continue;
      if (col.isBinary) continue;
      final firstValue = widget.rows.isNotEmpty
          ? widget.rows[0][col.name]
          : null;
      if (firstValue is String) return col.name;
    }
    return null;
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

  Widget _buildCardView(int displayIndex) {
    final displayCols = _getCardDisplayColumns();
    final titleCol = _getTitleColumn();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _currentRows.length,
      itemBuilder: (context, index) {
        final row = _currentRows[index];
        final originalIndex = widget.showPagination
            ? _currentPage * _rowsPerPage + index
            : index;
        final title = titleCol != null ? row[titleCol]?.toString() : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: const Color(0xFF1E293B),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: widget.onRowTap != null
                ? () => widget.onRowTap!(originalIndex)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
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

                  // Display first 6 columns
                  ...displayCols.map((col) {
                    final isPK = col.isPrimaryKey;
                    final isBit = col.isBit;
                    final isEnum = col.isEnum;
                    final isSet = col.isSet;
                    final value = row[col.name];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                if (isEnum)
                                  Icon(
                                    Icons.list,
                                    size: 12,
                                    color: Colors.purple[400],
                                  ),
                                if (isSet)
                                  Icon(
                                    Icons.checklist,
                                    size: 12,
                                    color: Colors.orange[400],
                                  ),
                                if (isPK || isBit || isEnum || isSet)
                                  const SizedBox(width: 4),
                                Text(
                                  col.name,
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
                          Expanded(child: _buildCardValue(value, isBit: isBit)),
                        ],
                      ),
                    );
                  }),

                  // Action hint
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.touch_app, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to edit/view details',
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

  Widget _buildCellContent(
    dynamic value, {
    bool isBinary = false,
    bool isBit = false,
  }) {
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

    if (isBinary) {
      // Binary data should already be formatted as hex string (e.g., "0xAABB...")
      if (value is String && value.startsWith('0x')) {
        text = value;
      } else if (value is List<int>) {
        // Format raw bytes as hex
        final hexStr = value
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        if (hexStr.length > 16) {
          text =
              '0x${hexStr.substring(0, 16)}... (${hexStr.length ~/ 2} bytes)';
        } else if (hexStr.isEmpty) {
          text = '0x';
        } else {
          text = '0x$hexStr';
        }
      } else {
        text = '<binary data>';
      }
    } else if (isBit && value is List<int>) {
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

  Widget _buildTableView(int displayIndex) {
    final minColWidth = 120.0;
    final calculatedMinWidth = (widget.columns.length * minColWidth).toDouble();
    final actualMinWidth = calculatedMinWidth < 600
        ? 600.0
        : calculatedMinWidth;

    return DataTable2(
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
                Icon(Icons.data_object, size: 14, color: Colors.grey[500]),
              if (col.isBinary) const SizedBox(width: 4),
              if (col.isEnum)
                Icon(Icons.list, size: 14, color: Colors.purple[400]),
              if (col.isEnum) const SizedBox(width: 4),
              if (col.isSet)
                Icon(Icons.checklist, size: 14, color: Colors.orange[400]),
              if (col.isSet) const SizedBox(width: 4),
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
      rows: List<DataRow>.generate(_currentRows.length, (index) {
        final row = _currentRows[index];
        final originalIndex = widget.showPagination
            ? _currentPage * _rowsPerPage + index
            : index;

        return DataRow(
          onSelectChanged: widget.onRowTap != null
              ? (_) => widget.onRowTap!(originalIndex)
              : null,
          cells: widget.columns.map((col) {
            return DataCell(
              _buildCellContent(
                row[col.name],
                isBinary: col.isBinary,
                isBit: col.isBit,
              ),
            );
          }).toList(),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useCardView = constraints.maxWidth < 600;

        return Column(
          children: [
            if (widget.header != null) widget.header!,
            Expanded(
              child: useCardView ? _buildCardView(0) : _buildTableView(0),
            ),
            if (widget.footer != null) widget.footer!,
            if (widget.showPagination) _buildPaginationControls(),
          ],
        );
      },
    );
  }
}
