# AGENTS.md

## 1. Overview

This document provides comprehensive guidance for AI agents and developers working on the Fluxlyn codebase. Fluxlyn is a Flutter cross-platform application (macOS, Android, Windows) for database management with MySQL support, SSH tunneling, and AI-powered features.

**Key Technologies:**
- Flutter 3.x with Material 3
- Provider for state management
- Hive for local encrypted storage
- mysql_dart for database connectivity
- Google Fonts (Inter)

**Target Platforms:**
- Current: macOS, Android, Windows
- Future: iOS, Linux

---

## 2. Storage Policy (CRITICAL)

### RULE: Use Hive with AES-256 Encryption for ALL Persistent Data

**PROHIBITED:**
- `flutter_secure_storage` - NEVER use
- macOS Keychain - NEVER use
- iOS Keychain - NEVER use
- Android KeyStore - NEVER use

**Rationale:**
1. Existing app uses Hive with internal salt-based encryption
2. Avoids platform-specific entitlement issues (macOS error -34018)
3. No dependency on signing certificates or provisioning profiles
4. Consistent encryption across all platforms
5. Simplifies development and deployment

**Implementation:**
- All data stored in encrypted Hive boxes using `HiveAesCipher`
- Encryption key stored in `encryption_key` box
- Optional master password protection available for enhanced security
- API keys and sensitive data encrypted alongside other data
- Use `StorageService` class for all persistence operations

### Master Password Protection

**Overview:**
Users can optionally enable a master password to encrypt the device encryption key. This provides true at-rest protection for sensitive credentials.

**Key Storage Models:**

| Mode | Key Storage | Security Level |
|------|-------------|----------------|
| No Password | `device_key` (unencrypted) in `encryption_key` box | Weak - key readable from disk |
| Password Enabled | `master_password_data` (encrypted key) in `encryption_key` box | Strong - key encrypted with user password |

**Implementation Details:**
- `MasterPasswordService` handles PBKDF2 key derivation (100,000 iterations)
- AES-256 encryption for the device key
- Verification hash to confirm password correctness
- `PasswordRequirement` enum tracks app state: `notRequired`, `required`, `firstLaunch`

**User Flow:**
1. First launch → Show setup dialog (user can skip)
2. Password enabled → Prompt on every app launch
3. Forgot password → Clear all data (no recovery possible)
4. Settings page → Toggle enable/disable, change password

**Files:**
- `lib/src/core/services/master_password_service.dart` - Key derivation and encryption
- `lib/src/core/presentation/pages/splash_page.dart` - Startup password flow
- `lib/src/features/settings/presentation/dialogs/master_password_setup_dialog.dart` - Setup UI
- `lib/src/features/settings/presentation/dialogs/master_password_prompt_dialog.dart` - Unlock UI
- `lib/src/features/settings/presentation/widgets/master_password_section.dart` - Settings UI

---

## 3. Architecture

### Clean Architecture Principles

```
lib/src/
├── core/                    # Shared utilities, services, models
│   ├── theme/              # App theming
│   ├── services/            # Storage, database services
│   └── models/             # Core data models (settings)
├── features/               # Self-contained feature modules
│   ├── connections/         # Connection management
│   ├── dashboard/          # Main app interface
│   ├── queries/            # Saved queries
│   └── settings/          # App settings
└── app.dart               # App entry point
```

### Feature Structure Pattern
Each feature follows this self-contained structure:

```
feature_name/
├── models/                 # Domain models with Hive adapters
├── providers/              # State management (Provider pattern)
└── presentation/           # UI components
    ├── pages/              # Full-screen pages
    ├── dialogs/            # Modal dialogs
    ├── tabs/               # Tab widgets
    └── widgets/           # Reusable components
```

**Benefits:**
- Features can be added/removed independently
- Clear separation of concerns
- Easy to navigate and maintain
- Consistent pattern across codebase

---

## 4. State Management

### Provider Pattern

All state management uses `package:provider` with `ChangeNotifier`.

**Access Patterns:**

```dart
// Watch for changes (rebuilds when state updates)
final provider = context.watch<MyProvider>();

// Read once (doesn't rebuild)
final provider = context.read<MyProvider>();
```

**Provider Registration:**
All providers registered in `MultiProvider` at app root (`app.dart`):

```dart
MultiProvider(
  providers: [
    Provider.value(value: storageService),
    ChangeNotifierProvider(create: (_) => ConnectionsProvider(storageService)),
    ChangeNotifierProvider(create: (_) => DashboardProvider()),
    ChangeNotifierProvider(create: (_) => SettingsProvider(storageService)),
  ],
)
```

**Provider Pattern:**

