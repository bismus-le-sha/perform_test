/// ═══════════════════════════════════════════════════════════════════════════
/// EXPERIMENT: SCN-LAZY - Lazy Load Performance
/// ═══════════════════════════════════════════════════════════════════════════
///
/// TOGGLE: lazyLoad
///   - OFF: Load ALL 50 images at full resolution immediately (SLOW, HIGH MEMORY)
///   - ON:  Load only visible images with cacheExtent optimization (FAST)
///
/// MEASURES: Initial build time and frame timing during image loading
///
/// OUTPUT: /sdcard/Download/flutter_perf_lazyLoad_*.csv
/// RETRIEVE: adb pull /sdcard/Download/flutter_perf_lazyLoad_*.csv ./raw_data/
///
/// RUN: flutter drive --driver=test_driver/integration_test.dart \
///        --target=integration_test/experiments/exp_lazy_load.dart \
///        --profile --no-dds
/// ═══════════════════════════════════════════════════════════════════════════
library;

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

  const scenario = 'SCN-LAZY';
  const toggle = 'lazyLoad';

  late CsvDataWriter csvWriter;
  late AppConfig appConfig;
  late FrameTimingCollector frameCollector;

  group('EXP-LAZY: Lazy Load Performance ($toggle)', () {
    setUpAll(() async {
      await di.init();
      appConfig = di.sl<AppConfig>();
      csvWriter = await CsvDataWriter.create(
        toggleName: toggle,
        scenarioId: scenario,
      );
      frameCollector = FrameTimingCollector();

      // Enable JSON parse optimization to isolate lazy load effect
      appConfig.set(FeatureToggle.largeJsonParce, true);

      debugPrint('');
      debugPrint(
        '╔═══════════════════════════════════════════════════════════╗',
      );
      debugPrint(
        '║  EXPERIMENT: LAZY LOAD                                     ║',
      );
      debugPrint(
        '║  Toggle: $toggle                                           ║',
      );
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
      debugPrint('║  WARNING: toggle=false loads 50 images at full res!    ║');
      debugPrint(
        '║      Each iteration may take 30-60 seconds.                 ║',
      );
      debugPrint(
        '╚═══════════════════════════════════════════════════════════╝',
      );
      debugPrint('');
    });

    tearDownAll(() async {
      await csvWriter.close();
    });

    testWidgets('$scenario: Initial build timing with image loading', (
      tester,
    ) async {
      for (final toggleState in [false, true]) {
        debugPrint('');
        debugPrint('[$scenario] ═══ TOGGLE STATE: $toggleState ═══');
        if (!toggleState) {
          debugPrint(
            '[$scenario] Full resolution mode - expect slow iterations',
          );
        }

        for (int i = 0; i < kWarmupIterations + kDataIterations; i++) {
          final isWarmup = i < kWarmupIterations;
          final label = isWarmup ? 'WARMUP' : 'DATA  ';
          final dataIndex = isWarmup ? i : i - kWarmupIterations;

          // Configure toggle BEFORE creating app
          appConfig.set(FeatureToggle.lazyLoad, toggleState);

          debugPrint(
            '[$scenario] [$label $dataIndex] Starting (toggleState=$toggleState)',
          );

          // Create app and start measuring
          final app = await createTestApp();
          frameCollector.start();
          final buildStart = DateTime.now();

          await tester.pumpWidget(app);

          // Wait for images to start appearing
          int waitCycles = 0;
          while (find.byType(PhotoListItem).evaluate().isEmpty &&
              waitCycles < 100) {
            await tester.pump(kFrameInterval);
            waitCycles++;
          }

          // Allow all visible images to load
          // For lazyLoad=false this will be SLOW (50 full-res images)
          await tester.pumpAndSettle(kHeavyOperationTimeout);

          final buildTime = DateTime.now().difference(buildStart);
          final timings = frameCollector.stop();

          // Count loaded images
          final loadedImages = find.byType(PhotoListItem).evaluate().length;

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

          // Write total build time
          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'initial_build_time',
            metricValue: buildTime.inMilliseconds,
            unit: 'milliseconds',
            iteration: i,
            isWarmup: isWarmup,
          );

          // Write image count
          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'loaded_image_count',
            metricValue: loadedImages,
            unit: 'count',
            iteration: i,
            isWarmup: isWarmup,
          );

          debugPrint(
            '[$scenario] [$label $dataIndex] buildTime=${buildTime.inMilliseconds}ms, frames=${timings.length}, images=$loadedImages',
          );

          // Reset app for next iteration
          await tester.pumpWidget(Container());
          await tester.pump(kIterationCooldown);
        }

        debugPrint('[$scenario] ═══ TOGGLE STATE $toggleState COMPLETE ═══');
        debugPrint('');
      }
    });
  });
}
