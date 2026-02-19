import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import '../../models/connection_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/snackbar_helper.dart';

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
  late TextEditingController _customTagController;
  bool _sslEnabled = false;
  ConnectionTag _selectedTag = ConnectionTag.none;

  // SSH Vars
  bool _useSsh = false;
  late TextEditingController _sshHostController;
  late TextEditingController _sshPortController;
  late TextEditingController _sshUserController;
  late TextEditingController _sshPasswordController;
  late TextEditingController _sshKeyPathController;
  late TextEditingController _sshKeyPasswordController;
  String _sshAuthMethod = 'password'; // 'password', 'key', 'agent'
  bool _keyModified = false;
  String? _originalKey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final c = widget.connection;
    _nameController = TextEditingController(text: c?.name ?? '');
    _hostController = TextEditingController(text: c?.host ?? '');
    _portController = TextEditingController(
      text: c?.port.toString() ?? '${AppConstants.portMySQL}',
    );
    _userController = TextEditingController(text: c?.username ?? '');
    _passwordController = TextEditingController(text: c?.password ?? '');
    _databaseController = TextEditingController(text: c?.databaseName ?? '');
    _sslEnabled = c?.sslEnabled ?? false;
    _customTagController = TextEditingController(text: c?.customTag ?? '');
    _selectedTag = c?.tag ?? ConnectionTag.none;

    _useSsh = c?.useSsh ?? false;
    _sshHostController = TextEditingController(text: c?.sshHost ?? '');
    _sshPortController = TextEditingController(
      text: c?.sshPort?.toString() ?? '${AppConstants.portSSH}',
    );
    _sshUserController = TextEditingController(text: c?.sshUsername ?? '');
    _sshPasswordController = TextEditingController(text: c?.sshPassword ?? '');

    _originalKey = c?.sshPrivateKey;
    if (c?.sshPrivateKey != null && c!.sshPrivateKey!.isNotEmpty) {
      _sshAuthMethod = 'key';
      _sshKeyPathController = TextEditingController(text: '<Private Key>');
    } else {
      _sshKeyPathController = TextEditingController(text: '');
    }

    _sshKeyPasswordController = TextEditingController(
      text: c?.sshKeyPassword ?? '',
    );
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
    _customTagController.dispose();

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
      String? privateKeyToSave;
      if (_sshAuthMethod == 'key') {
        if (_keyModified) {
          privateKeyToSave = _sshKeyPathController.text;
        } else {
          privateKeyToSave = _originalKey;
        }
      }

      final connection = ConnectionModel(
        id: widget.connection?.id,
        name: _nameController.text,
        host: _hostController.text,
        port: int.parse(_portController.text),
        username: _userController.text,
        password: _passwordController.text,
        sslEnabled: _sslEnabled,
        type: ConnectionType.mysql,

        useSsh: _useSsh,
        sshHost: _sshHostController.text,
        sshPort: int.tryParse(_sshPortController.text) ?? AppConstants.portSSH,
        sshUsername: _sshUserController.text,
        sshPassword: _sshAuthMethod == 'password'
            ? _sshPasswordController.text
            : null,
        sshPrivateKey: privateKeyToSave,
        sshKeyPassword: _sshAuthMethod == 'key'
            ? _sshKeyPasswordController.text
            : null,
        databaseName: _databaseController.text.isNotEmpty
            ? _databaseController.text
            : null,
        tag: _selectedTag,
        customTag:
            _selectedTag == ConnectionTag.custom &&
                _customTagController.text.isNotEmpty
            ? _customTagController.text
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
        final formatted = _formatSSHKey(content);
        setState(() {
          _sshKeyPathController.text = formatted;
          _keyModified = true;
        });
      } catch (e) {
        if (mounted) {
          SnackbarHelper.showError(context, 'Failed to read key file: $e');
        }
      }
    }
  }

  String _formatSSHKey(String key) {
    String formatted = key.trim();

    if (formatted.isEmpty) return formatted;

    if (!formatted.endsWith('\n')) {
      formatted += '\n';
    }

    return formatted;
  }

  void _clearKey() {
    setState(() {
      _sshKeyPathController.text = '';
      _keyModified = true;
    });
  }

  Future<void> _pasteKey() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      final formatted = _formatSSHKey(clipboardData!.text!);
      setState(() {
        _sshKeyPathController.text = formatted;
        _keyModified = true;
      });
    }
  }

  Widget _buildTagChip(ConnectionTag tag, String label) {
    final isSelected = _selectedTag == tag;
    final color = _getTagColor(tag);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedTag = tag;
          } else if (_selectedTag == tag) {
            _selectedTag = ConnectionTag.none;
          }
        });
      },
      selectedColor: color.withValues(alpha: 0.3),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }

  Color _getTagColor(ConnectionTag tag) {
    switch (tag) {
      case ConnectionTag.none:
        return Colors.grey;
      case ConnectionTag.development:
        return Colors.green;
      case ConnectionTag.production:
        return Colors.red;
      case ConnectionTag.testing:
        return Colors.yellow;
      case ConnectionTag.staging:
        return Colors.orange;
      case ConnectionTag.local:
        return Colors.purple;
      case ConnectionTag.custom:
        return Colors.blue;
    }
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
                        const SizedBox(height: 16),
                        Text(
                          'Tag',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        if (_selectedTag == ConnectionTag.custom)
                          TextFormField(
                            controller: _customTagController,
                            decoration: const InputDecoration(
                              labelText: 'Custom Tag Name',
                              hintText: 'e.g., Analytics, Staging, Team A',
                              suffixIcon: Icon(Icons.edit),
                            ),
                            validator: (value) =>
                                _selectedTag == ConnectionTag.custom &&
                                    (value?.isEmpty ?? true)
                                ? 'Required'
                                : null,
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildTagChip(ConnectionTag.none, 'None'),
                              _buildTagChip(
                                ConnectionTag.development,
                                'Development',
                              ),
                              _buildTagChip(
                                ConnectionTag.production,
                                'Production',
                              ),
                              _buildTagChip(ConnectionTag.testing, 'Testing'),
                              _buildTagChip(ConnectionTag.staging, 'Staging'),
                              _buildTagChip(ConnectionTag.local, 'Local'),
                              _buildTagChip(ConnectionTag.custom, 'Custom +'),
                            ],
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
                                          _sshKeyPathController.text ==
                                              '<Private Key>'
                                          ? 'Private Key (saved)'
                                          : (_sshKeyPathController
                                                    .text
                                                    .isNotEmpty
                                                ? 'Private Key (loaded)'
                                                : 'Private Key'),
                                      hintText: 'Pick a file or paste key',
                                      suffixIcon:
                                          _sshKeyPathController.text ==
                                              '<Private Key>'
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.paste,
                                                    size: 20,
                                                  ),
                                                  onPressed: _pasteKey,
                                                  tooltip: 'Paste new key',
                                                ),
                                              ],
                                            )
                                          : (_sshKeyPathController
                                                    .text
                                                    .isNotEmpty
                                                ? IconButton(
                                                    icon: const Icon(
                                                      Icons.clear,
                                                      size: 20,
                                                    ),
                                                    onPressed: _clearKey,
                                                    tooltip: 'Clear key',
                                                  )
                                                : null),
                                    ),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                    minLines: 1,
                                    maxLines: 10,
                                    readOnly:
                                        _sshKeyPathController.text ==
                                        '<Private Key>',
                                    keyboardType: TextInputType.multiline,
                                    validator: (value) {
                                      if (_useSsh && (value?.isEmpty ?? true)) {
                                        return 'Required';
                                      }
                                      if (value != null &&
                                          value.trim().isNotEmpty) {
                                        final trimmed = value.trim();
                                        if (trimmed == '<Private Key>') {
                                          return null;
                                        }
                                        if (!trimmed.startsWith('-----BEGIN')) {
                                          return 'Invalid key format: must start with -----BEGIN';
                                        }
                                        if (!trimmed.endsWith('-----END')) {
                                          return 'Invalid key format: must end with -----END';
                                        }
                                      }
                                      return null;
                                    },
                                    onFieldSubmitted: (value) {
                                      final formatted = _formatSSHKey(value);
                                      if (formatted != value) {
                                        _sshKeyPathController.text = formatted;
                                        _keyModified = true;
                                      } else if (value != '<Private Key>') {
                                        _keyModified = true;
                                      }
                                    },
                                    onTapOutside: (_) {
                                      final formatted = _formatSSHKey(
                                        _sshKeyPathController.text,
                                      );
                                      if (formatted !=
                                          _sshKeyPathController.text) {
                                        _sshKeyPathController.text = formatted;
                                        _keyModified = true;
                                      }
                                    },
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
