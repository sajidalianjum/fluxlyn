import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluxlyn/src/features/connections/providers/connections_provider.dart';
import 'package:fluxlyn/src/features/connections/models/connection_model.dart';
import '../../helpers/mock_storage_service.dart';

void main() {
  late ConnectionsProvider provider;
  late MockStorageService mockStorage;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockStorage = MockStorageService();
    when(() => mockStorage.getAllConnections()).thenReturn([]);
    when(() => mockStorage.saveConnection(any())).thenAnswer((_) async {});
    when(() => mockStorage.deleteConnection(any())).thenAnswer((_) async {});
    provider = ConnectionsProvider(mockStorage);
  });

  group('ConnectionsProvider', () {
    group('initialization', () {
      test('initializes with empty connections', () {
        expect(provider.connections, isEmpty);
      });

      test('loads connections from storage on creation', () {
        verify(() => mockStorage.getAllConnections()).called(1);
      });

      test('initializes with connections from storage', () {
        final existingConnections = [
          ConnectionModel(name: 'Existing', host: 'localhost', port: 3306),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(existingConnections);

        final newProvider = ConnectionsProvider(mockStorage);

        expect(newProvider.connections.length, 1);
        expect(newProvider.connections.first.name, 'Existing');
      });
    });

    group('addConnection', () {
      test('adds connection to list', () async {
        final connection = ConnectionModel(
          name: 'New Connection',
          host: 'localhost',
          port: 3306,
        );

        when(() => mockStorage.saveConnection(any()))
            .thenAnswer((_) async {});

        await provider.addConnection(connection);

        expect(provider.connections.length, 1);
        expect(provider.connections.first.name, 'New Connection');
      });

      test('saves connection to storage', () async {
        final connection = ConnectionModel(
          name: 'Test',
          host: 'localhost',
          port: 3306,
        );

        when(() => mockStorage.saveConnection(any()))
            .thenAnswer((_) async {});

        await provider.addConnection(connection);

        verify(() => mockStorage.saveConnection(any())).called(1);
      });

      test('notifies listeners after adding', () async {
        final connection = ConnectionModel(
          name: 'Test',
          host: 'localhost',
          port: 3306,
        );

        when(() => mockStorage.saveConnection(any()))
            .thenAnswer((_) async {});

        var notified = false;
        provider.addListener(() => notified = true);

        await provider.addConnection(connection);

        expect(notified, true);
      });

      test('assigns sortOrder when adding', () async {
        final connection = ConnectionModel(
          name: 'Test',
          host: 'localhost',
          port: 3306,
        );

        when(() => mockStorage.saveConnection(any()))
            .thenAnswer((_) async {});

        await provider.addConnection(connection);

        final addedConnection = provider.connections.first;
        expect(addedConnection.sortOrder, isNotNull);
      });

      test('increments sortOrder for subsequent connections', () async {
        when(() => mockStorage.saveConnection(any()))
            .thenAnswer((_) async {});

        final conn1 = ConnectionModel(name: 'First', host: 'h1', port: 3306);
        final conn2 = ConnectionModel(name: 'Second', host: 'h2', port: 3306);

        await provider.addConnection(conn1);
        await provider.addConnection(conn2);

        final first = provider.connections.first;
        final second = provider.connections[1];

        expect(second.sortOrder! > first.sortOrder!, true);
      });
    });

    group('updateConnection', () {
      test('updates existing connection', () async {
        final existing = ConnectionModel(
          id: 'conn-1',
          name: 'Old Name',
          host: 'localhost',
          port: 3306,
          sortOrder: 0,
        );

        when(() => mockStorage.getAllConnections())
            .thenReturn([existing]);

        final providerWithExisting = ConnectionsProvider(mockStorage);

        final updated = ConnectionModel(
          id: 'conn-1',
          name: 'New Name',
          host: 'newhost',
          port: 5432,
          sortOrder: 0,
        );

        when(() => mockStorage.saveConnection(any()))
            .thenAnswer((_) async {});

        await providerWithExisting.updateConnection(updated);

        expect(providerWithExisting.connections.first.name, 'New Name');
        expect(providerWithExisting.connections.first.host, 'newhost');
      });

      test('saves updated connection to storage', () async {
        final existing = ConnectionModel(
          id: 'conn-1',
          name: 'Test',
          host: 'localhost',
          port: 3306,
          sortOrder: 0,
        );

        when(() => mockStorage.getAllConnections())
            .thenReturn([existing]);

        final providerWithExisting = ConnectionsProvider(mockStorage);

        when(() => mockStorage.saveConnection(any()))
            .thenAnswer((_) async {});

        await providerWithExisting.updateConnection(existing);

        verify(() => mockStorage.saveConnection(any())).called(1);
      });

      test('does nothing when connection not found', () async {
        when(() => mockStorage.saveConnection(any()))
            .thenAnswer((_) async {});

        final nonExisting = ConnectionModel(
          id: 'non-existing',
          name: 'Test',
          host: 'localhost',
          port: 3306,
        );

        await provider.updateConnection(nonExisting);

        expect(provider.connections, isEmpty);
        verifyNever(() => mockStorage.saveConnection(any()));
      });

      test('notifies listeners after update', () async {
        final existing = ConnectionModel(
          id: 'conn-1',
          name: 'Test',
          host: 'localhost',
          port: 3306,
          sortOrder: 0,
        );

        when(() => mockStorage.getAllConnections())
            .thenReturn([existing]);

        final providerWithExisting = ConnectionsProvider(mockStorage);

        when(() => mockStorage.saveConnection(any()))
            .thenAnswer((_) async {});

        var notified = false;
        providerWithExisting.addListener(() => notified = true);

        await providerWithExisting.updateConnection(existing);

        expect(notified, true);
      });
    });

    group('removeConnection', () {
      test('removes connection from list', () async {
        final connection = ConnectionModel(
          id: 'conn-1',
          name: 'Test',
          host: 'localhost',
          port: 3306,
          sortOrder: 0,
        );

        when(() => mockStorage.getAllConnections())
            .thenReturn([connection]);

        final providerWithConnection = ConnectionsProvider(mockStorage);

        when(() => mockStorage.deleteConnection(any()))
            .thenAnswer((_) async {});

        await providerWithConnection.removeConnection('conn-1');

        expect(providerWithConnection.connections, isEmpty);
      });

      test('deletes connection from storage', () async {
        final connection = ConnectionModel(
          id: 'conn-1',
          name: 'Test',
          host: 'localhost',
          port: 3306,
          sortOrder: 0,
        );

        when(() => mockStorage.getAllConnections())
            .thenReturn([connection]);

        final providerWithConnection = ConnectionsProvider(mockStorage);

        when(() => mockStorage.deleteConnection(any()))
            .thenAnswer((_) async {});

        await providerWithConnection.removeConnection('conn-1');

        verify(() => mockStorage.deleteConnection('conn-1')).called(1);
      });

      test('notifies listeners after removal', () async {
        final connection = ConnectionModel(
          id: 'conn-1',
          name: 'Test',
          host: 'localhost',
          port: 3306,
          sortOrder: 0,
        );

        when(() => mockStorage.getAllConnections())
            .thenReturn([connection]);

        final providerWithConnection = ConnectionsProvider(mockStorage);

        when(() => mockStorage.deleteConnection(any()))
            .thenAnswer((_) async {});

        var notified = false;
        providerWithConnection.addListener(() => notified = true);

        await providerWithConnection.removeConnection('conn-1');

        expect(notified, true);
      });

      test('removes only specified connection', () async {
        final connections = [
          ConnectionModel(id: 'c1', name: 'A', host: 'h1', port: 3306, sortOrder: 0),
          ConnectionModel(id: 'c2', name: 'B', host: 'h2', port: 3306, sortOrder: 1),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        final providerWithConnections = ConnectionsProvider(mockStorage);

        when(() => mockStorage.deleteConnection(any()))
            .thenAnswer((_) async {});

        await providerWithConnections.removeConnection('c1');

        expect(providerWithConnections.connections.length, 1);
        expect(providerWithConnections.connections.first.id, 'c2');
      });
    });

    group('removeConnections', () {
      test('removes multiple connections', () async {
        final connections = [
          ConnectionModel(id: 'c1', name: 'A', host: 'h1', port: 3306, sortOrder: 0),
          ConnectionModel(id: 'c2', name: 'B', host: 'h2', port: 3306, sortOrder: 1),
          ConnectionModel(id: 'c3', name: 'C', host: 'h3', port: 3306, sortOrder: 2),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        final providerWithConnections = ConnectionsProvider(mockStorage);

        when(() => mockStorage.deleteConnection(any()))
            .thenAnswer((_) async {});

        await providerWithConnections.removeConnections({'c1', 'c3'});

        expect(providerWithConnections.connections.length, 1);
        expect(providerWithConnections.connections.first.id, 'c2');
      });

      test('deletes each connection from storage', () async {
        final connections = [
          ConnectionModel(id: 'c1', name: 'A', host: 'h1', port: 3306, sortOrder: 0),
          ConnectionModel(id: 'c2', name: 'B', host: 'h2', port: 3306, sortOrder: 1),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        final providerWithConnections = ConnectionsProvider(mockStorage);

        when(() => mockStorage.deleteConnection(any()))
            .thenAnswer((_) async {});

        await providerWithConnections.removeConnections({'c1', 'c2'});

        verify(() => mockStorage.deleteConnection('c1')).called(1);
        verify(() => mockStorage.deleteConnection('c2')).called(1);
      });

      test('handles empty set', () async {
        final connections = [
          ConnectionModel(id: 'c1', name: 'A', host: 'h1', port: 3306, sortOrder: 0),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        final providerWithConnections = ConnectionsProvider(mockStorage);

        await providerWithConnections.removeConnections({});

        expect(providerWithConnections.connections.length, 1);
        verifyNever(() => mockStorage.deleteConnection(any()));
      });
    });

    group('reorderConnections', () {
      test('reorders connections correctly', () async {
        final connections = [
          ConnectionModel(id: 'c1', name: 'First', host: 'h1', port: 3306, sortOrder: 0),
          ConnectionModel(id: 'c2', name: 'Second', host: 'h2', port: 3306, sortOrder: 1),
          ConnectionModel(id: 'c3', name: 'Third', host: 'h3', port: 3306, sortOrder: 2),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        final providerWithConnections = ConnectionsProvider(mockStorage);

        when(() => mockStorage.saveConnection(any()))
            .thenAnswer((_) async {});

        await providerWithConnections.reorderConnections(0, 2);

        expect(providerWithConnections.connections[0].name, 'Second');
        expect(providerWithConnections.connections[1].name, 'First');
        expect(providerWithConnections.connections[2].name, 'Third');
      });

      test('updates sortOrder for all connections', () async {
        final connections = [
          ConnectionModel(id: 'c1', name: 'A', host: 'h1', port: 3306, sortOrder: 0),
          ConnectionModel(id: 'c2', name: 'B', host: 'h2', port: 3306, sortOrder: 1),
          ConnectionModel(id: 'c3', name: 'C', host: 'h3', port: 3306, sortOrder: 2),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        final providerWithConnections = ConnectionsProvider(mockStorage);

        when(() => mockStorage.saveConnection(any()))
            .thenAnswer((_) async {});

        await providerWithConnections.reorderConnections(0, 2);

        for (var i = 0; i < providerWithConnections.connections.length; i++) {
          expect(providerWithConnections.connections[i].sortOrder, i);
        }
      });

      test('saves all reordered connections to storage', () async {
        final connections = [
          ConnectionModel(id: 'c1', name: 'A', host: 'h1', port: 3306, sortOrder: 0),
          ConnectionModel(id: 'c2', name: 'B', host: 'h2', port: 3306, sortOrder: 1),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        final providerWithConnections = ConnectionsProvider(mockStorage);

        when(() => mockStorage.saveConnection(any()))
            .thenAnswer((_) async {});

        await providerWithConnections.reorderConnections(0, 1);

        verify(() => mockStorage.saveConnection(any())).called(2);
      });

      test('does nothing when oldIndex equals newIndex', () async {
        final connections = [
          ConnectionModel(id: 'c1', name: 'A', host: 'h1', port: 3306, sortOrder: 0),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        final providerWithConnections = ConnectionsProvider(mockStorage);

        when(() => mockStorage.saveConnection(any()))
            .thenAnswer((_) async {});

        await providerWithConnections.reorderConnections(0, 0);

        verifyNever(() => mockStorage.saveConnection(any()));
      });

      test('handles invalid oldIndex', () async {
        final connections = [
          ConnectionModel(id: 'c1', name: 'A', host: 'h1', port: 3306, sortOrder: 0),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        final providerWithConnections = ConnectionsProvider(mockStorage);

        await providerWithConnections.reorderConnections(-1, 0);

        expect(providerWithConnections.connections.first.name, 'A');
      });

      test('notifies listeners after reorder', () async {
        final connections = [
          ConnectionModel(id: 'c1', name: 'A', host: 'h1', port: 3306, sortOrder: 0),
          ConnectionModel(id: 'c2', name: 'B', host: 'h2', port: 3306, sortOrder: 1),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        final providerWithConnections = ConnectionsProvider(mockStorage);

        when(() => mockStorage.saveConnection(any()))
            .thenAnswer((_) async {});

        var notified = false;
        providerWithConnections.addListener(() => notified = true);

        await providerWithConnections.reorderConnections(0, 1);

        expect(notified, true);
      });
    });

    group('connections getter', () {
      test('returns current connections list', () {
        final connections = [
          ConnectionModel(id: 'c1', name: 'A', host: 'h1', port: 3306, sortOrder: 0),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        final providerWithConnections = ConnectionsProvider(mockStorage);

        expect(providerWithConnections.connections.length, 1);
      });

      test('returns sorted connections by sortOrder', () {
        final connections = [
          ConnectionModel(id: 'c1', name: 'First', host: 'h1', port: 3306, sortOrder: 0),
          ConnectionModel(id: 'c2', name: 'Second', host: 'h2', port: 3306, sortOrder: 1),
          ConnectionModel(id: 'c3', name: 'Third', host: 'h3', port: 3306, sortOrder: 2),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        final providerWithConnections = ConnectionsProvider(mockStorage);

        expect(providerWithConnections.connections[0].name, 'First');
        expect(providerWithConnections.connections[1].name, 'Second');
        expect(providerWithConnections.connections[2].name, 'Third');
      });
    });
  });
}