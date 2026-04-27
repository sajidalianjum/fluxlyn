import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/widgets/snackbar_helper.dart';
import '../dialogs/master_password_setup_dialog.dart';
import '../../providers/settings_provider.dart';

class MasterPasswordSection extends StatelessWidget {
  const MasterPasswordSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storageService = context.watch<StorageService>();
    final settingsProvider = context.watch<SettingsProvider>();
    final isEnabled = storageService.isMasterPasswordEnabled();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Master Password',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Password Protection'),
          subtitle: Text(
            isEnabled
                ? 'Your credentials are encrypted with a master password'
                : 'Enable password protection for your credentials',
          ),
          value: isEnabled,
          onChanged: (value) => _handleToggle(context, value),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        if (isEnabled) ...[
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Change Password'),
            subtitle: const Text('Update your master password'),
            leading: const Icon(Icons.key),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            onTap: () => _showChangePasswordDialog(context),
          ),
        ],
const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEnabled
                      ? 'You\'ll need to enter your password each time you open the app. If you forget it, all data will be lost.'
                      : 'Without a master password, your encryption key is stored unencrypted on disk.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleToggle(BuildContext context, bool enable) async {
    final storageService = context.read<StorageService>();
    final settingsProvider = context.read<SettingsProvider>();

    if (enable) {
      final password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const MasterPasswordEnableDialog(),
      );

      if (password == null || password.isEmpty) return;

      try {
        await storageService.enableMasterPassword(password);
        await settingsProvider.updateSettings(masterPasswordEnabled: true);

        if (context.mounted) {
          SnackbarHelper.showSuccess(context, 'Master password enabled');
        }
      } catch (e) {
        if (context.mounted) {
          SnackbarHelper.showError(context, 'Failed to enable: $e');
        }
      }
    } else {
      final password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const MasterPasswordDisableDialog(),
      );

      if (password == null || password.isEmpty) return;

      try {
        await storageService.disableMasterPassword(password);
        await settingsProvider.updateSettings(masterPasswordEnabled: false);

        if (context.mounted) {
          SnackbarHelper.showSuccess(context, 'Master password disabled');
        }
      } catch (e) {
        if (context.mounted) {
          SnackbarHelper.showError(context, 'Invalid password or failed to disable');
        }
      }
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final storageService = context.read<StorageService>();

    final result = await showDialog<(String, String)>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const MasterPasswordChangeDialog(),
    );

    if (result == null) return;

    final (oldPassword, newPassword) = result;

    try {
      await storageService.changeMasterPassword(oldPassword, newPassword);

      if (context.mounted) {
        SnackbarHelper.showSuccess(context, 'Password changed successfully');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Invalid password or failed to change');
      }
    }
  }
}