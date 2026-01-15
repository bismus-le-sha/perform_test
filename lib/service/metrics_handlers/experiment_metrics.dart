import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:logging/logging.dart';
import '../logger/logger.dart';

/// Unified measurement infrastructure for all performance experiments.
///
/// This class provides consistent measurement methods across all experimental
/// scenarios to ensure comparable results and eliminate instrumentation bias.
///
/// Key design principles:
/// - Same instrumentation overhead for sync/async paths
/// - Warm-up support to exclude JIT compilation effects
/// - Statistical rigor with percentiles
/// - Timeline integration for DevTools visualization
class ExperimentMetrics {
  final Logger _logger;
  final String experimentName;

  /// Number of warm-up iterations to skip before recording metrics
  final int warmUpIterations;

  /// Current iteration count
  int _iterationCount = 0;

  /// Recorded measurements (after warm-up)
  final List<int> _measurements = []; // microseconds

  /// Whether we're past the warm-up phase
  bool get isWarmedUp => _iterationCount >= warmUpIterations;

  ExperimentMetrics({
    required this.experimentName,
    this.warmUpIterations = 3,
    Logger? logger,
  }) : _logger = logger ?? getLogger('ExperimentMetrics');

  /// Resets all measurements and iteration count
  void reset() {
    _iterationCount = 0;
    _measurements.clear();
    _logger.info('[$experimentName] Metrics reset');
  }

  /// Measures synchronous execution time with UI blocking detection.
  ///
  /// Use this for operations that block the UI thread (e.g., sync JSON parsing,
  /// sync Fibonacci calculation).
  ///
  /// Returns: (result, measurement in microseconds)
  Future<(T, int)> measureSyncOperation<T>(
    T Function() task, {
    String? label,
  }) async {
    _iterationCount++;
    final measurementLabel = label ?? '${experimentName}_SYNC';

    // Wait for frame to ensure clean measurement start
    await SchedulerBinding.instance.endOfFrame;

    developer.Timeline.startSync(
      measurementLabel,
      arguments: {'iteration': _iterationCount, 'isWarmUp': !isWarmedUp},
    );

    final sw = Stopwatch()..start();
    T result;
    try {
      result = task();
    } finally {
      sw.stop();
      developer.Timeline.finishSync();
    }

    // Wait for frame to measure actual UI impact
    await SchedulerBinding.instance.endOfFrame;

    final microseconds = sw.elapsedMicroseconds;

    if (isWarmedUp) {
      _measurements.add(microseconds);
      _logger.info(
        '[$experimentName] Sync measurement #${_iterationCount - warmUpIterations}: '
        '$microsecondsμs (${(microseconds / 1000).toStringAsFixed(2)}ms)',
      );
    } else {
      _logger.fine(
        '[$experimentName] Warm-up iteration $_iterationCount: '
        '$microsecondsμs (${(microseconds / 1000).toStringAsFixed(2)}ms)',
      );
    }

    return (result, microseconds);
  }

  /// Measures asynchronous execution time (e.g., compute() isolate work).
  ///
  /// Use this for operations that run in background isolates. The measurement
  /// includes isolate spawn overhead for first calls.
  ///
  /// Returns: (result, measurement in microseconds)
  Future<(T, int)> measureAsyncOperation<T>(
    Future<T> Function() task, {
    String? label,
  }) async {
    _iterationCount++;
    final measurementLabel = label ?? '${experimentName}_ASYNC';

    // Wait for frame to ensure clean measurement start
    await SchedulerBinding.instance.endOfFrame;

    developer.Timeline.startSync(
      measurementLabel,
      arguments: {'iteration': _iterationCount, 'isWarmUp': !isWarmedUp},
    );

    final sw = Stopwatch()..start();
    T result;
    try {
      result = await task();
    } finally {
      sw.stop();
      developer.Timeline.finishSync();
    }

    // Wait for frame to ensure consistent measurement end point
    await SchedulerBinding.instance.endOfFrame;

    final microseconds = sw.elapsedMicroseconds;

    if (isWarmedUp) {
      _measurements.add(microseconds);
      _logger.info(
        '[$experimentName] Async measurement #${_iterationCount - warmUpIterations}: '
        '$microsecondsμs (${(microseconds / 1000).toStringAsFixed(2)}ms)',
      );
    } else {
      _logger.fine(
        '[$experimentName] Warm-up iteration $_iterationCount: '
        '$microsecondsμs (${(microseconds / 1000).toStringAsFixed(2)}ms)',
      );
    }

    return (result, microseconds);
  }

