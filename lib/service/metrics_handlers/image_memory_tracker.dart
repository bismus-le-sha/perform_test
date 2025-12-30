import 'package:flutter/material.dart';

/// Tracks decoded image memory usage for the optimImageSize experiment.
///
/// HYPOTHESIS: Using cacheWidth/cacheHeight reduces decoded image memory
/// without changing visual appearance (within layout constraints).
///
/// METRICS:
/// - Decoded image size in bytes (sizeBytes from ImageInfo)
/// - Number of images tracked
/// - Total memory consumption
///
/// WHAT SHOULD CHANGE: Decoded bytes per image (lower with cacheWidth)
/// WHAT SHOULD NOT CHANGE: Visual appearance, layout, FPS
class ImageMemoryTracker {
  static final ImageMemoryTracker instance = ImageMemoryTracker._();
  ImageMemoryTracker._();

  final List<ImageMeasurement> _measurements = [];
  bool _isTracking = false;

  /// Start tracking image memory
  void start() {
    _measurements.clear();
    _isTracking = true;
    debugPrint('[ImageMemoryTracker] Started tracking');
  }

  /// Stop tracking and print summary
  void stop() {
    _isTracking = false;
    _printSummary();
    debugPrint('[ImageMemoryTracker] Stopped tracking');
  }

  /// Record an image measurement
  void recordImage({
    required String url,
    required int? sizeBytes,
    required int imageWidth,
    required int imageHeight,
    required int? cacheWidth,
    required int? cacheHeight,
    required double layoutWidth,
    required double layoutHeight,
    required double devicePixelRatio,
  }) {
    if (!_isTracking) return;

    final measurement = ImageMeasurement(
      url: url,
      sizeBytes: sizeBytes,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      layoutWidth: layoutWidth,
      layoutHeight: layoutHeight,
      devicePixelRatio: devicePixelRatio,
    );

    _measurements.add(measurement);

    debugPrint(
      '[ImageMemoryTracker] Image loaded: '
      '${imageWidth}x$imageHeight -> ${cacheWidth ?? imageWidth}x${cacheHeight ?? imageHeight} '
      '(layout: ${layoutWidth.toInt()}x${layoutHeight.toInt()}, dpr: ${devicePixelRatio.toStringAsFixed(1)}) '
      '${sizeBytes != null ? "${(sizeBytes / 1024).toStringAsFixed(0)} KB" : "size unknown"}',
    );
  }

  void _printSummary() {
    if (_measurements.isEmpty) {
      debugPrint('[ImageMemoryTracker] No images tracked');
      return;
    }

    final withSize = _measurements.where((m) => m.sizeBytes != null).toList();
    final totalBytes = withSize.fold<int>(0, (sum, m) => sum + m.sizeBytes!);
    final avgBytes = withSize.isNotEmpty ? totalBytes ~/ withSize.length : 0;

    final sortedSizes = withSize.map((m) => m.sizeBytes!).toList()..sort();
    final medianBytes = sortedSizes.isNotEmpty
        ? sortedSizes[sortedSizes.length ~/ 2]
        : 0;

    // Calculate potential savings from cacheWidth usage
    final withCache = _measurements.where((m) => m.cacheWidth != null).length;
    final withoutCache = _measurements
        .where((m) => m.cacheWidth == null)
        .length;

    debugPrint('''
=== IMAGE MEMORY SUMMARY ===
Images tracked: ${_measurements.length}
  - with cacheWidth: $withCache
  - without cacheWidth: $withoutCache

Memory (${withSize.length} images with size data):
  Total:  ${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB
  Avg:    ${(avgBytes / 1024).toStringAsFixed(0)} KB
  Median: ${(medianBytes / 1024).toStringAsFixed(0)} KB
=============================''');
  }

  /// Get current measurements for analysis
  List<ImageMeasurement> get measurements => List.unmodifiable(_measurements);
}

/// Single image measurement record
class ImageMeasurement {
  final String url;
  final int? sizeBytes;
  final int imageWidth;
  final int imageHeight;
  final int? cacheWidth;
  final int? cacheHeight;
  final double layoutWidth;
  final double layoutHeight;
  final double devicePixelRatio;
  final DateTime timestamp;

  ImageMeasurement({
    required this.url,
    required this.sizeBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.cacheWidth,
    required this.cacheHeight,
    required this.layoutWidth,
    required this.layoutHeight,
    required this.devicePixelRatio,
  }) : timestamp = DateTime.now();

  /// Expected decoded size in bytes (RGBA, 4 bytes per pixel)
  int get expectedDecodedBytes => imageWidth * imageHeight * 4;

  /// Expected cached size if cacheWidth/cacheHeight were used
  int get expectedCachedBytes {
    if (cacheWidth == null && cacheHeight == null) {
      return expectedDecodedBytes;
    }
    final w = cacheWidth ?? imageWidth;
    final h = cacheHeight ?? imageHeight;
    return w * h * 4;
  }

  /// Memory savings ratio from using cacheWidth/cacheHeight
  double get memorySavingsRatio {
    if (cacheWidth == null && cacheHeight == null) return 0;
    return 1 - (expectedCachedBytes / expectedDecodedBytes);
  }
}

/// Widget that wraps Image.network and tracks memory usage.
///
/// This widget handles:
/// 1. Calculating appropriate cacheWidth/cacheHeight from layout
/// 2. Tracking decoded image size
/// 3. Reporting metrics to ImageMemoryTracker
class TrackedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final bool useCacheSize;
  final BoxFit fit;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const TrackedNetworkImage({
    super.key,
    required this.imageUrl,
    required this.useCacheSize,
    this.fit = BoxFit.cover,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  State<TrackedNetworkImage> createState() => _TrackedNetworkImageState();
}

class _TrackedNetworkImageState extends State<TrackedNetworkImage> {
  bool _tracked = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);

        // Calculate cache dimensions based on actual layout size
        // This is the correct approach: layout size × devicePixelRatio
        int? cacheWidth;
        int? cacheHeight;

        if (widget.useCacheSize && constraints.hasBoundedWidth) {
          cacheWidth = (constraints.maxWidth * dpr).ceil();
          // Don't set cacheHeight - let Flutter maintain aspect ratio
        }

        final imageWidget = Image.network(
          widget.imageUrl,
          fit: widget.fit,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame != null && !_tracked) {
              // Image has loaded, resolve to get info
              _resolveImageInfo(
                context,
                cacheWidth,
                cacheHeight,
                dpr,
                constraints,
              );
            }
            return child;
          },
          loadingBuilder: widget.loadingBuilder,
          errorBuilder: widget.errorBuilder,
        );

        return imageWidget;
      },
    );
  }

  void _resolveImageInfo(
    BuildContext context,
    int? cacheWidth,
    int? cacheHeight,
    double dpr,
    BoxConstraints constraints,
  ) {
    if (_tracked) return;
    _tracked = true;

    final imageProvider = NetworkImage(widget.imageUrl);
    imageProvider
        .resolve(ImageConfiguration.empty)
        .addListener(
          ImageStreamListener((info, _) {
            ImageMemoryTracker.instance.recordImage(
              url: widget.imageUrl,
              sizeBytes: info.sizeBytes,
              imageWidth: info.image.width,
              imageHeight: info.image.height,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              layoutWidth: constraints.maxWidth,
              layoutHeight: constraints.maxHeight,
              devicePixelRatio: dpr,
            );
          }),
        );
  }
}
