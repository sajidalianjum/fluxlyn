import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../tabs/schema_tab.dart';
import '../tabs/query_tab.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();

    final List<Widget> pages = [
      const SchemaTab(),
      const QueryTab(),
      const Center(child: Text('History (Coming Soon)')),
      const Center(child: Text('Settings (Coming Soon)')),
    ];

    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await provider.disconnect();
        }
      },
      child: Scaffold(
        body: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.error != null
            ? Center(
                child: Text(
                  'Error: ${provider.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : pages[provider.selectedTabIndex],
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: const Color(0xFF0F172A),
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          currentIndex: provider.selectedTabIndex,
          onTap: (index) => provider.setTabIndex(index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dns), label: 'Databases'),
            BottomNavigationBarItem(icon: Icon(Icons.code), label: 'Editor'),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
