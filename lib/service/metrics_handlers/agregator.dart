// import 'package:flutter/material.dart';

// class ImageMetricsAggregator {
//   final int targetCount;
//   int _received = 0;

//   final List<int> visibleAfter = [];
//   final List<int> uiPipelineLatency = [];
//   final List<int> sizes = [];

//   VoidCallback? onDone;

//   ImageMetricsAggregator({required this.targetCount});

//   void add({
//     required int visibleAfterMs,
//     required int uiPipelineLatencyMs,
//     required int sizeBytes,
//   }) {
//     visibleAfter.add(visibleAfterMs);
//     uiPipelineLatency.add(uiPipelineLatencyMs);
//     sizes.add(sizeBytes);

//     _received++;

//     if (_received >= targetCount) {
//       _printSummary();
//       onDone?.call();
//     }
//   }

//   // --- utils ---------------------------------------------------------

//   double _median(List<int> values) {
//     if (values.isEmpty) return 0;
//     final sorted = [...values]..sort();
//     final mid = sorted.length ~/ 2;
//     if (sorted.length.isOdd) return sorted[mid].toDouble();
//     return (sorted[mid - 1] + sorted[mid]) / 2;
//   }

//   void _printSummary() {
//     debugPrint('''
// === METRICS SUMMARY (N=$targetCount) ===
// VisibleAfter median: ${_median(visibleAfter)} ms
// UiPipelineLatency median:   ${_median(uiPipelineLatency)} ms
// ImageSize median:    ${_median(sizes)} bytes
// ========================================
// ''');
//   }
// }
