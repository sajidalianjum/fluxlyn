import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'edit_confirmation_dialog.dart';
import '../../../../core/services/query_protection_service.dart';
import '../../../settings/providers/settings_provider.dart';

class FieldEditor extends StatelessWidget {
  final String column;
  final String? primaryKeyColumn;
  final List<String> binaryColumns;
  final List<String> bitColumns;
  final Map<String, List<String>> enumColumns;
  final Map<String, List<String>> setColumns;
  final TextEditingController controller;
  final bool isNull;
  final bool isReadOnly;
  final dynamic value;
  final Set<String>? setSelectedValues;
  final VoidCallback onUnsetNull;
  final VoidCallback onShowSetNullDialog;
  final VoidCallback onCheckForChanges;
  final VoidCallback? onCopy;

  const FieldEditor({
    super.key,
    required this.column,
    required this.primaryKeyColumn,
    required this.binaryColumns,
    required this.bitColumns,
    required this.enumColumns,
    required this.setColumns,
    required this.controller,
    required this.isNull,
    required this.isReadOnly,
    required this.value,
    this.setSelectedValues,
    required this.onUnsetNull,
    required this.onShowSetNullDialog,
    required this.onCheckForChanges,
    this.onCopy,
  });

  bool get isPK =>
      column == primaryKeyColumn ||
      primaryKeyColumn?.toLowerCase() == column.toLowerCase();

  bool get isBinary =>
      binaryColumns.contains(column) ||
      binaryColumns.any((c) => c.toLowerCase() == column.toLowerCase());

  bool get isEnum => enumColumns.containsKey(column);

  bool get isSet => setColumns.containsKey(column);

