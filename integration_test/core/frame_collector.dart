/// ═══════════════════════════════════════════════════════════════════════════
/// FRAME TIMING COLLECTOR - Uses Flutter's official FrameTiming API
/// ═══════════════════════════════════════════════════════════════════════════
///
/// This is the CORRECT way to measure frame performance:
/// - Uses engine-level timing data
/// - Provides build, raster, and total times
/// - No manual DateTime.now() measurements (inaccurate)
/// ═══════════════════════════════════════════════════════════════════════════

import 'dart:ui';

import 'package:flutter/scheduler.dart';

/// Collects frame timings using Flutter's SchedulerBinding.addTimingsCallback
class FrameTimingCollector {
  final List<FrameTiming> _timings = [];
  TimingsCallback? _callback;
  bool _isCollecting = false;

  /// Start collecting frame timings
  void start() {
    if (_isCollecting) return;

    _timings.clear();
    _callback = (List<FrameTiming> timings) {
      _timings.addAll(timings);
    };

    SchedulerBinding.instance.addTimingsCallback(_callback!);
    _isCollecting = true;
  }

  /// Stop collecting and return all collected timings
  List<FrameTiming> stop() {
    if (!_isCollecting) return [];

    if (_callback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_callback!);
      _callback = null;
    }

    _isCollecting = false;
    return List.unmodifiable(_timings);
  }

  /// Clear collected timings without stopping
  void clear() {
    _timings.clear();
  }

  int get frameCount => _timings.length;
  bool get isCollecting => _isCollecting;
}
