import 'package:flutter/material.dart';

class EditConfirmationDialog extends StatelessWidget {
  final String tableName;
  final String primaryKeyColumn;
  final dynamic primaryKeyValue;
  final Map<String, dynamic> updates;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const EditConfirmationDialog({
    super.key,
    required this.tableName,
    required this.primaryKeyColumn,
    required this.primaryKeyValue,
    required this.updates,
    required this.onConfirm,
    required this.onCancel,
  });

  String get _sqlPreview {
    final setClauses = <String>[];
    for (final entry in updates.entries) {
      if (entry.value == null) {
        setClauses.add('`${entry.key}` = NULL');
      } else if (entry.value is String) {
        final escaped = (entry.value as String).replaceAll("'", "''");
        setClauses.add('`${entry.key}` = \'$escaped\'');
      } else if (entry.value is DateTime) {
        final formatted = (entry.value as DateTime).toIso8601String();
        setClauses.add('`${entry.key}` = \'$formatted\'');
      } else {
        setClauses.add('`${entry.key}` = ${entry.value}');
      }
    }

    String whereClause;
    if (primaryKeyValue is String) {
      final escaped = (primaryKeyValue as String).replaceAll("'", "''");
      whereClause = '`$primaryKeyColumn` = \'$escaped\'';
    } else {
      whereClause = '`$primaryKeyColumn` = $primaryKeyValue';
    }

    return 'UPDATE `$tableName`\nSET ${setClauses.join(', ')}\nWHERE $whereClause';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Confirm Changes',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'You are about to update a row in table "$tableName". This action cannot be undone.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'SQL Preview:',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.grey.withValues(alpha: 0.3) : Colors.grey.shade300),
              ),
              child: SelectableText(
                _sqlPreview,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: isDark ? 0.1 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[400], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Row identifier: $primaryKeyColumn = $primaryKeyValue',
                      style: TextStyle(color: Colors.orange[400], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
