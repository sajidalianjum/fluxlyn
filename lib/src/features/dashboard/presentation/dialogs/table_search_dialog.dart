import 'package:flutter/material.dart';
import '../../models/table_search_result.dart';

class TableSearchDialog extends StatefulWidget {
  final List<String> columns;
  final TableSearchResult? initialResult;
  final Function(TableSearchResult) onApply;

  const TableSearchDialog({
    super.key,
    required this.columns,
    this.initialResult,
    required this.onApply,
  });

  @override
  State<TableSearchDialog> createState() => _TableSearchDialogState();
}

class _TableSearchDialogState extends State<TableSearchDialog> {
  late String? _searchColumn;
  late TextEditingController _searchController;
  late String? _sortColumn;
  late SortDirection _sortDirection;

  @override
  void initState() {
    super.initState();
    _searchColumn = widget.initialResult?.searchColumn;
    _searchController = TextEditingController(
      text: widget.initialResult?.searchText ?? '',
    );
    _sortColumn = widget.initialResult?.sortColumn;
    _sortDirection = widget.initialResult?.sortDirection ?? SortDirection.asc;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleApply() {
    final result = TableSearchResult(
      searchColumn: _searchColumn?.isEmpty == true ? null : _searchColumn,
      searchText: _searchController.text.isEmpty
          ? null
          : _searchController.text,
      sortColumn: _sortColumn?.isEmpty == true ? null : _sortColumn,
      sortDirection: _sortDirection,
    );
    widget.onApply(result);
    Navigator.of(context).pop();
  }

  void _handleReset() {
    setState(() {
      _searchColumn = null;
      _searchController.clear();
      _sortColumn = null;
      _sortDirection = SortDirection.asc;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Search & Filter',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _searchColumn,
                      decoration: const InputDecoration(
                        labelText: 'Column',
                        border: OutlineInputBorder(),
                      ),
                      dropdownColor: const Color(0xFF0F172A),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...widget.columns.map((col) {
                          return DropdownMenuItem<String>(
                            value: col,
                            child: Text(col),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _searchColumn = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Value (supports LIKE pattern)',
                        border: OutlineInputBorder(),
                        hintText: 'Enter search value...',
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Sort',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _sortColumn,
                      decoration: const InputDecoration(
                        labelText: 'Column',
                        border: OutlineInputBorder(),
                      ),
                      dropdownColor: const Color(0xFF0F172A),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...widget.columns.map((col) {
                          return DropdownMenuItem<String>(
                            value: col,
                            child: Text(col),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sortColumn = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<SortDirection>(
                      segments: const [
                        ButtonSegment(
                          value: SortDirection.asc,
                          label: Text('ASC'),
                          icon: Icon(Icons.arrow_upward, size: 16),
                        ),
                        ButtonSegment(
                          value: SortDirection.desc,
                          label: Text('DESC'),
                          icon: Icon(Icons.arrow_downward, size: 16),
                        ),
                      ],
                      selected: {_sortDirection},
                      onSelectionChanged: (Set<SortDirection> selected) {
                        setState(() {
                          _sortDirection = selected.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _handleReset, child: const Text('Reset')),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _handleApply,
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
