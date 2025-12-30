import 'package:flutter/material.dart';

import 'package:perform_test/core/config/feature_toggle.dart';
import 'package:perform_test/data/model/photo.dart';
import 'package:perform_test/presentation/profile/widgets/buttons_footer.dart';
import 'package:perform_test/presentation/profile/widgets/profile_header.dart';
import 'package:perform_test/service/app_config/app_config_provider.dart';
import 'package:perform_test/service/metrics_handlers/image_memory_tracker.dart';

/// Displays a single photo item in the feed.
///
/// EXPERIMENT: optimImageSize toggle
///
/// This widget demonstrates the difference between:
/// - Decoding full-resolution images (wastes GPU memory)
/// - Decoding at layout size × devicePixelRatio (optimized)
///
/// IMPORTANT: Both toggle states use the SAME image URL (photo.urls.regular).
/// The optimization is purely CLIENT-SIDE via cacheWidth/cacheHeight parameters.
class PhotoListItem extends StatelessWidget {
  final Photo photo;

  const PhotoListItem({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    final appConfig = AppConfigProvider.of(context);
    final aspectRatio = photo.width / photo.height;
    final useOptimizedSize = appConfig.get(FeatureToggle.optimImageSize);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ProfileHeader(user: photo.user),
        AspectRatio(
          aspectRatio: aspectRatio,
          child: useOptimizedSize
              ? _OptimizedImage(imageUrl: photo.urls.regular, fit: BoxFit.cover)
              : _UnoptimizedImage(
                  imageUrl: photo.urls.regular,
                  fit: BoxFit.cover,
                ),
        ),
        ButtonsFooter(photo: photo),
      ],
    );
  }
}

/// Image widget WITHOUT cacheWidth/cacheHeight optimization.
///
/// Decodes the full image resolution into GPU memory, regardless of
/// actual display size. This is the BASELINE (unoptimized) case.
class _UnoptimizedImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  const _UnoptimizedImage({required this.imageUrl, required this.fit});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);

        return Image.network(
          imageUrl,
          fit: fit,
          // NO cacheWidth/cacheHeight - full resolution decode
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame != null) {
              _trackImageMetrics(
                context: context,
                url: imageUrl,
                constraints: constraints,
                dpr: dpr,
                cacheWidth: null,
                cacheHeight: null,
              );
            }
            return child;
          },
        );
      },
    );
  }
}

/// Image widget WITH cacheWidth/cacheHeight optimization.
///
/// Calculates the optimal decode size based on:
/// - Actual layout constraints (maxWidth from LayoutBuilder)
/// - Device pixel ratio (for sharp rendering on high-DPI screens)
///
/// This tells Flutter to decode at the target size, saving GPU memory.
class _OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  const _OptimizedImage({required this.imageUrl, required this.fit});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);

        // Calculate cache dimensions from actual layout size
        // This is the KEY optimization: layout width × devicePixelRatio
        final cacheWidth = constraints.hasBoundedWidth
            ? (constraints.maxWidth * dpr).ceil()
            : null;

        // Only set cacheWidth, let Flutter maintain aspect ratio
        // Setting both can cause distortion or unnecessary computation

        return Image.network(
          imageUrl,
          fit: fit,
          cacheWidth: cacheWidth,
          // cacheHeight is not set - Flutter maintains aspect ratio
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame != null) {
              _trackImageMetrics(
                context: context,
                url: imageUrl,
                constraints: constraints,
                dpr: dpr,
                cacheWidth: cacheWidth,
                cacheHeight: null,
              );
            }
            return child;
          },
        );
      },
    );
  }
}

/// Track image loading metrics for experimental analysis.
void _trackImageMetrics({
  required BuildContext context,
  required String url,
  required BoxConstraints constraints,
  required double dpr,
  required int? cacheWidth,
  required int? cacheHeight,
}) {
  // Resolve image to get actual dimensions and size
  final imageProvider = NetworkImage(url);
  imageProvider
      .resolve(ImageConfiguration.empty)
      .addListener(
        ImageStreamListener(
          (info, _) {
            ImageMemoryTracker.instance.recordImage(
              url: url,
              sizeBytes: info.sizeBytes,
              imageWidth: info.image.width,
              imageHeight: info.image.height,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              layoutWidth: constraints.maxWidth,
              layoutHeight: constraints.maxHeight,
              devicePixelRatio: dpr,
            );
          },
          onError: (error, stackTrace) {
            debugPrint('Error resolving image info: $error');
          },
        ),
      );
}
