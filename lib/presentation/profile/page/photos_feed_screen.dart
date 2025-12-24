import 'dart:async';

import 'package:flutter/material.dart';
import 'package:perform_test/data/datasource/api.dart';
import 'package:perform_test/data/model/photo.dart';
import 'package:perform_test/presentation/profile/widgets/photo_list_display.dart';
import 'package:perform_test/presentation/profile/widgets/scroll_top_button.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/service/app_config/app_config_provider.dart';
import 'package:perform_test/service/app_config/widget/app_config_widgets.dart';
import 'package:perform_test/presentation/skeleton/skeleton.dart';
import 'package:perform_test/service/metrics_handlers/frame_stats_collector.dart';

class PhotosFeedScreen extends StatefulWidget {
  const PhotosFeedScreen({super.key, required this.datasource});
  final Datasource datasource;

  @override
  State<PhotosFeedScreen> createState() => _PhotosFeedScreenState();
}

class _PhotosFeedScreenState extends State<PhotosFeedScreen> {
  late Future<List<Photo>> _photos;
  final ScrollController _scrollController = ScrollController();
  final _collector = FrameStatsCollector(summaryInterval: Duration(seconds: 3));
  bool _showScrollingToTopButton = false;

  @override
  void initState() {
    super.initState();
    _photos = widget.datasource.fetchPhotos();
    // _scrollController.addListener(_scrollListener);
    _collector.start();
  }

  // void _scrollListener() {
  //   setState(() {
  //     _showScrollingToTopButton = _scrollController.offset > 100;
  //   });
  // }

  @override
  void dispose() {
    // _scrollController.removeListener(_scrollListener);
    _collector.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = AppConfigProvider.of(context);
    return Scaffold(
      appBar: AppConfigBar(
        title: const Text(
          'Guinea Pigs 🐹',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FutureBuilder<List<Photo>>(
        future: _photos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // return Center(child: const CircularProgressIndicator());
            return const SkeletonPlaceholder();
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return PhotoList(
              photos: snapshot.data!,
              scrollController: _scrollController,
            );
          }
        },
      ),
      floatingActionButton: appConfig.get(FeatureToggle.correctDataUpdate)
          ? OptimScrollToTopButton(scrollController: _scrollController)
          : (_showScrollingToTopButton
                ? FloatingActionButton(
                    onPressed: () {
                      _scrollController.animateTo(
                        0.0,
                        curve: Curves.easeIn,
                        duration: const Duration(milliseconds: 300),
                      );
                    },
                    child: const Icon(Icons.arrow_upward),
                  )
                : const SizedBox.shrink()),
    );
  }
}
