import 'package:flutter/material.dart';
import 'package:perform_test/di/injection_container.dart' as di;
import 'package:perform_test/domain/repository/photo_repository.dart';
import 'package:perform_test/perform_test_app.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/service/app_config/app_config_provider.dart';

void main() async {
  final stopwatch = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация DI контейнера
  await di.init();

  // Инициализация AppConfig
  final appConfig = di.sl<AppConfig>();
  await appConfig.init();

  debugPrint(appConfig.getConfigToString());

  runApp(
    AppConfigProvider(
      notifier: appConfig,
      child: PerformTestApp(photoRepository: di.sl<PhotoRepository>()),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    stopwatch.stop();
    debugPrint(
      'Первый кадр построен (layout+paint): ${stopwatch.elapsedMilliseconds} мс',
      // name: 'startup',
    );
  });
}
