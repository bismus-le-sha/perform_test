import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' as services;
import 'package:path_provider/path_provider.dart';
import 'package:perform_test/core/config/feature_toggle.dart';

/// Сервис конфигурации приложения.
/// Управляет feature toggles для демонстрации различных подходов к оптимизации.
class AppConfig extends ChangeNotifier {
  static final _instance = AppConfig._internal();
  final _flags = <FeatureToggle, bool>{};
  File? _configFile;
  bool _isIntegrationTest = false;
  bool _initialized = false;

  AppConfig._internal();
  factory AppConfig() => _instance;

  Future<void> init({bool isIntegrationTest = false}) async {
    // Skip re-initialization to preserve programmatically set toggles
    if (_initialized) {
      return;
    }
    _initialized = true;

    _isIntegrationTest = isIntegrationTest;
    if (isIntegrationTest) {
      final jsonString = await services.rootBundle.loadString(
        "assets/config/app_config.json",
      );
      _readConfig(jsonString);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _configFile = File('${dir.path}/app_config.json');
      if (await _configFile!.exists()) {
        final jsonString = await _configFile!.readAsString();
        _readConfig(jsonString);
      } else {
        await _saveToFile();
      }
    }
  }

  void _readConfig(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    for (final entry in data.entries) {
      final toggle = FeatureToggle.values.firstWhere(
        (e) => e.name == entry.key,
      );
      _flags[toggle] = entry.value as bool;
    }
  }

  bool get(FeatureToggle key) => _flags[key] ?? false;

  void set(FeatureToggle key, bool value) {
    _flags[key] = value;
    if (!_isIntegrationTest && _configFile != null) {
      _saveToFile();
    }
    notifyListeners();
  }

  Future<void> _saveToFile() async {
    if (_configFile == null) return;
    final jsonMap = {for (var e in _flags.entries) e.key.name: e.value};
    await _configFile!.writeAsString(jsonEncode(jsonMap));
  }

  String getConfigToString() {
    return _flags.toString();
  }
}
