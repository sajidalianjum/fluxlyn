import 'package:hive/hive.dart';

part 'alert_history_model.g.dart';

@HiveType(typeId: 7)
class AlertHistoryEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String alertId;

  @HiveField(2)
  final DateTime executedAt;

  @HiveField(3)
  final int executionTimeMs;

  @HiveField(4)
  final bool success;

  @HiveField(5)
  final String? errorMessage;

  @HiveField(6)
  final int? rowCount;

  @HiveField(7)
  final bool thresholdTriggered;

  @HiveField(8)
  final double? thresholdValue;

  @HiveField(9)
  final String? connectionId;

  @HiveField(10)
  final String? databaseName;

  AlertHistoryEntry({
    required this.id,
    required this.alertId,
    required this.executedAt,
    required this.executionTimeMs,
    required this.success,
    this.errorMessage,
    this.rowCount,
    this.thresholdTriggered = false,
    this.thresholdValue,
    this.connectionId,
    this.databaseName,
  });

  AlertHistoryEntry copyWith({
    String? id,
    String? alertId,
    DateTime? executedAt,
    int? executionTimeMs,
    bool? success,
    String? errorMessage,
    int? rowCount,
    bool? thresholdTriggered,
    double? thresholdValue,
    String? connectionId,
    String? databaseName,
  }) {
    return AlertHistoryEntry(
      id: id ?? this.id,
      alertId: alertId ?? this.alertId,
      executedAt: executedAt ?? this.executedAt,
      executionTimeMs: executionTimeMs ?? this.executionTimeMs,
      success: success ?? this.success,
      errorMessage: errorMessage ?? this.errorMessage,
      rowCount: rowCount ?? this.rowCount,
      thresholdTriggered: thresholdTriggered ?? this.thresholdTriggered,
      thresholdValue: thresholdValue ?? this.thresholdValue,
      connectionId: connectionId ?? this.connectionId,
      databaseName: databaseName ?? this.databaseName,
    );
  }
}
