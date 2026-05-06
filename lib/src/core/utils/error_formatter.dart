class ErrorFormatter {
  ErrorFormatter._();

  static String format(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();

    if (lowerError.contains('caching_sha2_password')) {
      return 'Authentication Failed: MySQL requires a secure connection for this user. Please try enabling "SSL" in your connection settings.';
    }
    if (lowerError.contains('errno=61') ||
        lowerError.contains('connection refused')) {
      return 'Connection Refused: Ensure your database is running and accepting remote connections on the specified port.';
    }
    if (lowerError.contains('errno=111') ||
        lowerError.contains('no route to host')) {
      return 'Host Unreachable: The specified host could not be reached. Please check host address and network connectivity.';
    }
    if (lowerError.contains('errno=113')) {
      return 'No Route to Host: The host is not reachable from this network.';
    }
    if (lowerError.contains('access denied') ||
        lowerError.contains('authentication failed')) {
      return 'Authentication Failed: Check your username and password credentials.';
    }
    if (lowerError.contains('timeout') || lowerError.contains('timed out')) {
      return 'Connection Timeout: The connection attempt timed out. Please check your network and try again.';
    }
    if (lowerError.contains('unknown database')) {
      return 'Database Not Found: The specified database does not exist or you do not have access to it.';
    }
    if (lowerError.contains('ssl') &&
        (lowerError.contains('error') || lowerError.contains('failed'))) {
      return 'SSL Error: There was an SSL/TLS connection issue. Please verify SSL settings.';
    }

    return errorMessage
        .replaceFirst('ConnectionException: ', '')
        .replaceFirst('ReconnectException: ', '')
        .replaceFirst('DatabaseException: ', '')
        .replaceFirst('QueryException: ', '')
        .replaceFirst('NetworkException: ', '')
        .replaceFirst('SSHException: ', '')
        .replaceFirst('StorageException: ', '')
        .replaceFirst('Failed to connect to MySQL: ', '')
        .replaceFirst('Failed to connect to PostgreSQL: ', '')
        .replaceFirst('Failed to execute query: ', '')
        .replaceFirst('Failed to get tables: ', '')
        .replaceFirst('Failed to get databases: ', '')
        .replaceFirst('Failed to select database: ', '')
        .replaceFirst('Failed to fetch table data: ', '')
        .replaceFirst('Failed to fetch filtered table data: ', '')
        .replaceFirst('Failed to update row: ', '')
        .replaceFirst('Auto-reconnect failed: ', '')
        .trim();
  }
}
