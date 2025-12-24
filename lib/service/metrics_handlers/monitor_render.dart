// import 'dart:ui';

// import 'package:flutter/material.dart';

// class MonitoredRender extends StatefulWidget {
//   final String label;
//   final Widget child;

//   const MonitoredRender({super.key, required this.label, required this.child});

//   @override
//   State<MonitoredRender> createState() => _MonitoredRenderState();
// }

// class _MonitoredRenderState extends State<MonitoredRender> {
//   late DateTime _buildStart;
//   int _frameCount = 0;

//   @override
//   void initState() {
//     super.initState();
//     _buildStart = DateTime.now();

//     WidgetsBinding.instance.addTimingsCallback(_onFrameTiming);
//   }

//   void _onFrameTiming(List<FrameTiming> timings) {
//     _frameCount += timings.length;
//     for (final timing in timings) {
//       final buildMs = timing.buildDuration.inMilliseconds;
//       final rasterMs = timing.rasterDuration.inMilliseconds;
//       debugPrint(
//         '[${widget.label}] frame build=$buildMs ms | raster=$rasterMs ms',
//       );
//     }
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeTimingsCallback(_onFrameTiming);
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final elapsed = DateTime.now().difference(_buildStart);
//       debugPrint(
//         '[${widget.label}] initial render completed in '
//         '${elapsed.inMilliseconds} ms ($_frameCount frames)',
//       );
//     });
//     return widget.child;
//   }
// }
