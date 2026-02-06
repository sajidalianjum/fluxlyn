import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../tabs/schema_tab.dart';
import '../tabs/query_tab.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch provider to get current tab index and connection status
    final provider = context.watch<DashboardProvider>();

    // Pages for Bottom Nav
    final List<Widget> pages = [
       const SchemaTab(),
       const QueryTab(),
       const Center(child: Text('History (Coming Soon)')),
       const Center(child: Text('Settings (Coming Soon)')),
    ];

    return Scaffold(
      // AppBar changes based on context, but keeping it simple for now as requested
      // The individual tabs might want to own the AppBar actually, but shared is fine for shell
      body: provider.isLoading 
         ? const Center(child: CircularProgressIndicator())
         : provider.error != null
             ? Center(child: Text('Error: ${provider.error}', style: const TextStyle(color: Colors.red)))
             : pages[provider.selectedTabIndex],
      
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F172A), // Matches AppTheme
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: provider.selectedTabIndex,
        onTap: (index) => provider.setTabIndex(index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dns), label: 'Databases'),
          BottomNavigationBarItem(icon: Icon(Icons.code), label: 'Editor'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
