import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;
import '../../../../core/models/settings_model.dart';
import '../../../../core/models/export_options.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/widgets/snackbar_helper.dart';
import '../../providers/settings_provider.dart';
import '../../../connections/providers/connections_provider.dart';
import '../dialogs/export_options_dialog.dart';
import '../dialogs/import_settings_dialog.dart';
import '../widgets/master_password_section.dart';

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
  late AppThemeMode _selectedThemeMode;
  bool _lock = false;
  bool _readOnlyMode = false;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _selectedProvider = settings.provider;
    _selectedThemeMode = settings.themeMode;
    _lock = settings.lock;
    _readOnlyMode = settings.readOnlyMode;
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _modelNameController = TextEditingController(text: settings.modelName);
    _endpointController = TextEditingController(
      text: settings.endpoint.isNotEmpty
          ? settings.endpoint
          : _selectedProvider.defaultEndpoint,
    );
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _packageInfo = info);
    }
  }

  void _syncLocalStateFromProvider() {
    final settings = context.read<SettingsProvider>().settings;
    setState(() {
      _selectedProvider = settings.provider;
      _selectedThemeMode = settings.themeMode;
      _lock = settings.lock;
      _readOnlyMode = settings.readOnlyMode;
      if (_apiKeyController.text != settings.apiKey) {
        _apiKeyController.text = settings.apiKey;
      }
      if (_modelNameController.text != settings.modelName) {
        _modelNameController.text = settings.modelName;
      }
      final expectedEndpoint = settings.endpoint.isNotEmpty
          ? settings.endpoint
          : settings.provider.defaultEndpoint;
      if (_endpointController.text != expectedEndpoint) {
        _endpointController.text = expectedEndpoint;
      }
    });
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

  Future<void> _onThemeModeChanged(AppThemeMode? themeMode) async {
    if (themeMode != null) {
      setState(() => _selectedThemeMode = themeMode);
      await context.read<SettingsProvider>().updateSettings(themeMode: themeMode);
    }
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
              Expanded(child: _buildAppearanceSection(theme)),
            ],
          ),
          const SizedBox(height: 32),
          _buildConnectionsSection(theme),
          const SizedBox(height: 32),
          _buildAIConfigSection(theme),
          const SizedBox(height: 32),
          _buildAboutCard(theme),
        ] else ...[
          _buildProtectionSection(theme),
          const SizedBox(height: 32),
          _buildAppearanceSection(theme),
          const SizedBox(height: 32),
          _buildConnectionsSection(theme),
          const SizedBox(height: 32),
          _buildAIConfigSection(theme),
          const SizedBox(height: 32),
          _buildAboutCard(theme),
        ],
      ],
    );
  }

  Widget _buildProtectionSection(ThemeData theme) {
    final storageService = context.watch<StorageService>();

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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Lock for Destructive Operations'),
          subtitle: const Text(
            'Prevent accidental data modification (DELETE, DROP, TRUNCATE, ALTER)',
          ),
          value: _lock,
          onChanged: _readOnlyMode ? null : _onLockChanged,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        const SizedBox(height: 24),
        MasterPasswordSection(),
      ],
    );
  }

  Widget _buildAppearanceSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Appearance',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Theme',
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AppThemeMode>(
              value: _selectedThemeMode,
              isExpanded: true,
              items: AppThemeMode.values.map((mode) {
                return DropdownMenuItem<AppThemeMode>(
                  value: mode,
                  child: Text(mode.displayName),
                );
              }).toList(),
              onChanged: _onThemeModeChanged,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your preferred color scheme',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildConnectionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connections',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exportConnections,
                icon: const Icon(Icons.upload_file),
                label: const Text('Export'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importConnections,
                icon: const Icon(Icons.download),
                label: const Text('Import'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Export or import connections securely with a password',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
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

  Future<void> _exportConnections() async {
    final provider = context.read<ConnectionsProvider>();
    final connections = provider.connections;

    if (connections.isEmpty) {
      SnackbarHelper.showError(context, 'No connections to export');
      return;
    }

    final options = await showDialog<ExportOptions>(
      context: context,
      builder: (context) => const ExportOptionsDialog(),
    );

    if (options == null) {
      return;
    }

    final password = await _showPasswordDialog(
      context,
      'Export Connections',
      'Enter a password to encrypt your connections:',
    );

    if (password == null || password.isEmpty) {
      return;
    }

    String savePath;

    if (Platform.isAndroid) {
      final directoryPath = await getDirectoryPath();
      if (directoryPath == null) {
        return;
      }
      savePath = path.join(directoryPath, 'connections.fluxlyn');
    } else {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Fluxlyn Connections',
        extensions: ['fluxlyn'],
      );

      final saveLocation = await getSaveLocation(
        suggestedName: 'connections.fluxlyn',
        acceptedTypeGroups: [typeGroup],
      );

      if (saveLocation == null) {
        return;
      }
      savePath = saveLocation.path;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Encrypting and exporting...',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final storageService = context.read<StorageService>();
      final settingsProvider = context.read<SettingsProvider>();
      await storageService.exportConnections(
        savePath,
        password,
        connections,
        includePasswords: options.includePasswords,
        includeSettings: options.includeSettings,
        settings: options.includeSettings ? settingsProvider.settings : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        final parts = ['Connections'];
        if (options.includePasswords) parts.add('passwords');
        if (options.includeSettings) parts.add('settings');
        final message = '${parts.join(' + ')} exported successfully';
        SnackbarHelper.showSuccess(context, message);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        SnackbarHelper.showError(context, 'Failed to export: $e');
      }
    }
  }

  Future<void> _importConnections() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'Fluxlyn Connections',
      extensions: ['fluxlyn'],
    );

    final file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file == null) {
      return;
    }

    final password = await _showPasswordDialog(
      context,
      'Import Connections',
      'Enter the password to decrypt your connections:',
    );

    if (password == null || password.isEmpty) {
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Decrypting and importing...',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final storageService = context.read<StorageService>();
      final result = await storageService.checkImportFile(file.path, password);

      bool overwriteSettings = false;
      if (result.hasSettings && result.settings != null) {
        if (!mounted) return;
        Navigator.of(context).pop();
        final settingsProvider = context.read<SettingsProvider>();
        if (_hasMeaningfulSettings(result.settings!, settingsProvider.settings)) {
          overwriteSettings =
              await showDialog<bool>(
                context: context,
                builder: (context) => ImportSettingsDialog(
                  currentSettings: settingsProvider.settings,
                ),
              ) ??
              false;
        }
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Importing connections...',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      final connections = await storageService.importConnections(
        file.path,
        password,
        overwriteSettings: overwriteSettings,
      );

      final provider = context.read<ConnectionsProvider>();
      for (final connection in connections) {
        await provider.addConnection(connection);
      }

      if (result.hasSettings && overwriteSettings) {
        await context.read<SettingsProvider>().loadSettings();
        _syncLocalStateFromProvider();
      }

      if (mounted) {
        Navigator.of(context).pop();
        String message =
            'Successfully imported ${connections.length} connection(s)';
        if (result.hasSettings && overwriteSettings) {
          message += ' and updated settings';
        }
        SnackbarHelper.showSuccess(context, message);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        SnackbarHelper.showError(context, 'Failed to import: $e');
      }
    }
  }

  /// Checks if imported settings contain meaningful values that would
  /// actually overwrite the user's current settings.
  /// Returns true if at least one of these is true:
  /// - API key is set (non-empty)
  /// - Model name is set (non-empty)
  /// - Endpoint is different from the provider's default endpoint
  bool _hasMeaningfulSettings(AppSettings imported, AppSettings current) {
    // Check if API key is set
    if (imported.apiKey.isNotEmpty) {
      return true;
    }

    // Check if model name is set
    if (imported.modelName.isNotEmpty) {
      return true;
    }

    // Check if endpoint is set and different from the provider's default
    if (imported.endpoint.isNotEmpty &&
        imported.endpoint != imported.provider.defaultEndpoint) {
      return true;
    }

    // If none of the above, settings are essentially empty/default
    return false;
  }

  Future<String?> _showPasswordDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    final controller = TextEditingController();
    final theme = Theme.of(context);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  Navigator.of(context).pop(value);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.of(context).pop(controller.text);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
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
                          _packageInfo != null
                              ? 'v${_packageInfo!.version}'
                              : 'Loading...',
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
