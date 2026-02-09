import 'package:flutter/material.dart';
import '../../models/connection_model.dart';

class ConnectionCard extends StatelessWidget {
  final ConnectionModel connection;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const ConnectionCard({
    super.key,
    required this.connection,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMysql = connection.type == ConnectionType.mysql;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 48,
                height: 48,
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
                        const SizedBox(width: 8),
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: connection.isConnected
                              ? const Color(0xFF10B981) // Green
                              : const Color(0xFFF59E0B), // Orange/Yellow
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connection.host,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
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
                  ],
                ),
              ),

              // Chevron & Edit
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 20),
                    color: Colors.white.withValues(alpha: 0.3),
                    tooltip: 'Edit Connection',
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
