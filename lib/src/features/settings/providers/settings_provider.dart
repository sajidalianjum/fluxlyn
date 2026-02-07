import 'package:flutter/foundation.dart';
import '../../../core/models/settings_model.dart';
import '../../../core/services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;
  AppSettings _settings = AppSettings.defaultSettings();
  bool _isLoading = false;
  String? _error;

  SettingsProvider(this._storageService) {
    loadSettings();
  }

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get lockDelete => _settings.lockDelete;
  bool get lockDrop => _settings.lockDrop;
  AIProvider get provider => _settings.provider;
  String get apiKey => _settings.apiKey;
  String get endpoint => _settings.endpoint;

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _settings = _storageService.loadSettings();
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings({
    bool? lockDelete,
    bool? lockDrop,
    AIProvider? provider,
    String? apiKey,
    String? endpoint,
  }) async {
    _settings = _settings.copyWith(
      lockDelete: lockDelete,
      lockDrop: lockDrop,
      provider: provider,
      apiKey: apiKey,
      endpoint: endpoint,
    );
    notifyListeners();

    try {
      await _storageService.saveSettings(_settings);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error saving settings: $e');
      notifyListeners();
    }
  }
}
