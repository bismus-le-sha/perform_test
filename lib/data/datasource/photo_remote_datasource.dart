import 'package:flutter/services.dart' as services;
import 'package:logging/logging.dart';
import 'package:perform_test/data/model/photo.dart';

/// Data source для получения фотографий из удаленного источника.
/// Отвечает только за получение сырых данных, без бизнес-логики.
class PhotoRemoteDataSource {
  final Logger _logger;

  PhotoRemoteDataSource({required Logger logger}) : _logger = logger;

  /// Имитация HTTP запроса с задержкой для демонстрации асинхронности
  Future<String> _mockHttpCall() async {
    _logger.info('Начало загрузки данных из удаленного источника');
    await Future.delayed(const Duration(milliseconds: 1500));
    final data = await services.rootBundle.loadString("assets/data/feed.json");
    _logger.info('Данные успешно загружены');
    return data;
  }

  static List<Photo> _parseResponse(String json) {
    return photoApiResponseFromJson(json).results;
  }

  /// Получение фотографий из удаленного источника
  Future<List<Photo>> fetchPhotos() async {
    _logger.fine('Запрос на получение фотографий');
    final response = await _mockHttpCall();
    final photos = _parseResponse(response);
    _logger.info('Получено ${photos.length} фотографий');
    return photos;
  }
}
