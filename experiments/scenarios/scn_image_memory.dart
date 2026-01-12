/// SCN-IMG: Image Memory Optimization Scenario
///
/// Tests the hypothesis that using cacheWidth/cacheHeight reduces GPU memory
/// usage without affecting visual quality at display size.
library;

import 'base_scenario.dart';

class ImageMemoryScenario extends ExperimentScenario {
  @override
  String get id => 'SCN-IMG';

  @override
  String get name => 'Image Memory: Full Resolution vs Sized Decoding';

  @override
  String get hypothesis => '''
Decoding full-resolution images (e.g., 4000x3000 pixels) into GPU memory is
wasteful when displayed at smaller sizes (e.g., 400x300 logical pixels).

Using cacheWidth/cacheHeight tells Flutter to decode at the target display
size × devicePixelRatio, reducing:
1. Decoded bitmap memory: from 48MB to ~4MB per image (example)
2. GPU memory pressure
3. Decode time (smaller bitmap)

IMPORTANT: This tests CLIENT-SIDE decoding optimization, NOT server-side
image resizing. Both conditions download the SAME image from the same URL.

NULL HYPOTHESIS (H0): cacheWidth/cacheHeight has no effect on memory usage.

ALTERNATIVE HYPOTHESIS (H1): Sized decoding significantly reduces decoded
image memory usage proportional to the resolution reduction.
''';

  @override
  String get independentVariable => '''
Image decode strategy:
- BASELINE (toggle=false): Decode at full source resolution
- OPTIMIZED (toggle=true): Decode at layoutWidth × devicePixelRatio
''';

  @override
  List<MetricDefinition> get dependentVariables => [
    // PRIMARY METRIC - Decoded Bitmap Size
    MetricDefinition(
      name: 'decoded_bytes_per_image',
      description: 'Average decoded bitmap size in bytes (width × height × 4)',
      source: MetricSource.dartLogger, // ImageMemoryTracker
      unit: MetricUnit.bytes,
      aggregation: AggregationType.median,
    ),

    // PRIMARY METRIC - Total Image Memory
    MetricDefinition(
      name: 'total_image_memory_mb',
      description: 'Total memory used by decoded images in cache',
      source: MetricSource.dartLogger,
      unit: MetricUnit.megabytes,
      aggregation: AggregationType.max, // Peak usage
      precision: 0.5,
    ),

    // SECONDARY METRIC - Memory Savings
    MetricDefinition(
      name: 'memory_savings_percent',
      description: 'Percentage reduction in image memory vs full resolution',
      source: MetricSource.dartLogger,
      unit: MetricUnit.percent,
      aggregation: AggregationType.mean,
    ),

    // SECONDARY METRIC - Compression Ratio
    MetricDefinition(
      name: 'compression_ratio',
      description: 'Original pixels / decoded pixels',
      source: MetricSource.dartLogger,
      unit: MetricUnit.count, // Ratio, unitless
      aggregation: AggregationType.mean,
    ),

    // CONTROL METRIC - Image Dimensions
    MetricDefinition(
      name: 'source_width',
      description: 'Original image width (should be same)',
      source: MetricSource.dartLogger,
      unit: MetricUnit.count,
      aggregation: AggregationType.median,
    ),

    // CONTEXT METRIC - Display Size
    MetricDefinition(
      name: 'layout_width',
      description: 'Logical layout width in pixels',
      source: MetricSource.dartLogger,
      unit: MetricUnit.count,
      aggregation: AggregationType.median,
    ),

    // CONTEXT METRIC - Device Pixel Ratio
    MetricDefinition(
      name: 'device_pixel_ratio',
      description: 'Screen density multiplier',
      source: MetricSource.dartLogger,
      unit: MetricUnit.count, // Ratio
      aggregation: AggregationType.median,
    ),
  ];

  @override
  List<String> get controlVariables => [
    'Image URL (same source image)',
    'Layout dimensions (same container size)',
    'Number of images (same count)',
    'Image format (JPEG from Unsplash)',
    'Image cache cleared before measurement',
  ];

  @override
  String get toggleName => 'optimImageSize';

  @override
  int get warmUpIterations => 1; // Need to load images fresh

  @override
  int get measurementIterations => 5; // Fewer iterations, each needs cache clear

  @override
  double get minEffectSize => 5.0; // Expect at least 5x memory reduction

  @override
  DegradationCriteria get degradationCriteria => DegradationCriteria(
    metricName: 'compression_ratio',
    threshold: 2.0, // If ratio < 2x, optimization not effective
    direction: DegradationDirection.lowerIsBad,
    description: 'Optimized decoding should achieve at least 2x compression',
  );
}

// =============================================================================
// CRITICAL ANALYSIS
// =============================================================================

/// ## VALIDITY ASSESSMENT
///
/// ### What This Experiment CORRECTLY Measures:
/// 1. ✅ Decoded bitmap size difference (PRIMARY)
/// 2. ✅ Memory savings from sized decoding
/// 3. ✅ Practical impact on image-heavy UIs
///
/// ### Common Misconceptions Addressed:
/// 1. ❌ "This reduces network usage" - FALSE. Same image downloaded.
/// 2. ❌ "This affects image quality" - FALSE at proper DPR calculation.
/// 3. ✅ This only affects CLIENT-SIDE decode memory.
///
/// ### Metrics That Are INVALID for This Experiment:
/// 1. ❌ Network time - Same URL, same download
/// 2. ❌ FPS - Not directly affected by bitmap size in memory
/// 3. ❌ Raster time after decode - Bitmap already in GPU memory
///
/// ### Potential Confounds:
/// 1. ⚠️ IMAGE CACHE: Flutter's ImageCache may affect measurements
///    - MITIGATION: Clear cache before each measurement
///
/// 2. ⚠️ JPEG DECODING VARIANCE: Same image may decode slightly differently
///    - MITIGATION: Use mathematical formula (W×H×4) not sizeBytes
///
/// 3. ⚠️ DEVICEPIXELRATIO: Different devices have different DPR
///    - MITIGATION: Document DPR, calculate expected sizes
///
/// ### Calculation Verification:
/// For a 4000×3000 image displayed at 400×300 logical pixels on 3x DPR:
/// - BASELINE: 4000 × 3000 × 4 = 48,000,000 bytes (48 MB)
/// - OPTIMIZED: 1200 × 900 × 4 = 4,320,000 bytes (4.3 MB)
/// - Compression ratio: 48 / 4.32 ≈ 11x
///
/// ### Recommendations:
/// 1. Always clear ImageCache before measurement
/// 2. Verify visual quality is acceptable (subjective check)
/// 3. Test with multiple image sizes for comprehensive analysis
/// 4. Document exact DPR and layout size for reproducibility
