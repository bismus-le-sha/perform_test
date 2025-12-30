import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:perform_test/data/datasource/calculate.dart';
import 'package:perform_test/data/datasource/photo_remote_datasource.dart';
import 'package:perform_test/data/repository/photo_repository_impl.dart';
import 'package:perform_test/domain/repository/photo_repository.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/service/logger/logger.dart';

final sl = GetIt.instance;

/// Инициализация контейнера зависимостей.
/// Регистрирует все сервисы и зависимости приложения.
Future<void> init() async {
  // Настройка глобального логгера
  configureGlobalLogging(level: Level.INFO);

  // Регистрация логгеров для различных компонентов
  sl.registerLazySingleton<Logger>(() => loggerFor('App'), instanceName: 'app');
  sl.registerLazySingleton<Logger>(
    () => loggerFor('PhotoRepository'),
    instanceName: 'photoRepository',
  );
  sl.registerLazySingleton<Logger>(
    () => loggerFor('PhotoRemoteDataSource'),
    instanceName: 'photoRemoteDataSource',
  );

  // AppConfig регистрируем как singleton
  sl.registerSingleton<AppConfig>(AppConfig());

  // Data sources
  sl.registerLazySingleton<PhotoRemoteDataSource>(
    () => PhotoRemoteDataSource(
      logger: sl<Logger>(instanceName: 'photoRemoteDataSource'),
      appConfig: sl<AppConfig>(),
    ),
  );

  // Repositories - используем напрямую без use cases
  sl.registerLazySingleton<PhotoRepository>(
    () => PhotoRepositoryImpl(
      remoteDataSource: sl<PhotoRemoteDataSource>(),
      appConfig: sl<AppConfig>(),
      logger: sl<Logger>(instanceName: 'photoRepository'),
    ),
  );

  // Calculate - для вычислений Фибоначчи
  sl.registerLazySingleton<Calculate>(() => Calculate());
}
