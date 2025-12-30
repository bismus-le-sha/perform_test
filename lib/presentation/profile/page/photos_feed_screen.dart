import 'dart:async';

import 'package:flutter/material.dart';
import 'package:perform_test/core/config/feature_toggle.dart';
import 'package:perform_test/core/providers/photo_repository_provider.dart';
import 'package:perform_test/data/model/photo.dart';
import 'package:perform_test/presentation/profile/widgets/photo_list_display.dart';
import 'package:perform_test/presentation/profile/widgets/scroll_top_button.dart';
import 'package:perform_test/service/app_config/app_config_provider.dart';
import 'package:perform_test/service/app_config/widget/app_config_widgets.dart';
import 'package:perform_test/presentation/skeleton/skeleton.dart';
import 'package:perform_test/service/metrics_handlers/frame_stats_collector.dart';
import 'package:perform_test/service/metrics_handlers/image_memory_tracker.dart';

/// Main feed screen displaying photos with performance instrumentation.
///
/// EXPERIMENTS ACTIVE ON THIS SCREEN:
///
/// 1. correctDataUpdate - Widget rebuild efficiency (scroll button)
/// 2. lazyLoad - Lazy vs eager list rendering
/// 3. optimImageSize - Image decode size optimization
/// 4. largeJsonParse - JSON parsing isolate offloading
/// 5. minimizeExpensiveRendering - Shimmer optimization (skeleton)
/// 6. staticPlaceholder - Animation cost isolation (skeleton)
class PhotosFeedScreen extends StatefulWidget {
  const PhotosFeedScreen({super.key});

  @override
  State<PhotosFeedScreen> createState() => _PhotosFeedScreenState();
}

class _PhotosFeedScreenState extends State<PhotosFeedScreen> {
  Future<List<Photo>>? _photos;
  final ScrollController _scrollController = ScrollController();
  final _collector = FrameStatsCollector(
    summaryInterval: Duration(seconds: 3),
    warmUpFrames: 30, // Skip first ~0.5s of frames
  );

  @override
  void initState() {
    super.initState();
    _collector.start();
    ImageMemoryTracker.instance.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize photo loading on first context access
    _photos ??= PhotoRepositoryProvider.of(context).getPhotos();
  }

  @override
  void dispose() {
    _collector.stop();
    ImageMemoryTracker.instance.stop();
    _scrollController.dispose();
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
        future: _photos!,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
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
      // EXPERIMENT: correctDataUpdate toggle
      // false: BadScrollToTopButton - setState on EVERY scroll event
      // true: OptimScrollToTopButton - setState only when threshold crossed
      floatingActionButton: appConfig.get(FeatureToggle.correctDataUpdate)
          ? OptimScrollToTopButton(scrollController: _scrollController)
          : BadScrollToTopButton(scrollController: _scrollController),
    );
  }
}
