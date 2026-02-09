class QueryResult {
  final String query;
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final int executionTimeMs;
  final bool success;
  final String? errorMessage;
  final List<String> binaryColumns;
  final List<String> bitColumns;
  final Map<String, List<String>> enumColumns;
  final Map<String, List<String>> setColumns;

  QueryResult({
    required this.query,
    required this.columns,
    required this.rows,
    required this.executionTimeMs,
    this.success = true,
    this.errorMessage,
    this.binaryColumns = const [],
    this.bitColumns = const [],
    this.enumColumns = const {},
    this.setColumns = const {},
  });
}
