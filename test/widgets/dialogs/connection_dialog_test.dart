import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxlyn/src/features/connections/presentation/dialogs/connection_dialog.dart';
import 'package:fluxlyn/src/features/connections/models/connection_model.dart';

void main() {
  group('ConnectionDialog', () {
    group('dialog rendering', () {
      testWidgets('shows New Connection title for new connection', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('New Connection'), findsOneWidget);
      });

      testWidgets('shows Edit Connection title for existing connection', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final existingConnection = ConnectionModel(
          id: 'test-id',
          name: 'Existing',
          host: 'localhost',
          port: 3306,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      connection: existingConnection,
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Edit Connection'), findsOneWidget);
      });

      testWidgets('shows required fields', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Connection Name'), findsOneWidget);
        expect(find.text('Database Type'), findsOneWidget);
        expect(find.text('Host'), findsOneWidget);
        expect(find.text('Port'), findsOneWidget);
        expect(find.text('Username'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
      });

      testWidgets('shows tabs for General and SSH Tunnel', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('General'), findsOneWidget);
        expect(find.text('SSH Tunnel'), findsOneWidget);
      });

      testWidgets('shows Cancel and Save buttons', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
      });
    });

    group('form validation', () {
      testWidgets('shows validation error for empty name', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        await tester.pump();

        expect(find.text('Required'), findsWidgets);
      });

      testWidgets('shows validation error for empty host', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final nameField = find.widgetWithText(TextFormField, 'Connection Name');
        await tester.enterText(nameField, 'Test Connection');

        await tester.tap(find.text('Save'));
        await tester.pump();

        expect(find.text('Required'), findsWidgets);
      });

      testWidgets('shows validation error for empty username', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final nameField = find.widgetWithText(TextFormField, 'Connection Name');
        final hostField = find.widgetWithText(TextFormField, 'Host');

        await tester.enterText(nameField, 'Test Connection');
        await tester.enterText(hostField, 'localhost');

        await tester.tap(find.text('Save'));
        await tester.pump();

        expect(find.text('Required'), findsWidgets);
      });
    });

    group('form input', () {
      testWidgets('populates fields with existing connection data', (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final existingConnection = ConnectionModel(
          id: 'test-id',
          name: 'My Database',
          host: 'db.example.com',
          port: 5432,
          username: 'admin',
          password: 'secret',
          type: ConnectionType.postgresql,
          databaseName: 'mydb',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      connection: existingConnection,
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('My Database'), findsOneWidget);
        expect(find.text('db.example.com'), findsOneWidget);
        expect(find.text('5432'), findsOneWidget);
        expect(find.text('admin'), findsOneWidget);
        expect(find.text('mydb'), findsOneWidget);
      });

      testWidgets('allows database type selection', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final dropdown = find.widgetWithText(DropdownButtonFormField<ConnectionType>, 'Database Type');
        expect(dropdown, findsOneWidget);

        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        expect(find.text('PostgreSQL'), findsOneWidget);
      });

      testWidgets('shows SSL toggle', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView).first, const Offset(0, -300));
        await tester.pumpAndSettle();

        expect(find.text('Enable SSL'), findsOneWidget);
      });
    });

    group('SSH Tunnel tab', () {
      testWidgets('shows SSH tunnel toggle', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('SSH Tunnel'));
        await tester.pumpAndSettle();

        expect(find.text('Use SSH Tunnel'), findsOneWidget);
      });

      testWidgets('shows SSH fields when enabled', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('SSH Tunnel'));
        await tester.pumpAndSettle();

        final sshToggle = find.widgetWithText(SwitchListTile, 'Use SSH Tunnel');
        await tester.tap(sshToggle);
        await tester.pumpAndSettle();

        expect(find.text('SSH Host'), findsOneWidget);
        expect(find.text('SSH Username'), findsOneWidget);
      });
    });

    group('tag selection', () {
      testWidgets('shows tag chips', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await tester.pumpAndSettle();

        expect(find.text('Tag'), findsOneWidget);
        expect(find.text('None'), findsOneWidget);
        expect(find.text('Development'), findsOneWidget);
        expect(find.text('Production'), findsOneWidget);
      });

      testWidgets('shows custom tag field when Custom tag selected', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await tester.pumpAndSettle();

        final customChip = find.widgetWithText(FilterChip, 'Custom +');
        await tester.tap(customChip);
        await tester.pumpAndSettle();

        expect(find.text('Custom Tag Name'), findsOneWidget);
      });
    });

    group('save functionality', () {
      testWidgets('calls onSave with valid data', (tester) async {
        ConnectionModel? savedConnection;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (conn) => savedConnection = conn,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final nameField = find.widgetWithText(TextFormField, 'Connection Name');
        final hostField = find.widgetWithText(TextFormField, 'Host');
        final userField = find.widgetWithText(TextFormField, 'Username');

        await tester.enterText(nameField, 'Test DB');
        await tester.enterText(hostField, 'localhost');
        await tester.enterText(userField, 'root');

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(savedConnection, isNotNull);
        expect(savedConnection!.name, 'Test DB');
        expect(savedConnection!.host, 'localhost');
        expect(savedConnection!.username, 'root');
      });

      testWidgets('closes dialog after save', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (_) {},
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final nameField = find.widgetWithText(TextFormField, 'Connection Name');
        final hostField = find.widgetWithText(TextFormField, 'Host');
        final userField = find.widgetWithText(TextFormField, 'Username');

        await tester.enterText(nameField, 'Test');
        await tester.enterText(hostField, 'localhost');
        await tester.enterText(userField, 'root');

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('New Connection'), findsNothing);
      });

      testWidgets('Cancel closes dialog without saving', (tester) async {
        ConnectionModel? savedConnection;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ConnectionDialog(
                      onSave: (conn) => savedConnection = conn,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(savedConnection, isNull);
        expect(find.text('New Connection'), findsNothing);
      });
    });
  });
}