import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (isWideScreen) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildProtectionSection(theme)),
              const SizedBox(width: 32),
              Expanded(child: _buildAIConfigSection(theme)),
            ],
          ),
          const SizedBox(height: 32),
          _buildAboutCard(theme),
        ] else ...[
          _buildProtectionSection(theme),
          const SizedBox(height: 32),
          _buildAIConfigSection(theme),
          const SizedBox(height: 32),
          _buildAboutCard(theme),
        ],
      ],
    );
  }

  Widget _buildProtectionSection(ThemeData theme) {
    return Column(
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
      ],
    );
  }

  Widget _buildAIConfigSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

  Widget _buildAboutCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.storage,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fluxlyn', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'v1.0.0+1',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'A modern database management tool for developers',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 18,
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  'Developed by ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                Text(
                  'Sajid Ali Anjum',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.verified,
                  size: 18,
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  'Licensed under ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                Text(
                  'GPLv3',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () async {
                final Uri url = Uri.parse(
                  'https://github.com/sajidalianjum/fluxlyn',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.code,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GitHub',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
