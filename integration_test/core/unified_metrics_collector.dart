/// Unified Metrics Collector for Performance Experiments
///
/// Provides programmatic access to performance metrics via:
/// - Flutter SchedulerBinding (frame timings)
/// - VM Service Protocol (memory, CPU, timeline)
/// - ADB commands (gfxinfo, meminfo)
/// - Custom Dart instrumentation
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/scheduler.dart';

/// Unified metrics collector that aggregates data from multiple sources.
class UnifiedMetricsCollector {
  final String experimentId;
  final bool enableVmService;
  final bool enableAdb;

  // Frame timing data
  final List<FrameTimingData> _frameTimings = [];
  bool _isCollectingFrames = false;
  int _warmUpFramesRemaining = 0;

  // Timeline events
  final List<Map<String, dynamic>> _timelineEvents = [];

  // Custom metrics (from Dart loggers)
  final Map<String, List<double>> _customMetrics = {};

  // ADB metrics cache
  Map<String, dynamic>? _adbGfxInfo;
  Map<String, dynamic>? _adbMemInfo;

  UnifiedMetricsCollector({
    required this.experimentId,
    this.enableVmService = true,
    this.enableAdb = true,
  });

  // ===========================================================================
  // FRAME TIMING COLLECTION
  // ===========================================================================

  /// Start collecting frame timings.
  ///
  /// [warmUpFrames] - Number of frames to skip before recording (JIT warm-up)
  void startFrameCollection({int warmUpFrames = 30}) {
    if (_isCollectingFrames) return;

    _frameTimings.clear();
    _warmUpFramesRemaining = warmUpFrames;
    _isCollectingFrames = true;

    SchedulerBinding.instance.addTimingsCallback(_onFrameTiming);
  }

  /// Stop collecting frame timings and return summary.
  FrameTimingSummary stopFrameCollection() {
    if (!_isCollectingFrames) {
      return FrameTimingSummary.empty();
    }

    _isCollectingFrames = false;
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTiming);

