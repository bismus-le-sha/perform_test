import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Собирает статистику по производительности кадров.
/// Разделяет метрики на build time, raster time и total time для
/// корректного анализа узких мест производительности.
class FrameStatsCollector {
  FrameStatsCollector({this.summaryInterval = const Duration(seconds: 5)});

  final Duration summaryInterval;

  final List<FrameTiming> _frames = [];
  final List<int> _buildTimes = []; // в микросекундах
  final List<int> _rasterTimes = []; // в микросекундах
  final List<int> _totalTimes = []; // в микросекундах
  
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
    _frames.clear();
    _buildTimes.clear();
    _rasterTimes.clear();
    _totalTimes.clear();

    SchedulerBinding.instance.addTimingsCallback(_onFrame);

    _summaryTimer = Timer.periodic(summaryInterval, (_) {
      _maybePrintSummary();
    });

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
    _buildTimes.clear();
    _rasterTimes.clear();
    _totalTimes.clear();

    debugPrint('[FrameStatsCollector] STOP');
  }

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

  void _onFrame(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frames.add(timing);
      
      // Сохраняем детальную информацию отдельно для каждого типа метрики
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

    final buildStats = _calculateStats(_buildTimes);
    final rasterStats = _calculateStats(_rasterTimes);
    final totalStats = _calculateStats(_totalTimes);
    final jankPercent = _calcJankPercent(_frames);

    final prefix = finalReport ? '[FINAL]' : '[SUMMARY]';

    debugPrint('''
$prefix FrameStats (N=${_frames.length}):
  FPS (avg): ${_fps(totalStats.avg).toStringAsFixed(1)}
  
  Build time (widget tree construction):
    avg: ${buildStats.avg.toStringAsFixed(2)} ms
    p75: ${buildStats.p75.toStringAsFixed(2)} ms
    p95: ${buildStats.p95.toStringAsFixed(2)} ms
    p99: ${buildStats.p99.toStringAsFixed(2)} ms
  
  Raster time (GPU rendering):
    avg: ${rasterStats.avg.toStringAsFixed(2)} ms
    p75: ${rasterStats.p75.toStringAsFixed(2)} ms
    p95: ${rasterStats.p95.toStringAsFixed(2)} ms
    p99: ${rasterStats.p99.toStringAsFixed(2)} ms
  
  Total time (build + layout + paint + raster):
    avg: ${totalStats.avg.toStringAsFixed(2)} ms
    p75: ${totalStats.p75.toStringAsFixed(2)} ms
    p95: ${totalStats.p95.toStringAsFixed(2)} ms
    p99: ${totalStats.p99.toStringAsFixed(2)} ms
  
  Jank (>16.67ms): ${jankPercent.toStringAsFixed(2)}%
''');
  }

  _FrameStats _calculateStats(List<int> values) {
    if (values.isEmpty) return _FrameStats(0, 0, 0, 0);
    
    final sorted = [...values]..sort();
    final length = sorted.length;
    
    final avg = sorted.reduce((a, b) => a + b) / length / 1000.0; // конвертируем в ms
    final p75 = sorted[(length * 0.75).floor()] / 1000.0;
    final p95 = sorted[(length * 0.95).floor()] / 1000.0;
    final p99 = sorted[(length * 0.99).floor()] / 1000.0;
    
    return _FrameStats(avg, p75, p95, p99);
  }

  double _fps(double avgFrameMs) {
    if (avgFrameMs <= 0) return 0;
    return 1000.0 / avgFrameMs;
  }

  /// Вычисляет процент кадров с jank (превышающих 16.67ms для 60 FPS).
  /// Использует правильный порог 16.67ms вместо 16ms.
  double _calcJankPercent(List<FrameTiming> timings) {
    if (timings.isEmpty) return 0;
    
    int jank = 0;
    // Правильный порог для 60 FPS: 1000ms / 60 = 16.67ms
    const jankThresholdMs = 16.67;
    
    for (final t in timings) {
      if (t.totalSpan.inMilliseconds > jankThresholdMs) {
        jank++;
      }
    }
    
    return (jank / timings.length) * 100;
  }
}

/// Внутренний класс для хранения статистики по кадрам.
class _FrameStats {
  final double avg;
  final double p75;
  final double p95;
  final double p99;
  
  _FrameStats(this.avg, this.p75, this.p95, this.p99);
}
