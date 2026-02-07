import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connections_provider.dart';
import '../../models/connection_model.dart';
import 'package:fluxlyn/src/features/alerts/presentation/dialogs/add_alert_wizard.dart';
import 'package:fluxlyn/src/features/alerts/providers/alerts_provider.dart';
import '../dialogs/connection_dialog.dart';
import '../tabs/connections_tab.dart';
import 'package:fluxlyn/src/features/alerts/presentation/tabs/alerts_tab.dart'
    as alerts;
import 'package:fluxlyn/src/features/settings/presentation/tabs/settings_tab.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  int _selectedTabIndex = 0;

  void _showConnectionDialog(
    BuildContext context, {
    ConnectionModel? connection,
  }) {
    showDialog(
      context: context,
      builder: (context) => ConnectionDialog(
        connection: connection,
        onSave: (newConnection) {
          final provider = context.read<ConnectionsProvider>();
          if (connection == null) {
            provider.addConnection(newConnection);
          } else {
            provider.updateConnection(newConnection);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      const ConnectionsTab(),
      const alerts.AlertsTab(),
      const SettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        actions: _getAppBarActions(),
      ),
      body: IndexedStack(index: _selectedTabIndex, children: tabs),
      floatingActionButton: _getFloatingActionButton(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedTabIndex,
        onTap: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dns), label: 'Connections'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget? _getFloatingActionButton() {
    if (_selectedTabIndex == 0) {
      return FloatingActionButton(
        onPressed: () => _showConnectionDialog(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      );
    } else if (_selectedTabIndex == 1) {
      return FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const AddAlertWizard(),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      );
    }
    return null;
  }

  String _getAppBarTitle() {
    switch (_selectedTabIndex) {
      case 0:
        return 'Connections';
      case 1:
        return 'Alerts';
      case 2:
        return 'Settings';
      default:
        return 'Fluxlyn';
    }
  }

  List<Widget> _getAppBarActions() {
    switch (_selectedTabIndex) {
      case 0:
        return [];
      case 1:
        return [
          Consumer<AlertsProvider>(
            builder: (context, provider, _) {
              if (provider.alerts.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                onPressed: () => _showClearAllDialog(context, provider),
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Clear All',
              );
            },
          ),
        ];
      case 2:
        return [];
      default:
        return [];
    }
  }

  void _showClearAllDialog(BuildContext context, AlertsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Clear All Alerts'),
        content: const Text('Are you sure you want to delete all alerts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              for (final alert in provider.alerts) {
                await provider.deleteAlert(alert.id);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All alerts deleted')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