  bool get isBit =>
      bitColumns.contains(column) ||
      bitColumns.any((c) => c.toLowerCase() == column.toLowerCase()) ||
      (value is List<int> &&
          value.length == 1 &&
          (value[0] == 0 || value[0] == 1));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldHeader(theme, isDark),
          const SizedBox(height: 4),
          _buildFieldContent(context, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildFieldHeader(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Text(
          column,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isPK ? Colors.yellow[700] : theme.colorScheme.onSurface,
          ),
        ),
        if (isPK) ...[
          const SizedBox(width: 4),
          const Icon(Icons.key, size: 14, color: Color(0xFFFFD700)),
        ],
        if (isBinary) ...[
          const SizedBox(width: 4),
          Icon(Icons.data_object, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ],
        if (isBit) ...[
          const SizedBox(width: 4),
          const Icon(Icons.toggle_on, size: 14, color: Color(0xFF60A5FA)),
        ],
        if (isEnum) ...[
          const SizedBox(width: 4),
          const Icon(Icons.list, size: 14, color: Color(0xFFC084FC)),
        ],
        if (isSet) ...[
          const SizedBox(width: 4),
          const Icon(Icons.check_box, size: 14, color: Color(0xFF4ADE80)),
        ],
        if (onCopy != null && !isBinary && !isNull)
          IconButton(
            icon: Icon(Icons.copy, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            onPressed: onCopy,
            tooltip: 'Copy to clipboard',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            splashRadius: 16,
          ),
        const Spacer(),
        if (isNull)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'NULL',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFieldContent(BuildContext context, ThemeData theme, bool isDark) {
    if (isBit) {
      return isNull ? _buildBitNullPlaceholder(theme, isDark) : _buildBitDropdown(theme, isDark);
    }
    if (isEnum) {
      return isNull ? _buildEnumNullPlaceholder(theme, isDark) : _buildEnumDropdown(theme, isDark);
    }
    if (isSet) {
      return isNull ? _buildSetNullPlaceholder(theme, isDark) : _buildSetMultiSelect(theme, isDark);
    }
    return _buildTextFormField(theme, isDark);
  }

  Widget _buildTextFormField(ThemeData theme, bool isDark) {
    final fillColor = isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final hintColor = isDark ? const Color(0xFF4B5563) : Colors.grey.shade500;
    final readonlyColor = isDark ? const Color(0xFF6B7280) : Colors.grey.shade600;

    return GestureDetector(
      onLongPress: isReadOnly
          ? null
          : () {
              if (isNull) {
                onUnsetNull();
              } else {
                onShowSetNullDialog();
              }
            },
      child: TextFormField(
        controller: controller,
        enabled: !isReadOnly,
        readOnly: isReadOnly,
        style: TextStyle(
          color: isReadOnly ? readonlyColor : textColor,
          fontFamily: value is String && value.length > 50 ? 'monospace' : null,
        ),
        maxLines: value is String && value.length > 100 ? 3 : 1,
        decoration: InputDecoration(
          hintText: isReadOnly
              ? (isPK ? 'Primary Key (read-only)' : 'Binary data (read-only)')
              : (isNull ? 'Click to enter value...' : 'Enter value...'),
          hintStyle: TextStyle(color: hintColor),
          filled: true,
          fillColor: fillColor,
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
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          suffixIcon: isReadOnly
              ? Icon(Icons.lock, size: 16, color: readonlyColor)
              : isNull
              ? IconButton(
                  icon: Icon(Icons.edit, size: 16, color: readonlyColor),
                  onPressed: onUnsetNull,
                  tooltip: 'Edit value',
                )
              : IconButton(
                  icon: Icon(Icons.delete_outline, size: 16, color: readonlyColor),
                  onPressed: onShowSetNullDialog,
                  tooltip: 'Set to NULL',
                ),
        ),
        onChanged: (text) {
          if (isNull && text.isNotEmpty) {
            onUnsetNull();
          }
          onCheckForChanges();
        },
      ),
    );
  }

  Widget _buildBitNullPlaceholder(ThemeData theme, bool isDark) {
    final fillColor = isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface;
    final hintColor = isDark ? const Color(0xFF4B5563) : Colors.grey.shade500;
    final iconColor = isDark ? const Color(0xFF6B7280) : Colors.grey.shade600;

    return InkWell(
      onTap: onUnsetNull,
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: fillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          suffixIcon: IconButton(
            icon: Icon(Icons.edit, size: 16, color: iconColor),
            onPressed: onUnsetNull,
            tooltip: 'Select value',
          ),
        ),
        child: Text('Click to select value...', style: TextStyle(color: hintColor)),
      ),
    );
  }

  Widget _buildBitDropdown(ThemeData theme, bool isDark) {
    final currentValue = controller.text;
    final intValue = int.tryParse(currentValue) ?? 0;
    final fillColor = isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final dropdownColor = isDark ? const Color(0xFF1E293B) : Colors.grey.shade100;
    final iconColor = isDark ? const Color(0xFF6B7280) : Colors.grey.shade600;

    return DropdownButtonFormField<int>(
      initialValue: intValue,
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor,
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
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1),
        ),
        suffixIcon: IconButton(
          icon: Icon(Icons.delete_outline, size: 16, color: iconColor),
          onPressed: onShowSetNullDialog,
          tooltip: 'Set to NULL',
        ),
      ),
      dropdownColor: dropdownColor,
      style: TextStyle(color: textColor),
      items: const [
        DropdownMenuItem(value: 0, child: Text('0')),
        DropdownMenuItem(value: 1, child: Text('1')),
      ],
      onChanged: (newValue) {
        if (newValue != null) {
          controller.text = newValue.toString();
          onCheckForChanges();
        }
      },
    );
  }

  Widget _buildEnumNullPlaceholder(ThemeData theme, bool isDark) {
    final fillColor = isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface;
    final hintColor = isDark ? const Color(0xFF4B5563) : Colors.grey.shade500;
    final iconColor = isDark ? const Color(0xFF6B7280) : Colors.grey.shade600;

    return InkWell(
      onTap: onUnsetNull,
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: fillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          suffixIcon: IconButton(
            icon: Icon(Icons.edit, size: 16, color: iconColor),
            onPressed: onUnsetNull,
            tooltip: 'Select value',
          ),
        ),
        child: Text('Click to select value...', style: TextStyle(color: hintColor)),
      ),
    );
  }

  Widget _buildEnumDropdown(ThemeData theme, bool isDark) {
    final currentValue = controller.text;
    final enumValues = enumColumns[column]!;
    final initialValue = enumValues.contains(currentValue) ? currentValue : null;
    final fillColor = isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final dropdownColor = isDark ? const Color(0xFF1E293B) : Colors.grey.shade100;
    final iconColor = isDark ? const Color(0xFF6B7280) : Colors.grey.shade600;

    return DropdownButtonFormField<String>(
      value: initialValue,
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor,
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
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1),
        ),
        suffixIcon: IconButton(
          icon: Icon(Icons.delete_outline, size: 16, color: iconColor),
          onPressed: onShowSetNullDialog,
          tooltip: 'Set to NULL',
        ),
      ),
      dropdownColor: dropdownColor,
      style: TextStyle(color: textColor),
      hint: Text('Select a value', style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600)),
      items: enumValues.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
      onChanged: (newValue) {
        if (newValue != null) {
          controller.text = newValue;
          onCheckForChanges();
        }
      },
    );
  }

  Widget _buildSetNullPlaceholder(ThemeData theme, bool isDark) {
    final fillColor = isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface;
    final hintColor = isDark ? const Color(0xFF4B5563) : Colors.grey.shade500;
    final iconColor = isDark ? const Color(0xFF6B7280) : Colors.grey.shade600;

    return InkWell(
      onTap: onUnsetNull,
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: fillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          suffixIcon: IconButton(
            icon: Icon(Icons.edit, size: 16, color: iconColor),
            onPressed: onUnsetNull,
            tooltip: 'Select values',
          ),
        ),
        child: Text('Click to select values...', style: TextStyle(color: hintColor)),
      ),
    );
  }

  Widget _buildSetMultiSelect(ThemeData theme, bool isDark) {
    final setValues = setColumns[column]!;
    final selectedValues = setSelectedValues ?? <String>{};
    final bgColor = isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface;
    final chipBgColor = isDark ? const Color(0xFF1F2937) : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final unselectedColor = isDark ? const Color(0xFF9CA3AF) : Colors.grey.shade600;
    final iconColor = isDark ? const Color(0xFF6B7280) : Colors.grey.shade600;
    final borderColor = isDark ? const Color(0xFF1F2937) : Colors.grey.shade300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
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
                  if (selected) {
                    selectedValues.add(value);
                  } else {
                    selectedValues.remove(value);
                  }
                  onCheckForChanges();
                },
                checkmarkColor: textColor,
                selectedColor: Colors.green.withValues(alpha: 0.3),
                backgroundColor: chipBgColor,
                labelStyle: TextStyle(color: isSelected ? textColor : unselectedColor),
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
                  icon: Icon(Icons.delete_outline, size: 16, color: iconColor),
                  onPressed: onShowSetNullDialog,
                  tooltip: 'Set to NULL',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

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
        final isBitCol =
            widget.bitColumns.contains(col) ||
            widget.bitColumns.any((c) => c.toLowerCase() == col.toLowerCase());
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
            final inner = value.substring(1, value.length - 1);
            final intValue = int.tryParse(inner.trim());
            textValue = (intValue ?? 0).toString();
          } else {
            textValue = value.toString();
          }
          _controllers[col] = TextEditingController(text: textValue);
          _originalValues[col] = int.tryParse(textValue) ?? 0;
        } else if (widget.setColumns.containsKey(col)) {
          final setValues = widget.setColumns[col]!;
          _controllers[col] = TextEditingController(text: value.toString());
          if (value is String && value.isNotEmpty) {
            final selectedValues = value
                .split(',')
                .map((v) => v.trim())
                .where((v) => v.isNotEmpty)
                .toSet();
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
              ? originalValue
                    .split(',')
                    .map((v) => v.trim())
                    .where((v) => v.isNotEmpty)
                    .toSet()
              : <String>{};
          if (!_setEquals(originalSetValues, _setSelectedValues[col]!)) {
            hasChanges = true;
            break;
          }
        }
      } else {
        final textValue = _controllers[col]?.text ?? '';
        if (originalValue == null && !isNowNull) {
          hasChanges = true;
          break;
        } else if (originalValue != null && isNowNull) {
          hasChanges = true;
          break;
        } else if (originalValue != null && !isNowNull) {
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
        if (originalValue == null &&
            !isNowNull &&
            _setSelectedValues[col]!.isNotEmpty) {
          changes[col] = _setSelectedValues[col]!.join(',');
        } else if (originalValue != null && isNowNull) {
          changes[col] = null;
        } else if (originalValue != null && !isNowNull) {
          final originalSetValues = originalValue is String
              ? originalValue
                    .split(',')
                    .map((v) => v.trim())
                    .where((v) => v.isNotEmpty)
                    .toSet()
              : <String>{};
          if (!_setEquals(originalSetValues, _setSelectedValues[col]!)) {
            changes[col] = _setSelectedValues[col]!.join(',');
          }
        }
      } else {
        final textValue = _controllers[col]?.text ?? '';
        if (originalValue == null && !isNowNull) {
          changes[col] = _convertValue(textValue, originalValue, col);
        } else if (originalValue != null && isNowNull) {
          changes[col] = null;
        } else if (originalValue != null && !isNowNull) {
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

    final isBitCol =
        widget.bitColumns.contains(column) ||
        widget.bitColumns.any((c) => c.toLowerCase() == column.toLowerCase());
    final isBitValue =
        originalValue is List<int> &&
        originalValue.length == 1 &&
        (originalValue[0] == 0 || originalValue[0] == 1);
    if (isBitCol || isBitValue) {
      return int.tryParse(text) ?? (text == '1' ? 1 : 0);
    }

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

  void _copyFieldValue(String column) {
    final value = widget.row[column];
    String textToCopy;

    if (value == null) {
      textToCopy = 'NULL';
    } else if (widget.setColumns.containsKey(column)) {
      final selectedValues = _setSelectedValues[column] ?? <String>{};
      textToCopy = selectedValues.join(',');
    } else {
      textToCopy = _controllers[column]?.text ?? value.toString();
    }

    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$column copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = context.read<SettingsProvider>();
    final settings = settingsProvider.settings;
    final protectionError = QueryProtectionService.checkEditOperation(
      settings.readOnlyMode,
      settings.lock,
    );

    final canEdit = widget.primaryKeyColumn != null && protectionError == null;
    final readOnlyOnlyError = settings.readOnlyMode && !settings.lock;

    return Dialog.fullscreen(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
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
                        readOnlyOnlyError
                            ? 'Read-only mode is active'
                            : (protectionError ?? 'Editing is not available'),
                        style: TextStyle(color: Colors.orange[400]),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.columns.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Text('Row Data', style: theme.textTheme.titleLarge);
                  }
                  if (index == 1) {
                    return const SizedBox(height: 16);
                  }

                  final col = widget.columns[index - 2];
                  final isPK =
                      col == widget.primaryKeyColumn ||
                      widget.primaryKeyColumn?.toLowerCase() ==
                          col.toLowerCase();
                  final isBinary =
                      widget.binaryColumns.contains(col) ||
                      widget.binaryColumns.any(
                        (c) => c.toLowerCase() == col.toLowerCase(),
                      );
                  final value = widget.row[col];
                  final isReadOnly = isPK || isBinary;

                  return RepaintBoundary(
                    child: FieldEditor(
                      key: ValueKey(col),
                      column: col,
                      primaryKeyColumn: widget.primaryKeyColumn,
                      binaryColumns: widget.binaryColumns,
                      bitColumns: widget.bitColumns,
                      enumColumns: widget.enumColumns,
                      setColumns: widget.setColumns,
                      controller: _controllers[col]!,
                      isNull: _isNull[col] ?? false,
                      isReadOnly: isReadOnly,
                      value: value,
                      setSelectedValues: widget.setColumns.containsKey(col)
                          ? _setSelectedValues[col]
                          : null,
                      onUnsetNull: () => _unsetNull(col),
                      onShowSetNullDialog: () => _showSetNullDialog(col),
                      onCheckForChanges: _checkForChanges,
                      onCopy: () => _copyFieldValue(col),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetNullDialog(String column) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
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
