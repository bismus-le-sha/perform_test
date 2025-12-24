import 'package:flutter/material.dart';
import 'package:perform_test/service/app_config/widget/app_config_widgets.dart';

import '../data/datasource/api.dart';
import '../data/model/photo.dart';
import 'profile/widgets/photo_list_item.dart';

class LargeImagePage extends StatefulWidget {
  const LargeImagePage({super.key, required this.datasource});
  final Datasource datasource;

  @override
  State<LargeImagePage> createState() => _LargeImagePageState();
}

class _LargeImagePageState extends State<LargeImagePage> {
  late Future<List<Photo>> _photos;

  @override
  void initState() {
    super.initState();
    _photos = widget.datasource.fetchPhotos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppConfigBar(title: Text('LargeImage')),
      body: FutureBuilder(
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
