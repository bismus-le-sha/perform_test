/// SCN-JSON: Large JSON Parsing Scenario
///
/// Tests the hypothesis that parsing large JSON on the main isolate blocks
/// the UI, while compute() offloading maintains responsiveness.
library;

import 'base_scenario.dart';

class JsonParsingScenario extends ExperimentScenario {
  @override
  String get id => 'SCN-JSON';

  @override
  String get name => 'JSON Parsing: Main Isolate vs compute()';

  @override
  String get hypothesis => '''
Parsing large JSON data (~3.5MB, 500 records) on the main isolate blocks the 
UI event loop during the parsing phase, causing:
1. Shimmer animation stutter/freeze
2. Input unresponsiveness
3. Frame deadline misses

Using compute() moves JSON parsing to a background isolate, allowing the UI
to remain responsive during data processing.

IMPORTANT DISTINCTION: This experiment isolates PARSING TIME from I/O TIME.
File/network I/O is always asynchronous and does not block UI.

NULL HYPOTHESIS (H0): UI responsiveness is the same for synchronous and
compute()-based JSON parsing.

ALTERNATIVE HYPOTHESIS (H1): compute()-based parsing maintains significantly
smoother animation compared to synchronous parsing.
''';

  @override
  String get independentVariable => '''
JSON parsing context:
- BASELINE (toggle=false): jsonDecode() + model mapping on main isolate
- OPTIMIZED (toggle=true): jsonDecode() + model mapping via compute()
''';

  @override
  List<MetricDefinition> get dependentVariables => [
    // PRIMARY METRIC - Animation Smoothness
    MetricDefinition(
      name: 'animation_fps_during_parse',
      description: 'FPS of shimmer animation during JSON parsing',
      source: MetricSource.frameTimings,
      unit: MetricUnit.fps,
      aggregation: AggregationType.mean,
      precision: 1.0,
    ),

    // PRIMARY METRIC - Frame Consistency
    MetricDefinition(
      name: 'frame_time_p95_ms',
      description: '95th percentile frame time during parsing',
      source: MetricSource.frameTimings,
      unit: MetricUnit.milliseconds,
      aggregation: AggregationType.p95,
      precision: 1.0,
    ),

    // SECONDARY METRIC - Jank Count
    MetricDefinition(
      name: 'jank_frames_during_parse',
      description: 'Frames exceeding 16.67ms during parsing',
      source: MetricSource.frameTimings,
      unit: MetricUnit.count,
      aggregation: AggregationType.sum,
    ),

    // CONTROL METRIC - Parse Time (should be similar)
    MetricDefinition(
      name: 'parse_time_ms',
      description: 'Time to complete JSON parsing (excluding I/O)',
      source: MetricSource.dartLogger,
      unit: MetricUnit.milliseconds,
      aggregation: AggregationType.median,
      precision: 20.0,
    ),

    // CONTROL METRIC - I/O Time (should NOT differ)
    MetricDefinition(
      name: 'io_time_ms',
      description: 'Time for file/network I/O (async, should not differ)',
      source: MetricSource.dartLogger,
      unit: MetricUnit.milliseconds,
      aggregation: AggregationType.median,
    ),

    // TERTIARY - Total Load Time
    MetricDefinition(
      name: 'total_load_time_ms',
      description: 'Total time from request to data ready',
      source: MetricSource.dartLogger,
      unit: MetricUnit.milliseconds,
      aggregation: AggregationType.median,
    ),
  ];

  @override
  List<String> get controlVariables => [
    'JSON file size (~3.5MB)',
    'Number of records (500 Photo objects)',
    'Data model complexity (Photo with nested Urls)',
    'File source (local asset vs network)',
    'Shimmer animation active during measurement',
  ];

  @override
  String get toggleName => 'largeJsonParce';

  @override
  int get warmUpIterations => 3;

  @override
  int get measurementIterations => 10;

  @override
  double get minEffectSize => 20.0; // Expect 20+ FPS improvement during parse

  @override
  DegradationCriteria get degradationCriteria => DegradationCriteria(
    metricName: 'animation_fps_during_parse',
    threshold: 45.0,
    direction: DegradationDirection.lowerIsBad,
    description: 'Animation should maintain >45 FPS during parsing',
  );
}

// =============================================================================
// CRITICAL ANALYSIS
// =============================================================================

/// ## VALIDITY ASSESSMENT
///
/// ### What This Experiment CORRECTLY Measures:
/// 1. ✅ JSON parsing impact on UI thread
/// 2. ✅ Animation smoothness during data processing
/// 3. ✅ Practical benefit of isolate offloading for parsing
///
/// ### Common Misconceptions Addressed:
/// 1. ❌ "Network I/O blocks UI" - FALSE. Dart async I/O is non-blocking.
/// 2. ❌ "All JSON parsing is slow" - Depends on size and model complexity.
/// 3. ✅ Only CPU-bound work (parsing, mapping) can block UI.
///
/// ### Potential Confounds:
/// 1. ⚠️ JSON SIZE VARIANCE: Different JSON files may have different parse times
///    - MITIGATION: Use same file across all iterations
///
/// 2. ⚠️ MODEL COMPLEXITY: Generated code (json_serializable) may vary
///    - MITIGATION: Document exact model structure and generated code
///
/// 3. ⚠️ GC FROM ALLOCATIONS: Parsing creates many objects
///    - MITIGATION: Monitor GC events via VM Service
///
/// 4. ⚠️ COMPUTE() SERIALIZATION OVERHEAD: Data must be serialized to isolate
///    - MITIGATION: Measure serialization time separately, document overhead
///
/// ### Metrics That Are INVALID for This Experiment:
/// 1. ❌ Network latency - Not testing network performance
/// 2. ❌ File read time - async I/O doesn't block UI
/// 3. ❌ Total "load time" alone - Confounds I/O and parsing
///
/// ### Recommendations:
/// 1. Always measure I/O and parsing SEPARATELY
/// 2. Document the compute() serialization overhead
/// 3. Consider testing with different JSON sizes to establish scaling
