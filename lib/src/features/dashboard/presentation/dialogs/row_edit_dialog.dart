import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'edit_confirmation_dialog.dart';
import '../../../../core/services/query_protection_service.dart';
import '../../../settings/providers/settings_provider.dart';

class RowEditDialog extends StatefulWidget {
  final String tableName;
  final List<String> columns;
  final Map<String, dynamic> row;
  final String? primaryKeyColumn;
  final dynamic primaryKeyValue;
  final List<String> binaryColumns;
  final List<String> bitColumns;
  final Map<String, List<String>> enumColumns;
  final Map<String, List<String>> setColumns;
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
    this.primaryKeyValue,
    this.binaryColumns = const [],
    this.bitColumns = const [],
    this.enumColumns = const {},
    this.setColumns = const {},
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
  late Map<String, Set<String>> _setSelectedValues;
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
    _setSelectedValues = {};

    for (final col in widget.columns) {
      final value = widget.row[col];
      _originalValues[col] = value;

      if (value == null) {
        _isNull[col] = true;
        _controllers[col] = TextEditingController(text: '');
        if (widget.setColumns.containsKey(col)) {
          _setSelectedValues[col] = {};
        }
      } else {
        _isNull[col] = false;
        // Handle BIT columns - ensure they're integers
        final isBitCol =
            widget.bitColumns.contains(col) ||
            widget.bitColumns.any((c) => c.toLowerCase() == col.toLowerCase());
        // Detect by value pattern - if value is List<int> with single 0 or 1, treat as BIT
        final isBitValue =
            value is List<int> &&
            value.length == 1 &&
            (value[0] == 0 || value[0] == 1);
        if (isBitCol || isBitValue) {
          String textValue;
          if (value is List<int>) {
            textValue = value.isNotEmpty ? value.first.toString() : '0';
          } else if (value is String &&
              value.startsWith('[') &&
              value.endsWith(']')) {
            // Handle string representation like "[0]" or "[1]"
            final inner = value.substring(1, value.length - 1);
            final intValue = int.tryParse(inner.trim());
            textValue = (intValue ?? 0).toString();
          } else {
            textValue = value.toString();
          }
          _controllers[col] = TextEditingController(text: textValue);
          // Also update the original value to be an int for consistency
          _originalValues[col] = int.tryParse(textValue) ?? 0;
        } else if (widget.setColumns.containsKey(col)) {
          // Handle SET columns - parse comma-separated values
          final setValues = widget.setColumns[col]!;
          _controllers[col] = TextEditingController(text: value.toString());
          if (value is String && value.isNotEmpty) {
            final selectedValues = value
                .split(',')
                .map((v) => v.trim())
                .toSet();
            // Only include values that are valid for this SET column
            _setSelectedValues[col] = selectedValues
                .where((v) => setValues.contains(v))
                .toSet();
          } else {
            _setSelectedValues[col] = {};
          }
        } else {
          _controllers[col] = TextEditingController(text: value.toString());
        }
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
      final isPK =
          col == widget.primaryKeyColumn ||
          widget.primaryKeyColumn?.toLowerCase() == col.toLowerCase();
      final isBinary =
          widget.binaryColumns.contains(col) ||
          widget.binaryColumns.any((c) => c.toLowerCase() == col.toLowerCase());
      if (isPK || isBinary) {
        continue;
      }

      final originalValue = _originalValues[col];
      final isNowNull = _isNull[col] ?? false;

      if (widget.setColumns.containsKey(col)) {
        // Handle SET columns specially
        if (originalValue == null &&
            !isNowNull &&
            _setSelectedValues[col]!.isNotEmpty) {
          hasChanges = true;
          break;
        } else if (originalValue != null && isNowNull) {
          hasChanges = true;
          break;
        } else if (originalValue != null && !isNowNull) {
          final originalSetValues = originalValue is String
              ? originalValue.split(',').map((v) => v.trim()).toSet()
              : <String>{};
          if (!_setEquals(originalSetValues, _setSelectedValues[col]!)) {
            hasChanges = true;
            break;
          }
        }
      } else {
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
    }

    setState(() {
      _hasChanges = hasChanges;
    });
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.every((element) => b.contains(element));
  }

  Map<String, dynamic> _collectChanges() {
    final changes = <String, dynamic>{};

    for (final col in widget.columns) {
      // Skip primary key and binary columns (but not BIT columns)
      final isPK =
          col == widget.primaryKeyColumn ||
          widget.primaryKeyColumn?.toLowerCase() == col.toLowerCase();
      final isBinary =
          widget.binaryColumns.contains(col) ||
          widget.binaryColumns.any((c) => c.toLowerCase() == col.toLowerCase());
      if (isPK || isBinary) {
        continue;
      }

      final originalValue = _originalValues[col];
      final isNowNull = _isNull[col] ?? false;

      if (widget.setColumns.containsKey(col)) {
        // Handle SET columns
        if (originalValue == null &&
            !isNowNull &&
            _setSelectedValues[col]!.isNotEmpty) {
          // Was NULL, now has value
          changes[col] = _setSelectedValues[col]!.join(',');
        } else if (originalValue != null && isNowNull) {
          // Had value, now NULL
          changes[col] = null;
        } else if (originalValue != null && !isNowNull) {
          // Both have values, check if changed
          final originalSetValues = originalValue is String
              ? originalValue.split(',').map((v) => v.trim()).toSet()
              : <String>{};
          if (!_setEquals(originalSetValues, _setSelectedValues[col]!)) {
            changes[col] = _setSelectedValues[col]!.join(',');
          }
        }
      } else {
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
    }

    return changes;
  }

  dynamic _convertValue(String text, dynamic originalValue, String column) {
    if (text.isEmpty) return null;

    // Handle BIT columns
    final isBitCol =
        widget.bitColumns.contains(column) ||
        widget.bitColumns.any((c) => c.toLowerCase() == column.toLowerCase());
    // Also check if original value is a BIT pattern
    final isBitValue =
        originalValue is List<int> &&
        originalValue.length == 1 &&
        (originalValue[0] == 0 || originalValue[0] == 1);
    if (isBitCol || isBitValue) {
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
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
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _hasChanges && canEdit ? _saveChanges : null,
                    child: const Text('Save'),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Status bar
            if (!canEdit)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.orange.withValues(alpha: 0.1),
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
              child: ListView(
                padding: const EdgeInsets.all(16),
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
          ],
        ),
      ),
    );
  }

