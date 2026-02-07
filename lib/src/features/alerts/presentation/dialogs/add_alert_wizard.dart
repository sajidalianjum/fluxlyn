import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../connections/models/connection_model.dart';
import '../../../connections/providers/connections_provider.dart';
import '../../../dashboard/providers/dashboard_provider.dart';
import '../../../dashboard/presentation/widgets/query_editor_widget.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../core/services/schema_service.dart';
import '../../../../core/services/ai_service.dart';
import '../../models/alert_model.dart';
import '../../providers/alerts_provider.dart';

class AddAlertWizard extends StatefulWidget {
  const AddAlertWizard({super.key});

  @override
  State<AddAlertWizard> createState() => _AddAlertWizardState();
}

class _AddAlertWizardState extends State<AddAlertWizard> {
  final _uuid = const Uuid();
  int _currentStep = 0;

  ConnectionModel? _selectedConnection;
  String? _selectedDatabase;
  String _query = '';
  String _alertName = '';
  AlertSchedule _schedule = AlertSchedule.daily;
  int? _scheduleHour;
  int? _scheduleMinute;
  String? _thresholdColumn;
  ThresholdOperator? _thresholdOperator;
  double? _thresholdValue;
  bool _isConnecting = false;
  String? _connectionError;

  List<String>? _testColumns;
  List<Map<String, dynamic>>? _testResults;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create Alert',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildStepContent()),
            const SizedBox(height: 16),
            _buildStepNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildSelectConnectionStep();
      case 1:
        return _buildSelectDatabaseStep();
      case 2:
        return _buildQueryStep();
      case 3:
        return _buildTestResultsStep();
      case 4:
        return _buildConfigureAlertStep();
      case 5:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSelectConnectionStep() {
    final connectionsProvider = context.watch<ConnectionsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 1: Select Connection',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (connectionsProvider.connections.isEmpty)
          const Center(
            child: Text(
              'No connections available. Please create a connection first.',
            ),
          )
        else
          ...connectionsProvider.connections.map((connection) {
            return RadioListTile<ConnectionModel>(
              title: Text(connection.name),
              subtitle: Text('${connection.host}:${connection.port}'),
              value: connection,
              groupValue: _selectedConnection,
              onChanged: _isConnecting
                  ? null
                  : (value) async {
                      if (value == null) return;

                      setState(() {
                        _selectedConnection = value;
                        _isConnecting = true;
                        _connectionError = null;
                        _selectedDatabase = null;
                      });

                      try {
                        final dashboardProvider = context
                            .read<DashboardProvider>();
                        await dashboardProvider.connect(value);

                        if (mounted && dashboardProvider.error != null) {
                          setState(() {
                            _connectionError = dashboardProvider.error;
                            _isConnecting = false;
                          });
                        } else {
                          setState(() {
                            _isConnecting = false;
                          });
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            _connectionError = e.toString();
                            _isConnecting = false;
                          });
                        }
                      }
                    },
            );
          }),
        if (_isConnecting)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Connecting to database...'),
              ],
            ),
          ),
        if (_connectionError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectionError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectDatabaseStep() {
    final dashboardProvider = context.watch<DashboardProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 2: Select Database',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (dashboardProvider.databases.isEmpty)
          const Center(
            child: Text(
              'No databases available. Please connect to a database first.',
            ),
          )
        else
          ...dashboardProvider.databases.map((database) {
            return RadioListTile<String>(
              title: Text(database),
              value: database,
              groupValue: _selectedDatabase,
              onChanged: (value) {
                setState(() {
                  _selectedDatabase = value;
                });
              },
            );
          }),
      ],
    );
  }

  Widget _buildQueryStep() {
    return QueryEditorWidget(
      initialQuery: _query,
      showDatabaseSelector: false,
      showAIQuery: true,
      showSaveQuery: false,
      showLoadQuery: false,
      showHistory: false,
      onShowDatabaseSelector: () async {},
      onShowAIQueryDialog: _showAIQueryDialog,
      onExecuteQuery: (query) async {
        final dashboardProvider = context.read<DashboardProvider>();
        final result = await dashboardProvider.executeQuery(query);
        if (result == null) {
          throw Exception('Failed to execute query');
        }

        final columns = result.rows.isNotEmpty
            ? result.rows.first.assoc().keys.toList()
            : <String>[];

        final rows = result.rows.map((row) {
          final rowMap = <String, dynamic>{};
          for (final col in columns) {
            try {
              final value = row.colByName(col);
              if (value != null) {
                rowMap[col] = value.toString();
              } else {
                rowMap[col] = null;
              }
            } catch (e) {
              rowMap[col] = '<binary>';
            }
          }
          return rowMap;
        }).toList();

        setState(() {
          _query = query;
          _testColumns = columns;
          _testResults = rows;
        });

        return rows;
      },
      onFormatSQL: null,
      onSaveQuery: null,
      onLoadQuery: null,
      onShowHistory: null,
      onClear: () => setState(() => _query = ''),
    );
  }

  Widget _buildTestResultsStep() {
    if (_testResults == null || _testColumns == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_testResults!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              'Query executed successfully',
              style: TextStyle(color: Colors.green),
            ),
            SizedBox(height: 8),
            Text('No rows returned', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final displayRows = _testResults!.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 4: Query Results',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'Showing ${displayRows.length} of ${_testResults!.length} rows',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                headingRowColor: WidgetStateColor.resolveWith(
                  (states) => const Color(0xFF0F172A),
                ),
                columns: _testColumns!.map((col) {
                  return DataColumn(
                    label: Text(
                      col,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
                rows: displayRows.map((row) {
                  return DataRow(
                    cells: _testColumns!.map((col) {
                      final value = row[col];
                      return DataCell(_buildCellContent(value));
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCellContent(dynamic value) {
    if (value == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'NULL',
          style: TextStyle(
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
            fontSize: 12,
          ),
        ),
      );
    }
    return Text(value.toString(), style: const TextStyle(color: Colors.white));
  }

  Widget _buildConfigureAlertStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 5: Configure Alert',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          TextField(
            decoration: const InputDecoration(
              labelText: 'Alert Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (value) => _alertName = value,
          ),
          const SizedBox(height: 16),

          const Text('Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<AlertSchedule>(
            segments: const [
              ButtonSegment(
                value: AlertSchedule.hourly,
                label: Text('Hourly'),
                icon: Icon(Icons.access_time),
              ),
              ButtonSegment(
                value: AlertSchedule.daily,
                label: Text('Daily'),
                icon: Icon(Icons.calendar_today),
              ),
              ButtonSegment(
                value: AlertSchedule.weekly,
                label: Text('Weekly'),
                icon: Icon(Icons.date_range),
              ),
            ],
            selected: {_schedule},
            onSelectionChanged: (Set<AlertSchedule> selection) {
              setState(() {
                _schedule = selection.first;
              });
            },
          ),
          const SizedBox(height: 16),

          if (_schedule != AlertSchedule.hourly) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Hour',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _scheduleHour,
                    items: List.generate(24, (hour) {
                      return DropdownMenuItem(
                        value: hour,
                        child: Text('${hour.toString().padLeft(2, '0')}:00'),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        _scheduleHour = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Minute',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _scheduleMinute,
                    items: List.generate(60, (minute) {
                      return DropdownMenuItem(
                        value: minute,
                        child: Text(minute.toString().padLeft(2, '0')),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        _scheduleMinute = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          const Text(
            'Threshold (Optional)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_testColumns != null && _testColumns!.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Column to Check',
                border: OutlineInputBorder(),
              ),
              initialValue: _thresholdColumn,
              items: _testColumns!.map((col) {
                return DropdownMenuItem(value: col, child: Text(col));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _thresholdColumn = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ThresholdOperator>(
                    decoration: const InputDecoration(
                      labelText: 'Operator',
                      border: OutlineInputBorder(),
                    ),
                    value: _thresholdOperator,
                    items: const [
                      DropdownMenuItem(
                        value: ThresholdOperator.greaterThan,
                        child: Text('> Greater than'),
                      ),
                      DropdownMenuItem(
                        value: ThresholdOperator.lessThan,
                        child: Text('< Less than'),
                      ),
                      DropdownMenuItem(
                        value: ThresholdOperator.equals,
                        child: Text('= Equals'),
                      ),
                      DropdownMenuItem(
                        value: ThresholdOperator.notEquals,
                        child: Text('!= Not equals'),
                      ),
                      DropdownMenuItem(
                        value: ThresholdOperator.greaterOrEqual,
                        child: Text('>= Greater or equal'),
                      ),
                      DropdownMenuItem(
                        value: ThresholdOperator.lessOrEqual,
                        child: Text('<= Less or equal'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _thresholdOperator = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) {
                      setState(() {
                        _thresholdValue = double.tryParse(value);
                      });
                    },
                  ),
                ),
              ],
            ),
          ] else
            const Text('Run query first to see available columns'),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 6: Review & Save',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildReviewItem('Alert Name', _alertName),
          const SizedBox(height: 12),
          _buildReviewItem(
            'Connection',
            _selectedConnection?.name ?? 'Not selected',
          ),
          const SizedBox(height: 12),
          _buildReviewItem('Database', _selectedDatabase ?? 'Not selected'),
          const SizedBox(height: 12),
          _buildReviewItem('Schedule', _getScheduleDisplay()),
          const SizedBox(height: 12),
          if (_thresholdColumn != null) ...[
            _buildReviewItem('Threshold', _getThresholdDisplay()),
            const SizedBox(height: 12),
          ],
          const Text('Query:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _query,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _getScheduleDisplay() {
    switch (_schedule) {
      case AlertSchedule.hourly:
        return 'Every hour';
      case AlertSchedule.daily:
        if (_scheduleHour != null && _scheduleMinute != null) {
          return 'Daily at ${_scheduleHour!.toString().padLeft(2, '0')}:${_scheduleMinute!.toString().padLeft(2, '0')}';
        }
        return 'Daily';
      case AlertSchedule.weekly:
        if (_scheduleHour != null && _scheduleMinute != null) {
          return 'Weekly at ${_scheduleHour!.toString().padLeft(2, '0')}:${_scheduleMinute!.toString().padLeft(2, '0')}';
        }
        return 'Weekly';
    }
  }

  String _getThresholdDisplay() {
    if (_thresholdColumn == null ||
        _thresholdOperator == null ||
        _thresholdValue == null) {
      return 'No threshold';
    }

    String operatorSymbol;
    switch (_thresholdOperator!) {
      case ThresholdOperator.greaterThan:
        operatorSymbol = '>';
        break;
      case ThresholdOperator.lessThan:
        operatorSymbol = '<';
        break;
      case ThresholdOperator.equals:
        operatorSymbol = '=';
        break;
      case ThresholdOperator.notEquals:
        operatorSymbol = '!=';
        break;
      case ThresholdOperator.greaterOrEqual:
        operatorSymbol = '>=';
        break;
      case ThresholdOperator.lessOrEqual:
        operatorSymbol = '<=';
        break;
    }

    return '$_thresholdColumn $operatorSymbol $_thresholdValue';
  }

  Widget _buildStepNavigation() {
    final isLastStep = _currentStep == 5;
    final isFirstStep = _currentStep == 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!isFirstStep)
          OutlinedButton(
            onPressed: () {
              setState(() {
                _currentStep--;
              });
            },
            child: const Text('Back'),
          )
        else
          const SizedBox.shrink(),
        Row(
          children: [
            ...List.generate(6, (index) {
              final isActive = index == _currentStep;
              final isCompleted = index < _currentStep;
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? Colors.blue
                      : isCompleted
                      ? Colors.green
                      : Colors.grey,
                ),
              );
            }),
          ],
        ),
        if (!isLastStep)
          FilledButton(
            onPressed: _canProceed() ? _handleNext : null,
            child: const Text('Next'),
          )
        else
          FilledButton(
            onPressed: _canSave() ? _handleSave : null,
            child: const Text('Save Alert'),
          ),
      ],
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _selectedConnection != null &&
            !_isConnecting &&
            _connectionError == null;
      case 1:
        return _selectedDatabase != null;
      case 2:
        return _query.isNotEmpty;
      case 3:
        return _testResults != null;
      case 4:
        return _alertName.isNotEmpty;
      case 5:
        return true;
      default:
        return false;
    }
  }

  bool _canSave() {
    return _canProceed() && _alertName.isNotEmpty;
  }

  Future<void> _handleNext() async {
    setState(() {
      _currentStep++;
    });
  }

  Future<void> _handleSave() async {
    final now = DateTime.now();
    final alert = AlertModel(
      id: _uuid.v4(),
      name: _alertName,
      connectionId: _selectedConnection!.id,
      databaseName: _selectedDatabase,
      query: _query,
      schedule: _schedule,
      scheduleHour: _scheduleHour,
      scheduleMinute: _scheduleMinute,
      thresholdColumn: _thresholdColumn,
      thresholdOperator: _thresholdOperator,
      thresholdValue: _thresholdValue,
      isEnabled: true,
      createdAt: now,
      modifiedAt: now,
    );

    try {
      final alertsProvider = context.read<AlertsProvider>();
      await alertsProvider.addAlert(alert);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert created successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAIQueryDialog() async {
    final dashboardProvider = context.read<DashboardProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final database = dashboardProvider.selectedDatabase;
    final connection = dashboardProvider.currentConnection;

    if (database == null || connection == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a database first'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (settingsProvider.apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set your AI API key in Settings'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final promptController = TextEditingController();
    bool isGenerating = false;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('AI Query Assistant'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Describe what you want to query in natural language:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: promptController,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Show all users who signed up last week',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                  enabled: !isGenerating,
                ),
                if (isGenerating) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text(
                    'Generating SQL...',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isGenerating
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isGenerating
                    ? null
                    : () async {
                        final prompt = promptController.text.trim();
                        if (prompt.isEmpty) return;

                        setDialogState(() => isGenerating = true);

                        try {
                          final schemaService = context.read<SchemaService>();
                          final tables = dashboardProvider.tables;
                          final schemaBuffer = StringBuffer();

                          for (final table in tables) {
                            final columns = await schemaService.getColumns(
                              connection,
                              database,
                              table,
                            );
                            schemaBuffer.writeln('Table: $table');
                            schemaBuffer.writeln(
                              'Columns: ${columns.map((c) => "${c.name} (${c.dataType})").join(", ")}',
                            );
                            schemaBuffer.writeln();
                          }

                          final aiService = context.read<AIService>();
                          final sql = await aiService.generateSQL(
                            prompt: prompt,
                            schema: schemaBuffer.toString(),
                            settings: settingsProvider.settings,
                          );

                          if (context.mounted) {
                            Navigator.of(context).pop(sql);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setDialogState(() => isGenerating = false);
                          }
                        }
                      },
                child: const Text('Generate'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _query = result!;
      });
    }
  }
}
