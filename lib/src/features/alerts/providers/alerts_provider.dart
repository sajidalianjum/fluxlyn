import 'package:flutter/foundation.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/alert_scheduler_service.dart';
import '../models/alert_model.dart';
import '../models/alert_history_model.dart';

class AlertsProvider extends ChangeNotifier {
  final StorageService _storageService;
  final DatabaseService _databaseService;
  AlertSchedulerService? _scheduler;

  List<AlertModel> _alerts = [];
  bool _isLoading = false;
  String? _error;

  AlertsProvider(this._storageService) : _databaseService = DatabaseService() {
    _scheduler = AlertSchedulerService(_storageService, _databaseService);
    _scheduler?.start();
    loadAlerts();
  }

  List<AlertModel> get alerts => _alerts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAlerts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _alerts = _storageService.getAllAlerts();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addAlert(AlertModel alert) async {
    try {
      await _storageService.saveAlert(alert);
      _alerts.add(alert);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateAlert(AlertModel alert) async {
    try {
      await _storageService.saveAlert(alert);
      final index = _alerts.indexWhere((a) => a.id == alert.id);
      if (index != -1) {
        _alerts[index] = alert;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteAlert(String id) async {
    try {
      await _storageService.deleteAlert(id);
      _alerts.removeWhere((a) => a.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleAlertEnabled(String id) async {
    try {
      final alert = _alerts.firstWhere((a) => a.id == id);
      final updatedAlert = alert.copyWith(
        isEnabled: !alert.isEnabled,
        modifiedAt: DateTime.now(),
      );
      await updateAlert(updatedAlert);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<AlertHistoryEntry> runAlert(AlertModel alert) async {
    if (_scheduler == null) {
      throw Exception('AlertSchedulerService not initialized');
    }

    try {
      final historyEntry = await _scheduler!.runAlertNow(alert);

      final index = _alerts.indexWhere((a) => a.id == alert.id);
      if (index != -1) {
        _alerts[index] = alert.copyWith(lastRunAt: historyEntry.executedAt);
      }
      notifyListeners();

      return historyEntry;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  List<AlertHistoryEntry> getAlertHistory(String alertId) {
    return _storageService.getAlertHistory(alertId);
  }

  Future<void> clearAlertHistory(String alertId) async {
    try {
      await _storageService.clearAlertHistory(alertId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  List<AlertModel> getAlertsByConnection(String connectionId) {
    return _alerts.where((a) => a.connectionId == connectionId).toList();
  }

  @override
  void dispose() {
    _scheduler?.stop();
    super.dispose();
  }
}