```dart
class MyProvider extends ChangeNotifier {
  final StorageService _storageService;
  DataType _data = defaultData();
  bool _isLoading = false;
  String? _error;

  MyProvider(this._storageService) {
    loadData();
  }

  DataType get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _data = await _storageService.loadData();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateData(DataType newData) async {
    _data = newData;
    notifyListeners();

    try {
      await _storageService.saveData(newData);
      _error = null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
```

---

## 5. UI/UX Patterns

### Material 3 Design System

- `useMaterial3: true` enforced
- Dark theme enforced: `themeMode: ThemeMode.dark`

### Color Scheme

```dart
Background:    0xFF0F172A (Slate 900)
Card:          0xFF1E293B (Slate 800)
Primary:        0xFF3B82F6 (Blue 500)
Text Primary:   Colors.white
```

### Typography

```dart
Font Family: Google Fonts 'Inter'
```

### Dialog Pattern

```dart
void _showMyDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const MyDialog(),
  );
}

class MyDialog extends StatefulWidget {
  const MyDialog({super.key});

  @override
  State<MyDialog> createState() => _MyDialogState();
}

class _MyDialogState extends State<MyDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog content
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                SizedBox(width: 16),
                FilledButton(onPressed: () => Navigator.pop(context), child: Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### Responsive Layouts

Use `BoxConstraints` for dialog sizing:
```dart
constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700)
```

### Loading & Error States

```dart
if (provider.isLoading) {
  return const Center(child: CircularProgressIndicator());
}

if (provider.error != null) {
  return Center(
    child: Text(
      'Error: ${provider.error}',
      style: const TextStyle(color: Colors.red),
    ),
  );
}
```

---

## 6. Persistent Data Storage

### Settings Storage (`settings` box)

**Purpose:** Application-wide configuration

**Data Structure:**

| Field | Type | Default | Description |
|-------|------|----------|-------------|
| `lockDelete` | bool | `true` | Prevents accidental deletion |
| `lockDrop` | bool | `true` | Prevents accidental dropping |
| `provider` | AIProvider enum | `openai` | Selected AI provider |
| `apiKey` | String | `''` | API key (encrypted) |
| `endpoint` | String | (provider default) | Configurable API endpoint |

**AIProvider Options:**
- `openai` - https://api.openai.com/v1/chat/completions
- `anthropic` - https://api.anthropic.com/v1/messages
- `openrouter` - https://openrouter.ai/api/v1/chat/completions
- `groq` - https://api.groq.com/openai/v1/chat/completions
- `xai` - https://api.x.ai/v1/chat/completions
- `custom` - User-specified endpoint

**API:**
```dart
// Load settings
final settings = storageService.loadSettings();

// Save settings
await storageService.saveSettings(settings);

// Access via Provider
final settingsProvider = context.read<SettingsProvider>();
final settings = settingsProvider.settings;
await settingsProvider.updateSettings(lockDelete: true, apiKey: 'sk-...');
```

---

### Connection Storage (`connections` box)

**Purpose:** Database connection configurations

**Data Structure:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | UUID identifier |
| `name` | String | Connection display name |
| `host` | String | Database server host |
| `port` | int | Port number |
| `username` | String | Database username |
| `password` | String | Database password (encrypted) |
| `type` | ConnectionType | `mysql` or `postgresql` |
| `sslEnabled` | bool | SSL connection flag |
| `isConnected` | bool | Current connection state |
| `useSsh` | bool | SSH tunnel enabled |
| `sshHost` | String? | SSH tunnel host |
| `sshPort` | int? | SSH tunnel port (default 22) |
| `sshUsername` | String? | SSH username |
| `sshPassword` | String? | SSH password (encrypted) |
| `sshPrivateKey` | String? | SSH private key path (encrypted) |
| `sshKeyPassword` | String? | SSH key passphrase (encrypted) |
| `databaseName` | String? | Optional default database |

**API:**
```dart
// Get all connections
final connections = storageService.getAllConnections();

// Save connection
await storageService.saveConnection(connection);

// Delete connection
await storageService.deleteConnection(id);
```

---

### Query Storage (`queries` box)

**Purpose:** Saved SQL queries

**Data Structure:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | UUID identifier |
| `name` | String | Query name |
| `query` | String | SQL query text |
| `createdAt` | DateTime | Creation timestamp |
| `modifiedAt` | DateTime | Last modified timestamp |
| `isFavorite` | bool | Favorite flag |
| `connectionId` | String | Associated connection ID |

**API:**
```dart
// Get saved queries for connection
final queries = storageService.getSavedQueries(connectionId);

// Get favorite queries
final favorites = storageService.getFavoriteQueries(connectionId);

