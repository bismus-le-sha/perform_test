import 'package:flutter/material.dart';

import 'package:perform_test/data/model/photo.dart';
import 'package:perform_test/presentation/profile/widgets/buttons_footer.dart';
import 'package:perform_test/presentation/profile/widgets/profile_header.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/service/app_config/app_config_provider.dart';

class PhotoListItem extends StatelessWidget {
  final Photo photo;

  const PhotoListItem({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    final appConfig = AppConfigProvider.of(context);
    final aspectRatio = photo.width / photo.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ProfileHeader(user: photo.user),
        AspectRatio(
          aspectRatio: aspectRatio,
          child: appConfig.get(FeatureToggle.optimImageSize)
              ? Image.network(
                  photo.urls.small,
                  // cacheWidth: desiredImageWidth
                )
              : Image.network(photo.urls.full),
        ),
        ButtonsFooter(photo: photo),
      ],
    );
  }
}
