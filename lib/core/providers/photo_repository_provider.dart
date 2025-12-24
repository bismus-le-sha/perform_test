import 'package:flutter/material.dart';
import 'package:perform_test/domain/repository/photo_repository.dart';

/// Provider для доступа к PhotoRepository через контекст.
/// Позволяет избежать передачи репозитория через конструкторы виджетов.
class PhotoRepositoryProvider extends InheritedWidget {
  final PhotoRepository repository;

  const PhotoRepositoryProvider({
    super.key,
    required this.repository,
    required super.child,
  });

  /// Получить PhotoRepository из контекста
  static PhotoRepository of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<PhotoRepositoryProvider>();
    assert(
      provider != null,
      'PhotoRepositoryProvider not found in context',
    );
    return provider!.repository;
  }

  @override
  bool updateShouldNotify(PhotoRepositoryProvider oldWidget) {
    return repository != oldWidget.repository;
  }
}


