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
  @HiveField(3)
  minutes,
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
  @HiveField(6)
  changed,
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
  final int? scheduleMinutes;

  @HiveField(9)
  final String? thresholdColumn;

  @HiveField(10)
  final ThresholdOperator? thresholdOperator;

  @HiveField(11)
  final double? thresholdValue;

  @HiveField(12)
  final double? lastThresholdValue;

  @HiveField(13)
  final bool isEnabled;

  @HiveField(14)
  final DateTime createdAt;

  @HiveField(15)
  final DateTime modifiedAt;

  @HiveField(16)
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
    this.scheduleMinutes,
    this.thresholdColumn,
    this.thresholdOperator,
    this.thresholdValue,
    this.lastThresholdValue,
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
    int? scheduleMinutes,
    String? thresholdColumn,
    ThresholdOperator? thresholdOperator,
    double? thresholdValue,
    double? lastThresholdValue,
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
      scheduleMinutes: scheduleMinutes ?? this.scheduleMinutes,
      thresholdColumn: thresholdColumn ?? this.thresholdColumn,
      thresholdOperator: thresholdOperator ?? this.thresholdOperator,
      thresholdValue: thresholdValue ?? this.thresholdValue,
      lastThresholdValue: lastThresholdValue ?? this.lastThresholdValue,
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
      case AlertSchedule.minutes:
        if (scheduleMinutes != null) {
          return 'Every $scheduleMinutes minute${scheduleMinutes == 1 ? '' : 's'}';
        }
        return 'Custom minutes';
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
        thresholdOperator == null) {
      return 'No threshold';
    }

    if (thresholdOperator == ThresholdOperator.changed) {
      return '$thresholdColumn != Previous Value';
    }

    if (thresholdValue == null) {
      return 'No threshold';
    }

    String opSymbol;
    switch (thresholdOperator!) {
      case ThresholdOperator.greaterThan:
        opSymbol = '>';
        break;
      case ThresholdOperator.lessThan:
        opSymbol = '<';
        break;
      case ThresholdOperator.equals:
        opSymbol = '=';
        break;
      case ThresholdOperator.notEquals:
        opSymbol = '!=';
        break;
      case ThresholdOperator.greaterOrEqual:
        opSymbol = '>=';
        break;
      case ThresholdOperator.lessOrEqual:
        opSymbol = '<=';
        break;
      case ThresholdOperator.changed:
        opSymbol = '!=';
        break;
    }

    return '$thresholdColumn $opSymbol $thresholdValue';
  }
}
