/// ═══════════════════════════════════════════════════════════════════════════
/// EXPERIMENT: SCN-REBUILD - Widget Rebuild Performance
/// ═══════════════════════════════════════════════════════════════════════════
///
/// TOGGLE: correctDataUpdate
///   - OFF: Inefficient state updates causing excessive rebuilds
///   - ON:  Optimized state management with minimal rebuilds
///
/// MEASURES: Frame timing during scroll operations
///
/// OUTPUT: /sdcard/Download/flutter_perf_correctDataUpdate_*.csv
/// RETRIEVE: adb pull /sdcard/Download/flutter_perf_correctDataUpdate_*.csv ./raw_data/
///
/// RUN: flutter drive --driver=test_driver/integration_test.dart \
///        --target=integration_test/experiments/exp_rebuild.dart \
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

  const scenario = 'SCN-REBUILD';
  const toggle = 'correctDataUpdate';

  late CsvDataWriter csvWriter;
  late AppConfig appConfig;
  late FrameTimingCollector frameCollector;

  group('EXP-REBUILD: Widget Rebuild Performance ($toggle)', () {
    setUpAll(() async {
      await di.init();
      appConfig = di.sl<AppConfig>();
      await appConfig.init(isIntegrationTest: true);
      csvWriter = await CsvDataWriter.create(
        toggleName: toggle,
        scenarioId: scenario,
      );
      frameCollector = FrameTimingCollector();

      // Enable prerequisites for consistent baseline
      appConfig.set(FeatureToggle.lazyLoad, true);
      appConfig.set(FeatureToggle.largeJsonParce, true);

      debugPrint('');
      debugPrint(
        '╔═══════════════════════════════════════════════════════════╗',
      );
      debugPrint(
        '║  EXPERIMENT: WIDGET REBUILD                                ║',
      );
      debugPrint('║  Toggle: $toggle                               ║');
      debugPrint('║  Scenario: $scenario                                    ║');
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
        '║  Prerequisites enabled:                                     ║',
      );
      debugPrint(
        '║    - lazyLoad: true                                         ║',
      );
      debugPrint(
        '║    - largeJsonParce: true                                   ║',
      );
      debugPrint(
        '╚═══════════════════════════════════════════════════════════╝',
      );
      debugPrint('');
    });

    tearDownAll(() async {
      await csvWriter.close();
    });

    testWidgets('$scenario: Frame timing during scroll', (tester) async {
      for (final toggleState in [false, true]) {
        debugPrint('');
        debugPrint('[$scenario] ═══ TOGGLE STATE: $toggleState ═══');

        for (int i = 0; i < kWarmupIterations + kDataIterations; i++) {
          final isWarmup = i < kWarmupIterations;
          final label = isWarmup ? 'WARMUP' : 'DATA  ';
          final dataIndex = isWarmup ? i : i - kWarmupIterations;

          // Configure toggle BEFORE creating app
          appConfig.set(FeatureToggle.correctDataUpdate, toggleState);

          debugPrint(
            '[$scenario] [$label $dataIndex] Starting (toggleState=$toggleState)',
          );

          // Create app
          final app = await createTestApp();
          await tester.pumpWidget(app);

          // Wait for initial load
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

          // Perform scroll down
          await tester.fling(scrollable, const Offset(0, -500), 1500);
          await tester.pumpAndSettle();

          // Perform scroll up (back)
          await tester.fling(scrollable, const Offset(0, 500), 1500);
          await tester.pumpAndSettle();

          final scrollTime = DateTime.now().difference(scrollStart);
          final timings = frameCollector.stop();

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

          debugPrint(
            '[$scenario] [$label $dataIndex] scrollTime=${scrollTime.inMilliseconds}ms, frames=${timings.length}',
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
