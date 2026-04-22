import 'package:mocktail/mocktail.dart';
import 'package:fluxlyn/src/core/services/storage_service.dart';
import 'package:fluxlyn/src/features/connections/models/connection_model.dart';
import 'package:fluxlyn/src/features/queries/models/query_model.dart';
import 'package:fluxlyn/src/core/models/settings_model.dart';

class MockStorageService extends Mock implements StorageService {}

void registerFallbackValues() {
  registerFallbackValue(ConnectionModel(
    name: 'fallback',
    host: 'fallback',
    port: 3306,
  ));
  registerFallbackValue(QueryModel(
    id: 'fallback',
    name: 'fallback',
    query: 'fallback',
    createdAt: DateTime.now(),
    modifiedAt: DateTime.now(),
    connectionId: 'fallback',
  ));
  registerFallbackValue(QueryHistoryEntry(
    id: 'fallback',
    query: 'fallback',
    executedAt: DateTime.now(),
    executionTimeMs: 0,
    rowCount: 0,
    success: true,
    connectionId: 'fallback',
  ));
  registerFallbackValue(AppSettings.defaultSettings());
}