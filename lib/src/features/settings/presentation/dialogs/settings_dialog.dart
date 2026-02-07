import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/settings_model.dart';
import '../../providers/settings_provider.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _apiKeyController;
  late TextEditingController _endpointController;
  late AIProvider _selectedProvider;
  bool _lockDelete = false;
  bool _lockDrop = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _selectedProvider = settings.provider;
    _lockDelete = settings.lockDelete;
    _lockDrop = settings.lockDrop;
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _endpointController = TextEditingController(
      text: settings.endpoint.isNotEmpty
          ? settings.endpoint
          : _selectedProvider.defaultEndpoint,
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  void _onProviderChanged(AIProvider? provider) {
    if (provider != null) {
      setState(() {
        _selectedProvider = provider;
        if (_endpointController.text.isEmpty ||
            _endpointController.text ==
                context
                    .read<SettingsProvider>()
                    .settings
                    .provider
                    .defaultEndpoint) {
          _endpointController.text = provider.defaultEndpoint;
        }
      });
    }
  }

  Future<void> _onLockDeleteChanged(bool value) async {
    setState(() => _lockDelete = value);
    await context.read<SettingsProvider>().updateSettings(lockDelete: value);
  }

  Future<void> _onLockDropChanged(bool value) async {
    setState(() => _lockDrop = value);
    await context.read<SettingsProvider>().updateSettings(lockDrop: value);
  }

  Future<void> _save() async {
    final provider = context.read<SettingsProvider>();
    await provider.updateSettings(
      lockDelete: _lockDelete,
      lockDrop: _lockDrop,
      provider: _selectedProvider,
      apiKey: _apiKeyController.text.trim(),
      endpoint: _endpointController.text.trim(),
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Settings', style: theme.textTheme.headlineSmall),
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
                      'Protection',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Lock for Delete'),
                      subtitle: const Text(
                        'Prevent accidental deletion of items',
                      ),
                      value: _lockDelete,
                      onChanged: _onLockDeleteChanged,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Lock for Drop'),
                      subtitle: const Text(
                        'Prevent accidental dropping of items',
                      ),
                      value: _lockDrop,
                      onChanged: _onLockDropChanged,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 32),

                    Text(
                      'AI Configuration',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'AI Provider',
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<AIProvider>(
                          value: _selectedProvider,
                          isExpanded: true,
                          items: AIProvider.values.map((provider) {
                            return DropdownMenuItem<AIProvider>(
                              value: provider,
                              child: Text(provider.displayName),
                            );
                          }).toList(),
                          onChanged: _onProviderChanged,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _endpointController,
                      decoration: const InputDecoration(
                        labelText: 'API Endpoint',
                        border: OutlineInputBorder(),
                        helperText: 'Edit endpoint for any provider',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        border: OutlineInputBorder(),
                        helperText: 'Your API key will be stored securely',
                      ),
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                    ),
                  ],
                ),
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
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
