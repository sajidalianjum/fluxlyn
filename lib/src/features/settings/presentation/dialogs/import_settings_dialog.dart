import 'package:flutter/material.dart';
import '../../../../core/models/settings_model.dart';

class ImportSettingsDialog extends StatelessWidget {
  final AppSettings currentSettings;

  const ImportSettingsDialog({super.key, required this.currentSettings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String maskApiKey(String apiKey) {
      if (apiKey.isEmpty) return 'Not set';
      if (apiKey.length <= 10) return '***';
      return '${apiKey.substring(0, 7)}***';
    }

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import Settings', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(
              'This export file contains settings. Do you want to overwrite your current settings?',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Settings',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingRow(
                    context,
                    'AI Provider',
                    currentSettings.provider.displayName,
                  ),
                  const SizedBox(height: 12),
                  _buildSettingRow(
                    context,
                    'API Endpoint',
                    currentSettings.endpoint.isNotEmpty
                        ? currentSettings.endpoint
                        : 'Default',
                  ),
                  const SizedBox(height: 12),
                  _buildSettingRow(
                    context,
                    'Model Name',
                    currentSettings.modelName.isNotEmpty
                        ? currentSettings.modelName
                        : 'Not set',
                  ),
                  const SizedBox(height: 12),
                  _buildSettingRow(
                    context,
                    'API Key',
                    maskApiKey(currentSettings.apiKey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Keep Current Settings'),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Overwrite Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
