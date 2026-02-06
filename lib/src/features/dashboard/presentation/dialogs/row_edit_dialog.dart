import 'package:flutter/material.dart';

class RowEditDialog extends StatefulWidget {
  final String tableName;
  final List<String> columns;
  final Map<String, dynamic> row;
  final String? primaryKeyColumn;
  final List<String> binaryColumns;
  final List<String> bitColumns;
  final int currentRowIndex;
  final int totalRows;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCancel;
  final Function(Map<String, dynamic>) onSave;

  const RowEditDialog({
    super.key,
    required this.tableName,
    required this.columns,
    required this.row,
    this.primaryKeyColumn,
    this.binaryColumns = const [],
    this.bitColumns = const [],
    required this.currentRowIndex,
    required this.totalRows,
    required this.onPrevious,
    required this.onNext,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<RowEditDialog> createState() => _RowEditDialogState();
}

class _RowEditDialogState extends State<RowEditDialog> {
  late Map<String, TextEditingController> _controllers;
  late Map<String, bool> _isNull;
  late Map<String, dynamic> _originalValues;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void didUpdateWidget(RowEditDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reinitialize when row changes (for Previous/Next navigation)
    if (oldWidget.row != widget.row) {
      _disposeControllers();
      _initializeControllers();
    }
  }

  void _initializeControllers() {
    _controllers = {};
    _isNull = {};
    _originalValues = {};

    for (final col in widget.columns) {
      final value = widget.row[col];
      _originalValues[col] = value;

      if (value == null) {
        _isNull[col] = true;
        _controllers[col] = TextEditingController(text: '');
      } else {
        _isNull[col] = false;
        _controllers[col] = TextEditingController(text: value.toString());
      }
    }

    _checkForChanges();
  }

  void _disposeControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _checkForChanges() {
    bool hasChanges = false;

    for (final col in widget.columns) {
      // Skip primary key and binary columns
      if (col == widget.primaryKeyColumn ||
          widget.binaryColumns.contains(col)) {
        continue;
      }

      final originalValue = _originalValues[col];
      final isNowNull = _isNull[col] ?? false;
      final textValue = _controllers[col]?.text ?? '';

      if (originalValue == null && !isNowNull) {
        // Was NULL, now has value
        hasChanges = true;
        break;
      } else if (originalValue != null && isNowNull) {
        // Had value, now NULL
        hasChanges = true;
        break;
      } else if (originalValue != null && !isNowNull) {
        // Both have values, check if changed
        if (originalValue.toString() != textValue) {
          hasChanges = true;
          break;
        }
      }
    }

    setState(() {
      _hasChanges = hasChanges;
    });
  }

  Map<String, dynamic> _collectChanges() {
    final changes = <String, dynamic>{};

    for (final col in widget.columns) {
      // Skip primary key and binary columns (but not BIT columns)
      if (col == widget.primaryKeyColumn ||
          widget.binaryColumns.contains(col)) {
        continue;
      }

      final originalValue = _originalValues[col];
      final isNowNull = _isNull[col] ?? false;
      final textValue = _controllers[col]?.text ?? '';

      if (originalValue == null && !isNowNull) {
        // Was NULL, now has value
        changes[col] = _convertValue(textValue, originalValue, col);
      } else if (originalValue != null && isNowNull) {
        // Had value, now NULL
        changes[col] = null;
      } else if (originalValue != null && !isNowNull) {
        // Both have values, check if changed
        if (originalValue.toString() != textValue) {
          changes[col] = _convertValue(textValue, originalValue, col);
        }
      }
    }

    return changes;
  }

  dynamic _convertValue(String text, dynamic originalValue, String column) {
    if (text.isEmpty) return null;

    // Handle BIT columns
    if (widget.bitColumns.contains(column)) {
      return int.tryParse(text) ?? (text == '1' ? 1 : 0);
    }

    // Try to preserve original type
    if (originalValue is int) {
      return int.tryParse(text) ?? text;
    } else if (originalValue is double) {
      return double.tryParse(text) ?? text;
    } else if (originalValue is bool) {
      return text.toLowerCase() == 'true' || text == '1';
    }
    return text;
  }

  void _setNull(String column) {
    setState(() {
      _isNull[column] = true;
      _controllers[column]?.text = '';
    });
    _checkForChanges();
  }

  void _unsetNull(String column) {
    setState(() {
      _isNull[column] = false;
    });
    _checkForChanges();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canEdit = widget.primaryKeyColumn != null;

    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0F172A),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onCancel,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Row - ${widget.tableName}'),
              Text(
                'Row ${widget.currentRowIndex + 1} of ${widget.totalRows}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            // Previous/Next navigation
            if (widget.totalRows > 1) ...[
              IconButton(
                onPressed: widget.currentRowIndex > 0
                    ? widget.onPrevious
                    : null,
                icon: const Icon(Icons.arrow_back_ios),
                tooltip: 'Previous Row',
              ),
              IconButton(
                onPressed: widget.currentRowIndex < widget.totalRows - 1
                    ? widget.onNext
                    : null,
                icon: const Icon(Icons.arrow_forward_ios),
                tooltip: 'Next Row',
              ),
              const SizedBox(width: 16),
            ],
            // Cancel button
            TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
            const SizedBox(width: 8),
            // Save button
            FilledButton(
              onPressed: _hasChanges && canEdit ? _saveChanges : null,
              child: const Text('Save Changes'),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Column(
          children: [
            // Status bar
            if (!canEdit)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.orange.withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: Colors.orange[400],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Read-only: Table has no primary key',
                        style: TextStyle(color: Colors.orange[400]),
                      ),
                    ),
                  ],
                ),
              ),
            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Row Data', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Long press any field to set it to NULL',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...widget.columns.map((col) => _buildField(col)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String column) {
    final isPK = column == widget.primaryKeyColumn;
    final isBinary = widget.binaryColumns.contains(column);
    final isBit = widget.bitColumns.contains(column);
    final isReadOnly = isPK || isBinary;
    final isNull = _isNull[column] ?? false;
    final value = widget.row[column];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                column,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isPK ? Colors.yellow[700] : Colors.white,
                ),
              ),
              if (isPK) ...[
                const SizedBox(width: 4),
                Icon(Icons.key, size: 14, color: Colors.yellow[700]),
              ],
              if (isBinary) ...[
                const SizedBox(width: 4),
                Icon(Icons.data_object, size: 14, color: Colors.grey[500]),
              ],
              if (isBit) ...[
                const SizedBox(width: 4),
                Icon(Icons.toggle_on, size: 14, color: Colors.blue[400]),
              ],
              const Spacer(),
              if (isNull)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'NULL',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (isBit && !isNull)
            _buildBitDropdown(column)
          else
            GestureDetector(
              onLongPress: isReadOnly
                  ? null
                  : () {
                      if (isNull) {
                        _unsetNull(column);
                      } else {
                        _showSetNullDialog(column);
                      }
                    },
              child: TextFormField(
                controller: _controllers[column],
                enabled: !isReadOnly && !isNull,
                readOnly: isReadOnly,
                style: TextStyle(
                  color: isReadOnly
                      ? Colors.grey[500]
                      : isNull
                      ? Colors.grey[500]
                      : Colors.white,
                  fontFamily: value is String && value.length > 50
                      ? 'monospace'
                      : null,
                ),
                maxLines: value is String && value.length > 100 ? 3 : 1,
                decoration: InputDecoration(
                  hintText: isReadOnly
                      ? (isPK
                            ? 'Primary Key (read-only)'
                            : 'Binary data (read-only)')
                      : (isNull ? 'NULL' : 'Enter value...'),
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.blue, width: 1),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: isReadOnly
                      ? Icon(Icons.lock, size: 16, color: Colors.grey[600])
                      : isNull
                      ? IconButton(
                          icon: Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                          onPressed: () => _unsetNull(column),
                          tooltip: 'Edit value',
                        )
                      : IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                          onPressed: () => _showSetNullDialog(column),
                          tooltip: 'Set to NULL',
                        ),
                ),
                onChanged: (_) => _checkForChanges(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBitDropdown(String column) {
    final currentValue = _controllers[column]?.text ?? '0';
    final intValue = int.tryParse(currentValue) ?? 0;

    return DropdownButtonFormField<int>(
      value: intValue,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue, width: 1),
        ),
        suffixIcon: IconButton(
          icon: Icon(Icons.delete_outline, size: 16, color: Colors.grey[500]),
          onPressed: () => _showSetNullDialog(column),
          tooltip: 'Set to NULL',
        ),
      ),
      dropdownColor: const Color(0xFF1E293B),
      style: const TextStyle(color: Colors.white),
      items: const [
        DropdownMenuItem(value: 0, child: Text('0')),
        DropdownMenuItem(value: 1, child: Text('1')),
      ],
      onChanged: (newValue) {
        if (newValue != null) {
          _controllers[column]?.text = newValue.toString();
          _checkForChanges();
        }
      },
    );
  }

  void _showSetNullDialog(String column) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Set to NULL?'),
        content: Text(
          'Do you want to set "$column" to NULL? This will clear the current value.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _setNull(column);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Set NULL'),
          ),
        ],
      ),
    );
  }

  void _saveChanges() {
    final changes = _collectChanges();
    if (changes.isNotEmpty) {
      widget.onSave(changes);
    }
  }
}
