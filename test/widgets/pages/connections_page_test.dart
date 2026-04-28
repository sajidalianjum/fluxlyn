import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluxlyn/src/features/connections/presentation/pages/connections_page.dart';
import 'package:fluxlyn/src/features/connections/providers/connections_provider.dart';
import 'package:fluxlyn/src/features/settings/providers/settings_provider.dart';
import 'package:fluxlyn/src/features/dashboard/providers/dashboard_provider.dart';
import 'package:fluxlyn/src/core/services/storage_service.dart';
import 'package:fluxlyn/src/features/connections/models/connection_model.dart';
import 'package:fluxlyn/src/core/models/settings_model.dart';
import '../../helpers/mock_storage_service.dart';

void main() {
  late MockStorageService mockStorage;
  late MockStorageService mockSettingsStorage;

  setUpAll(() {
    Provider.debugCheckInvalidValueType = null;
    registerFallbackValues();
  });

  setUp(() {
    mockStorage = MockStorageService();
    mockSettingsStorage = MockStorageService();

    when(() => mockStorage.getAllConnections()).thenReturn([]);
    when(() => mockStorage.saveConnection(any())).thenAnswer((_) async {});
    when(() => mockStorage.deleteConnection(any())).thenAnswer((_) async {});
    when(() => mockStorage.getAllSavedQueries()).thenReturn([]);
    when(() => mockStorage.getQueryHistory(any())).thenReturn([]);
    when(() => mockStorage.getAllQueryHistory()).thenReturn([]);
    when(() => mockStorage.isMasterPasswordEnabled()).thenReturn(false);
    when(() => mockSettingsStorage.loadSettings())
        .thenReturn(AppSettings.defaultSettings());
    when(() => mockSettingsStorage.saveSettings(any()))
        .thenAnswer((_) async {});
    when(() => mockSettingsStorage.isMasterPasswordEnabled()).thenReturn(false);
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          Provider<StorageService>.value(value: mockStorage),
          ChangeNotifierProvider<ConnectionsProvider>(
            create: (_) => ConnectionsProvider(mockStorage),
          ),
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider(mockSettingsStorage),
          ),
          ChangeNotifierProvider<DashboardProvider>(
            create: (_) => DashboardProvider(mockStorage),
          ),
        ],
        child: const ConnectionsPage(),
      ),
    );
  }

  group('ConnectionsPage', () {
    group('page rendering', () {
      testWidgets('shows Connections title in AppBar', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Connections'), findsWidgets);
      });

      testWidgets('shows bottom navigation bar on mobile', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(NavigationBar), findsOneWidget);
      });

      testWidgets('shows navigation destinations', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Connections'), findsWidgets);
        expect(find.text('Queries'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      });

      testWidgets('shows floating action button on Connections tab', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });
    });

    group('navigation', () {
      testWidgets('switches to Queries tab', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text('Queries'));
        await tester.pumpAndSettle();

        expect(find.text('Queries'), findsWidgets);
      });

      testWidgets('switches to Settings tab', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(find.text('Settings'), findsWidgets);
      });

      testWidgets('hides FAB on Queries tab', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text('Queries'));
        await tester.pumpAndSettle();

        expect(find.byType(FloatingActionButton), findsNothing);
      });

      testWidgets('hides FAB on Settings tab', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(find.byType(FloatingActionButton), findsNothing);
      });
    });

    group('empty state', () {
      testWidgets('shows empty connections list initially', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(ConnectionsPage), findsOneWidget);
      });

      testWidgets('shows add button on FAB', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byIcon(Icons.add), findsOneWidget);
      });
    });

    group('search functionality', () {
      testWidgets('shows search bar when search icon tapped', (tester) async {
        final connections = [
          ConnectionModel(
            id: 'c1',
            name: 'Test Connection',
            host: 'localhost',
            port: 3306,
            sortOrder: 0,
          ),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();

        expect(find.text('Search connections...'), findsOneWidget);
      });

      testWidgets('shows close icon when searching', (tester) async {
        final connections = [
          ConnectionModel(
            id: 'c1',
            name: 'Test Connection',
            host: 'localhost',
            port: 3306,
            sortOrder: 0,
          ),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('closes search when close icon tapped', (tester) async {
        final connections = [
          ConnectionModel(
            id: 'c1',
            name: 'Test Connection',
            host: 'localhost',
            port: 3306,
            sortOrder: 0,
          ),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.text('Search connections...'), findsNothing);
      });
    });

    group('connection actions', () {
      testWidgets('opens connection dialog on FAB tap', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(find.text('New Connection'), findsOneWidget);
      });

      testWidgets('closes dialog on Cancel', (tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('New Connection'), findsNothing);
      });
    });

    group('with existing connections', () {
      testWidgets('displays connections from provider', (tester) async {
        final connections = [
          ConnectionModel(
            id: 'c1',
            name: 'Test Connection',
            host: 'localhost',
            port: 3306,
            sortOrder: 0,
          ),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.text('Test Connection'), findsOneWidget);
      });

      testWidgets('displays multiple connections', (tester) async {
        final connections = [
          ConnectionModel(
            id: 'c1',
            name: 'First Connection',
            host: 'localhost',
            port: 3306,
            sortOrder: 0,
          ),
          ConnectionModel(
            id: 'c2',
            name: 'Second Connection',
            host: 'localhost',
            port: 3306,
            sortOrder: 1,
          ),
        ];

        when(() => mockStorage.getAllConnections())
            .thenReturn(connections);

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.text('First Connection'), findsOneWidget);
        expect(find.text('Second Connection'), findsOneWidget);
      });
    });

    group('responsive layout', () {
      testWidgets('shows NavigationBar on small screen', (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestWidget());

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
      });

      testWidgets('shows NavigationRail on large screen', (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byType(NavigationRail), findsOneWidget);
      });
    });
  });
}