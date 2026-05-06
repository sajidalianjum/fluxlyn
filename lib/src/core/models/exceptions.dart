class DatabaseException implements Exception {
  final String message;
  final String? operation;
  final String? connectionName;
  final dynamic originalError;

  DatabaseException(
    this.message, {
    this.operation,
    this.connectionName,
    this.originalError,
  });

  @override
  String toString() {
    final parts = <String>['DatabaseException: $message'];
    if (operation != null) parts.add('Operation: $operation');
    if (connectionName != null) parts.add('Connection: $connectionName');
    return parts.join(' | ');
  }
}

class NetworkException implements Exception {
  final String message;
  final String? url;
  final int? statusCode;
  final dynamic originalError;

  NetworkException(
    this.message, {
    this.url,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() {
    final parts = <String>['NetworkException: $message'];
    if (url != null) parts.add('URL: $url');
    if (statusCode != null) parts.add('Status: $statusCode');
    return parts.join(' | ');
  }
}

class SSHException implements Exception {
  final String message;
  final String? host;
  final int? port;
  final dynamic originalError;

  SSHException(this.message, {this.host, this.port, this.originalError});

  @override
  String toString() {
    final parts = <String>['SSHException: $message'];
    if (host != null || port != null) parts.add('Host: $host:$port');
    return parts.join(' | ');
  }
}

class StorageException implements Exception {
  final String message;
  final String? operation;
  final String? filePath;
  final dynamic originalError;

  StorageException(
    this.message, {
    this.operation,
    this.filePath,
    this.originalError,
  });

  @override
  String toString() {
    final parts = <String>['StorageException: $message'];
    if (operation != null) parts.add('Operation: $operation');
    if (filePath != null) parts.add('File: $filePath');
    return parts.join(' | ');
  }
}

class TimeoutException implements Exception {
  final String message;
  final Duration? timeout;
  final String? operation;

  TimeoutException(this.message, {this.timeout, this.operation});

  @override
  String toString() {
    final parts = <String>['TimeoutException: $message'];
    if (operation != null) parts.add('Operation: $operation');
    if (timeout != null) parts.add('Timeout: ${timeout!.inSeconds}s');
    return parts.join(' | ');
  }
}

class ConnectionException implements Exception {
  final String message;
  final String? connectionName;
  final String? host;
  final int? port;
  final bool isReconnect;
  final dynamic originalError;

  ConnectionException(
    this.message, {
    this.connectionName,
    this.host,
    this.port,
    this.isReconnect = false,
    this.originalError,
  });

  @override
  String toString() {
    final parts = <String>[
      isReconnect ? 'ReconnectException' : 'ConnectionException',
      message,
    ];
    if (connectionName != null) parts.add('Connection: $connectionName');
    if (host != null || port != null) parts.add('Host: $host:$port');
    return parts.join(' | ');
  }

  String toUserFriendlyString() {
    return message;
  }
}

class QueryException implements Exception {
  final String message;
  final String? query;
  final String? database;
  final String? table;
  final dynamic originalError;

  QueryException(
    this.message, {
    this.query,
    this.database,
    this.table,
    this.originalError,
  });

  @override
  String toString() {
    final parts = <String>['QueryException: $message'];
    if (database != null) parts.add('Database: $database');
    if (table != null) parts.add('Table: $table');
    if (query != null && query!.length <= 200) parts.add('Query: $query');
    return parts.join(' | ');
  }
}

class ValidationException implements Exception {
  final String message;
  final String? field;
  final dynamic value;

  ValidationException(this.message, {this.field, this.value});

  @override
  String toString() {
    final parts = <String>['ValidationException: $message'];
    if (field != null) parts.add('Field: $field');
    if (value != null) parts.add('Value: $value');
    return parts.join(' | ');
  }
}
