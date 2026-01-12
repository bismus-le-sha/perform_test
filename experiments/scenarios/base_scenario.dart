/// Base class for all performance experiment scenarios.
///
/// Each scenario represents a controlled experiment with:
/// - Clear hypothesis
/// - Defined independent/dependent variables
/// - Measurable outcomes
/// - Degradation criteria
library;

import 'dart:convert';

/// Represents a single experiment scenario configuration.
abstract class ExperimentScenario {
  /// Unique identifier for the scenario (e.g., 'SCN-FIB')
  String get id;

  /// Human-readable name
  String get name;

  /// Research hypothesis being tested
  String get hypothesis;

  /// What is the independent variable (what we manipulate)
  String get independentVariable;

  /// What are the dependent variables (what we measure)
  List<MetricDefinition> get dependentVariables;

  /// Control variables (what we keep constant)
  List<String> get controlVariables;

  /// Feature toggle that controls this experiment
  String get toggleName;

  /// Number of warm-up iterations (excluded from analysis)
  int get warmUpIterations => 3;

  /// Number of measurement iterations
  int get measurementIterations => 10;

  /// Minimum expected effect size to consider optimization valid
  double get minEffectSize;

  /// Criteria for determining if results show degradation
  DegradationCriteria get degradationCriteria;

  /// Environmental requirements for valid measurement
  List<EnvironmentRequirement> get requirements => [
    EnvironmentRequirement.profileMode,
    EnvironmentRequirement.stableDevice,
    EnvironmentRequirement.usbConnection,
  ];

  /// Generate scenario metadata as JSON for results file
  Map<String, dynamic> toMetadata() => {
    'scenarioId': id,
    'name': name,
    'hypothesis': hypothesis,
    'independentVariable': independentVariable,
    'dependentVariables': dependentVariables.map((m) => m.toJson()).toList(),
    'controlVariables': controlVariables,
    'toggleName': toggleName,
    'warmUpIterations': warmUpIterations,
    'measurementIterations': measurementIterations,
    'minEffectSize': minEffectSize,
    'degradationCriteria': degradationCriteria.toJson(),
  };

  /// Validate that experiment configuration is sound
  List<String> validate() {
    final errors = <String>[];

    if (measurementIterations < 5) {
      errors.add('Insufficient iterations for statistical significance');
    }

    if (dependentVariables.isEmpty) {
      errors.add('No dependent variables defined');
    }

    if (minEffectSize <= 0) {
      errors.add('Effect size must be positive');
    }

    return errors;
  }
}

/// Definition of a measurable metric.
class MetricDefinition {
  final String name;
  final String description;
  final MetricSource source;
  final MetricUnit unit;
  final AggregationType aggregation;
  final double? precision; // measurement precision/uncertainty

  const MetricDefinition({
    required this.name,
    required this.description,
    required this.source,
    required this.unit,
    this.aggregation = AggregationType.median,
    this.precision,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'source': source.name,
    'unit': unit.name,
    'aggregation': aggregation.name,
    if (precision != null) 'precision': precision,
  };
}

/// Source of metric data collection.
enum MetricSource {
  /// Flutter SchedulerBinding.addTimingsCallback
  frameTimings,

  /// dart:developer Timeline API
  timeline,

  /// VM Service Protocol (memory, CPU)
  vmService,

  /// adb shell dumpsys gfxinfo
  adbGfxinfo,

  /// adb shell dumpsys meminfo
  adbMeminfo,

  /// Custom Dart logger/stopwatch
  dartLogger,

  /// DevTools export (manual)
  devToolsExport,
}

/// Unit of measurement for metrics.
enum MetricUnit {
  microseconds,
  milliseconds,
  seconds,
  bytes,
  kilobytes,
  megabytes,
  frames,
  percent,
  count,
  fps,
}

/// How to aggregate multiple measurements.
enum AggregationType {
  median, // Preferred for skewed distributions
  mean,
  p50,
  p75,
  p95,
  p99,
  max,
  min,
  sum,
}

/// Criteria for detecting performance degradation.
class DegradationCriteria {
  final String metricName;
  final double threshold;
  final DegradationDirection direction;
  final String description;

  const DegradationCriteria({
    required this.metricName,
    required this.threshold,
    required this.direction,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'metricName': metricName,
    'threshold': threshold,
    'direction': direction.name,
    'description': description,
  };
}

enum DegradationDirection {
  /// Higher values are worse (e.g., latency, jank)
  higherIsBad,

  /// Lower values are worse (e.g., FPS, throughput)
  lowerIsBad,
}

/// Environmental requirements for valid experiment execution.
enum EnvironmentRequirement {
  /// App must run in Flutter profile mode
  profileMode,

  /// Device should be thermally stable (no throttling)
  stableDevice,

  /// USB connection required for reliable ADB
  usbConnection,

  /// Airplane mode to eliminate network variance
  airplaneMode,

  /// Developer options enabled
  developerOptions,

