import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import '../../models/connection_model.dart';

class ConnectionDialog extends StatefulWidget {
  final ConnectionModel? connection;
  final Function(ConnectionModel) onSave;

  const ConnectionDialog({super.key, this.connection, required this.onSave});

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // General Vars
  late TextEditingController _nameController;
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _userController;
  late TextEditingController _passwordController;
  late TextEditingController _databaseController;
  bool _sslEnabled = false;

  // SSH Vars
  bool _useSsh = false;
  late TextEditingController _sshHostController;
  late TextEditingController _sshPortController;
  late TextEditingController _sshUserController;
  late TextEditingController _sshPasswordController;
  late TextEditingController _sshKeyPathController;
  late TextEditingController _sshKeyPasswordController;
  String _sshAuthMethod = 'password'; // 'password', 'key', 'agent'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final c = widget.connection;
    _nameController = TextEditingController(text: c?.name ?? '');
    _hostController = TextEditingController(text: c?.host ?? '');
    _portController = TextEditingController(text: c?.port.toString() ?? '3306');
    _userController = TextEditingController(text: c?.username ?? '');
    _passwordController = TextEditingController(text: c?.password ?? '');
    _databaseController = TextEditingController(text: c?.databaseName ?? '');
    _sslEnabled = c?.sslEnabled ?? false;

    _useSsh = c?.useSsh ?? false;
    _sshHostController = TextEditingController(text: c?.sshHost ?? '');
    _sshPortController = TextEditingController(
      text: c?.sshPort?.toString() ?? '22',
    );
    _sshUserController = TextEditingController(text: c?.sshUsername ?? '');
    _sshPasswordController = TextEditingController(text: c?.sshPassword ?? '');
    _sshKeyPathController = TextEditingController(text: c?.sshPrivateKey ?? '');
    _sshKeyPasswordController = TextEditingController(
      text: c?.sshKeyPassword ?? '',
    );

    if (c?.sshPrivateKey != null && c!.sshPrivateKey!.isNotEmpty) {
      _sshAuthMethod = 'key';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _databaseController.dispose();

    _sshHostController.dispose();
    _sshPortController.dispose();
    _sshUserController.dispose();
    _sshPasswordController.dispose();
    _sshKeyPathController.dispose();
    _sshKeyPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final connection = ConnectionModel(
        id: widget.connection?.id, // Keep ID if editing
        name: _nameController.text,
        host: _hostController.text,
        port: int.parse(_portController.text),
        username: _userController.text,
        password: _passwordController.text,
        sslEnabled: _sslEnabled,
        type: ConnectionType.mysql,

        useSsh: _useSsh,
        sshHost: _sshHostController.text,
        sshPort: int.tryParse(_sshPortController.text) ?? 22,
        sshUsername: _sshUserController.text,
        sshPassword: _sshAuthMethod == 'password'
            ? _sshPasswordController.text
            : null,
        sshPrivateKey: _sshAuthMethod == 'key'
            ? _sshKeyPathController.text
            : null,
        sshKeyPassword: _sshAuthMethod == 'key'
            ? _sshKeyPasswordController.text
            : null,
        databaseName: _databaseController.text.isNotEmpty
            ? _databaseController.text
            : null,
      );

      widget.onSave(connection);
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickKeyFile() async {
    const XTypeGroup typeGroup = XTypeGroup(label: 'private keys');
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[typeGroup],
    );
    if (file != null) {
      try {
        final fileObj = File(file.path);
        final content = await fileObj.readAsString();
        setState(() {
          _sshKeyPathController.text = content;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to read key file: $e')),
          );
        }
      }
    }
  }

  void _clearKey() {
    setState(() {
      _sshKeyPathController.text = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxWidth: isMobile ? screenWidth - 48 : 500,
          maxHeight: 700,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.connection == null
                          ? 'New Connection'
                          : 'Edit Connection',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                      tabs: const [
                        Tab(text: 'General'),
                        Tab(text: 'SSH Tunnel'),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.connection == null
                          ? 'New Connection'
                          : 'Edit Connection',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                      tabs: const [
                        Tab(text: 'General'),
                        Tab(text: 'SSH Tunnel'),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: General
                    ListView(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Connection Name',
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _hostController,
                                decoration: const InputDecoration(
                                  labelText: 'Host',
                                ),
                                validator: (value) =>
                                    value?.isEmpty ?? true ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _portController,
                                decoration: const InputDecoration(
                                  labelText: 'Port',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _userController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                          ),
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _databaseController,
                          decoration: const InputDecoration(
                            labelText: 'Database (Optional)',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Enable SSL'),
                          value: _sslEnabled,
                          onChanged: (val) => setState(() => _sslEnabled = val),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),

                    // Tab 2: SSH
                    ListView(
                      children: [
                        SwitchListTile(
                          title: const Text('Use SSH Tunnel'),
                          value: _useSsh,
                          onChanged: (val) => setState(() => _useSsh = val),
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (_useSsh) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _sshHostController,
                                  decoration: const InputDecoration(
                                    labelText: 'SSH Host',
                                  ),
                                  validator: (value) =>
                                      _useSsh && (value?.isEmpty ?? true)
                                      ? 'Required'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _sshPortController,
                                  decoration: const InputDecoration(
                                    labelText: 'Port',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _sshUserController,
                            decoration: const InputDecoration(
                              labelText: 'SSH Username',
                            ),
                            validator: (value) =>
                                _useSsh && (value?.isEmpty ?? true)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Authentication Method',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'password',
                                label: Text('Password'),
                              ),
                              ButtonSegment(
                                value: 'key',
                                label: Text('Private Key'),
                              ),
                              // ButtonSegment(value: 'agent', label: Text('Agent')), // Scope creep for now
                            ],
                            selected: {_sshAuthMethod},
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _sshAuthMethod = newSelection.first;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          if (_sshAuthMethod == 'password')
                            TextFormField(
                              controller: _sshPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'SSH Password',
                              ),
                              obscureText: true,
                              validator: (value) =>
                                  _useSsh && (value?.isEmpty ?? true)
                                  ? 'Required'
                                  : null,
                            ),

                          if (_sshAuthMethod == 'key') ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _sshKeyPathController,
                                    decoration: InputDecoration(
                                      labelText:
                                          _sshKeyPathController.text.isNotEmpty
                                          ? 'Private Key (loaded)'
                                          : 'Private Key',
                                      hintText: 'Pick a file or paste key',
                                      suffixIcon:
                                          _sshKeyPathController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.clear,
                                                size: 20,
                                              ),
                                              onPressed: _clearKey,
                                              tooltip: 'Clear key',
                                            )
                                          : null,
                                    ),
                                    maxLines:
                                        _sshKeyPathController.text.isNotEmpty
                                        ? 2
                                        : 1,
                                    readOnly: false,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: IconButton(
                                    onPressed: _pickKeyFile,
                                    icon: const Icon(Icons.folder_open),
                                    tooltip: 'Pick file',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _sshKeyPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'Key Passphrase (Optional)',
                              ),
                              obscureText: true,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(onPressed: _submit, child: const Text('Save')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
