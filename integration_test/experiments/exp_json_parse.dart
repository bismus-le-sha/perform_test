/// ═══════════════════════════════════════════════════════════════════════════
/// EXPERIMENT: SCN-JSON - Large JSON Parsing Performance
/// ═══════════════════════════════════════════════════════════════════════════
///
/// TOGGLE: largeJsonParce
///   - OFF: Parse 25MB JSON on main isolate (UI FREEZES)
///   - ON:  Parse via compute() in separate isolate (UI RESPONSIVE)
///
/// DATA SOURCE: https://raw.githubusercontent.com/json-iterator/test-data/
///              refs/heads/master/large-file.json (~25MB, ~11000 events)
///
/// NAVIGATION: Tab 1 "JSON" -> NetworkJsonScreen
///
/// OUTPUT: /sdcard/Download/flutter_perf_largeJsonParce_*.csv
/// RETRIEVE: adb pull /sdcard/Download/flutter_perf_largeJsonParce_*.csv ./raw_data/
///
/// RUN: flutter drive --driver=test_driver/integration_test.dart \
///        --target=integration_test/experiments/exp_json_parse.dart \
///        --profile --no-dds
/// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:perform_test/core/config/feature_toggle.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/di/injection_container.dart' as di;
import 'package:perform_test/data/datasource/network_json_datasource.dart';

import '../core/csv_writer.dart';
import '../core/frame_collector.dart';
import '../core/test_constants.dart';
import '../test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'SCN-JSON';
  const toggle = 'largeJsonParce';

  late CsvDataWriter csvWriter;
  late AppConfig appConfig;
  late FrameTimingCollector frameCollector;
  late NetworkJsonDatasource networkJsonDatasource;

  group('EXP-JSON: Large JSON Parse ($toggle)', () {
    setUpAll(() async {
      await di.init();
      appConfig = di.sl<AppConfig>();
      networkJsonDatasource = di.sl<NetworkJsonDatasource>();
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
        '║  EXPERIMENT: LARGE JSON PARSE                              ║',
      );
      debugPrint('║  Toggle: $toggle                                   ║');
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
        '╚═══════════════════════════════════════════════════════════╝',
      );
      debugPrint('');
    });

    tearDownAll(() async {
      await csvWriter.close();
    });

    testWidgets('$scenario: Frame timing during 25MB JSON parse', (
      tester,
    ) async {
      for (final toggleState in [false, true]) {
        debugPrint('');
        debugPrint('[$scenario] ═══ TOGGLE STATE: $toggleState ═══');

        // Clear JSON cache to force fresh download for first iteration
        networkJsonDatasource.clearCache();
        debugPrint('[$scenario] Cache cleared');

        for (int i = 0; i < kWarmupIterations + kDataIterations; i++) {
          final isWarmup = i < kWarmupIterations;
          final label = isWarmup ? 'WARMUP' : 'DATA  ';
          final dataIndex = isWarmup ? i : i - kWarmupIterations;

          // Configure toggle BEFORE creating app
          appConfig.set(FeatureToggle.largeJsonParce, toggleState);

          // Create app
          final app = await createTestApp();
          await tester.pumpWidget(app);
          await tester.pumpAndSettle();

          // Navigate to JSON tab (index 1)
          final bottomNav = find.byType(BottomNavigationBar);
          expect(
            bottomNav,
            findsOneWidget,
            reason: 'BottomNavigationBar not found',
          );

          // Tap on JSON tab icon
          final jsonTabIcon = find.byIcon(Icons.cloud_download);
          expect(
            jsonTabIcon,
            findsOneWidget,
            reason: 'JSON tab icon not found',
          );
          await tester.tap(jsonTabIcon);
          await tester.pumpAndSettle();

          // Verify we're on NetworkJsonScreen
          expect(
            find.text('Network JSON Parse'),
            findsOneWidget,
            reason: 'NetworkJsonScreen title not found',
          );

          // Find "FETCH & PARSE JSON" button
          final fetchButton = find.text('FETCH & PARSE JSON');
          expect(fetchButton, findsOneWidget, reason: 'Fetch button not found');

          debugPrint(
            '[$scenario] [$label $dataIndex] Starting fetch (toggleState=$toggleState)',
          );

          // Start frame collection BEFORE triggering fetch
          frameCollector.start();
          final loadStart = DateTime.now();

          // Tap fetch button to start loading
          await tester.tap(fetchButton);
          await tester.pump();

          // Wait for loading to complete
          bool completed = false;
          String result = 'unknown';

          while (!completed) {
            await tester.pump(kFrameInterval);

            // Check for results (success case)
            if (find.text('Results').evaluate().isNotEmpty) {
              completed = true;
              result = 'success';
            }

            // Check for error (failure case)
            if (find.textContaining('Error').evaluate().isNotEmpty) {
              completed = true;
              result = 'error';
            }

            // Timeout protection
            if (DateTime.now().difference(loadStart) > kNetworkTimeout) {
              result = 'timeout';
              break;
            }
          }

          await tester.pumpAndSettle();
          final loadTime = DateTime.now().difference(loadStart);

          // Stop frame collection
          final timings = frameCollector.stop();

          // Write each frame timing to CSV
          for (int f = 0; f < timings.length; f++) {
            csvWriter.writeFrameTiming(
              toggleState: toggleState,
              iteration: i,
              frameId: f,
              timing: timings[f],
              isWarmup: isWarmup,
            );
          }

          // Write total load time
          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'load_time_total',
            metricValue: loadTime.inMilliseconds,
            unit: 'milliseconds',
            iteration: i,
            isWarmup: isWarmup,
          );

          // Write result status
          csvWriter.writeRow(
            toggleState: toggleState,
            metricName: 'result_status',
            metricValue: result == 'success' ? 1 : 0,
            unit: 'boolean',
            iteration: i,
            isWarmup: isWarmup,
          );

          debugPrint(
            '[$scenario] [$label $dataIndex] $result: frames=${timings.length}, time=${loadTime.inMilliseconds}ms',
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
