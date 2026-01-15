/// ═══════════════════════════════════════════════════════════════════════════
/// EXPERIMENT: SCN-IMG - Image Memory Optimization Performance
/// ═══════════════════════════════════════════════════════════════════════════
///
/// TOGGLE: optimImageSize
///   - OFF: Decode images at full source resolution (HIGH MEMORY)
///   - ON:  Decode at layoutWidth × devicePixelRatio (OPTIMIZED)
///
/// NAVIGATION: Tab 0 "Photos" -> PhotosFeedScreen (scroll through images)
///
/// HYPOTHESIS: Using cacheWidth/cacheHeight reduces decoded image memory
/// proportionally to resolution reduction, without visible quality loss.
///
/// OUTPUT: /sdcard/Download/flutter_perf_optimImageSize_*.csv
/// RETRIEVE: adb pull /sdcard/Download/flutter_perf_optimImageSize_*.csv ./raw_data/
///
/// RUN: flutter drive --driver=test_driver/integration_test.dart \
///        --target=integration_test/experiments/exp_image_memory.dart \
///        --profile --no-dds
/// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:perform_test/core/config/feature_toggle.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/di/injection_container.dart' as di;
import 'package:perform_test/presentation/profile/widgets/photo_list_item.dart';

import '../core/csv_writer.dart';
import '../core/frame_collector.dart';
import '../core/test_constants.dart';
import '../test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'SCN-IMG';
  const toggle = 'optimImageSize';

  late CsvDataWriter csvWriter;
  late AppConfig appConfig;
  late FrameTimingCollector frameCollector;

  group('EXP-IMG: Image Memory Optimization ($toggle)', () {
    setUpAll(() async {
      await di.init();
      appConfig = di.sl<AppConfig>();
      csvWriter = await CsvDataWriter.create(
        toggleName: toggle,
        scenarioId: scenario,
      );
      frameCollector = FrameTimingCollector();

      // Enable prerequisites to isolate image decode effect
      appConfig.set(FeatureToggle.lazyLoad, true); // Use lazy loading
      appConfig.set(FeatureToggle.largeJsonParce, true); // Optimize JSON

      debugPrint('');
      debugPrint(
        '╔═══════════════════════════════════════════════════════════╗',
      );
      debugPrint(
        '║  EXPERIMENT: IMAGE MEMORY OPTIMIZATION                     ║',
      );
      debugPrint('║  Toggle: $toggle                               ║');
      debugPrint(
        '║  Scenario: $scenario                                       ║',
      );
      debugPrint(
        '╠═══════════════════════════════════════════════════════════╣',
      );
      debugPrint(
        '║  Iterations: ${kWarmupIterations} warmup + ${kDataIterations} data per state        ║',
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
        '║  Prerequisites enabled:                                     ║',
      );
      debugPrint(
        '║    - lazyLoad: true                                         ║',
      );
      debugPrint(
        '║    - largeJsonParce: true                                   ║',
      );
      debugPrint(
        '║                                                             ║',
      );
      debugPrint(
        '║  Expected behavior:                                         ║',
      );
      debugPrint(
        '║    toggle=false: Full res decode (high memory)             ║',
      );
      debugPrint(
        '║    toggle=true:  Sized decode (low memory)                 ║',
      );
      debugPrint(
        '╚═══════════════════════════════════════════════════════════╝',
      );
      debugPrint('');
    });

    tearDownAll(() async {
      await csvWriter.close();
    });

    testWidgets('$scenario: Frame timing and memory during scroll', (
      tester,
    ) async {
      for (final toggleState in [false, true]) {
        debugPrint('');
        debugPrint('[$scenario] ═══ TOGGLE STATE: $toggleState ═══');
        debugPrint(
          '[$scenario] Mode: ${toggleState ? "Optimized decode (sized)" : "Full resolution decode"}',
        );

        for (int i = 0; i < kWarmupIterations + kDataIterations; i++) {
          final isWarmup = i < kWarmupIterations;
          final label = isWarmup ? 'WARMUP' : 'DATA  ';
          final dataIndex = isWarmup ? i : i - kWarmupIterations;

          // Configure toggle BEFORE creating app
          appConfig.set(FeatureToggle.optimImageSize, toggleState);

          debugPrint(
            '[$scenario] [$label $dataIndex] Starting (toggleState=$toggleState)',
          );

          // Clear image cache before each iteration for fair comparison
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();

          // Create app
          final app = await createTestApp();
          await tester.pumpWidget(app);

          // Wait for initial images to load
          int waitCycles = 0;
          while (find.byType(PhotoListItem).evaluate().isEmpty &&
              waitCycles < 100) {
            await tester.pump(kFrameInterval);
            waitCycles++;
          }
          await tester.pumpAndSettle();

          // Find scrollable
          final scrollable = find.byType(Scrollable).first;

          // Start frame collection
          frameCollector.start();
          final scrollStart = DateTime.now();

          // Perform scroll down to trigger image loading
          await tester.fling(scrollable, const Offset(0, -800), 1200);
          await tester.pumpAndSettle();

          // Scroll more to load more images
          await tester.fling(scrollable, const Offset(0, -800), 1200);
          await tester.pumpAndSettle();

          // Scroll back up
          await tester.fling(scrollable, const Offset(0, 800), 1200);
          await tester.pumpAndSettle();

          final scrollTime = DateTime.now().difference(scrollStart);
          final timings = frameCollector.stop();

          // Get image cache stats
          final cacheStats = PaintingBinding.instance.imageCache;
          final liveImageCount = cacheStats.liveImageCount;
          final currentSizeBytes = cacheStats.currentSizeBytes;

          // Calculate frame metrics
          int droppedFrames = 0;
          for (final timing in timings) {
            final frameMs = timing.totalSpan.inMicroseconds / 1000.0;
            if (frameMs > 16.67) {
              droppedFrames++;
            }
          }

          final fps = timings.isNotEmpty
              ? (timings.length / (scrollTime.inMilliseconds / 1000.0))
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

          // Write scroll duration
          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'scroll_duration',
            metricValue: scrollTime.inMilliseconds,
            unit: 'milliseconds',
            iteration: i,
            isWarmup: isWarmup,
          );

          // Write image cache metrics
          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'image_cache_count',
            metricValue: liveImageCount,
            unit: 'count',
            iteration: i,
            isWarmup: isWarmup,
          );

          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'image_cache_size_bytes',
            metricValue: currentSizeBytes,
            unit: 'bytes',
            iteration: i,
            isWarmup: isWarmup,
          );

          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'image_cache_size_mb',
            metricValue: currentSizeBytes / (1024 * 1024),
            unit: 'megabytes',
            iteration: i,
            isWarmup: isWarmup,
          );

          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'fps_during_scroll',
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

          debugPrint(
            '[$scenario] [$label $dataIndex] '
            'scrollTime=${scrollTime.inMilliseconds}ms, '
            'frames=${timings.length}, '
            'fps=${fps.toStringAsFixed(1)}, '
            'cacheSize=${(currentSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB, '
            'images=$liveImageCount',
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
