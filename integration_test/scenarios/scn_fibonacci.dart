/// SCN-FIB: Fibonacci Computation Scenario
///
/// Tests the hypothesis that heavy synchronous computation on the main isolate
/// blocks the UI thread, causing dropped frames, while compute() offloading
/// maintains UI responsiveness.
library;

import 'base_scenario.dart';

class FibonacciScenario extends ExperimentScenario {
  @override
  String get id => 'SCN-FIB';

  @override
  String get name => 'Fibonacci Computation: Main Isolate vs compute()';

  @override
  String get hypothesis => '''
Heavy synchronous computation (recursive Fibonacci n=42, ~2s) on the main 
isolate blocks the UI event loop, causing:
1. Animation freeze (FPS drops to 0)
2. Input unresponsiveness
3. Dropped frames visible in timeline

Using compute() offloads work to a background isolate, allowing the UI thread
to continue processing frames at 60 FPS during computation.

NULL HYPOTHESIS (H0): There is no difference in UI responsiveness between
synchronous and compute()-based execution.

ALTERNATIVE HYPOTHESIS (H1): compute() execution maintains significantly
higher FPS during computation compared to synchronous execution.
''';

  @override
  String get independentVariable => '''
Execution context:
- BASELINE (toggle=false): Synchronous execution on main isolate
- OPTIMIZED (toggle=true): Asynchronous execution via compute() in background isolate
''';

  @override
  List<MetricDefinition> get dependentVariables => [
    // PRIMARY METRIC - UI Responsiveness
    MetricDefinition(
      name: 'fps_during_computation',
      description: 'Average FPS measured during the computation period',
      source: MetricSource.frameTimings,
      unit: MetricUnit.fps,
      aggregation: AggregationType.mean,
      precision: 1.0, // ±1 FPS
    ),

    // SECONDARY METRIC - Frame Drops
    MetricDefinition(
      name: 'dropped_frames',
      description:
          'Number of frames exceeding 16.67ms deadline during computation',
      source: MetricSource.frameTimings,
      unit: MetricUnit.count,
      aggregation: AggregationType.sum,
    ),

    // SECONDARY METRIC - UI Freeze Duration
    MetricDefinition(
      name: 'ui_freeze_duration_ms',
      description: 'Total duration where no frames were rendered (freeze)',
      source: MetricSource.dartLogger,
      unit: MetricUnit.milliseconds,
      aggregation: AggregationType.max,
      precision: 10.0, // ±10ms due to timer resolution
    ),

    // CONTROL METRIC - Computation Time (should NOT differ)
    MetricDefinition(
      name: 'computation_time_ms',
      description:
          'Time to complete Fibonacci calculation (should be equal in both conditions)',
      source: MetricSource.dartLogger,
      unit: MetricUnit.milliseconds,
      aggregation: AggregationType.median,
      precision: 50.0, // ±50ms due to isolate spawn variance
    ),

    // TERTIARY METRIC - Jank Percentage
    MetricDefinition(
      name: 'jank_percent',
      description: 'Percentage of frames exceeding 16.67ms',
      source: MetricSource.frameTimings,
      unit: MetricUnit.percent,
      aggregation: AggregationType.mean,
    ),
  ];

  @override
  List<String> get controlVariables => [
    'Fibonacci N value (n=42)',
    'Computation algorithm (naive recursive)',
    'Device thermal state (warm-up before measurement)',
    'Background processes (airplane mode, minimal apps)',
    'Screen brightness (50%)',
    'Flutter profile mode',
  ];

  @override
  String get toggleName => 'optimFibonacci';

  @override
  int get warmUpIterations => 2; // First compute() call has isolate spawn overhead

  @override
  int get measurementIterations => 10;

  @override
  double get minEffectSize => 50.0; // Expect at least 50 FPS difference

  @override
  DegradationCriteria get degradationCriteria => DegradationCriteria(
    metricName: 'fps_during_computation',
    threshold: 30.0, // If optimized path drops below 30 FPS, something is wrong
    direction: DegradationDirection.lowerIsBad,
    description: 'Optimized path should maintain >30 FPS during computation',
  );

  /// Metrics that should NOT differ between conditions (validity check)
  List<String> get invariantMetrics => ['computation_time_ms'];

  /// Expected outcomes
  Map<String, ExpectedOutcome> get expectedOutcomes => {
    'fps_during_computation': ExpectedOutcome(
      baseline: 0.0, // Main thread blocked
      optimized: 60.0, // UI thread free
      tolerance: 5.0,
    ),
    'dropped_frames': ExpectedOutcome(
      baseline: 120.0, // ~2 seconds of dropped frames
      optimized: 0.0, // No drops
      tolerance: 5.0,
    ),
    'computation_time_ms': ExpectedOutcome(
      baseline: 2000.0,
      optimized: 2100.0, // Slightly higher due to isolate overhead
      tolerance: 200.0,
    ),
  };
}

/// Expected outcome for validation.
class ExpectedOutcome {
  final double baseline;
  final double optimized;
  final double tolerance;

  const ExpectedOutcome({
    required this.baseline,
    required this.optimized,
    required this.tolerance,
  });
}

// =============================================================================
// CRITICAL ANALYSIS OF THIS SCENARIO
// =============================================================================

/// ## VALIDITY ASSESSMENT
///
/// ### What This Experiment CORRECTLY Measures:
/// 1. UI thread blocking vs. non-blocking execution
/// 2. Frame drop count during CPU-intensive work
/// 3. Practical benefit of isolate offloading
///
/// ### Potential Confounds:
/// 1. ISOLATE SPAWN OVERHEAD: First compute() call includes isolate creation
///    - MITIGATION: Warm-up iterations exclude first call from measurement
///
/// 2. THERMAL THROTTLING: Long computation may heat device
///    - MITIGATION: Pause between iterations, monitor CPU temp via ADB
///
/// 3. GC INTERFERENCE: Memory allocation during computation may trigger GC
///    - MITIGATION: Use recursive Fibonacci (minimal allocation)
///
/// 4. BACKGROUND PROCESSES: System services may consume CPU
///    - MITIGATION: Airplane mode, close background apps
///
/// ### Limitations:
/// 1. Timer-based freeze detection has ~50ms resolution
/// 2. Frame timing callback may miss frames during severe blocking
/// 3. Isolate spawn time varies (50-200ms first call)
///
/// ### Recommendations for Improvement:
/// 1. Use VM Service Timeline API for precise frame-level analysis
/// 2. Measure input responsiveness (tap-to-response latency)
/// 3. Add CPU profiling to verify isolate utilization