// Save query
await storageService.saveQuery(query);

// Delete query
await storageService.deleteQuery(id);
```

---

### Query History (`query_history` box)

**Purpose:** Query execution history

**Data Structure:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | UUID identifier |
| `query` | String | Executed SQL query |
| `executedAt` | DateTime | Execution timestamp |
| `executionTimeMs` | int | Duration in milliseconds |
| `rowCount` | int | Number of rows returned |
| `success` | bool | Execution success flag |
| `errorMessage` | String? | Error message if failed |
| `connectionId` | String | Associated connection ID |
| `databaseName` | String? | Target database |

**Auto-Cleanup:**
- Maximum 100 entries per connection
- Automatically removes oldest entries beyond limit

**API:**
```dart
// Get history for connection
final history = storageService.getQueryHistory(connectionId);

// Add to history
await storageService.addToHistory(entry);

// Clear history
await storageService.clearHistory(connectionId);
```

---

## 7. Hive Storage Implementation

### Initialization

`StorageService.init()` is called at app startup in `main.dart`:

```dart
Future<void> init() async {
  await Hive.initFlutter();

  // Register TypeAdapters
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ConnectionModelAdapter());
  }
  // Register all other adapters...

  // Derive Encryption Key (32 bytes for AES-256)
  final encryptionKey = _deriveEncryptionKey();

  // Open Encrypted Boxes
  await Hive.openBox<ConnectionModel>(
    'connections',
    encryptionCipher: HiveAesCipher(encryptionKey),
  );
}
```

### Adding a New Hive Box

**Step 1: Create Model with Hive Annotations**

```dart
@HiveType(typeId: 4) // Unique ID
class MyModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  MyModel({
    required this.id,
    required this.name,
  });
}
```

**Step 2: Generate TypeAdapter**

```bash
flutter pub run build_runner build
```

**Step 3: Register Adapter in StorageService**

```dart
static const String _myBoxName = 'my_box';

Future<void> init() async {
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(MyModelAdapter());
  }

  await Hive.openBox<MyModel>(
    _myBoxName,
    encryptionCipher: HiveAesCipher(encryptionKey),
  );
}
```

**Step 4: Add Box Accessor Methods**

```dart
Box<MyModel> get myBox => Hive.box<MyModel>(_myBoxName);

Future<void> saveMyModel(MyModel model) async {
  await myBox.put(model.id, model);
}

List<MyModel> getAllMyModels() {
  return myBox.values.toList();
}
```

---

## 8. Core UI Components

### Pages Overview

| Page | Path | Description |
|-------|------|-------------|
| `ConnectionsPage` | `/` | Entry page with connection list, add button, settings button |
| `DashboardPage` | `/dashboard` | Main app interface with 4-tab bottom navigation |
| `TableDataPage` | `/dashboard/table` | View/edit table rows with pagination |
| `QueryResultsPage` | `/dashboard/query-results` | Display query execution results |

### Navigation Structure

```
App Start
  ↓
ConnectionsPage
  ↓ (tap connection card)
DashboardPage (Bottom Nav: 4 tabs)
  ├── Tab 0: SchemaTab
  │     └── (tap table) → TableDataPage
  ├── Tab 1: QueryTab
  ├── Tab 2: History (Coming Soon)
  └── Tab 3: Settings (Coming Soon)
```

### Dialogs

| Dialog | Purpose | Location |
|---------|----------|----------|
| `ConnectionDialog` | Add/Edit database connections | `features/connections/presentation/dialogs/` |
| `SettingsDialog` | App settings (toggles + AI config) | `features/settings/presentation/dialogs/` |
| `RowEditDialog` | Edit table row data with prev/next nav | `features/dashboard/presentation/dialogs/` |
| `EditConfirmationDialog` | Confirm row edits with diff view | `features/dashboard/presentation/dialogs/` |

### Widgets

| Widget | Purpose |
|---------|----------|
| `ConnectionCard` | Display connection with status, actions |

### Bottom Navigation (DashboardPage)

| Index | Icon | Label | Content |
|--------|-------|--------|---------|
| 0 | Icons.dns | Databases | SchemaTab |
| 1 | Icons.code | Editor | QueryTab |
| 2 | Icons.history | History | Placeholder (Coming Soon) |
| 3 | Icons.settings | Settings | Placeholder (Coming Soon) |

---

## 9. Common Patterns

### Form Validation Pattern

```dart
final _formKey = GlobalKey<FormState>();

TextFormField(
  controller: _controller,
  decoration: const InputDecoration(labelText: 'Field Name'),
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
),

