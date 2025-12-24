import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:perform_test/di/injection_container.dart' as di;
import 'package:perform_test/domain/repository/photo_repository.dart';
import 'package:perform_test/perform_test_app.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/service/app_config/app_config_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Async инициализация (не включается в startup time)
  // Это I/O операции, которые не являются частью синхронного startup
  await di.init();
  final appConfig = di.sl<AppConfig>();
  await appConfig.init();

  debugPrint(appConfig.getConfigToString());

  // Начинаем измерение ТОЛЬКО синхронного startup (runApp и первый кадр)
  // Используем Timeline для визуализации в DevTools
  developer.Timeline.startSync('APP_STARTUP');
  final startupStopwatch = Stopwatch()..start();

  runApp(
    AppConfigProvider(
      notifier: appConfig,
      child: PerformTestApp(photoRepository: di.sl<PhotoRepository>()),
    ),
  );

  // Измеряем время до первого кадра (startup time)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    startupStopwatch.stop();
    developer.Timeline.finishSync();

    final startupTimeMs = startupStopwatch.elapsedMicroseconds / 1000.0;
    debugPrint(
      'Startup time (first frame): ${startupTimeMs.toStringAsFixed(2)} ms\n'
      'Note: This measures time from runApp() to first frame.\n'
      'For detailed startup analysis, use Flutter DevTools Performance tab.',
    );
  });
}
