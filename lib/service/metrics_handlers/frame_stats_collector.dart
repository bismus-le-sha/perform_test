import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class FrameStatsCollector {
  FrameStatsCollector({this.summaryInterval = const Duration(seconds: 5)});

  final Duration summaryInterval;

  final List<FrameTiming> _frames = [];
  bool _isRunning = false;

  Timer? _summaryTimer;

  /// Количество кадров, известное на момент последнего summary.
  int _lastFrameCount = 0;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _lastFrameCount = 0;

    SchedulerBinding.instance.addTimingsCallback(_onFrame);

    // _summaryTimer = Timer.periodic(summaryInterval, (_) {
    //   _maybePrintSummary();
    // });
    _maybePrintSummary();

    debugPrint('[FrameStatsCollector] START');
  }

  void stop() {
    if (!_isRunning) return;
    _isRunning = false;

    SchedulerBinding.instance.removeTimingsCallback(_onFrame);

    _summaryTimer?.cancel();
    _summaryTimer = null;

    // всегда финальный отчет, даже если кадров нет
    _printSummary(finalReport: true);

    _frames.clear();

    debugPrint('[FrameStatsCollector] STOP');
  }

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

  void _onFrame(List<FrameTiming> timings) {
    _frames.addAll(timings);
  }

  // ---------------------------------------------------------------------------
  // Summary control
  // ---------------------------------------------------------------------------

  void _maybePrintSummary() {
    if (_frames.isEmpty) return;

    // Проверяем, изменилось ли количество кадров
    if (_frames.length == _lastFrameCount) {
      return; // новых кадров нет → summary не выводим
    }

    _lastFrameCount = _frames.length;
    _printSummary();
  }

  // ---------------------------------------------------------------------------
  // Stats
  // ---------------------------------------------------------------------------

  void _printSummary({bool finalReport = false}) {
    if (_frames.isEmpty) {
      debugPrint('[FrameStatsCollector] No frames yet');
      return;
    }

    final durations =
        _frames
            .map((t) => t.totalSpan.inMicroseconds / 1000.0) // ms
            .toList()
          ..sort();

    final avg = durations.reduce((a, b) => a + b) / durations.length;
    final p75 = durations[(durations.length * 0.75).floor()];
    final p95 = durations[(durations.length * 0.95).floor()];
    final jankPercent = _calcJankPercent(_frames);

    final prefix = finalReport ? '[FINAL]' : '[SUMMARY]';

    debugPrint('''
$prefix FrameStats:
  Frames: ${_frames.length}
  FPS (avg): ${_fps(avg).toStringAsFixed(1)}
  Total time:
    avg: ${avg.toStringAsFixed(2)} ms
    p75: ${p75.toStringAsFixed(2)} ms
    p95: ${p95.toStringAsFixed(2)} ms
  Jank: ${jankPercent.toStringAsFixed(2)}%
''');
  }

  double _fps(double avgFrameMs) {
    if (avgFrameMs <= 0) return 0;
    return 1000.0 / avgFrameMs;
  }

  double _calcJankPercent(List<FrameTiming> timings) {
    int jank = 0;
    for (final t in timings) {
      if (t.totalSpan.inMilliseconds > 16) {
        jank++;
      }
    }
    return timings.isEmpty ? 0 : (jank / timings.length) * 100;
  }
}