  /// USB debugging enabled
  usbDebugging,
}

/// Result of a single experiment run.
class ExperimentResult {
  final String scenarioId;
  final DateTime timestamp;
  final String deviceId;
  final String flutterVersion;
  final String? commitHash;
  final Map<String, dynamic> environment;
  final bool baselineCondition; // false = baseline, true = optimized
  final Map<String, List<double>> rawMeasurements;
  final Map<String, AggregatedMetric> aggregatedMetrics;

  ExperimentResult({
    required this.scenarioId,
    required this.timestamp,
    required this.deviceId,
    required this.flutterVersion,
    this.commitHash,
    required this.environment,
    required this.baselineCondition,
    required this.rawMeasurements,
    required this.aggregatedMetrics,
  });

  Map<String, dynamic> toJson() => {
    'scenarioId': scenarioId,
    'timestamp': timestamp.toIso8601String(),
    'deviceId': deviceId,
    'flutterVersion': flutterVersion,
    if (commitHash != null) 'commitHash': commitHash,
    'environment': environment,
    'condition': baselineCondition ? 'optimized' : 'baseline',
    'rawMeasurements': rawMeasurements,
    'aggregatedMetrics': aggregatedMetrics.map(
      (k, v) => MapEntry(k, v.toJson()),
    ),
  };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Aggregated metric with statistical measures.
class AggregatedMetric {
  final String name;
  final int sampleCount;
  final double min;
  final double max;
  final double mean;
  final double median;
  final double p75;
  final double p95;
  final double p99;
  final double stdDev;

  const AggregatedMetric({
    required this.name,
    required this.sampleCount,
    required this.min,
    required this.max,
    required this.mean,
    required this.median,
    required this.p75,
    required this.p95,
    required this.p99,
    required this.stdDev,
  });

  factory AggregatedMetric.fromSamples(String name, List<double> samples) {
    if (samples.isEmpty) {
      return AggregatedMetric(
        name: name,
        sampleCount: 0,
        min: 0,
        max: 0,
        mean: 0,
        median: 0,
        p75: 0,
        p95: 0,
        p99: 0,
        stdDev: 0,
      );
    }

    final sorted = [...samples]..sort();
    final n = sorted.length;
    final sum = sorted.reduce((a, b) => a + b);
    final mean = sum / n;

    // Standard deviation
    final squaredDiffs = sorted.map((x) => (x - mean) * (x - mean));
    final variance = squaredDiffs.reduce((a, b) => a + b) / n;
    final stdDev = variance > 0 ? _sqrt(variance) : 0.0;

    return AggregatedMetric(
      name: name,
      sampleCount: n,
      min: sorted.first,
      max: sorted.last,
      mean: mean,
      median: n.isOdd
          ? sorted[n ~/ 2]
          : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2,
      p75: sorted[((n - 1) * 0.75).round()],
      p95: sorted[((n - 1) * 0.95).round()],
      p99: sorted[((n - 1) * 0.99).round()],
      stdDev: stdDev,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'sampleCount': sampleCount,
    'min': min,
    'max': max,
    'mean': mean,
    'median': median,
    'p75': p75,
    'p95': p95,
    'p99': p99,
    'stdDev': stdDev,
  };

  static double _sqrt(double value) {
    if (value <= 0) return 0;
    double guess = value / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + value / guess) / 2;
    }
    return guess;
  }
}

/// Comparison between baseline and optimized results.
class ExperimentComparison {
  final ExperimentResult baseline;
  final ExperimentResult optimized;
  final Map<String, MetricComparison> comparisons;
  final bool isSignificant;
  final String conclusion;

  ExperimentComparison({
    required this.baseline,
    required this.optimized,
    required this.comparisons,
    required this.isSignificant,
    required this.conclusion,
  });

  Map<String, dynamic> toJson() => {
    'baseline': baseline.toJson(),
    'optimized': optimized.toJson(),
    'comparisons': comparisons.map((k, v) => MapEntry(k, v.toJson())),
    'isSignificant': isSignificant,
    'conclusion': conclusion,
  };
}

/// Comparison of a single metric between conditions.
class MetricComparison {
  final String metricName;
  final double baselineValue;
  final double optimizedValue;
  final double absoluteDifference;
  final double percentChange;
  final bool isImprovement;

  MetricComparison({
    required this.metricName,
    required this.baselineValue,
    required this.optimizedValue,
  }) : absoluteDifference = optimizedValue - baselineValue,
       percentChange = baselineValue != 0
           ? ((optimizedValue - baselineValue) / baselineValue) * 100
           : 0,
       isImprovement =
           optimizedValue < baselineValue; // Assumes lower is better

  Map<String, dynamic> toJson() => {
    'metricName': metricName,
    'baselineValue': baselineValue,
    'optimizedValue': optimizedValue,
    'absoluteDifference': absoluteDifference,
    'percentChange': percentChange,
    'isImprovement': isImprovement,
  };
}
