import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' as services;

import 'package:perform_test/data/model/photo.dart';
import 'package:perform_test/service/app_config/app_config.dart';

class Datasource {
  final AppConfig appConfig;

  Datasource({required this.appConfig});
  List<Photo> filterPhotos(List<Photo> photos) {
    // arbitrary function to mock a "filter" function
    // otherwise combining issue 1 and 4 might crash the app on low end device :D
    return photos.sublist(0, 50);
  }

  // const String CLIENT_ID = 'CHANGE_ME';
  // const SEARCH = 'guinea pigs';
  // final response = await http.get(Uri.https(
  //     'api.unsplash.com',
  //     '/search/photos/',
  //     {'query': SEARCH, 'per_page': '1000', 'client_id': CLIENT_ID}));

  // We mock the API to ensure we don't get rate limited
  Future<String> mockHttpCall() async {
    // Add a delay to simulate network request
    await Future.delayed(const Duration(milliseconds: 1500));
    return services.rootBundle.loadString("assets/data/feed.json");
  }

  static List<Photo> parseResponse(String json) {
    return photoApiResponseFromJson(json).results;
  }

  Future<List<Photo>> fetchPhotos() async {
    final response = await mockHttpCall();
    final photos = appConfig.get(FeatureToggle.largeJsonParce)
        ? await compute(parseResponse, response)
        : parseResponse(response);

    return filterPhotos(photos);
  }
}
