/// SCN-REBUILD: Widget Rebuild Efficiency Scenario
///
/// Tests the hypothesis that unnecessary setState() calls cause excessive
/// widget rebuilds and performance degradation.
library;

import 'base_scenario.dart';

class WidgetRebuildScenario extends ExperimentScenario {
  @override
  String get id => 'SCN-REBUILD';

  @override
  String get name => 'Widget Rebuild: Naive vs Conditional setState()';

  @override
  String get hypothesis => '''
Calling setState() on every scroll event (60+ times/second during scrolling)
causes unnecessary widget rebuilds, consuming CPU cycles and potentially
causing frame drops. 

Checking if state actually changed before calling setState() reduces rebuild
count from N (all scroll events) to ~2 (threshold crossings only).

NULL HYPOTHESIS (H0): Build count does not affect frame rendering time.

ALTERNATIVE HYPOTHESIS (H1): Reducing setState() calls significantly reduces
widget rebuild count and improves frame timing consistency.

IMPORTANT: This experiment tests REBUILD COUNT, not necessarily FPS.
The impact on FPS depends on widget complexity and device performance.
''';

  @override
  String get independentVariable => '''
setState() invocation strategy:
- BASELINE (toggle=false): setState() on EVERY scroll event
- OPTIMIZED (toggle=true): setState() only when crossing visibility threshold
''';

  @override
  List<MetricDefinition> get dependentVariables => [
    // PRIMARY METRIC - Rebuild Count
    MetricDefinition(
      name: 'widget_build_count',
      description: 'Number of times build() was called during scroll gesture',
      source: MetricSource.dartLogger,
      unit: MetricUnit.count,
      aggregation: AggregationType.sum,
    ),

    // SECONDARY METRIC - Build Time Accumulation
    MetricDefinition(
      name: 'total_build_time_ms',
      description: 'Cumulative time spent in build() during scroll',
      source: MetricSource.dartLogger,
      unit: MetricUnit.milliseconds,
      aggregation: AggregationType.sum,
    ),

    // SECONDARY METRIC - Frame Consistency
    MetricDefinition(
      name: 'frame_time_variance',
      description: 'Variance in frame times during scroll (lower = smoother)',
      source: MetricSource.frameTimings,
      unit: MetricUnit.milliseconds,
      aggregation: AggregationType.mean,
    ),

    // TERTIARY METRIC - FPS During Scroll
    MetricDefinition(
      name: 'scroll_fps',
      description: 'Average FPS during scroll gesture',
      source: MetricSource.frameTimings,
      unit: MetricUnit.fps,
      aggregation: AggregationType.mean,
      precision: 1.0,
    ),

    // CONTEXT METRIC - Scroll Event Count
    MetricDefinition(
      name: 'scroll_event_count',
      description: 'Number of scroll events received (control)',
      source: MetricSource.dartLogger,
      unit: MetricUnit.count,
      aggregation: AggregationType.sum,
    ),
  ];

  @override
  List<String> get controlVariables => [
    'Scroll distance (1000 pixels down, 1000 up)',
    'Scroll velocity (programmatic, consistent)',
    'Widget complexity (ScrollToTopButton)',
    'List content (same 500 items)',
  ];

  @override
  String get toggleName => 'correctDataUpdate';

  @override
  int get warmUpIterations => 2;

  @override
  int get measurementIterations => 10;

  @override
  double get minEffectSize => 0.9; // Expect 90% reduction in build count

  @override
  DegradationCriteria get degradationCriteria => DegradationCriteria(
    metricName: 'widget_build_count',
    threshold: 100.0, // If optimized has >100 builds, optimization not working
    direction: DegradationDirection.higherIsBad,
    description:
        'Optimized path should have minimal rebuilds (<10 per gesture)',
  );
}

// =============================================================================
// CRITICAL ANALYSIS
// =============================================================================

/// ## VALIDITY ASSESSMENT
///
/// ### What This Experiment CORRECTLY Measures:
/// 1. Rebuild count reduction (PRIMARY GOAL)
/// 2. CPU time saved by avoiding unnecessary rebuilds
/// 3. Best practice demonstration
///
/// ### What This Experiment MAY NOT Detect:
/// 1. FPS IMPACT: On modern devices, a simple widget rebuild may not cause
///    visible FPS drop. The experiment validates the PRINCIPLE, not necessarily
///    a user-visible improvement.
///
/// 2. WIDGET COMPLEXITY: The ScrollToTopButton is trivial. A complex widget
///    would show more dramatic differences.
///
/// ### Potential Confounds:
/// 1. FLUTTER OPTIMIZATION: Flutter may skip actual repaint if widget tree
///    doesn't change (RenderObject caching).
///    - MITIGATION: Measure build() call count, not just visual updates
///
/// 2. SCROLL CALLBACK FREQUENCY: Varies with scroll velocity
///    - MITIGATION: Use programmatic scroll with consistent parameters
///
/// ### Metrics That Are QUESTIONABLE for This Experiment:
/// 1. FPS - May not change for simple widgets
/// 2. Memory - Rebuilds don't necessarily increase memory
///
/// ### Valid Primary Metric:
/// - BUILD COUNT is the only reliable metric for this experiment
/// - Other metrics are context-dependent
///
/// ### Recommendations:
/// 1. Test with more complex widget to show FPS impact
/// 2. Use RepaintBoundary to isolate measurement
/// 3. Consider profiling with DevTools "Track Widget Rebuilds"
