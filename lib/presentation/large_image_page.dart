import 'package:flutter/material.dart';
import 'package:perform_test/core/providers/photo_repository_provider.dart';
import 'package:perform_test/data/model/photo.dart';
import 'package:perform_test/service/app_config/widget/app_config_widgets.dart';
import 'profile/widgets/photo_list_item.dart';

class LargeImagePage extends StatefulWidget {
  const LargeImagePage({super.key});

  @override
  State<LargeImagePage> createState() => _LargeImagePageState();
}

class _LargeImagePageState extends State<LargeImagePage> {
  Future<List<Photo>>? _photos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Инициализируем загрузку фотографий при первом доступе к контексту
    _photos ??= PhotoRepositoryProvider.of(context).getPhotos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppConfigBar(title: Text('LargeImage')),
      body: FutureBuilder<List<Photo>>(
        future: _photos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return Center(child: PhotoListItem(photo: snapshot.data![0]));
          }
        },
      ),
    );
  }
}
