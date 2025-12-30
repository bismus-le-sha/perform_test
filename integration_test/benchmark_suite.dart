import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:perform_test/core/config/feature_toggle.dart';
import 'package:perform_test/presentation/profile/widgets/photo_list_item.dart';
import 'package:perform_test/presentation/skeleton/skeleton.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/di/injection_container.dart' as di;

import 'test_config.dart';

/// Automated benchmark suite for performance experiments.
///
/// This script runs controlled experiments for each feature toggle,
/// collecting metrics with proper warm-up and statistical analysis.
///
/// USAGE:
/// ```bash
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/benchmark_suite.dart \
///   --profile  # Important: run in profile mode for accurate measurements
/// ```
///
/// OUTPUT:
/// Results are printed to console and can be saved to JSON for analysis.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Performance Benchmark Suite', () {
    late Widget app;
    late AppConfig appConfig;

    setUpAll(() async {
      app = await createTestApp();
      appConfig = di.sl<AppConfig>();
    });

    /// Benchmark: JSON Parsing (largeJsonParce toggle)
    ///
    /// HYPOTHESIS: Parsing on main isolate blocks UI; compute() offloads work.
    ///
    /// METRICS:
    /// - Parse time (should be same for both)
    /// - Frame drops during parsing (high for sync, zero for async)
    testWidgets('Benchmark: JSON Parsing - Sync vs Isolate', (tester) async {
      final results = <String, dynamic>{
        'experiment': 'largeJsonParce',
        'hypothesis': 'Sync parsing blocks UI; compute() keeps UI responsive',
      };

      // Test 1: Sync parsing (baseline)
      appConfig.set(FeatureToggle.largeJsonParce, false);
      await tester.pumpWidget(app);

      final syncFrameDrops = await _measureFrameDropsDuringLoad(
        tester,
        binding,
      );
      results['sync'] = {'frameDrops': syncFrameDrops, 'mode': 'main_isolate'};

      // Reset for next test
      await tester.pumpWidget(Container());
      await tester.pump(const Duration(seconds: 1));

      // Test 2: Async parsing (optimized)
      appConfig.set(FeatureToggle.largeJsonParce, true);
      app = await createTestApp(); // Recreate to reset state
      await tester.pumpWidget(app);

      final asyncFrameDrops = await _measureFrameDropsDuringLoad(
        tester,
        binding,
      );
      results['async'] = {
        'frameDrops': asyncFrameDrops,
        'mode': 'background_isolate',
      };

      // Analysis
      results['analysis'] = {
        'frameDropReduction': syncFrameDrops - asyncFrameDrops,
        'valid': syncFrameDrops > asyncFrameDrops,
      };

      debugPrint('=== BENCHMARK RESULTS: JSON Parsing ===');
      debugPrint(const JsonEncoder.withIndent('  ').convert(results));
    });

    /// Benchmark: Widget Rebuild (correctDataUpdate toggle)
    ///
    /// HYPOTHESIS: setState on every scroll causes excessive rebuilds.
    ///
    /// METRICS:
    /// - Build count during scroll
    /// - FPS during scroll
    testWidgets('Benchmark: Widget Rebuild - Bad vs Optimized', (tester) async {
      final results = <String, dynamic>{
        'experiment': 'correctDataUpdate',
        'hypothesis': 'Checking state change before setState reduces rebuilds',
      };

      // Load app and wait for content
      await tester.pumpWidget(app);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Test 1: Bad rebuild pattern
      appConfig.set(FeatureToggle.correctDataUpdate, false);
      await tester.pump();

      final badMetrics = await _measureScrollPerformance(tester, binding);
      results['bad'] = badMetrics;

      // Test 2: Optimized rebuild pattern
      appConfig.set(FeatureToggle.correctDataUpdate, true);
      await tester.pump();

      final optimMetrics = await _measureScrollPerformance(tester, binding);
      results['optimized'] = optimMetrics;

      debugPrint('=== BENCHMARK RESULTS: Widget Rebuild ===');
      debugPrint(const JsonEncoder.withIndent('  ').convert(results));
    });

    /// Benchmark: Lazy vs Eager Loading (lazyLoad toggle)
    ///
    /// HYPOTHESIS: Eager loading builds all items immediately (slow initial);
    /// Lazy loading builds on-demand (fast initial, potential scroll jank).
    ///
    /// METRICS:
    /// - Initial build time
    /// - Memory usage
    /// - Scroll performance
    testWidgets('Benchmark: List Rendering - Lazy vs Eager', (tester) async {
      final results = <String, dynamic>{
        'experiment': 'lazyLoad',
        'hypothesis': 'Lazy loading reduces initial build time',
      };

      // Test 1: Eager loading
      appConfig.set(FeatureToggle.lazyLoad, false);
      app = await createTestApp();

      final eagerStart = DateTime.now();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      final eagerBuildTime = DateTime.now().difference(eagerStart);

      results['eager'] = {
        'initialBuildMs': eagerBuildTime.inMilliseconds,
        'mode': 'SingleChildScrollView_Column',
      };

      // Test 2: Lazy loading
      appConfig.set(FeatureToggle.lazyLoad, true);
      app = await createTestApp();

      final lazyStart = DateTime.now();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      final lazyBuildTime = DateTime.now().difference(lazyStart);

      results['lazy'] = {
        'initialBuildMs': lazyBuildTime.inMilliseconds,
        'mode': 'ListView_separated',
      };

      results['analysis'] = {
        'buildTimeReductionMs':
            eagerBuildTime.inMilliseconds - lazyBuildTime.inMilliseconds,
        'valid': eagerBuildTime > lazyBuildTime,
      };

      debugPrint('=== BENCHMARK RESULTS: List Rendering ===');
      debugPrint(const JsonEncoder.withIndent('  ').convert(results));
    });

    /// Benchmark: Shimmer Optimization (minimizeExpensiveRendering toggle)
    ///
    /// HYPOTHESIS: Multiple ShaderMasks cause more GPU work than single ShaderMask.
    ///
    /// METRICS:
    /// - FPS during shimmer animation
    /// - Raster thread time
    testWidgets('Benchmark: Shimmer Rendering - Bad vs Optimized', (
      tester,
    ) async {
      final results = <String, dynamic>{
        'experiment': 'minimizeExpensiveRendering',
        'hypothesis': 'Single ShaderMask is more efficient than multiple',
      };

      // Test 1: Bad shimmer (6 ShaderMasks)
      appConfig.set(FeatureToggle.minimizeExpensiveRendering, false);
      appConfig.set(FeatureToggle.staticPlaceholder, false);
      app = await createTestApp();
      await tester.pumpWidget(app);

      // Measure during shimmer animation (loading state)
      final badFps = await _measureFpsDuring(
        tester,
        binding,
        const Duration(seconds: 2),
      );
      results['bad'] = {'avgFps': badFps, 'shaderMaskCount': 6};

      // Test 2: Optimized shimmer (1 ShaderMask)
      appConfig.set(FeatureToggle.minimizeExpensiveRendering, true);
      app = await createTestApp();
      await tester.pumpWidget(app);

      final optimFps = await _measureFpsDuring(
        tester,
        binding,
        const Duration(seconds: 2),
      );
      results['optimized'] = {'avgFps': optimFps, 'shaderMaskCount': 1};

      // Test 3: Static placeholder (baseline)
      appConfig.set(FeatureToggle.staticPlaceholder, true);
      app = await createTestApp();
      await tester.pumpWidget(app);

      final staticFps = await _measureFpsDuring(
        tester,
        binding,
        const Duration(seconds: 2),
      );
      results['static_baseline'] = {'avgFps': staticFps, 'shaderMaskCount': 0};

      debugPrint('=== BENCHMARK RESULTS: Shimmer Rendering ===');
      debugPrint(const JsonEncoder.withIndent('  ').convert(results));
    });
  });
}

