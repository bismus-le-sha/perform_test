import 'package:flutter/material.dart';
import 'package:perform_test/data/datasource/api.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/service/app_config/app_config_provider.dart';
import 'package:perform_test/tabs.dart';

void main() async {
  final stopwatch = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  final appConfig = AppConfig();
  await appConfig.init();
  final datasource = Datasource(appConfig: appConfig);
  debugPrint(appConfig.getConfigToString());

  runApp(
    AppConfigProvider(
      notifier: appConfig,
      child: MyApp(datasource: datasource),
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

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.datasource});
  final Datasource datasource;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BottomTabs(datasource: datasource),
      checkerboardRasterCacheImages: true,
      checkerboardOffscreenLayers: true,
    );
  }
}
