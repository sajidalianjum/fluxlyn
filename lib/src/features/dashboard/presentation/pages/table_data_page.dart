import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';

class TableDataPage extends StatefulWidget {
  final String tableName;

  const TableDataPage({super.key, required this.tableName});

  @override
  State<TableDataPage> createState() => _TableDataPageState();
}

class _TableDataPageState extends State<TableDataPage> {
  // Mock Data for UI Matching (will hook up to provider later)
  final List<Map<String, dynamic>> _rows = [
    {'id': 10234, 'customer': 'Alexandria Montgomery', 'email': 'alex@example.com', 'status': 'ACTIVE'},
    {'id': 10235, 'customer': 'Jordan Smith', 'email': 'jordan@code.io', 'status': 'ACTIVE'},
    {'id': 10236, 'customer': 'Marcus T. Wright', 'email': 'marcus@wright.com', 'status': 'INACTIVE'},
    {'id': 10237, 'customer': 'NULL', 'email': 'null@null.com', 'status': 'PENDING'},
    {'id': 10238, 'customer': 'Sarah Jenkins', 'email': 'sarah@j.com', 'status': 'ACTIVE'},
    {'id': 10239, 'customer': 'Elena Rodriquez', 'email': 'elena@r.com', 'status': 'ACTIVE'},
  ];
  
  int _selectedRowIndex = 1; // Jordan Smith selected in screenshot

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Table: ${widget.tableName}', style: Theme.of(context).textTheme.titleMedium),
            Text('PostgreSQL • 12.4ms', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: Column(
        children: [
          // Toolbar (Filter & Sort)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                 Expanded(
                   child: _buildDropdownButton('Filter: All Rows'),
                 ),
                 const SizedBox(width: 12),
                 Expanded(
                   child: _buildDropdownButton('Sort: ID (DESC)', isBlue: true),
                 ),
              ],
            ),
          ),
          
          // Data Grid
          Expanded(
            child: DataTable2(
               columnSpacing: 12,
               horizontalMargin: 12,
               minWidth: 600,
               headingRowColor: WidgetStateColor.resolveWith((states) => const Color(0xFF1E293B)),
               columns: const [
                 DataColumn2(label: Text('#'), fixedWidth: 50),
                 DataColumn2(label: Text('ID'), size: ColumnSize.S),
                 DataColumn2(label: Text('CUSTOMER'), size: ColumnSize.L),
                 DataColumn2(label: Text('EMAIL'), size: ColumnSize.L),
                 DataColumn2(label: Text('STATUS'), size: ColumnSize.S),
               ],
               rows: List<DataRow>.generate(_rows.length, (index) {
                 final row = _rows[index];
                 final isSelected = index == _selectedRowIndex;
                 return DataRow(
                   selected: isSelected,
                   onSelectChanged: (val) => setState(() => _selectedRowIndex = index),
                   cells: [
                     DataCell(Text('${index + 1}', style: TextStyle(color: Colors.grey.withValues(alpha: 0.5)))),
                     DataCell(Row(children: [ 
                        const Icon(Icons.tag, size: 14, color: Colors.blue), 
                        const SizedBox(width: 4), 
                        Text('${row['id']}') 
                     ])),
                     DataCell(Row(children: [
                        const Icon(Icons.person, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(row['customer'])
                     ])),
                     DataCell(Text(row['email'])),
                     DataCell(Text(row['status'], style: TextStyle(color: row['status'] == 'ACTIVE' ? Colors.green : Colors.grey))),
                   ],
                 );
               }),
            ),
          ),
          
          // Footer / Pagination
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF0F172A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Showing 1-50 of 1,240', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Row(
                  children: [
                    IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_left)),
                    const SizedBox(width: 8),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_right)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDropdownButton(String text, {bool isBlue = false}) {
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
       decoration: BoxDecoration(
          color: isBlue ? Colors.blue.withValues(alpha: 0.1) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: isBlue ? Border.all(color: Colors.blue.withValues(alpha: 0.3)) : null,
       ),
       height: 40,
       child: Row(
         children: [
           Icon(Icons.filter_list, size: 16, color: isBlue ? Colors.blue : Colors.grey),
           const SizedBox(width: 8),
           Expanded(child: Text(text, style: TextStyle(color: isBlue ? Colors.blue : Colors.white))),
           Icon(Icons.keyboard_arrow_down, size: 16, color: isBlue ? Colors.blue : Colors.grey),
         ],
       ),
     );
  }
}