    return _computeFrameSummary();
  }

  void _onFrameTiming(List<FrameTiming> timings) {
    for (final timing in timings) {
      if (_warmUpFramesRemaining > 0) {
        _warmUpFramesRemaining--;
        continue;
      }

      _frameTimings.add(
        FrameTimingData(
          buildDurationUs: timing.buildDuration.inMicroseconds,
          rasterDurationUs: timing.rasterDuration.inMicroseconds,
          totalDurationUs: timing.totalSpan.inMicroseconds,
          vsyncOverrunUs: timing.vsyncOverhead.inMicroseconds,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  FrameTimingSummary _computeFrameSummary() {
    if (_frameTimings.isEmpty) return FrameTimingSummary.empty();

    final buildTimes = _frameTimings
        .map((f) => f.buildDurationUs / 1000)
        .toList();
    final rasterTimes = _frameTimings
        .map((f) => f.rasterDurationUs / 1000)
        .toList();
    final totalTimes = _frameTimings
        .map((f) => f.totalDurationUs / 1000)
        .toList();

    // Count janky frames (>16.67ms)
    const frameDeadlineMs = 16.67;
    final jankCount = totalTimes.where((t) => t > frameDeadlineMs).length;

    return FrameTimingSummary(
      frameCount: _frameTimings.length,
      buildStats: _computeStats(buildTimes),
      rasterStats: _computeStats(rasterTimes),
      totalStats: _computeStats(totalTimes),
      jankCount: jankCount,
      jankPercent: (jankCount / _frameTimings.length) * 100,
      avgFps: _frameTimings.isNotEmpty
          ? 1000 / _computeStats(totalTimes).mean
          : 0,
    );
  }

  // ===========================================================================
  // CUSTOM METRICS
  // ===========================================================================

  /// Record a custom metric value.
  void recordMetric(String name, double value) {
    _customMetrics.putIfAbsent(name, () => []);
    _customMetrics[name]!.add(value);
  }

  /// Get all recorded values for a metric.
  List<double> getMetricValues(String name) {
    return List.unmodifiable(_customMetrics[name] ?? []);
  }

  /// Clear custom metrics.
  void clearCustomMetrics() {
    _customMetrics.clear();
  }

  // ===========================================================================
  // TIMELINE / VM SERVICE
  // ===========================================================================

  /// Start timeline recording for specific events.
  void startTimeline({List<String> streams = const ['Dart', 'Embedder']}) {
    // Enable VM Service timeline recording
    developer.Timeline.startSync('$experimentId:START');
    developer.Timeline.finishSync();

    // Note: Full VM Service access requires service extension
    // This is a simplified approach using dart:developer
  }

  /// Mark a timeline event.
  void markTimeline(String name, {Map<String, dynamic>? arguments}) {
    developer.Timeline.startSync(name, arguments: arguments);
    developer.Timeline.finishSync();

    _timelineEvents.add({
      'name': name,
      'timestamp': DateTime.now().toIso8601String(),
      'arguments': arguments,
    });
  }

  /// Execute a function with timeline measurement.
  Future<T> measureTimeline<T>(String name, Future<T> Function() action) async {
    developer.Timeline.startSync(name);
    final stopwatch = Stopwatch()..start();

    try {
      return await action();
    } finally {
      stopwatch.stop();
      developer.Timeline.finishSync();

      _timelineEvents.add({
        'name': name,
        'durationMs': stopwatch.elapsedMicroseconds / 1000,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  // ===========================================================================
  // ADB METRICS (Android only)
  // ===========================================================================

  /// Collect graphics info via ADB.
  Future<Map<String, dynamic>> collectAdbGfxInfo() async {
    if (!enableAdb || !Platform.isAndroid) {
      return {'error': 'ADB not available'};
    }

    try {
      // This would be called from host machine, not from app
      // Placeholder for the structure
      final result = await _runAdbCommand(
        'shell dumpsys gfxinfo com.example.perform_test',
      );
      _adbGfxInfo = _parseGfxInfo(result);
      return _adbGfxInfo!;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Collect memory info via ADB.
  Future<Map<String, dynamic>> collectAdbMemInfo() async {
    if (!enableAdb || !Platform.isAndroid) {
      return {'error': 'ADB not available'};
    }

    try {
      final result = await _runAdbCommand(
        'shell dumpsys meminfo com.example.perform_test',
      );
      _adbMemInfo = _parseMemInfo(result);
      return _adbMemInfo!;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<String> _runAdbCommand(String command) async {
    // Note: ADB commands must be run from host, not device
    // This is a placeholder for the expected interface
    final result = await Process.run('adb', command.split(' '));
    if (result.exitCode != 0) {
      throw Exception('ADB command failed: ${result.stderr}');
    }
    return result.stdout as String;
  }

  Map<String, dynamic> _parseGfxInfo(String output) {
    // Parse dumpsys gfxinfo output
    final lines = output.split('\n');
    final result = <String, dynamic>{};

    for (final line in lines) {
      if (line.contains('Total frames rendered:')) {
        result['totalFrames'] = int.tryParse(line.split(':').last.trim());
      }
      if (line.contains('Janky frames:')) {
        final match = RegExp(r'(\d+) \(').firstMatch(line);
        result['jankyFrames'] = int.tryParse(match?.group(1) ?? '0');
      }
      // Add more parsing as needed
    }

    return result;
  }

  Map<String, dynamic> _parseMemInfo(String output) {
    // Parse dumpsys meminfo output
    final lines = output.split('\n');
    final result = <String, dynamic>{};

    for (final line in lines) {
      if (line.contains('TOTAL PSS:')) {
        result['totalPssKb'] = int.tryParse(
          line.replaceAll(RegExp(r'[^\d]'), ''),
        );
      }
      if (line.contains('Native Heap')) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          result['nativeHeapKb'] = int.tryParse(parts[1]);
        }
      }
    }

    return result;
  }

  // ===========================================================================
  // EXPORT
  // ===========================================================================

  /// Export all collected metrics to JSON.
  Map<String, dynamic> exportToJson() {
    final frameSummary = _computeFrameSummary();

    return {
      'experimentId': experimentId,
      'timestamp': DateTime.now().toIso8601String(),
      'frameTimings': {
        'summary': frameSummary.toJson(),
        'rawCount': _frameTimings.length,
      },
      'customMetrics': _customMetrics.map((key, values) {
        return MapEntry(key, {
          'values': values,
          'stats': _computeStats(values).toJson(),
        });
      }),
      'timelineEvents': _timelineEvents,
      'adbGfxInfo': _adbGfxInfo,
      'adbMemInfo': _adbMemInfo,
    };
  }

  /// Export to formatted JSON string.
  String exportToJsonString() {
    return const JsonEncoder.withIndent('  ').convert(exportToJson());
  }

  /// Reset all collected data.
  void reset() {
    _frameTimings.clear();
    _customMetrics.clear();
    _timelineEvents.clear();
    _adbGfxInfo = null;
    _adbMemInfo = null;
    _isCollectingFrames = false;
    _warmUpFramesRemaining = 0;
  }

  // ===========================================================================
  // STATISTICS HELPERS
  // ===========================================================================

  MetricStats _computeStats(List<double> values) {
    if (values.isEmpty) return MetricStats.empty();

    final sorted = [...values]..sort();
    final n = sorted.length;
    final sum = sorted.reduce((a, b) => a + b);
    final mean = sum / n;

    // Standard deviation
    final squaredDiffs = sorted.map((x) => (x - mean) * (x - mean));
    final variance = squaredDiffs.reduce((a, b) => a + b) / n;
    final stdDev = _sqrt(variance);

    return MetricStats(
      count: n,
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

  static double _sqrt(double value) {
    if (value <= 0) return 0;
    double guess = value / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + value / guess) / 2;
    }
    return guess;
  }
}

// ===========================================================================
// DATA CLASSES
// ===========================================================================

/// Single frame timing record.
class FrameTimingData {
  final int buildDurationUs;
  final int rasterDurationUs;
  final int totalDurationUs;
  final int vsyncOverrunUs;
  final DateTime timestamp;

  const FrameTimingData({
    required this.buildDurationUs,
    required this.rasterDurationUs,
    required this.totalDurationUs,
    required this.vsyncOverrunUs,
    required this.timestamp,
  });
}

/// Summary of frame timing collection.
class FrameTimingSummary {
  final int frameCount;
  final MetricStats buildStats;
  final MetricStats rasterStats;
  final MetricStats totalStats;
  final int jankCount;
  final double jankPercent;
  final double avgFps;

  const FrameTimingSummary({
    required this.frameCount,
    required this.buildStats,
    required this.rasterStats,
    required this.totalStats,
    required this.jankCount,
    required this.jankPercent,
    required this.avgFps,
  });

  factory FrameTimingSummary.empty() => FrameTimingSummary(
    frameCount: 0,
    buildStats: MetricStats.empty(),
    rasterStats: MetricStats.empty(),
    totalStats: MetricStats.empty(),
    jankCount: 0,
    jankPercent: 0,
    avgFps: 0,
  );

  Map<String, dynamic> toJson() => {
    'frameCount': frameCount,
    'buildStats': buildStats.toJson(),
    'rasterStats': rasterStats.toJson(),
    'totalStats': totalStats.toJson(),
    'jankCount': jankCount,
    'jankPercent': jankPercent,
    'avgFps': avgFps,
  };
}

/// Statistical summary of metric values.
class MetricStats {
  final int count;
  final double min;
  final double max;
  final double mean;
  final double median;
  final double p75;
  final double p95;
  final double p99;
  final double stdDev;

  const MetricStats({
    required this.count,
    required this.min,
    required this.max,
    required this.mean,
    required this.median,
    required this.p75,
    required this.p95,
    required this.p99,
    required this.stdDev,
  });

  factory MetricStats.empty() => const MetricStats(
    count: 0,
    min: 0,
    max: 0,
    mean: 0,
    median: 0,
    p75: 0,
    p95: 0,
    p99: 0,
    stdDev: 0,
  );

  Map<String, dynamic> toJson() => {
    'count': count,
    'min': min,
    'max': max,
    'mean': mean,
    'median': median,
    'p75': p75,
    'p95': p95,
    'p99': p99,
    'stdDev': stdDev,
  };
}
