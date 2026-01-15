/// ═══════════════════════════════════════════════════════════════════════════
/// EXPERIMENT: SCN-SHIMMER - Shimmer Animation Performance
/// ═══════════════════════════════════════════════════════════════════════════
///
/// TOGGLES:
///   minimizeExpensiveRendering - ShaderMask consolidation
///   staticPlaceholder - Disable shimmer animation entirely
///
/// THREE EXPERIMENTAL STATES:
///   1. BASELINE: 6 ShaderMask widgets (minimizeExpensiveRendering=false, staticPlaceholder=false)
///   2. OPTIMIZED: 1 ShaderMask widget (minimizeExpensiveRendering=true, staticPlaceholder=false)
///   3. STATIC: No ShaderMask, static gray boxes (staticPlaceholder=true)
///
/// MEASURES: Frame timing during shimmer/placeholder phase
///
/// OUTPUT: /sdcard/Download/flutter_perf_shimmer_*.csv
/// RETRIEVE: adb pull /sdcard/Download/flutter_perf_shimmer_*.csv ./raw_data/
///
/// RUN: flutter drive --driver=test_driver/integration_test.dart \
///        --target=integration_test/experiments/exp_shimmer.dart \
///        --profile --no-dds
/// ═══════════════════════════════════════════════════════════════════════════

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

/// Represents one experimental condition in the shimmer experiment
class ShimmerCondition {
  final String name;
  final bool minimizeExpensiveRendering;
  final bool staticPlaceholder;
  final String description;

  const ShimmerCondition({
    required this.name,
    required this.minimizeExpensiveRendering,
    required this.staticPlaceholder,
    required this.description,
  });

  @override
  String toString() => name;
}

/// The three experimental conditions for SCN-SHIMMER
const shimmerConditions = [
  ShimmerCondition(
    name: 'BASELINE',
    minimizeExpensiveRendering: false,
    staticPlaceholder: false,
    description: '6 ShaderMask widgets (expensive)',
  ),
  ShimmerCondition(
    name: 'OPTIMIZED',
    minimizeExpensiveRendering: true,
    staticPlaceholder: false,
    description: '1 ShaderMask widget (consolidated)',
  ),
  ShimmerCondition(
    name: 'STATIC',
    minimizeExpensiveRendering: false, // doesn't matter when static=true
    staticPlaceholder: true,
    description: 'No ShaderMask, static gray boxes',
  ),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'SCN-SHIMMER';
  const toggleName = 'shimmer_condition'; // Combined toggle for 3 states

  late CsvDataWriter csvWriter;
  late AppConfig appConfig;
  late FrameTimingCollector frameCollector;

  group('EXP-SHIMMER: Shimmer Animation Performance', () {
    setUpAll(() async {
      await di.init();
      appConfig = di.sl<AppConfig>();
      csvWriter = await CsvDataWriter.create(
        toggleName: toggleName,
        scenarioId: scenario,
      );
      frameCollector = FrameTimingCollector();

      // Enable prerequisites for consistent baseline
      appConfig.set(FeatureToggle.lazyLoad, true);
      appConfig.set(FeatureToggle.largeJsonParce, true);

      debugPrint('');
      debugPrint(
        '╔═══════════════════════════════════════════════════════════════════╗',
      );
      debugPrint(
        '║  EXPERIMENT: SHIMMER ANIMATION PERFORMANCE                        ║',
      );
      debugPrint(
        '║  Scenario: $scenario                                           ║',
      );
      debugPrint(
        '╠═══════════════════════════════════════════════════════════════════╣',
      );
      debugPrint(
        '║  Conditions:                                                      ║',
      );
      for (final c in shimmerConditions) {
        debugPrint(
          '║    ${c.name.padRight(10)} - ${c.description.padRight(40)}║',
        );
      }
      debugPrint(
        '╠═══════════════════════════════════════════════════════════════════╣',
      );
      debugPrint(
        '║  Iterations: ${kWarmupIterations} warmup + ${kDataIterations} data per condition           ║',
      );
      debugPrint(
        '║  Total iterations: ${(kWarmupIterations + kDataIterations) * shimmerConditions.length}                                         ║',
      );
      debugPrint(
        '║  Animation duration: ${kAnimationDuration.inSeconds}s per iteration                       ║',
      );
      debugPrint(
        '╚═══════════════════════════════════════════════════════════════════╝',
      );
      debugPrint('');
    });

    tearDownAll(() async {
      await csvWriter.close();
    });

    testWidgets('$scenario: Frame timing across 3 conditions', (tester) async {
      for (final condition in shimmerConditions) {
        debugPrint('');
        debugPrint(
          '[$scenario] ════════════════════════════════════════════════════',
        );
        debugPrint('[$scenario] CONDITION: ${condition.name}');
        debugPrint('[$scenario] ${condition.description}');
        debugPrint(
          '[$scenario] minimizeExpensiveRendering=${condition.minimizeExpensiveRendering}',
        );
        debugPrint(
          '[$scenario] staticPlaceholder=${condition.staticPlaceholder}',
        );
        debugPrint(
          '[$scenario] ════════════════════════════════════════════════════',
        );

        for (int i = 0; i < kWarmupIterations + kDataIterations; i++) {
          final isWarmup = i < kWarmupIterations;
          final label = isWarmup ? 'WARMUP' : 'DATA  ';
          final dataIndex = isWarmup ? i : i - kWarmupIterations;

          // Configure toggles BEFORE creating app
          appConfig.set(
            FeatureToggle.minimizeExpensiveRendering,
            condition.minimizeExpensiveRendering,
          );
          appConfig.set(
            FeatureToggle.staticPlaceholder,
            condition.staticPlaceholder,
          );

          debugPrint(
            '[$scenario] [$label $dataIndex] Starting (${condition.name})',
          );

          // Create app
          final app = await createTestApp();
          await tester.pumpWidget(app);

          // Start collecting frames immediately
          // (shimmer animations start during loading)
          frameCollector.start();
          final animStart = DateTime.now();

          // Pump frames for animation duration
          while (DateTime.now().difference(animStart) < kAnimationDuration) {
            await tester.pump(kFrameInterval);
          }

          final animTime = DateTime.now().difference(animStart);
          final timings = frameCollector.stop();

          // Calculate frame rate
          final frameRate = timings.length / animTime.inSeconds;

          // Write frame data - use condition.name as toggle_state for clarity
          for (int f = 0; f < timings.length; f++) {
            csvWriter.writeFrameTimingWithCondition(
              condition: condition.name,
              iteration: i,
              frameId: f,
              timing: timings[f],
              isWarmup: isWarmup,
            );
          }

          // Write animation duration
          csvWriter.writeRowWithCondition(
            condition: condition.name,
            metricName: 'animation_duration',
            metricValue: animTime.inMilliseconds,
            unit: 'milliseconds',
            iteration: i,
            isWarmup: isWarmup,
          );

          // Write frame rate
          csvWriter.writeRowWithCondition(
            condition: condition.name,
            metricName: 'frame_rate',
            metricValue: frameRate,
            unit: 'fps',
            iteration: i,
            isWarmup: isWarmup,
          );

          debugPrint(
            '[$scenario] [$label $dataIndex] frames=${timings.length}, fps=${frameRate.toStringAsFixed(1)}',
          );

          // Reset app for next iteration
          await tester.pumpWidget(Container());
          await tester.pump(kIterationCooldown);
        }

        debugPrint('[$scenario] ═══ CONDITION ${condition.name} COMPLETE ═══');
        debugPrint('');
      }
    });
  });
}
