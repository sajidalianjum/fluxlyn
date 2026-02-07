import 'package:flutter/material.dart';
import 'package:fluxlyn/src/features/settings/presentation/dialogs/settings_dialog.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const SettingsDialog(),
          );
        },
        icon: const Icon(Icons.settings),
        label: const Text('Open Settings'),
      ),
    );
  }
}
