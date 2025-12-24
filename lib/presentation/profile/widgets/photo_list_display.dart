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
    final buildStart = DateTime.now();

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
              .map((entry) => PhotoListItem(photo: entry.value))
              .toList(),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final duration = DateTime.now().difference(buildStart);
      debugPrint("PhotoList built in ${duration.inMilliseconds} ms");
    });

    return listContent;
  }
}
