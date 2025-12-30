import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Collects frame timing statistics for performance analysis.
///
/// Separates metrics into build time, raster time, and total time for
/// identifying performance bottlenecks.
///
/// METRICS PROVIDED:
/// - FPS (average and effective)
/// - Build time percentiles (p50, p75, p95, p99)
/// - Raster time percentiles (p50, p75, p95, p99)
/// - Total frame time percentiles (p50, p75, p95, p99)
/// - Jank percentage (frames > 16.67ms)
///
/// WARM-UP SUPPORT:
/// Set warmUpFrames > 0 to exclude initial frames from statistics,
/// eliminating JIT compilation noise from measurements.
class FrameStatsCollector {
  FrameStatsCollector({
    this.summaryInterval = const Duration(seconds: 5),
    this.warmUpFrames = 30, // Skip first ~0.5 seconds of frames
  });

  final Duration summaryInterval;
  final int warmUpFrames;

  final List<FrameTiming> _frames = [];
  final List<int> _buildTimes = []; // microseconds
  final List<int> _rasterTimes = []; // microseconds
  final List<int> _totalTimes = []; // microseconds

  int _skippedFrames = 0;
  bool _isRunning = false;
  Timer? _summaryTimer;

  /// Frame count at last summary
  int _lastFrameCount = 0;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _lastFrameCount = 0;
    _skippedFrames = 0;
    _frames.clear();
    _buildTimes.clear();
    _rasterTimes.clear();
    _totalTimes.clear();

    SchedulerBinding.instance.addTimingsCallback(_onFrame);

    _summaryTimer = Timer.periodic(summaryInterval, (_) {
      _maybePrintSummary();
    });

    debugPrint('[FrameStatsCollector] START (warm-up: $warmUpFrames frames)');
  }

  void stop() {
    if (!_isRunning) return;
    _isRunning = false;

    SchedulerBinding.instance.removeTimingsCallback(_onFrame);

    _summaryTimer?.cancel();
    _summaryTimer = null;

    _printSummary(finalReport: true);

    _frames.clear();
    _buildTimes.clear();
    _rasterTimes.clear();
    _totalTimes.clear();

    debugPrint('[FrameStatsCollector] STOP');
  }

  /// Get current statistics without printing
  FrameStatsSummary getStats() {
    return FrameStatsSummary(
      frameCount: _frames.length,
      skippedFrames: _skippedFrames,
      buildStats: _calculateStats(_buildTimes),
      rasterStats: _calculateStats(_rasterTimes),
      totalStats: _calculateStats(_totalTimes),
      jankPercent: _calcJankPercent(_frames),
    );
  }

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

  void _onFrame(List<FrameTiming> timings) {
    for (final timing in timings) {
      // Skip warm-up frames
      if (_skippedFrames < warmUpFrames) {
        _skippedFrames++;
        continue;
      }

      _frames.add(timing);
      _buildTimes.add(timing.buildDuration.inMicroseconds);
      _rasterTimes.add(timing.rasterDuration.inMicroseconds);
      _totalTimes.add(timing.totalSpan.inMicroseconds);
    }
  }

  // ---------------------------------------------------------------------------
  // Summary control
  // ---------------------------------------------------------------------------

  void _maybePrintSummary() {
    if (_frames.isEmpty) return;
    if (_frames.length == _lastFrameCount) return;

    _lastFrameCount = _frames.length;
    _printSummary();
  }

  // ---------------------------------------------------------------------------
  // Stats
  // ---------------------------------------------------------------------------

  void _printSummary({bool finalReport = false}) {
    if (_frames.isEmpty) {
      debugPrint(
        '[FrameStatsCollector] No frames yet (skipped: $_skippedFrames warm-up)',
      );
      return;
    }

    final buildStats = _calculateStats(_buildTimes);
    final rasterStats = _calculateStats(_rasterTimes);
    final totalStats = _calculateStats(_totalTimes);
    final jankPercent = _calcJankPercent(_frames);

    final prefix = finalReport ? '[FINAL]' : '[SUMMARY]';

    debugPrint('''
$prefix FrameStats (N=${_frames.length}, warm-up skipped: $_skippedFrames):
  FPS (avg): ${_fps(totalStats.avg).toStringAsFixed(1)}
  
  Build time (widget tree construction):
    median: ${totalStats.p50.toStringAsFixed(2)} ms (p50)
    avg:    ${buildStats.avg.toStringAsFixed(2)} ms
    p75:    ${buildStats.p75.toStringAsFixed(2)} ms
    p95:    ${buildStats.p95.toStringAsFixed(2)} ms
    p99:    ${buildStats.p99.toStringAsFixed(2)} ms
  
  Raster time (GPU rendering):
    median: ${rasterStats.p50.toStringAsFixed(2)} ms (p50)
    avg:    ${rasterStats.avg.toStringAsFixed(2)} ms
    p75:    ${rasterStats.p75.toStringAsFixed(2)} ms
    p95:    ${rasterStats.p95.toStringAsFixed(2)} ms
    p99:    ${rasterStats.p99.toStringAsFixed(2)} ms
  
  Total time (build + layout + paint + raster):
    median: ${totalStats.p50.toStringAsFixed(2)} ms (p50)
    avg:    ${totalStats.avg.toStringAsFixed(2)} ms
    p75:    ${totalStats.p75.toStringAsFixed(2)} ms
    p95:    ${totalStats.p95.toStringAsFixed(2)} ms
    p99:    ${totalStats.p99.toStringAsFixed(2)} ms
  
  Jank (>16.67ms): ${jankPercent.toStringAsFixed(2)}%
''');
  }

  FrameStats _calculateStats(List<int> values) {
    if (values.isEmpty) return FrameStats.empty;

    final sorted = [...values]..sort();
    final length = sorted.length;

    final avg = sorted.reduce((a, b) => a + b) / length / 1000.0;
    final p50 = length.isOdd
        ? sorted[length ~/ 2] / 1000.0
        : (sorted[length ~/ 2 - 1] + sorted[length ~/ 2]) / 2 / 1000.0;
    final p75 = sorted[(length * 0.75).floor()] / 1000.0;
    final p95 = sorted[(length * 0.95).floor()] / 1000.0;
    final p99 = sorted[(length * 0.99).floor()] / 1000.0;

    return FrameStats(avg, p50, p75, p95, p99);
  }

  double _fps(double avgFrameMs) {
    if (avgFrameMs <= 0) return 0;
    return 1000.0 / avgFrameMs;
  }

  /// Calculate jank percentage (frames exceeding 16.67ms for 60 FPS).
  double _calcJankPercent(List<FrameTiming> timings) {
    if (timings.isEmpty) return 0;

    int jank = 0;
    const jankThresholdUs = 16670; // 16.67ms in microseconds for precision

    for (final t in timings) {
      if (t.totalSpan.inMicroseconds > jankThresholdUs) {
        jank++;
      }
    }

    return (jank / timings.length) * 100;
  }
}