  Widget _buildField(String column) {
    final isPK = column == widget.primaryKeyColumn;
    final isBinary =
        widget.binaryColumns.contains(column) ||
        widget.binaryColumns.any(
          (c) => c.toLowerCase() == column.toLowerCase(),
        );
    final isEnum = widget.enumColumns.containsKey(column);
    final isSet = widget.setColumns.containsKey(column);
    final value = widget.row[column];
    // Detect BIT columns: either in list OR value is List<int> with 0/1
    final isBit =
        widget.bitColumns.contains(column) ||
        widget.bitColumns.any((c) => c.toLowerCase() == column.toLowerCase()) ||
        (value is List<int> &&
            value.length == 1 &&
            (value[0] == 0 || value[0] == 1));
    final isReadOnly = isPK || isBinary;
    final isNull = _isNull[column] ?? false;

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
              if (isEnum) ...[
                const SizedBox(width: 4),
                Icon(Icons.list, size: 14, color: Colors.purple[400]),
              ],
              if (isSet) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_box, size: 14, color: Colors.green[400]),
              ],
              const Spacer(),
              if (isNull)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
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
          if (isBit)
            isNull
                ? _buildBitNullPlaceholder(column)
                : _buildBitDropdown(column)
          else if (isEnum)
            isNull
                ? _buildEnumNullPlaceholder(column)
                : _buildEnumDropdown(column)
          else if (isSet)
            isNull
                ? _buildSetNullPlaceholder(column)
                : _buildSetMultiSelect(column)
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
                enabled: !isReadOnly,
                readOnly: isReadOnly,
                style: TextStyle(
                  color: isReadOnly ? Colors.grey[500] : Colors.white,
                  fontFamily: value is String && value.length > 50
                      ? 'monospace'
                      : null,
                ),
                maxLines: value is String && value.length > 100 ? 3 : 1,
                onTap: !isReadOnly && isNull ? () => _unsetNull(column) : null,
                decoration: InputDecoration(
                  hintText: isReadOnly
                      ? (isPK
                            ? 'Primary Key (read-only)'
                            : 'Binary data (read-only)')
                      : (isNull ? 'Click to enter value...' : 'Enter value...'),
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
                onChanged: (text) {
                  if (isNull && text.isNotEmpty) {
                    _unsetNull(column);
                  }
                  _checkForChanges();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBitNullPlaceholder(String column) {
    return InkWell(
      onTap: () => _unsetNull(column),
      child: InputDecorator(
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
          suffixIcon: IconButton(
            icon: Icon(Icons.edit, size: 16, color: Colors.grey[500]),
            onPressed: () => _unsetNull(column),
            tooltip: 'Select value',
          ),
        ),
        child: Text(
          'Click to select value...',
          style: TextStyle(color: Colors.grey[600]),
        ),
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

  Widget _buildEnumNullPlaceholder(String column) {
    return InkWell(
      onTap: () => _unsetNull(column),
      child: InputDecorator(
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
          suffixIcon: IconButton(
            icon: Icon(Icons.edit, size: 16, color: Colors.grey[500]),
            onPressed: () => _unsetNull(column),
            tooltip: 'Select value',
          ),
        ),
        child: Text(
          'Click to select value...',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildEnumDropdown(String column) {
    final currentValue = _controllers[column]?.text ?? '';
    final enumValues = widget.enumColumns[column]!;

    return DropdownButtonFormField<String>(
      value: enumValues.contains(currentValue) ? currentValue : null,
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
      hint: const Text('Select a value', style: TextStyle(color: Colors.grey)),
      items: enumValues
          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
          .toList(),
      onChanged: (newValue) {
        if (newValue != null) {
          _controllers[column]?.text = newValue;
          _checkForChanges();
        }
      },
    );
  }

  Widget _buildSetNullPlaceholder(String column) {
    return InkWell(
      onTap: () => _unsetNull(column),
      child: InputDecorator(
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
          suffixIcon: IconButton(
            icon: Icon(Icons.edit, size: 16, color: Colors.grey[500]),
            onPressed: () => _unsetNull(column),
            tooltip: 'Select values',
          ),
        ),
        child: Text(
          'Click to select values...',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildSetMultiSelect(String column) {
    final setValues = widget.setColumns[column]!;
    final selectedValues = _setSelectedValues[column]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: setValues.map((value) {
              final isSelected = selectedValues.contains(value);
              return FilterChip(
                label: Text(value),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _setSelectedValues[column]!.add(value);
                    } else {
                      _setSelectedValues[column]!.remove(value);
                    }
                    _checkForChanges();
                  });
                },
                checkmarkColor: Colors.white,
                selectedColor: Colors.green.withValues(alpha: 0.3),
                backgroundColor: Colors.grey[800],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[400],
                ),
                side: BorderSide.none,
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (selectedValues.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  onPressed: () => _showSetNullDialog(column),
                  tooltip: 'Set to NULL',
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
    // Check query protection settings
    final settingsProvider = context.read<SettingsProvider>();
    final settings = settingsProvider.settings;
    final protectionError = QueryProtectionService.checkEditOperation(
      settings.readOnlyMode,
      settings.lock,
    );

    if (protectionError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(protectionError),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final changes = _collectChanges();
    if (changes.isNotEmpty && widget.primaryKeyColumn != null) {
      showDialog(
        context: context,
        builder: (context) => EditConfirmationDialog(
          tableName: widget.tableName,
          primaryKeyColumn: widget.primaryKeyColumn!,
          primaryKeyValue: widget.primaryKeyValue,
          updates: changes,
          onConfirm: () {
            Navigator.of(context).pop();
            widget.onSave(changes);
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        ),
      );
    } else if (changes.isNotEmpty) {
      widget.onSave(changes);
    }
  }
}