// On submit:
if (_formKey.currentState!.validate()) {
  // Process valid form
}
```

### Async Operations with Loading State

```dart
Future<void> _doAsyncWork() async {
  setState(() {
    _isLoading = true;
    _error = null;
  });

  try {
    await someAsyncOperation();
  } catch (e) {
    setState(() {
      _error = e.toString();
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
```

### Error Handling with User Feedback

```dart
try {
  await operation();
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Success!')),
    );
  }
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

### File Selection (Cross-platform)

```dart
import 'package:file_selector/file_selector.dart';

Future<void> _pickFile() async {
  const XTypeGroup typeGroup = XTypeGroup(label: 'Files');
  final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
  if (file != null) {
    setState(() {
      _pathController.text = file.path;
    });
  }
}
```

---

## 10. Coding Standards

### General Rules

- **No unnecessary comments** - Code should be self-documenting
- **Follow existing code style** - Match patterns in codebase
- **Use existing libraries** - Check `pubspec.yaml` before adding new packages
- **Run `flutter analyze`** - Must pass before committing

### File Naming

- **Files:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Variables/Functions:** `camelCase`
- **Constants:** `lowerCamelCase` or `SCREAMING_SNAKE_CASE`

### Imports

```dart
// Dart core imports first
import 'dart:convert';

// Package imports next
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Project imports last (relative)
import '../models/my_model.dart';
import '../../services/my_service.dart';
```

### Null Safety

```dart
// Prefer non-nullable types
String name; // Good
String? name; // Use only when truly nullable

// Default values
String name = myParam ?? 'default';

// Early returns
if (value == null) return;
```

---

## 11. Feature Development Checklist

When adding a new feature, ensure:

- [ ] Storage uses Hive (NOT flutter_secure_storage)
- [ ] State uses Provider pattern with ChangeNotifier
- [ ] UI follows Material 3 theme
- [ ] Model has Hive TypeAdapter with unique typeId
- [ ] TypeAdapter registered in StorageService.init()
- [ ] Encrypted box opened in StorageService.init()
- [ ] Provider registered in MultiProvider (app.dart)
- [ ] Feature is self-contained in its folder
- [ ] Loading and error states handled
- [ ] `flutter analyze` passes with no errors
- [ ] Dark theme colors match app scheme
- [ ] Dialogs use proper close patterns

---

## 12. Project-Specific Notes

### Default Settings

- `lockDelete`: `true` (enabled by default)
- `lockDrop`: `true` (enabled by default)
- `provider`: `openai`

### Connection Support

- **MySQL:** via mysql_dart
- **PostgreSQL:** via postgres package
- **Features:**
  - SSL connections
  - SSH tunnel support
  - Optional default database selection

### Query Management

- Saved queries per connection
- Favorite queries filtering
- Query history limited to 100 entries per connection
- Auto-cleanup of old history entries

### Dependencies

Key packages from `pubspec.yaml`:
- `provider` - State management
- `hive_flutter` - Encrypted local storage
- `mysql_dart` - MySQL connectivity
- `postgres` - PostgreSQL connectivity
- `google_fonts` - Inter font
- `data_table_2` - Table display component

---

## 13. Common Commands

```bash
# Run app
flutter run -d macos
flutter run -d windows
flutter run -d android

# Build for release
flutter build macos --release
flutter build windows --release
flutter build apk --release
flutter build appbundle --release

# Clean build
flutter clean

# Generate TypeAdapters
flutter pub run build_runner build --delete-conflicting-outputs

# Analyze code
flutter analyze --no-pub

# Format code
dart format .

# Get dependencies
flutter pub get
```

---

## 14. Troubleshooting

### macOS Keychain Entitlement Error (-34018)

**Symptom:** `PlatformException(Unexpected security result code, Code: -34018)`

**Cause:** Using `flutter_secure_storage` without proper entitlements

**Solution:** DO NOT USE flutter_secure_storage. Use Hive with encryption instead.

### Hive Adapter Not Registered

**Symptom:** `HiveError: No adapter found for type X`

**Solution:**
1. Run `flutter pub run build_runner build`
2. Check adapter registration in `StorageService.init()`
3. Ensure typeId is unique

### Provider Not Found

**Symptom:** `ProviderNotFoundException`

**Solution:**
1. Check provider is registered in `MultiProvider` in `app.dart`
2. Check you're accessing provider in widget tree
3. Use `context.read<T>()` for reads, `context.watch<T>()` for rebuilds

---

## 15. Contact & Resources

- **Repository:** Check project root for README.md
- **Flutter Docs:** https://flutter.dev/docs
- **Provider Docs:** https://pub.dev/packages/provider
- **Hive Docs:** https://docs.hivedb.dev

---

**Last Updated:** 2026-02-22
**Version:** 1.0.0