/// Frame timing statistics (public for export)
class FrameStats {
  final double avg;
  final double p50; // median
  final double p75;
  final double p95;
  final double p99;

  const FrameStats(this.avg, this.p50, this.p75, this.p95, this.p99);

  static const empty = FrameStats(0, 0, 0, 0, 0);
}

/// Public summary of frame statistics for export/analysis
class FrameStatsSummary {
  final int frameCount;
  final int skippedFrames;
  final FrameStats buildStats;
  final FrameStats rasterStats;
  final FrameStats totalStats;
  final double jankPercent;

  FrameStatsSummary({
    required this.frameCount,
    required this.skippedFrames,
    required this.buildStats,
    required this.rasterStats,
    required this.totalStats,
    required this.jankPercent,
  });

  double get avgFps => totalStats.avg > 0 ? 1000.0 / totalStats.avg : 0;

  Map<String, dynamic> toJson() => {
    'frameCount': frameCount,
    'skippedWarmUpFrames': skippedFrames,
    'avgFps': avgFps,
    'jankPercent': jankPercent,
    'buildTimeMs': {
      'avg': buildStats.avg,
      'p50': buildStats.p50,
      'p75': buildStats.p75,
      'p95': buildStats.p95,
      'p99': buildStats.p99,
    },
    'rasterTimeMs': {
      'avg': rasterStats.avg,
      'p50': rasterStats.p50,
      'p75': rasterStats.p75,
      'p95': rasterStats.p95,
      'p99': rasterStats.p99,
    },
    'totalTimeMs': {
      'avg': totalStats.avg,
      'p50': totalStats.p50,
      'p75': totalStats.p75,
      'p95': totalStats.p95,
      'p99': totalStats.p99,
    },
  };
}
