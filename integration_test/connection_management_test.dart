import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluxlyn/src/features/connections/presentation/pages/connections_page.dart';
import 'package:fluxlyn/src/features/connections/providers/connections_provider.dart';
import 'package:fluxlyn/src/features/settings/providers/settings_provider.dart';
import 'package:fluxlyn/src/core/services/storage_service.dart';
import 'package:fluxlyn/src/features/connections/models/connection_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Connection Management Integration Tests', () {
    late StorageService storageService;

    setUpAll(() async {
      storageService = StorageService();
      await storageService.init();
    });

    testWidgets('complete connection creation flow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider.value(value: storageService),
              ChangeNotifierProvider(
                create: (_) => ConnectionsProvider(storageService),
              ),
              ChangeNotifierProvider(
                create: (_) => SettingsProvider(storageService),
              ),
            ],
            child: const ConnectionsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('New Connection'), findsOneWidget);

      final nameField = find.widgetWithText(TextFormField, 'Connection Name');
      await tester.enterText(nameField, 'Integration Test DB');

      final hostField = find.widgetWithText(TextFormField, 'Host');
      await tester.enterText(hostField, 'localhost');

      final userField = find.widgetWithText(TextFormField, 'Username');
      await tester.enterText(userField, 'testuser');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Integration Test DB'), findsOneWidget);
    });

    testWidgets('connection persistence across app restart', (tester) async {
      final connection = ConnectionModel(
        name: 'Persistent Connection',
        host: 'persistent.example.com',
        port: 3306,
        username: 'persistent_user',
        type: ConnectionType.mysql,
      );

      await storageService.saveConnection(connection);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider.value(value: storageService),
              ChangeNotifierProvider(
                create: (_) => ConnectionsProvider(storageService),
              ),
              ChangeNotifierProvider(
                create: (_) => SettingsProvider(storageService),
              ),
            ],
            child: const ConnectionsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Persistent Connection'), findsOneWidget);

      final connections = storageService.getAllConnections();
      expect(connections.any((c) => c.name == 'Persistent Connection'), true);
    });

    testWidgets('connection edit flow', (tester) async {
      final originalConnection = ConnectionModel(
        id: 'edit-test-id',
        name: 'Original Name',
        host: 'original.host',
        port: 3306,
        username: 'original_user',
        type: ConnectionType.mysql,
        sortOrder: 0,
      );

      await storageService.saveConnection(originalConnection);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider.value(value: storageService),
              ChangeNotifierProvider(
                create: (_) => ConnectionsProvider(storageService),
              ),
              ChangeNotifierProvider(
                create: (_) => SettingsProvider(storageService),
              ),
            ],
            child: const ConnectionsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Original Name'), findsOneWidget);
    });

    testWidgets('connection deletion flow', (tester) async {
      final connectionToDelete = ConnectionModel(
        id: 'delete-test-id',
        name: 'Connection to Delete',
        host: 'delete.host',
        port: 3306,
        username: 'delete_user',
        type: ConnectionType.mysql,
        sortOrder: 0,
      );

      await storageService.saveConnection(connectionToDelete);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider.value(value: storageService),
              ChangeNotifierProvider(
                create: (_) => ConnectionsProvider(storageService),
              ),
              ChangeNotifierProvider(
                create: (_) => SettingsProvider(storageService),
              ),
            ],
            child: const ConnectionsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Connection to Delete'), findsOneWidget);

      await storageService.deleteConnection('delete-test-id');

      final provider = ConnectionsProvider(storageService);

      expect(provider.connections.where((c) => c.id == 'delete-test-id'), isEmpty);
    });
  });
}