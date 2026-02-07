import 'package:hive/hive.dart';

part 'alert_model.g.dart';

@HiveType(typeId: 4)
enum AlertSchedule {
  @HiveField(0)
  hourly,
  @HiveField(1)
  daily,
  @HiveField(2)
  weekly,
}

@HiveType(typeId: 5)
enum ThresholdOperator {
  @HiveField(0)
  greaterThan,
  @HiveField(1)
  lessThan,
  @HiveField(2)
  equals,
  @HiveField(3)
  notEquals,
  @HiveField(4)
  greaterOrEqual,
  @HiveField(5)
  lessOrEqual,
}

@HiveType(typeId: 6)
class AlertModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String connectionId;

  @HiveField(3)
  final String? databaseName;

  @HiveField(4)
  final String query;

  @HiveField(5)
  final AlertSchedule schedule;

  @HiveField(6)
  final int? scheduleHour;

  @HiveField(7)
  final int? scheduleMinute;

  @HiveField(8)
  final String? thresholdColumn;

  @HiveField(9)
  final ThresholdOperator? thresholdOperator;

  @HiveField(10)
  final double? thresholdValue;

  @HiveField(11)
  final bool isEnabled;

  @HiveField(12)
  final DateTime createdAt;

  @HiveField(13)
  final DateTime modifiedAt;

  @HiveField(14)
  DateTime? lastRunAt;

  AlertModel({
    required this.id,
    required this.name,
    required this.connectionId,
    required this.query,
    required this.schedule,
    this.databaseName,
    this.scheduleHour,
    this.scheduleMinute,
    this.thresholdColumn,
    this.thresholdOperator,
    this.thresholdValue,
    this.isEnabled = true,
    required this.createdAt,
    required this.modifiedAt,
    this.lastRunAt,
  });

  AlertModel copyWith({
    String? id,
    String? name,
    String? connectionId,
    String? query,
    AlertSchedule? schedule,
    String? databaseName,
    int? scheduleHour,
    int? scheduleMinute,
    String? thresholdColumn,
    ThresholdOperator? thresholdOperator,
    double? thresholdValue,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? modifiedAt,
    DateTime? lastRunAt,
  }) {
    return AlertModel(
      id: id ?? this.id,
      name: name ?? this.name,
      connectionId: connectionId ?? this.connectionId,
      query: query ?? this.query,
      schedule: schedule ?? this.schedule,
      databaseName: databaseName ?? this.databaseName,
      scheduleHour: scheduleHour ?? this.scheduleHour,
      scheduleMinute: scheduleMinute ?? this.scheduleMinute,
      thresholdColumn: thresholdColumn ?? this.thresholdColumn,
      thresholdOperator: thresholdOperator ?? this.thresholdOperator,
      thresholdValue: thresholdValue ?? this.thresholdValue,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      lastRunAt: lastRunAt ?? this.lastRunAt,
    );
  }

  String getScheduleDisplay() {
    switch (schedule) {
      case AlertSchedule.hourly:
        return 'Every hour';
      case AlertSchedule.daily:
        if (scheduleHour != null && scheduleMinute != null) {
          return 'Daily at ${scheduleHour!.toString().padLeft(2, '0')}:${scheduleMinute!.toString().padLeft(2, '0')}';
        }
        return 'Daily';
      case AlertSchedule.weekly:
        if (scheduleHour != null && scheduleMinute != null) {
          return 'Weekly at ${scheduleHour!.toString().padLeft(2, '0')}:${scheduleMinute!.toString().padLeft(2, '0')}';
        }
        return 'Weekly';
    }
  }

  String getThresholdDisplay() {
    if (thresholdColumn == null ||
        thresholdOperator == null ||
        thresholdValue == null) {
      return 'No threshold';
    }

    String operatorSymbol;
    switch (thresholdOperator!) {
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

    return '$thresholdColumn $operatorSymbol $thresholdValue';
  }
}
