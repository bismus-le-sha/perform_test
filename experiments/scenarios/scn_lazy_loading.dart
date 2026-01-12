/// SCN-LAZY: Lazy vs Eager List Loading Scenario
///
/// Tests the hypothesis that lazy list rendering (ListView.builder) is more
/// efficient for initial load than eager rendering (Column with all items).
library;

import 'base_scenario.dart';

class LazyLoadingScenario extends ExperimentScenario {
  @override
  String get id => 'SCN-LAZY';

  @override
  String get name => 'List Rendering: Eager Column vs Lazy ListView';

  @override
  String get hypothesis => '''
Eagerly building all list items (500 items via Column in SingleChildScrollView)
creates the entire widget tree at once, causing:
1. Long initial build time
2. High memory usage (all widgets in memory)
3. Delayed time-to-first-frame

Lazy rendering (ListView.builder/separated) builds only visible items (~10-15)
plus a small buffer, resulting in:
1. Fast initial build time
2. Lower memory usage
3. Quick time-to-first-frame
4. Potential scroll jank (on-demand building trade-off)

NULL HYPOTHESIS (H0): Initial build time is the same for eager and lazy rendering.

ALTERNATIVE HYPOTHESIS (H1): Lazy rendering significantly reduces initial build
time and widget count.
''';

  @override
  String get independentVariable => '''
List rendering strategy:
- BASELINE (toggle=false): SingleChildScrollView + Column with ALL 500 items
- OPTIMIZED (toggle=true): ListView.separated with on-demand item building
''';

  @override
  List<MetricDefinition> get dependentVariables => [
    // PRIMARY METRIC - Initial Build Time
    MetricDefinition(
      name: 'initial_build_time_ms',
      description: 'Time to build initial widget tree (before first frame)',
      source: MetricSource.dartLogger,
      unit: MetricUnit.milliseconds,
      aggregation: AggregationType.median,
      precision: 10.0,
    ),

    // PRIMARY METRIC - Widget Count
    MetricDefinition(
      name: 'initial_widget_count',
      description: 'Number of widgets built during initial render',
      source: MetricSource.dartLogger,
      unit: MetricUnit.count,
      aggregation: AggregationType.median,
    ),

    // SECONDARY METRIC - Time to First Frame
    MetricDefinition(
      name: 'time_to_first_frame_ms',
      description: 'Time from widget build start to first frame rendered',
      source: MetricSource.timeline,
      unit: MetricUnit.milliseconds,
      aggregation: AggregationType.median,
      precision: 5.0,
    ),

    // SECONDARY METRIC - Memory at Initial Render
    MetricDefinition(
      name: 'heap_used_mb',
      description: 'Dart heap usage after initial render',
      source: MetricSource.vmService,
      unit: MetricUnit.megabytes,
      aggregation: AggregationType.median,
      precision: 0.5,
    ),

    // TRADE-OFF METRIC - Scroll Performance
    MetricDefinition(
      name: 'scroll_jank_percent',
      description: 'Percentage of janky frames during scroll (trade-off)',
      source: MetricSource.frameTimings,
      unit: MetricUnit.percent,
      aggregation: AggregationType.mean,
    ),

    // TRADE-OFF METRIC - Scroll FPS
    MetricDefinition(
      name: 'scroll_fps',
      description: 'Average FPS during scroll (may differ due to on-demand building)',
      source: MetricSource.frameTimings,
      unit: MetricUnit.fps,
      aggregation: AggregationType.mean,
      precision: 1.0,
    ),
  ];

  @override
  List<String> get controlVariables => [
    'Total item count (500)',
    'Item widget complexity (PhotoListItem)',
    'Separator spacing (16px)',
    'Scroll physics (default)',
  ];

  @override
  String get toggleName => 'lazyLoad';

  @override
  int get warmUpIterations => 2;

  @override
  int get measurementIterations => 10;

  @override
  double get minEffectSize => 0.8; // Expect 80% reduction in initial build time

  @override
  DegradationCriteria get degradationCriteria => DegradationCriteria(
    metricName: 'initial_build_time_ms',
    threshold: 500.0, // If lazy takes >500ms, something is wrong
    direction: DegradationDirection.higherIsBad,
    description: 'Lazy loading should complete initial build in <500ms',
  );
}

// =============================================================================
// CRITICAL ANALYSIS
// =============================================================================

/// ## VALIDITY ASSESSMENT
///
/// ### What This Experiment CORRECTLY Measures:
/// 1. ✅ Initial build time difference (dramatic for large lists)
/// 2. ✅ Widget count difference (500 vs ~15 initially)
/// 3. ✅ Memory footprint difference
///
/// ### Important Nuances:
///
/// 1. ⚠️ BUILD() STOPWATCH MEASURES DIFFERENT THINGS:
///    - EAGER: Measures building Column with 500 PhotoListItem children
///    - LAZY: Measures building ListView.separated widget (NOT item builders)
///
///    The Stopwatch in PhotoList.build() shows DRAMATIC difference because
///    it measures widget CONSTRUCTION, not rendering.
///
/// 2. ⚠️ SCROLL PERFORMANCE TRADE-OFF:
///    - EAGER: All items pre-built, scroll is "free"
///    - LAZY: Items built on-demand, may cause scroll jank
///
///    This is a TRADE-OFF, not a bug. Document both metrics.
///
/// 3. ⚠️ ITEM COMPLEXITY MATTERS:
///    - Simple items: Lazy has small advantage
///    - Complex items with images: Lazy has HUGE advantage
///
/// ### Potential Confounds:
/// 1. ⚠️ IMAGE LOADING: Network images load asynchronously
///    - MITIGATION: Use cached images or measure without images
///
/// 2. ⚠️ LIST VIEW CACHING: ListView has internal item cache
///    - MITIGATION: Document cache size (cacheExtent)
///
/// ### Metrics That Are QUESTIONABLE for This Experiment:
/// 1. ⚠️ FPS during initial load - Both complete quickly on modern devices
/// 2. ⚠️ "Total render time" - Ambiguous definition
///
/// ### Recommendations:
/// 1. Always measure BOTH initial build AND scroll performance
/// 2. Document the trade-off clearly
/// 3. Test with varying list sizes to show scaling
/// 4. Measure memory with ImageCache cleared
