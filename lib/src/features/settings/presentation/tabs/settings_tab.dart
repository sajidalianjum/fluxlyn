import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/settings_model.dart';
import '../../providers/settings_provider.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late TextEditingController _apiKeyController;
  late TextEditingController _endpointController;
  late TextEditingController _modelNameController;
  late AIProvider _selectedProvider;
  bool _lock = false;
  bool _readOnlyMode = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _selectedProvider = settings.provider;
    _lock = settings.lock;
    _readOnlyMode = settings.readOnlyMode;
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _modelNameController = TextEditingController(text: settings.modelName);
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
    _modelNameController.dispose();
    super.dispose();
  }

  Future<void> _onProviderChanged(AIProvider? provider) async {
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

      await context.read<SettingsProvider>().updateSettings(
        lock: _lock,
        readOnlyMode: _readOnlyMode,
        provider: _selectedProvider,
        apiKey: _apiKeyController.text.trim(),
        endpoint: _endpointController.text.trim(),
        modelName: _modelNameController.text.trim(),
      );
    }
  }

  Future<void> _onReadOnlyModeChanged(bool value) async {
    setState(() => _readOnlyMode = value);
    await context.read<SettingsProvider>().updateSettings(readOnlyMode: value);
  }

  Future<void> _onLockChanged(bool value) async {
    setState(() => _lock = value);
    await context.read<SettingsProvider>().updateSettings(lock: value);
  }

  Future<void> _saveCurrentSettings() async {
    await context.read<SettingsProvider>().updateSettings(
      lock: _lock,
      readOnlyMode: _readOnlyMode,
      provider: _selectedProvider,
      apiKey: _apiKeyController.text.trim(),
      endpoint: _endpointController.text.trim(),
      modelName: _modelNameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Protection',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Read-Only Mode'),
          subtitle: const Text('Prevent all write operations'),
          value: _readOnlyMode,
          onChanged: _onReadOnlyModeChanged,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Lock for Destructive Operations'),
          subtitle: const Text(
            'Prevent accidental deletion or dropping of items',
          ),
          value: _lock,
          onChanged: _readOnlyMode ? null : _onLockChanged,
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
          onChanged: (_) => _saveCurrentSettings(),
          onFieldSubmitted: (_) => _saveCurrentSettings(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _modelNameController,
          decoration: const InputDecoration(
            labelText: 'Model Name',
            border: OutlineInputBorder(),
            helperText: 'e.g. gpt-4, claude-3-opus-20240229, etc.',
          ),
          onChanged: (_) => _saveCurrentSettings(),
          onFieldSubmitted: (_) => _saveCurrentSettings(),
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
          onChanged: (_) => _saveCurrentSettings(),
          onFieldSubmitted: (_) => _saveCurrentSettings(),
        ),
      ],
    );
  }
}
