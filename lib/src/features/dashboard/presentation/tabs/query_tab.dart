import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/sql.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';

class QueryTab extends StatefulWidget {
  const QueryTab({super.key});

  @override
  State<QueryTab> createState() => _QueryTabState();
}

class _QueryTabState extends State<QueryTab> {
  final _controller = CodeController(
    language: sql,
    text: "SELECT * FROM users\nWHERE last_login > '2023-01-01'\nORDER BY created_at DESC\nLIMIT 10;",
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
         titleSpacing: 0,
         title: Row(
           children: [
             _buildTab(context, 'Query 1', isSelected: true),
             _buildTab(context, 'GetUsers.sql', isSelected: false),
             IconButton(onPressed: () {}, icon: const Icon(Icons.add, size: 20, color: Colors.grey)),
           ],
         ),
         actions: [
            TextButton(
               onPressed: () {},
               child: const Text('Save', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
         ],
      ),
      body: Column(
        children: [
           // Editor Area
           Expanded(
             flex: 3, // Editor takes more space
             child: CodeTheme(
               data: CodeThemeData(styles: monokaiSublimeTheme),
               child: SingleChildScrollView(
                 child: CodeField(
                   controller: _controller,
                   textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                   gutterStyle: const GutterStyle(
                      textStyle: TextStyle(color: Colors.grey),
                      width: 48,
                      margin: 0,
                   ),
                   cursorColor: Colors.blue,
                   background: const Color(0xFF0F172A),
                 ),
               ),
             ),
           ),
           
           // Resize Handle (Mock)
           Container(
             height: 4,
             width: 40,
             margin: const EdgeInsets.symmetric(vertical: 8),
             decoration: BoxDecoration(
               color: Colors.grey.withValues(alpha: 0.3),
               borderRadius: BorderRadius.circular(2),
             ),
           ),
           
           // Toolbar
           SingleChildScrollView(
             scrollDirection: Axis.horizontal,
             padding: const EdgeInsets.symmetric(horizontal: 16),
             child: Row(
               children: [
                 _buildKeywordButton('SELECT'),
                 _buildKeywordButton('FROM'),
                 _buildKeywordButton('WHERE'),
                 _buildKeywordButton('JOIN'),
                 _buildKeywordButton('ORDER BY'),
               ],
             ),
           ),
           const Divider(height: 24, thickness: 1, color: Color(0xFF1E293B)),
           
           // Results Area / Run Button
           Expanded(
              flex: 2,
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 16),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Row(
                               children: [
                                 Text('QUERY RESULTS', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey, fontWeight: FontWeight.bold)),
                                 const SizedBox(width: 8),
                                 Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('12ms', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                 ),
                               ],
                             ),
                             Row(
                               children: [
                                  IconButton(onPressed: () {}, icon: const Icon(Icons.download, size: 18, color: Colors.grey)),
                                  IconButton(onPressed: () {}, icon: const Icon(Icons.close, size: 18, color: Colors.grey)),
                               ],
                             ),
                           ],
                         ),
                       ),
                       const Divider(color: Color(0xFF1E293B)),
                       // Mock Results Table
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateColor.resolveWith((states) => const Color(0xFF0F172A)),
                              columns: const [
                                DataColumn(label: Text('id', style: TextStyle(color: Colors.grey))),
                                DataColumn(label: Text('username', style: TextStyle(color: Colors.grey))),
                                DataColumn(label: Text('email', style: TextStyle(color: Colors.grey))),
                                DataColumn(label: Text('status', style: TextStyle(color: Colors.grey))),
                              ],
                              rows: const [
                                DataRow(cells: [DataCell(Text('1024')), DataCell(Text('john_doe')), DataCell(Text('john@example.com')), DataCell(Text('ACTIVE', style: TextStyle(color: Colors.green)))]),
                                DataRow(cells: [DataCell(Text('1025')), DataCell(Text('sarah_dev')), DataCell(Text('sarah@code.io')), DataCell(Text('ACTIVE', style: TextStyle(color: Colors.green)))]),
                                DataRow(cells: [DataCell(Text('1026')), DataCell(Text('mike_admin')), DataCell(Text('mike@corp.com')), DataCell(Text('INACTIVE', style: TextStyle(color: Colors.grey)))]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // FAB (Run Button)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      onPressed: () {
                         // Hook up execute
                      },
                      backgroundColor: Colors.blue,
                      child: const Icon(Icons.play_arrow),
                    ),
                  ),
                ],
              ),
           ),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, String title, {required bool isSelected}) {
     return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
           border: isSelected ? const Border(bottom: BorderSide(color: Colors.blue, width: 2)) : null,
        ),
        child: Row(
          children: [
            Icon(Icons.description, size: 16, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: isSelected ? Colors.blue : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
     );
  }

  Widget _buildKeywordButton(String text) {
     return Container(
        margin: const EdgeInsets.only(right: 8),
        child: OutlinedButton(
           onPressed: () {},
           style: OutlinedButton.styleFrom(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
             foregroundColor: Colors.white,
             side: const BorderSide(color: Color(0xFF334155)),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
           ),
           child: Text(text),
        ),
     );
  }
}