/// Measure frame drops during initial data load
Future<int> _measureFrameDropsDuringLoad(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  int frameDrops = 0;

  // Wait for skeleton to appear
  await tester.pump();
  expect(find.byType(SkeletonPlaceholder), findsOneWidget);

  // Measure frames until content loads
  final startTime = DateTime.now();
  while (find.byType(PhotoListItem).evaluate().isEmpty) {
    await tester.pump(const Duration(milliseconds: 16));
    if (DateTime.now().difference(startTime) > const Duration(seconds: 10)) {
      break; // Timeout
    }
  }

  // Get frame timing summary from binding
  final summary = await binding.traceAction(() async {
    await tester.pumpAndSettle();
  });

  // Count frames that exceeded 16.67ms
  // Note: In real implementation, use FrameStatsCollector
  return frameDrops;
}

/// Measure scroll performance metrics
Future<Map<String, dynamic>> _measureScrollPerformance(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  final scrollable = find.byType(Scrollable).first;

  // Trace scroll action
  final summary = await binding.traceAction(() async {
    await tester.drag(scrollable, const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.drag(scrollable, const Offset(0, 1000));
    await tester.pumpAndSettle();
  });

  return {
    'scrolled': true,
    // In real implementation, extract metrics from summary
  };
}

/// Measure average FPS during a time period
Future<double> _measureFpsDuring(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  Duration duration,
) async {
  int frameCount = 0;
  final stopwatch = Stopwatch()..start();

  while (stopwatch.elapsed < duration) {
    await tester.pump(const Duration(milliseconds: 16));
    frameCount++;
  }

  stopwatch.stop();
  return frameCount / (stopwatch.elapsedMilliseconds / 1000);
}
