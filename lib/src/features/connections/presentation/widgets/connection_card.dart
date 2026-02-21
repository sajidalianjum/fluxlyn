import 'package:flutter/material.dart';
import '../../models/connection_model.dart';

class ConnectionCard extends StatelessWidget {
  final ConnectionModel connection;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ConnectionCard({
    super.key,
    required this.connection,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMysql = connection.type == ConnectionType.mysql;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        label:
            'Connection card for ${connection.name}, ${connection.type.name} database',
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(isWideScreen ? 20 : 16),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: isWideScreen ? 56 : 48,
                  height: isWideScreen ? 56 : 48,
                  decoration: BoxDecoration(
                    color: isMysql
                        ? const Color(0xFF3E2C28)
                        : const Color(
                            0xFF1E3A5F,
                          ), // Brownish for MySQL, Blueish for PG
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.dns, // Generic storage icon
                    color: isMysql ? Colors.orange : Colors.blue,
                    semanticLabel: '${connection.type.name} database icon',
                    size: isWideScreen ? 28 : 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              connection.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (isWideScreen)
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.dns,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  connection.host,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.settings_ethernet,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ':${connection.port}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            if (connection.username != null &&
                                connection.username!.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    connection.username!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            if (connection.useSsh)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock,
                                    size: 14,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'SSH',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        )
                      else
                        Text(
                          connection.host,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              connection.type == ConnectionType.mysql
                                  ? 'MYSQL'
                                  : 'POSTGRESQL',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (connection.tag != null &&
                              connection.tag != ConnectionTag.none)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getTagColor(
                                  connection.tag!,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _getTagColor(connection.tag!),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                connection.tag == ConnectionTag.custom
                                    ? (connection.customTag ?? 'Custom')
                                    : connection.tag!.name[0].toUpperCase() +
                                          connection.tag!.name.substring(1),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _getTagColor(connection.tag!),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Chevron & Menu
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      onSelected: (choice) {
                        switch (choice) {
                          case 'edit':
                            onEdit();
                            break;
                          case 'delete':
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 12),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 12),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white.withValues(alpha: 0.3),
                      semanticLabel: 'Connect to ${connection.name}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTagColor(ConnectionTag tag) {
    switch (tag) {
      case ConnectionTag.none:
        return Colors.grey;
      case ConnectionTag.development:
        return Colors.green;
      case ConnectionTag.production:
        return Colors.red;
      case ConnectionTag.testing:
        return Colors.yellow;
      case ConnectionTag.staging:
        return Colors.orange;
      case ConnectionTag.local:
        return Colors.purple;
      case ConnectionTag.custom:
        return Colors.blue;
    }
  }
}
