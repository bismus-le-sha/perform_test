import 'package:perform_test/data/model/photo.dart';

/// Абстракция репозитория для работы с фотографиями.
/// Разделяет domain логику от деталей реализации источника данных.
abstract class PhotoRepository {
  /// Получение списка фотографий с применением бизнес-логики фильтрации
  Future<List<Photo>> getPhotos();
}


