<div align="center">

  ![Fluxlyn Logo](assets/icon/app_icon.png)

  # Fluxlyn

  **A Modern Cross-Platform Database Explorer**

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.10+-blue?logo=dart)](https://dart.dev)
  [![License](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)
  [![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Android%20%7C%20Windows-lightgrey?logo=flutter)](https://flutter.dev/multi-platform)

  [Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Contributing](#-contributing)

</div>

---

## 📖 About

Fluxlyn is a powerful, cross-platform database explorer built with Flutter, designed for everyone. It provides a modern interface for managing MySQL databases with advanced features like SSH tunneling, AI-powered query assistance, and secure encrypted storage of connections.

**Supported Platforms:**
- 🍎 macOS
- 🤖 Android
- 🪟 Windows
- 🔜 iOS (Coming Soon)
- 🔜 Linux (Coming Soon)

---

## 🚀 Quick Start

Get up and running with Fluxlyn in under 5 minutes:

```bash
# 1. Clone the repository
git clone https://github.com/sajidalianjum/fluxlyn.git
cd fluxlyn

# 2. Install dependencies
flutter pub get

# 3. Generate type adapters
flutter pub run build_runner build --delete-conflicting-outputs

# 4. Run the app
# On macOS
flutter run -d macos

# On Windows
flutter run -d windows

# On Android
flutter run -d android
```

That's it! You're ready to explore your databases. Click the **"+"** button to add your first connection.

---

### Why Fluxlyn?

- 🔒 **Secure**: All credentials encrypted with AES-256
- 🚀 **Fast**: Built with Flutter for native performance
- 🎨 **Modern UI**: Material 3 design with dark theme
- 🤖 **AI-Powered**: Integrated AI assistance for query generation
- 🔌 **SSH Tunneling**: Secure database connections through SSH
- 💾 **Query Management**: Save, organize, and track your queries
- 📊 **Rich Data Tables**: Advanced data grid with sorting and filtering

---

## ✨ Features

### Database Management
- 🗄️ **MySQL & PostgreSQL Support** - Full database connectivity
- 🔗 **Connection Management** - Save and manage multiple database connections
- 🔐 **SSL/TLS Support** - Secure database connections
- 📡 **SSH Tunneling** - Connect to remote databases through SSH tunnels
  - Password and private key authentication
  - Automatic fallback between netcat and direct-tcpip

### Query Editor
- 📝 **SQL Editor** - Syntax-highlighted SQL query editor
- 💾 **Save Queries** - Save frequently used queries
- 📜 **Query History** - Automatic tracking of executed queries (last 100 per connection)
- ⚡ **Query Execution** - Execute queries with performance metrics

### Data Exploration
- 📊 **Schema Browser** - Browse databases, tables, and columns
- 📋 **Data Grid** - View and edit table data
- 🔍 **Table Search** - Quick search across tables
- 📄 **Pagination** - Efficiently navigate large datasets
- ✏️ **Inline Editing** - Edit rows directly with confirmation dialog

### Security
- 🔒 **Encrypted Storage** - All sensitive data encrypted with AES-256
- 🛡️ **Protection Locks** - Two-tier protection system:
  - **Read-Only Mode**: Blocks ALL write operations (INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, TRUNCATE, RENAME)
  - **Destructive Operations Lock**: Blocks irreversible operations (DELETE, DROP, TRUNCATE, ALTER) while allowing data modification (UPDATE)
- 🔑 **Secure Credentials** - No plaintext password storage

### AI Integration
- 🤖 **Multiple AI Providers**:
  - OpenAI (GPT-4, GPT-3.5)
  - Anthropic (Claude)
  - OpenRouter
  - Groq
  - xAI
  - Custom endpoints

### User Experience
- 🌙 **Dark Theme** - Eye-friendly dark interface
- 🎨 **Material 3 Design** - Modern, consistent UI
- 📱 **Responsive Layout** - Adapts to different screen sizes
- ⚙️ **Settings Management** - Customizable app behavior

---

## 🚀 Installation

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (3.19.0 or higher)
  ```bash
  flutter --version
  ```
- **Dart SDK** (3.10.8 or higher)

### Platform-Specific Requirements

**macOS:**
- Xcode command line tools
  ```bash
  xcode-select --install
  ```

**Windows:**
- Visual Studio 2022 with "Desktop development with C++" workload
- Windows 10 or later

**Android:**
- Android Studio
- Android SDK (API 21 or higher)
- Enable Developer Mode on your device

### Step 1: Clone the Repository

```bash
git clone https://github.com/sajidalianjum/fluxlyn.git
cd fluxlyn
```

### Step 2: Install Dependencies

```bash
flutter pub get
```

### Step 3: Generate Type Adapters

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Step 4: Run the Application

```bash
# On macOS
flutter run -d macos

# On Windows
flutter run -d windows

# On Android
flutter run -d android

# Or run in release mode
flutter run --release -d macos
```

---

## 📖 Usage

### First Launch

1. **Welcome Screen** - You'll be greeted with the connections page
2. **Add Connection** - Click the "+" button to create a new database connection
3. **Configure Connection** - Fill in your database details:
   - Connection name
   - Host and port
   - Username and password
   - Database name (optional)
   - SSL options
   - SSH tunneling (optional)

### Managing Connections

- **Connect** - Click on a connection card to connect
- **Edit** - Use the edit button to modify connection details
- **Delete** - Remove connections (with confirmation if lock is enabled)

### Dashboard

Once connected, you'll have access to 3 main tabs:

#### 1. Databases Tab
- Browse all databases on the server
- View tables within each database
- Click on tables to view data
- Edit rows inline with confirmation

#### 2. Editor Tab
- Write SQL queries with syntax highlighting
- Execute queries and see results
- Save queries for later use
- Export query results to CSV, JSON, or XLSX

#### 3. History Tab
- Comprehensive query history
- Clear all history functionality

### Settings

Access settings by clicking the settings icon on the connections page:

- **Protection**:
  - **Read-Only Mode**: Prevent all write operations (INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, TRUNCATE, RENAME)
  - **Lock for Destructive Operations**: Prevent accidental data modification through destructive operations (DELETE, DROP, TRUNCATE, ALTER) while allowing safe updates (UPDATE)
- **AI Configuration**:
  - Select AI provider
  - Configure API key
  - Set custom endpoint (for custom provider)

---

## 🛠️ Development

### Project Structure

```
lib/
├── main.dart                 # App entry point
├── src/
│   ├── app.dart             # App configuration
│   ├── core/                # Core utilities and services
│   │   ├── constants/       # App constants
│   │   ├── models/          # Core data models
│   │   ├── services/        # Storage, database, AI services
│   │   ├── theme/           # App theming
│   │   └── widgets/         # Reusable widgets
│   └── features/            # Feature modules
│       ├── connections/     # Connection management
│       ├── dashboard/       # Main app interface
│       ├── queries/         # Saved queries
│       ├── settings/        # App settings
│       └── welcome/         # Welcome/onboarding
```

### Key Technologies

| Package | Purpose |
|---------|---------|
| `provider` | State management |
| `hive_flutter` | Encrypted local storage |
| `mysql_dart` | MySQL database connectivity |
| `dartssh2` | SSH tunneling |
| `google_fonts` | Typography (Inter font) |
| `data_table_2` | Advanced data grid |
| `flutter_code_editor` | Code editor component |
| `flutter_highlight` | SQL syntax highlighting |

### Available Scripts

```bash
# Run the app
flutter run -d macos
flutter run -d windows
flutter run -d android

# Build for release
flutter build macos --release
flutter build windows --release
flutter build apk --release
flutter build appbundle --release

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format .

# Clean build artifacts
flutter clean

# Generate code (TypeAdapters)
flutter pub run build_runner build --delete-conflicting-outputs
```

### Coding Standards

- **No unnecessary comments** - Code should be self-documenting
- **Follow existing code style** - Match patterns in codebase
- **Use existing libraries** - Check `pubspec.yaml` before adding new packages
- **Run `flutter analyze`** - Must pass before committing

For detailed developer guidelines, see [AGENTS.md](AGENTS.md).

---

## 🔒 Security

### Data Storage

Fluxlyn uses **Hive** with **AES-256 encryption** for all persistent data:

- ✅ Encrypted credentials (passwords, API keys, SSH keys)
- ✅ Encrypted connection configurations
- ✅ Encrypted saved queries
- ❌ NO use of platform keychains (avoids entitlement issues)

### Protection Features

- **Operation Locks**: Optional confirmation dialogs for DELETE and DROP operations
- **Secure Connections**: SSL/TLS support for database connections
- **SSH Tunneling**: Secure connectivity through SSH tunnels

---

## 🗺️ Roadmap

### Version 1.1 (Planned)
- [ ] AI-powered query optimization
- [ ] Visual query builder
- [ ] Database backup/restore

### Version 1.2 (Planned)
- [ ] iOS support
- [ ] Linux support

### Version 2.0 (Future)
- [ ] Collaborative features
- [ ] Cloud sync for connections
- [ ] Plugin system
- [ ] Advanced data visualization

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Make your changes**
4. **Run tests and analysis** (`flutter test && flutter analyze`)
5. **Commit your changes** (`git commit -m 'Add amazing feature'`)
6. **Push to the branch** (`git push origin feature/amazing-feature`)
7. **Open a Pull Request**

### Development Guidelines

- Follow the existing code structure and patterns
- Use Provider for state management
- Use Hive for all persistent storage
- Ensure Material 3 design compliance
- Test on all target platforms (macOS, Android, Windows) before submitting PR
- Update documentation as needed

See [AGENTS.md](AGENTS.md) for comprehensive development guidelines.

---

## 🔒 Privacy

### AI Features & Data Usage

Fluxlyn includes AI-powered features to help you generate SQL queries more efficiently. Here's how it works:

**Direct Integration with AI Providers**
- Requests are sent **directly** to the AI provider you configure (OpenAI, Anthropic, Groq, xAI, OpenRouter, or custom endpoint)
- Fluxlyn acts only as a conduit - it forwards your query and schema information to your chosen provider
- **Fluxlyn does NOT store, log, or process** any AI requests or responses
- All communication is between your device and the AI provider

**What is sent to your AI provider:**
- Database schema information (table names and column definitions)
- Your natural language query description

**What is NOT sent:**
- Actual data from your database
- Database credentials or passwords
- Connection details (host, port, username)
- SSH credentials or keys

**Supported AI providers:**
- OpenAI (GPT-4, GPT-3.5)
- Anthropic (Claude)
- OpenRouter
- Groq
- xAI
- Custom endpoints

Your privacy is important to us. All sensitive data stored locally on your device is encrypted with AES-256, and AI requests go directly to your configured provider without any intermediation.

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the [GNU General Public License](LICENSE) for more details.

---

## 👤 Author

**Softlitude**

- GitHub: [@sajidalianjum](https://github.com/sajidalianjum)
- Built with passion for making database management easier for everyone

---

## 🙏 Acknowledgments

- **Flutter Team** - For the amazing Flutter framework
- **Provider Package** - Excellent state management solution
- **Hive Team** - Fast and secure local storage
- **Material Design Team** - Beautiful design system

---

## 📞 Support

- 🐛 Issues: [GitHub Issues](https://github.com/sajidalianjum/fluxlyn/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/sajidalianjum/fluxlyn/discussions)
- 📖 Documentation: [AGENTS.md](AGENTS.md) for developer guidelines

---

## ⭐ Show Your Support

If you find Fluxlyn helpful, consider giving it a star on GitHub!

<div align="center">
  <sub>Built with ❤️ by <a href="https://github.com/sajidalianjum">Sajid Ali Anjum</a></sub>
</div>
