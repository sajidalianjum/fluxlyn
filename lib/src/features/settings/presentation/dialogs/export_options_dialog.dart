import 'package:flutter/material.dart';
import '../../../../core/models/export_options.dart';

class ExportOptionsDialog extends StatefulWidget {
  const ExportOptionsDialog({super.key});

  @override
  State<ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<ExportOptionsDialog> {
  bool _includePasswords = true;
  bool _includeSettings = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export Options', style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            CheckboxListTile(
              title: const Text('Include passwords and SSH keys'),
              subtitle: const Text(
                'Include database passwords and SSH credentials in the export',
              ),
              value: _includePasswords,
              onChanged: (value) {
                setState(() {
                  _includePasswords = value ?? true;
                });
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Include AI and other settings'),
              subtitle: const Text(
                'Include AI configuration, protection settings, and other preferences',
              ),
              value: _includeSettings,
              onChanged: (value) {
                setState(() {
                  _includeSettings = value ?? true;
                });
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All data will be encrypted and password protected',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      ExportOptions(
                        includePasswords: _includePasswords,
                        includeSettings: _includeSettings,
                      ),
                    );
                  },
                  child: const Text('Export'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
