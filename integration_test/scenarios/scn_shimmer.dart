/// SCN-SHIMMER: Shimmer Animation Optimization Scenario
///
/// Tests the hypothesis that multiple ShaderMask widgets cause more GPU work
/// than a single consolidated ShaderMask.
library;

import 'base_scenario.dart';

class ShimmerScenario extends ExperimentScenario {
  @override
  String get id => 'SCN-SHIMMER';

  @override
  String get name => 'Shimmer Effect: Multiple vs Single ShaderMask';

  @override
  String get hypothesis => '''
Multiple ShaderMask widgets (6 in the "bad" implementation) each:
1. Trigger independent animation ticks (6x setState() per frame)
2. Require separate GPU shader computations
3. Create redundant AnimationController instances

Consolidating into a single ShaderMask wrapping all content:
1. Reduces setState() calls from 6x to 1x per frame
2. Single GPU shader pass
3. One AnimationController instance

NULL HYPOTHESIS (H0): Number of ShaderMask widgets has no effect on performance.

ALTERNATIVE HYPOTHESIS (H1): Consolidating ShaderMask widgets significantly
reduces setState() calls and improves GPU efficiency.

BASELINE COMPARISON: Static placeholders (no ShaderMask) establish the cost
of shimmer animation itself.
''';

  @override
  String get independentVariable => '''
ShaderMask architecture:
- BASELINE (minimizeExpensiveRendering=false): 6 separate ShaderMask widgets
- OPTIMIZED (minimizeExpensiveRendering=true): 1 ShaderMask wrapping content
- STATIC (staticPlaceholder=true): No ShaderMask, static gray boxes
''';

  @override
  List<MetricDefinition> get dependentVariables => [
    // PRIMARY METRIC - setState() Call Rate
    MetricDefinition(
      name: 'setstate_calls_per_second',
      description: 'Number of setState() invocations per second',
      source: MetricSource.dartLogger,
      unit: MetricUnit.count,
      aggregation: AggregationType.mean,
    ),

    // PRIMARY METRIC - Raster Thread Time
    MetricDefinition(
      name: 'raster_time_p95_ms',
      description: '95th percentile raster thread time per frame',
      source: MetricSource.frameTimings,
      unit: MetricUnit.milliseconds,
      aggregation: AggregationType.p95,
      precision: 0.5,
    ),

    // SECONDARY METRIC - FPS
    MetricDefinition(
      name: 'animation_fps',
      description: 'Average FPS during shimmer animation',
      source: MetricSource.frameTimings,
      unit: MetricUnit.fps,
      aggregation: AggregationType.mean,
      precision: 1.0,
    ),

    // SECONDARY METRIC - Build Time
    MetricDefinition(
      name: 'build_time_p50_ms',
      description: 'Median build phase time per frame',
      source: MetricSource.frameTimings,
      unit: MetricUnit.milliseconds,
      aggregation: AggregationType.p50,
      precision: 0.1,
    ),

    // TERTIARY METRIC - Jank Percentage
    MetricDefinition(
      name: 'jank_percent',
      description: 'Percentage of frames exceeding 16.67ms',
      source: MetricSource.frameTimings,
      unit: MetricUnit.percent,
      aggregation: AggregationType.mean,
    ),

    // CONTEXT METRIC - Widget Count
    MetricDefinition(
      name: 'shader_mask_count',
      description: 'Number of ShaderMask widgets in tree',
      source: MetricSource.dartLogger,
      unit: MetricUnit.count,
      aggregation: AggregationType.median,
    ),
  ];

  @override
  List<String> get controlVariables => [
    'Animation duration (1500ms)',
    'Shader gradient type (linear)',
    'Content layout (same placeholder structure)',
    'Screen size (same)',
    'Animation curve (same)',
  ];

  @override
  String get toggleName => 'minimizeExpensiveRendering';

  @override
  int get warmUpIterations => 30; // ~0.5 seconds of animation

  @override
  int get measurementIterations => 300; // ~5 seconds of animation

  @override
  double get minEffectSize => 5.0; // Expect 5x reduction in setState() calls

  @override
  DegradationCriteria get degradationCriteria => DegradationCriteria(
    metricName: 'raster_time_p95_ms',
    threshold: 12.0, // If p95 > 12ms, approaching 16.67ms deadline
    direction: DegradationDirection.higherIsBad,
    description: 'Raster time should stay well below frame deadline',
  );
}

// =============================================================================
// CRITICAL ANALYSIS
// =============================================================================

/// ## VALIDITY ASSESSMENT
///
/// ### What This Experiment CORRECTLY Measures:
/// 1. setState() call reduction (6x → 1x)
/// 2. GPU shader consolidation benefit
/// 3. AnimationController instance reduction
///
/// ### Important Nuances:
///
/// 1. DEVICE SENSITIVITY:
///    - Low-end devices: May show significant FPS difference
///    - High-end devices: Both may hit 60 FPS (ceiling effect)
///
///    The experiment validates the PRINCIPLE even if FPS is same.
///
/// 2. SHADER COMPLEXITY:
///    - Simple linear gradient: Low GPU cost
///    - Complex shaders: Would show more dramatic difference
///
/// 3. FLUTTER OPTIMIZATION:
///    - Flutter may optimize redundant paints
///    - RenderObject caching may reduce actual GPU work
///
/// ### Potential Confounds:
/// 1. THERMAL THROTTLING: Continuous animation heats device
///    - MITIGATION: Limit measurement duration, pause between runs
///
/// 2. GC FROM ANIMATION: Object allocation per tick
///    - MITIGATION: Monitor GC events during measurement
///
/// 3. VSYNC ALIASING: 60Hz display caps FPS at 60
///    - MITIGATION: Measure raster time, not just FPS
///
/// ### Metrics That Are PARTIALLY VALID:
/// 1. FPS - May be same on capable devices (use as sanity check)
/// 2. CPU usage - Hard to attribute specifically to ShaderMask
///
/// ### Three-Way Comparison Design:
/// This experiment benefits from THREE conditions:
/// 1. BAD: 6 ShaderMasks (worst)
/// 2. OPTIMIZED: 1 ShaderMask (better)
/// 3. STATIC: 0 ShaderMasks (baseline - isolates animation cost)
///
/// ### Recommendations:
/// 1. Always include static baseline to isolate shader cost
/// 2. Measure on low-end device for visible FPS differences
/// 3. Report setState() count as primary metric (always differs)
/// 4. Consider adding battery/power measurement for sustained animation
