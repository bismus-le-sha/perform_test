/// ═══════════════════════════════════════════════════════════════════════════
/// EXPERIMENT: SCN-FIB - Fibonacci Computation Performance
/// ═══════════════════════════════════════════════════════════════════════════
///
/// TOGGLE: optimFibonacci
///   - OFF: Synchronous computation on main isolate (UI FREEZES ~2s)
///   - ON:  Asynchronous computation via compute() (UI RESPONSIVE)
///
/// NAVIGATION: Tab 2 "Performance" -> BlocUITab -> KillWidget
///
/// HYPOTHESIS: Heavy computation (fib(42) ≈ 2s) on main isolate blocks UI,
///             causing FPS to drop to 0. Using compute() maintains 60 FPS.
///
/// OUTPUT: /sdcard/Download/flutter_perf_optimFibonacci_*.csv
/// RETRIEVE: adb pull /sdcard/Download/flutter_perf_optimFibonacci_*.csv ./raw_data/
///
/// RUN: flutter drive --driver=test_driver/integration_test.dart \
///        --target=integration_test/experiments/exp_fibonacci.dart \
///        --profile --no-dds
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:perform_test/core/config/feature_toggle.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/di/injection_container.dart' as di;

import '../core/csv_writer.dart';
import '../core/frame_collector.dart';
import '../core/test_constants.dart';
import '../test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'SCN-FIB';
  const toggle = 'optimFibonacci';

  late CsvDataWriter csvWriter;
  late AppConfig appConfig;
  late FrameTimingCollector frameCollector;

  group('EXP-FIB: Fibonacci Computation ($toggle)', () {
    setUpAll(() async {
      await di.init();
      appConfig = di.sl<AppConfig>();
      await appConfig.init(isIntegrationTest: true);
      csvWriter = await CsvDataWriter.create(
        toggleName: toggle,
        scenarioId: scenario,
      );
      frameCollector = FrameTimingCollector();

      debugPrint('');
      debugPrint(
        '╔═══════════════════════════════════════════════════════════╗',
      );
      debugPrint(
        '║  EXPERIMENT: FIBONACCI COMPUTATION                         ║',
      );
      debugPrint('║  Toggle: $toggle                                ║');
      debugPrint(
        '║  Scenario: $scenario                                       ║',
      );
      debugPrint(
        '╠═══════════════════════════════════════════════════════════╣',
      );
      debugPrint(
        '║  Iterations: $kWarmupIterations warmup + $kDataIterations data per state        ║',
      );
      debugPrint(
        '║  Toggle states: [false, true]                              ║',
      );
      debugPrint(
        '║  Total iterations: ${(kWarmupIterations + kDataIterations) * 2}                              ║',
      );
      debugPrint(
        '║                                                             ║',
      );
      debugPrint(
        '║  Expected behavior:                                         ║',
      );
      debugPrint(
        '║    toggle=false: UI freezes ~2s (FPS ≈ 0)                  ║',
      );
      debugPrint(
        '║    toggle=true:  UI responsive (FPS ≈ 60)                  ║',
      );
      debugPrint(
        '╚═══════════════════════════════════════════════════════════╝',
      );
      debugPrint('');
    });

    tearDownAll(() async {
      await csvWriter.close();
    });

    testWidgets('$scenario: Frame timing during heavy computation', (
      tester,
    ) async {
      for (final toggleState in [false, true]) {
        debugPrint('');
        debugPrint('[$scenario] ═══ TOGGLE STATE: $toggleState ═══');
        debugPrint(
          '[$scenario] Mode: ${toggleState ? "Isolate (non-blocking)" : "Sync (UI blocking)"}',
        );

        for (int i = 0; i < kWarmupIterations + kDataIterations; i++) {
          final isWarmup = i < kWarmupIterations;
          final label = isWarmup ? 'WARMUP' : 'DATA  ';
          final dataIndex = isWarmup ? i : i - kWarmupIterations;

          // Configure toggle BEFORE creating app
          appConfig.set(FeatureToggle.optimFibonacci, toggleState);

          debugPrint(
            '[$scenario] [$label $dataIndex] Starting (toggleState=$toggleState)',
          );

          // Create app
          final app = await createTestApp();
          await tester.pumpWidget(app);
          await tester.pumpAndSettle();

          debugPrint(
            '[$scenario] App created, navigating to Performance tab...',
          );

          // Navigate to Performance tab (index 2) using text label
          final bottomNav = find.byType(BottomNavigationBar);
          expect(
            bottomNav,
            findsOneWidget,
            reason: 'BottomNavigationBar not found',
          );

          // Use text label instead of icon for more reliable tap
          final performanceTab = find.text('Performance');
          expect(
            performanceTab,
            findsOneWidget,
            reason: 'Performance tab not found',
          );
          await tester.tap(performanceTab);
          await tester
              .pump(); // Use pump() instead of pumpAndSettle() for faster response

          debugPrint(
            '[$scenario] Tapped Performance tab, looking for KillWidget...',
          );

          // Wait a bit for navigation to complete
          await tester.pump(const Duration(milliseconds: 500));

          // Find the calculate button by text (more reliable than nested type search)
          // Button text depends on toggle state
          final buttonText = toggleState
              ? 'Calculate in Isolate'
              : 'KILL UI THREAD';
          final calcButton = find.text(buttonText);

          if (calcButton.evaluate().isEmpty) {
            debugPrint(
              '[$scenario] WARNING: Button "$buttonText" not found! Widgets on screen:',
            );
            // Try alternative button finder
            final anyButton = find.byType(ElevatedButton);
            debugPrint(
              '  Found ${anyButton.evaluate().length} ElevatedButtons',
            );

            // List text widgets for debugging
            final textWidgets = find.byType(Text);
            for (final element in textWidgets.evaluate().take(15)) {
              final text = element.widget as Text;
              debugPrint('  Text: "${text.data}"');
            }
          }

          expect(
            calcButton,
            findsOneWidget,
            reason: 'Calculate button "$buttonText" not found',
          );

          // Start frame collection BEFORE triggering computation
          frameCollector.start();
          final computeStart = DateTime.now();

          // Tap button to start Fibonacci computation
          await tester.tap(calcButton);
          await tester.pump();

          // Wait for computation to complete
          // fib(42) takes ~2s on fast device, ~12s on slower devices in profile mode
          bool completed = false;
          int framesPumped = 0;
          const maxWaitMs = 30000; // 30 second timeout for slower devices

          debugPrint('[$scenario] Waiting for computation result...');

          while (!completed) {
            await tester.pump(kFrameInterval);
            framesPumped++;

            // Check if result is displayed (computation complete)
            final resultFinder = find.textContaining('Result:');
            if (resultFinder.evaluate().isNotEmpty) {
              completed = true;
              debugPrint(
                '[$scenario] Computation completed! Frames pumped: $framesPumped',
              );
            }

            // Also check for "Calculating" text to know computation started
            if (framesPumped == 1) {
              final calculatingFinder = find.textContaining('Calculating');
              if (calculatingFinder.evaluate().isNotEmpty) {
                debugPrint('[$scenario] Computation started (calculating...)');
              }
            }

            // Timeout protection
            if (DateTime.now().difference(computeStart).inMilliseconds >
                maxWaitMs) {
              debugPrint(
                '[$scenario] [$label $dataIndex] TIMEOUT waiting for result after ${maxWaitMs}ms',
              );
              // Try to find what's on screen for debugging
              final allTexts = find.byType(Text);
              debugPrint('  Current text widgets:');
              for (final e in allTexts.evaluate().take(10)) {
                final text = e.widget as Text;
                debugPrint('    "${text.data}"');
              }
              break;
            }
          }

          // DON'T use pumpAndSettle() - FadeSquare has infinite animation!
          // Just pump a few more frames to ensure UI is updated
          await tester.pump(const Duration(milliseconds: 100));

          final computeTime = DateTime.now().difference(computeStart);
          final timings = frameCollector.stop();

          // Calculate metrics
          int droppedFrames = 0;
          double totalJank = 0;
          for (final timing in timings) {
            final frameMs = timing.totalSpan.inMicroseconds / 1000.0;
            if (frameMs > 16.67) {
              droppedFrames++;
              totalJank += (frameMs - 16.67);
            }
          }

          final fps = timings.isNotEmpty
              ? (timings.length / (computeTime.inMilliseconds / 1000.0))
              : 0.0;
          final jankPercent = timings.isNotEmpty
              ? (droppedFrames / timings.length * 100)
              : 0.0;

          // Write frame data
          for (int f = 0; f < timings.length; f++) {
            csvWriter.writeFrameTiming(
              toggleState: toggleState,
              iteration: i,
              frameId: f,
              timing: timings[f],
              isWarmup: isWarmup,
            );
          }

          // Write aggregate metrics
          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'computation_time',
            metricValue: computeTime.inMilliseconds,
            unit: 'milliseconds',
            iteration: i,
            isWarmup: isWarmup,
          );

          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'frames_during_compute',
            metricValue: timings.length,
            unit: 'count',
            iteration: i,
            isWarmup: isWarmup,
          );

          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'dropped_frames',
            metricValue: droppedFrames,
            unit: 'count',
            iteration: i,
            isWarmup: isWarmup,
          );

          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'fps_during_compute',
            metricValue: fps,
            unit: 'fps',
            iteration: i,
            isWarmup: isWarmup,
          );

          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'jank_percent',
            metricValue: jankPercent,
            unit: 'percent',
            iteration: i,
            isWarmup: isWarmup,
          );

          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'total_jank',
            metricValue: totalJank,
            unit: 'milliseconds',
            iteration: i,
            isWarmup: isWarmup,
          );

          debugPrint(
            '[$scenario] [$label $dataIndex] '
            'time=${computeTime.inMilliseconds}ms, '
            'frames=${timings.length}, '
            'fps=${fps.toStringAsFixed(1)}, '
            'dropped=$droppedFrames, '
            'jank=${jankPercent.toStringAsFixed(1)}%',
          );

          // Reset app for next iteration
          await tester.pumpWidget(Container());
          await tester.pump(kIterationCooldown);
        }

        debugPrint('[$scenario] ═══ TOGGLE STATE $toggleState COMPLETE ═══');
        debugPrint('');
      }

      debugPrint('');
      debugPrint(
        '[$scenario] ════════════════════════════════════════════════',
      );
      debugPrint('[$scenario]  EXPERIMENT COMPLETE');
      debugPrint(
        '[$scenario]  Data saved to: /sdcard/Download/flutter_perf_${toggle}_*.csv',
      );
      debugPrint(
        '[$scenario] ════════════════════════════════════════════════',
      );
    });
  });
}
