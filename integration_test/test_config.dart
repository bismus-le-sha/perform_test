import 'package:flutter/widgets.dart';
import 'package:perform_test/data/datasource/api.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/service/app_config/app_config_provider.dart';
import 'package:perform_test/main.dart';

/// Создаёт тестовый экземпляр приложения с полностью инициализированным AppConfig.
Future<Widget> createTestApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appConfig = AppConfig();
  await appConfig.init(isIntegrationTest: true);

  final datasource = Datasource(appConfig: appConfig);

  return AppConfigProvider(
    notifier: appConfig,
    child: MyApp(datasource: datasource),
  );
}
