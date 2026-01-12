import 'package:flutter/material.dart';

/// Tracks decoded image memory usage for the optimImageSize experiment.
///
/// ## HYPOTHESIS
/// Using `cacheWidth`/`cacheHeight` reduces decoded bitmap size in GPU memory
/// without affecting visual quality at the displayed size.
///
/// ## KEY METRICS
/// - **Decoded Bitmap Size**: `width × height × 4` bytes (RGBA)
/// - **Compression Ratio**: `originalPixels / decodedPixels`
/// - **Memory Savings %**: `(original - decoded) / original × 100`
///
/// ## EXCLUDED METRICS (not valid for this experiment)
/// - Raster time: does not change after image is decoded
/// - FPS: not affected by bitmap size in memory
/// - Network time: same URL in both conditions
class ImageMemoryTracker {
  static final ImageMemoryTracker instance = ImageMemoryTracker._();
  ImageMemoryTracker._();

  final List<ImageMemoryRecord> _records = [];
  bool _isTracking = false;
  int _iterationNumber = 0;

  /// Start a new tracking session
  void start() {
    _records.clear();
    _iterationNumber++;
    _isTracking = true;
    debugPrint(
      '[ImageMemoryTracker] ═══ Iteration $_iterationNumber START ═══',
    );
  }

  /// Stop tracking and print comprehensive summary
  void stop() {
    _isTracking = false;
    _printSummary();
    debugPrint('[ImageMemoryTracker] ═══ Iteration $_iterationNumber END ═══');
  }

  /// Clear image cache before measurement (call this for clean experiments)
  void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugPrint('[ImageMemoryTracker] Image cache cleared');
  }

  /// Record an image measurement with full metrics
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

    // Calculate actual decoded dimensions
    int decodedWidth = imageWidth;
    int decodedHeight = imageHeight;

    if (cacheWidth != null) {
      decodedWidth = cacheWidth;
      // Flutter maintains aspect ratio
      decodedHeight = (imageHeight * cacheWidth / imageWidth).ceil();
    }

    final originalBytes = imageWidth * imageHeight * 4;
    final decodedBytes = decodedWidth * decodedHeight * 4;
    final compressionRatio = originalBytes / decodedBytes;
    final savingsPercent = (originalBytes - decodedBytes) / originalBytes * 100;
    final isOptimized = cacheWidth != null;

    final record = ImageMemoryRecord(
      url: url,
      originalWidth: imageWidth,
      originalHeight: imageHeight,
      decodedWidth: decodedWidth,
      decodedHeight: decodedHeight,
      originalBytes: originalBytes,
      decodedBytes: decodedBytes,
      compressionRatio: compressionRatio,
      savingsPercent: savingsPercent,
      layoutWidth: layoutWidth.toInt(),
      layoutHeight: layoutHeight.toInt(),
      devicePixelRatio: devicePixelRatio,
      isOptimized: isOptimized,
    );

    _records.add(record);

    debugPrint(
      '[IMG ${_records.length.toString().padLeft(2)}] '
      '${isOptimized ? "✓ OPT" : "✗ RAW"}: '
      '${imageWidth}×$imageHeight → ${decodedWidth}×$decodedHeight | '
      '${_formatBytes(originalBytes)} → ${_formatBytes(decodedBytes)} | '
      '${compressionRatio.toStringAsFixed(1)}x | '
      '${isOptimized ? "-${savingsPercent.toStringAsFixed(0)}%" : "baseline"}',
    );
  }

  void _printSummary() {
    if (_records.isEmpty) {
      debugPrint('[ImageMemoryTracker] No images tracked');
      return;
    }

    // Calculate totals
    int totalOriginalBytes = 0;
    int totalDecodedBytes = 0;
    final compressionRatios = <double>[];

    for (final r in _records) {
      totalOriginalBytes += r.originalBytes;
      totalDecodedBytes += r.decodedBytes;
      compressionRatios.add(r.compressionRatio);
    }

    compressionRatios.sort();

    final totalSavings = totalOriginalBytes - totalDecodedBytes;
    final totalSavingsPercent = totalOriginalBytes > 0
        ? (totalSavings / totalOriginalBytes * 100)
        : 0.0;

    // Median compression ratio
    final medianCompression = compressionRatios.isNotEmpty
        ? compressionRatios[compressionRatios.length ~/ 2]
        : 1.0;

    // Average per image
    final avgDecoded = totalDecodedBytes ~/ _records.length;

    final isOptimized = _records.any((r) => r.isOptimized);

    debugPrint('''

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃  IMAGE MEMORY EXPERIMENT - ITERATION $_iterationNumber                      ┃
┃  Mode: ${isOptimized ? "OPTIMIZED (cacheWidth enabled)" : "BASELINE (full resolution)"}              ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃  Images tracked: ${_records.length.toString().padLeft(3)}                                          ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃  ▸ PRIMARY METRIC: Decoded Bitmap Size                       ┃
┃    ─────────────────────────────────────────────────────     ┃
┃    Original (before):  ${_formatBytes(totalOriginalBytes).padLeft(12)}                        ┃
┃    Decoded (after):    ${_formatBytes(totalDecodedBytes).padLeft(12)}                        ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃  ▸ SECONDARY METRICS                                         ┃
┃    ─────────────────────────────────────────────────────     ┃
┃    Memory Savings:     ${_formatBytes(totalSavings).padLeft(12)} (${totalSavingsPercent.toStringAsFixed(1)}%)             ┃
┃    Compression Ratio:  ${medianCompression.toStringAsFixed(1).padLeft(12)}x (median)              ┃
┃    Avg per image:      ${_formatBytes(avgDecoded).padLeft(12)}                        ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
''');
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  /// Get current records for analysis
  List<ImageMemoryRecord> get records => List.unmodifiable(_records);

  /// Get current iteration number
  int get iterationNumber => _iterationNumber;

  /// Reset iteration counter (for new experiment session)
  void resetIterations() {
    _iterationNumber = 0;
    _records.clear();
  }
}

/// Immutable record of a single image memory measurement.
///
/// Contains pre-calculated metrics for experiment analysis:
/// - Compression ratio (how much smaller the decoded image is)
/// - Memory savings percentage
/// - Original vs decoded dimensions
class ImageMemoryRecord {
  final String url;
  final int originalWidth;
  final int originalHeight;
  final int decodedWidth;
  final int decodedHeight;
  final int originalBytes;
  final int decodedBytes;
  final double compressionRatio;
  final double savingsPercent;
  final int layoutWidth;
  final int layoutHeight;
  final double devicePixelRatio;
  final bool isOptimized;
  final DateTime timestamp;

  ImageMemoryRecord({
    required this.url,
    required this.originalWidth,
    required this.originalHeight,
    required this.decodedWidth,
    required this.decodedHeight,
    required this.originalBytes,
    required this.decodedBytes,
    required this.compressionRatio,
    required this.savingsPercent,
    required this.layoutWidth,
    required this.layoutHeight,
    required this.devicePixelRatio,
    required this.isOptimized,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'ImageMemoryRecord('
        '${originalWidth}×$originalHeight → ${decodedWidth}×$decodedHeight, '
        'ratio: ${compressionRatio.toStringAsFixed(1)}x, '
        'savings: ${savingsPercent.toStringAsFixed(0)}%)';
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
