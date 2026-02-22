class QueryProtectionService {
  static final RegExp _writeOperationPattern = RegExp(
    r'^\s*(INSERT|UPDATE|DELETE|CREATE|ALTER|DROP|TRUNCATE|RENAME)\s+',
    caseSensitive: false,
  );

  static final RegExp _destructiveOperationPattern = RegExp(
    r'^\s*(UPDATE|DELETE|DROP|TRUNCATE|ALTER)\s+',
    caseSensitive: false,
  );

  static bool isWriteOperation(String query) {
    return _writeOperationPattern.hasMatch(query);
  }

  static bool isDestructiveOperation(String query) {
    return _destructiveOperationPattern.hasMatch(query);
  }

  static String? checkQuery(String query, bool readOnlyMode, bool lock) {
    if (readOnlyMode && isWriteOperation(query)) {
      return 'Read-only mode is enabled. Write operations are not allowed.';
    }

    if (lock && isDestructiveOperation(query)) {
      return 'Destructive operations are locked.';
    }

    return null;
  }

  static String? checkEditOperation(bool readOnlyMode, bool lock) {
    if (readOnlyMode) {
      return 'Read-only mode is active.';
    }

    if (lock) {
      return 'Destructive operations are locked.';
    }

    return null;
  }
}