  /// Measures only the specified phase without frame synchronization.
  ///
  /// Use this for isolating specific phases (e.g., file I/O vs parsing).
  (T, int) measurePhase<T>(T Function() task, String phaseName) {
    developer.Timeline.startSync('${experimentName}_$phaseName');
    final sw = Stopwatch()..start();
    T result;
    try {
      result = task();
    } finally {
      sw.stop();
      developer.Timeline.finishSync();
    }
    final microseconds = sw.elapsedMicroseconds;
    _logger.fine(
      '[$experimentName] Phase "$phaseName": '
      '$microsecondsμs (${(microseconds / 1000).toStringAsFixed(2)}ms)',
    );
    return (result, microseconds);
  }

  /// Measures only the specified async phase without frame synchronization.
  Future<(T, int)> measureAsyncPhase<T>(
    Future<T> Function() task,
    String phaseName,
  ) async {
    developer.Timeline.startSync('${experimentName}_$phaseName');
    final sw = Stopwatch()..start();
    T result;
    try {
      result = await task();
    } finally {
      sw.stop();
      developer.Timeline.finishSync();
    }
    final microseconds = sw.elapsedMicroseconds;
    _logger.fine(
      '[$experimentName] Phase "$phaseName": '
      '$microsecondsμs (${(microseconds / 1000).toStringAsFixed(2)}ms)',
    );
    return (result, microseconds);
  }

  /// Returns statistical summary of recorded measurements
  ExperimentStats getStats() {
    if (_measurements.isEmpty) {
      return ExperimentStats.empty(experimentName);
    }

    final sorted = [..._measurements]..sort();
    final n = sorted.length;

    return ExperimentStats(
      experimentName: experimentName,
      count: n,
      warmUpSkipped: warmUpIterations,
      minUs: sorted.first,
      maxUs: sorted.last,
      meanUs: sorted.reduce((a, b) => a + b) / n,
      medianUs: n.isOdd
          ? sorted[n ~/ 2].toDouble()
          : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2,
      p75Us: sorted[(n * 0.75).floor()].toDouble(),
      p95Us: sorted[(n * 0.95).floor()].toDouble(),
      p99Us: sorted[(n * 0.99).floor()].toDouble(),
    );
  }

  /// Prints a summary of all measurements
  void printSummary() {
    final stats = getStats();
    debugPrint(stats.toString());
  }
}

/// Statistical summary of experiment measurements
class ExperimentStats {
  final String experimentName;
  final int count;
  final int warmUpSkipped;
  final int minUs;
  final int maxUs;
  final double meanUs;
  final double medianUs;
  final double p75Us;
  final double p95Us;
  final double p99Us;

  const ExperimentStats({
    required this.experimentName,
    required this.count,
    required this.warmUpSkipped,
    required this.minUs,
    required this.maxUs,
    required this.meanUs,
    required this.medianUs,
    required this.p75Us,
    required this.p95Us,
    required this.p99Us,
  });

  factory ExperimentStats.empty(String name) => ExperimentStats(
    experimentName: name,
    count: 0,
    warmUpSkipped: 0,
    minUs: 0,
    maxUs: 0,
    meanUs: 0,
    medianUs: 0,
    p75Us: 0,
    p95Us: 0,
    p99Us: 0,
  );

  double get minMs => minUs / 1000;
  double get maxMs => maxUs / 1000;
  double get meanMs => meanUs / 1000;
  double get medianMs => medianUs / 1000;
  double get p75Ms => p75Us / 1000;
  double get p95Ms => p95Us / 1000;
  double get p99Ms => p99Us / 1000;

  @override
  String toString() {
    if (count == 0) {
      return '[$experimentName] No measurements recorded (warm-up: $warmUpSkipped)';
    }
    return '''
=== EXPERIMENT: $experimentName ===
Samples: $count (warm-up skipped: $warmUpSkipped)
  min:    ${minMs.toStringAsFixed(2)} ms
  max:    ${maxMs.toStringAsFixed(2)} ms
  mean:   ${meanMs.toStringAsFixed(2)} ms
  median: ${medianMs.toStringAsFixed(2)} ms (p50)
  p75:    ${p75Ms.toStringAsFixed(2)} ms
  p95:    ${p95Ms.toStringAsFixed(2)} ms
  p99:    ${p99Ms.toStringAsFixed(2)} ms
=====================================''';
  }

  Map<String, dynamic> toJson() => {
    'experiment': experimentName,
    'count': count,
    'warmUpSkipped': warmUpSkipped,
    'minMs': minMs,
    'maxMs': maxMs,
    'meanMs': meanMs,
    'medianMs': medianMs,
    'p75Ms': p75Ms,
    'p95Ms': p95Ms,
    'p99Ms': p99Ms,
  };
}
