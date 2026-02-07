import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:uuid/uuid.dart';
import '../../features/alerts/models/alert_model.dart';
import '../../features/alerts/models/alert_history_model.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';
import '../services/local_notifications_service.dart';

class AlertSchedulerService {
  final StorageService _storageService;
  final DatabaseService _databaseService;
  final Uuid _uuid = const Uuid();
  final LocalNotificationsService _notifications = LocalNotificationsService();

  Timer? _timer;
  bool _isRunning = false;

  AlertSchedulerService(this._storageService, this._databaseService);

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;

    await _notifications.initialize();
    _isRunning = true;
    _startScheduler();
    debugPrint('AlertSchedulerService started');
  }

  void _startScheduler() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAndExecuteAlerts();
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    debugPrint('AlertSchedulerService stopped');
  }

  Future<void> _checkAndExecuteAlerts() async {
    try {
      final alerts = _storageService.getAllAlerts();
      final now = DateTime.now();

      debugPrint('\n--- Checking alerts at ${now.toIso8601String()} ---');
      debugPrint('Total alerts: ${alerts.length}');
      debugPrint('Enabled alerts: ${alerts.where((a) => a.isEnabled).length}');

      for (final alert in alerts) {
        if (!alert.isEnabled) {
          debugPrint('Skipping disabled alert: ${alert.name}');
          continue;
        }

        if (_shouldRunAlert(alert, now)) {
          debugPrint('Running alert: ${alert.name}');
          await _executeAlert(alert);
        } else {
          debugPrint('Alert not due: ${alert.name}');
        }
      }
    } catch (e) {
      debugPrint('Error checking alerts: $e');
    }
  }

  bool _shouldRunAlert(AlertModel alert, DateTime now) {
    if (alert.lastRunAt == null) return true;

    final diff = now.difference(alert.lastRunAt!);

    switch (alert.schedule) {
      case AlertSchedule.minutes:
        if (alert.scheduleMinutes == null || alert.scheduleMinutes! <= 0) {
          return false;
        }
        return diff.inMinutes >= alert.scheduleMinutes!;
      case AlertSchedule.hourly:
        return diff.inHours >= 1;
      case AlertSchedule.daily:
        return diff.inDays >= 1;
      case AlertSchedule.weekly:
        return diff.inDays >= 7;
    }
  }

  Future<AlertHistoryEntry> _executeAlert(AlertModel alert) async {
    final startTime = DateTime.now();
    debugPrint('\n========== EXECUTING ALERT ==========');
    debugPrint('Alert Name: ${alert.name}');
    debugPrint('Schedule: ${alert.getScheduleDisplay()}');
    debugPrint('Query: ${alert.query}');
    debugPrint('Threshold: ${alert.getThresholdDisplay()}');
    debugPrint('===================================\n');

    final historyEntry = AlertHistoryEntry(
      id: _uuid.v4(),
      alertId: alert.id,
      executedAt: startTime,
      executionTimeMs: 0,
      success: false,
      connectionId: alert.connectionId,
      databaseName: alert.databaseName,
    );

    try {
      final connection = _storageService.getConnectionById(alert.connectionId);
      if (connection == null) {
        throw Exception('Connection not found');
      }

      final conn = await _databaseService.connect(connection);

      if (alert.databaseName != null && alert.databaseName!.isNotEmpty) {
        await _databaseService.useDatabase(conn, alert.databaseName!);
        debugPrint('Using database: ${alert.databaseName}');
      } else {
        debugPrint('No database specified, using connection default');
      }

      final result = await _databaseService.execute(conn, alert.query);

      debugPrint('Query executed successfully');
      debugPrint('Rows returned: ${result.rows.length}');

      if (result.rows.isNotEmpty) {
        debugPrint('First row data: ${result.rows.first.assoc()}');
      } else {
        debugPrint('No rows returned');
      }

      final executionTime = DateTime.now().difference(startTime).inMilliseconds;
      bool thresholdTriggered = false;
      double? thresholdValue;
      double? previousValue;

      if (alert.thresholdColumn != null &&
          alert.thresholdOperator != null &&
          result.rows.isNotEmpty) {
        final thresholdResult = await _checkThreshold(alert, result);

        thresholdTriggered = thresholdResult['triggered'] as bool;
        thresholdValue = thresholdResult['value'] as double?;
        previousValue = thresholdResult['previous'] as double?;

        debugPrint('Threshold Check:');
        debugPrint('  - Previous Value: $previousValue');
        debugPrint('  - Current Value: $thresholdValue');
        debugPrint('  - Threshold Triggered: $thresholdTriggered');

        if (thresholdTriggered) {
          debugPrint('\n*** ALERT TRIGGERED ***');
          await _sendAlertNotification(alert, thresholdValue);
        }
      }

      final finalHistoryEntry = historyEntry.copyWith(
        success: true,
        executionTimeMs: executionTime,
        rowCount: result.rows.length,
        thresholdTriggered: thresholdTriggered,
        thresholdValue: thresholdValue,
        previousValue: previousValue,
      );

      await _storageService.addToAlertHistory(finalHistoryEntry);

      final updatedAlert = alert.copyWith(
        lastRunAt: startTime,
        lastThresholdValue: thresholdValue,
      );
      await _storageService.saveAlert(updatedAlert);

      await _databaseService.disconnect();

      debugPrint('Alert execution completed successfully');
      debugPrint('Execution time: ${executionTime}ms');
      debugPrint('===================================\n');

      return finalHistoryEntry;
    } catch (e) {
      await _databaseService.disconnect();

      debugPrint('ERROR executing alert: $e');

      final errorHistoryEntry = historyEntry.copyWith(
        success: false,
        executionTimeMs: DateTime.now().difference(startTime).inMilliseconds,
        errorMessage: e.toString(),
      );

      await _storageService.addToAlertHistory(errorHistoryEntry);

      final updatedAlert = alert.copyWith(lastRunAt: startTime);
      await _storageService.saveAlert(updatedAlert);

      debugPrint('===================================\n');

      return errorHistoryEntry;
    }
  }

  Future<Map<String, dynamic>> _checkThreshold(
    AlertModel alert,
    IResultSet queryResult,
  ) async {
    try {
      if (alert.thresholdColumn == null || alert.thresholdOperator == null) {
        return {'triggered': false};
      }

      final firstRow = queryResult.rows.first.assoc();
      final columnValue = firstRow[alert.thresholdColumn];

      if (columnValue == null) {
        return {
          'triggered': false,
          'value': null,
          'previous': alert.lastThresholdValue,
        };
      }

      final double currentValue = _parseDouble(columnValue);
      final double? previousValue = alert.lastThresholdValue;
      bool triggered = false;

      switch (alert.thresholdOperator!) {
        case ThresholdOperator.greaterThan:
          triggered = currentValue > (alert.thresholdValue ?? 0);
          break;
        case ThresholdOperator.lessThan:
          triggered = currentValue < (alert.thresholdValue ?? 0);
          break;
        case ThresholdOperator.equals:
          triggered = currentValue == (alert.thresholdValue ?? 0);
          break;
        case ThresholdOperator.notEquals:
          triggered = currentValue != (alert.thresholdValue ?? 0);
          break;
        case ThresholdOperator.greaterOrEqual:
          triggered = currentValue >= (alert.thresholdValue ?? 0);
          break;
        case ThresholdOperator.lessOrEqual:
          triggered = currentValue <= (alert.thresholdValue ?? 0);
          break;
        case ThresholdOperator.changed:
          triggered = previousValue != null && currentValue != previousValue;
          break;
      }

      return {
        'triggered': triggered,
        'value': currentValue,
        'previous': previousValue,
      };
    } catch (e) {
      debugPrint('Error checking threshold: $e');
      return {'triggered': false};
    }
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> _sendAlertNotification(
    AlertModel alert,
    double? currentValue,
  ) async {
    final thresholdDisplay = alert.getThresholdDisplay();
    final body = currentValue != null
        ? '$thresholdDisplay\nCurrent value: $currentValue'
        : thresholdDisplay;

    debugPrint('Sending notification:');
    debugPrint('  Title: Alert Triggered: ${alert.name}');
    debugPrint('  Body: $body');
    debugPrint('');

    await _notifications.showAlertNotification(
      title: 'Alert Triggered: ${alert.name}',
      body: body,
    );

    debugPrint('Notification sent successfully');
  }

  Future<AlertHistoryEntry> runAlertNow(AlertModel alert) async {
    return await _executeAlert(alert);
  }
}
