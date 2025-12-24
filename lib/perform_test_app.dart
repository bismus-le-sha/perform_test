import 'package:flutter/material.dart';
import 'package:perform_test/core/providers/photo_repository_provider.dart';
import 'package:perform_test/domain/repository/photo_repository.dart';
import 'package:perform_test/config/router/tabs.dart';

class PerformTestApp extends StatelessWidget {
  const PerformTestApp({super.key, required this.photoRepository});
  final PhotoRepository photoRepository;
  @override
  Widget build(BuildContext context) {
    // Получаем репозиторий из DI контейнера

    return PhotoRepositoryProvider(
      repository: photoRepository,
      child: MaterialApp(
        home: BottomTabs(),
        checkerboardRasterCacheImages: true,
        checkerboardOffscreenLayers: true,
      ),
    );
  }
}
