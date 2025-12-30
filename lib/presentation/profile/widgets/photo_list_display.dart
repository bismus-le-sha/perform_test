import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:perform_test/core/config/feature_toggle.dart';
import 'package:perform_test/data/model/photo.dart';
import 'package:perform_test/presentation/profile/widgets/photo_list_item.dart';
import 'package:perform_test/service/app_config/app_config_provider.dart';

class PhotoList extends StatelessWidget {
  final List<Photo> photos;
  final ScrollController scrollController;

  const PhotoList({
    super.key,
    required this.photos,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final appConfig = AppConfigProvider.of(context);

    // Используем Timeline для визуализации в DevTools
    developer.Timeline.startSync(
      'PHOTO_LIST_BUILD',
      arguments: {
        'photoCount': photos.length,
        'lazyLoad': appConfig.get(FeatureToggle.lazyLoad),
      },
    );

    // Используем Stopwatch для точного измерения
    final buildStopwatch = Stopwatch()..start();

    Widget listContent;
    if (appConfig.get(FeatureToggle.lazyLoad)) {
      listContent = ListView.separated(
        controller: scrollController,
        itemCount: photos.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) => PhotoListItem(photo: photos[index]),
      );
    } else {
      listContent = SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: photos
              .asMap()
              .entries
              .expand(
                (entry) => [
                  PhotoListItem(photo: entry.value),
                  if (entry.key < photos.length - 1) const SizedBox(height: 16),
                ],
              )
              .toList(),
        ),
      );
    }

    buildStopwatch.stop();
    developer.Timeline.finishSync();

    // Логируем результат после завершения build
    // Используем микросекунды для точности, но выводим в миллисекундах
    final buildTimeMs = buildStopwatch.elapsedMicroseconds / 1000.0;
    debugPrint(
      'PhotoList build time: ${buildTimeMs.toStringAsFixed(2)} ms '
      '(photos: ${photos.length}, lazyLoad: ${appConfig.get(FeatureToggle.lazyLoad)})',
    );

    return listContent;
  }
}
