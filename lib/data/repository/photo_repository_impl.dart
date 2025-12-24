import 'package:logging/logging.dart';
import 'package:perform_test/data/datasource/photo_remote_datasource.dart';
import 'package:perform_test/data/model/photo.dart';
import 'package:perform_test/domain/repository/photo_repository.dart';
import 'package:perform_test/service/app_config/app_config.dart';

/// Реализация репозитория фотографий.
/// Координирует работу с data source и применяет бизнес-логику.
class PhotoRepositoryImpl implements PhotoRepository {
  final PhotoRemoteDataSource _remoteDataSource;
  // Зарезервировано для будущего использования feature toggles
  // ignore: unused_field
  final AppConfig _appConfig;
  final Logger _logger;

  PhotoRepositoryImpl({
    required PhotoRemoteDataSource remoteDataSource,
    required AppConfig appConfig,
    required Logger logger,
  }) : _remoteDataSource = remoteDataSource,
       _appConfig = appConfig,
       _logger = logger;

  @override
  Future<List<Photo>> getPhotos() async {
    _logger.info('Запрос на получение списка фотографий');
    final photos = await _remoteDataSource.fetchPhotos();

    // Бизнес-логика фильтрации: ограничиваем до 50 элементов
    // для демонстрации производительности на слабых устройствах
    // _appConfig зарезервирован для будущего использования feature toggles
    final filteredPhotos = photos.sublist(
      0,
      photos.length > 50 ? 50 : photos.length,
    );

    _logger.info(
      'Возвращено ${filteredPhotos.length} фотографий после фильтрации',
    );
    return filteredPhotos;
  }
}
