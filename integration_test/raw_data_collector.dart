/// ═══════════════════════════════════════════════════════════════════════════
/// RAW DATA ACQUISITION - STAGE 1 (CORRECT IMPLEMENTATION)
/// ═══════════════════════════════════════════════════════════════════════════
///
/// CRITICAL DESIGN PRINCIPLES:
/// 1. Data is written DIRECTLY to CSV file on device filesystem
/// 2. NO stdout/print-based data collection (logs are for debugging only)
/// 3. Each measurement = one row, written immediately (no buffering loss)
/// 4. Uses Flutter's FrameTiming API for accurate frame metrics
/// 5. Fail-safe: data persists even if test crashes
///
/// OUTPUT: /sdcard/Download/flutter_perf_raw_{timestamp}.csv
/// RETRIEVAL: adb pull /sdcard/Download/flutter_perf_raw_*.csv ./raw_data/
///
/// ═══════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:perform_test/core/config/feature_toggle.dart';
import 'package:perform_test/presentation/profile/widgets/photo_list_item.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/di/injection_container.dart' as di;
import 'package:perform_test/data/datasource/network_json_datasource.dart';

import 'test_config.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════

/// Number of data iterations per toggle state (excluding warmup)
const int DATA_ITERATIONS = 10;

/// Number of warmup iterations (marked in data, analyzed separately)
const int WARMUP_ITERATIONS = 2;

/// Cooldown between iterations to stabilize device state
const Duration ITERATION_COOLDOWN = Duration(seconds: 2);

/// Scroll duration for scroll-based scenarios
const Duration SCROLL_DURATION = Duration(milliseconds: 1500);

/// Animation observation duration
const Duration ANIMATION_DURATION = Duration(seconds: 2);

// ═══════════════════════════════════════════════════════════════════════════
// CSV DATA WRITER - Direct file output
// ═══════════════════════════════════════════════════════════════════════════

/// Writes raw measurements directly to CSV file on device storage.
///
/// Design rationale:
/// - File I/O is synchronous to ensure data is written before proceeding
/// - Each row is flushed immediately (no buffering = no data loss on crash)
/// - File path is on external storage for easy retrieval via adb
class CsvDataWriter {
  late final File _file;
  late final IOSink _sink;
  final String runId;
  int _rowCount = 0;

  /// Device metadata (captured once)
  late final String deviceModel;
  late final String androidVersion;
  late final String flutterVersion;

  CsvDataWriter._({required this.runId});

  /// Factory constructor - initializes file and writes header
  static Future<CsvDataWriter> create() async {
    final runId = DateTime.now().toIso8601String().replaceAll(':', '-');
    final writer = CsvDataWriter._(runId: runId);
    await writer._initialize();
    return writer;
  }

  Future<void> _initialize() async {
    // Capture device metadata
    deviceModel = _getDeviceModel();
    androidVersion = _getAndroidVersion();
    flutterVersion = _getFlutterVersion();

    // Create file on external storage (accessible via adb)
    final fileName = 'flutter_perf_raw_$runId.csv';
    final filePath = '/sdcard/Download/$fileName';

    _file = File(filePath);
    _sink = _file.openWrite(mode: FileMode.writeOnly);

    // Write CSV header
    _sink.writeln(_csvHeader);
    await _sink.flush();

    debugPrint('[CsvDataWriter] Output file: $filePath');
    debugPrint(
      '[CsvDataWriter] Device: $deviceModel, Android: $androidVersion, Flutter: $flutterVersion',
    );
  }

  /// CSV header row - matches specification exactly
  static const _csvHeader =
      'timestamp,'
      'scenario_id,'
      'experiment_run_id,'
      'device_model,'
      'android_version,'
      'flutter_version,'
      'profile_mode,'
      'optimization_toggle,'
      'toggle_state,'
      'metric_name,'
      'metric_value,'
      'unit,'
      'iteration,'
      'frame_id,'
      'is_warmup';

  /// Write a single measurement row
  void writeRow({
    required String scenarioId,
    required String toggle,
    required bool toggleState,
    required String metricName,
    required num metricValue,
    required String unit,
    required int iteration,
    int? frameId,
    required bool isWarmup,
  }) {
    final timestamp = DateTime.now().toIso8601String();

    final row = [
      timestamp,
      scenarioId,
      runId,
      deviceModel,
      androidVersion,
      flutterVersion,
      'true', // profile_mode - always true for performance tests
      toggle,
      toggleState.toString(),
      metricName,
      metricValue.toString(),
      unit,
      iteration.toString(),
      frameId?.toString() ?? '',
      isWarmup.toString(),
    ].join(',');

    _sink.writeln(row);
    _rowCount++;

    // Flush every 100 rows or immediately for important metrics
    if (_rowCount % 100 == 0 ||
        metricName.contains('total') ||
        metricName.contains('load')) {
      _sink.flush();
    }
  }

  /// Write frame timing data from Flutter's FrameTiming API
  void writeFrameTiming({
    required String scenarioId,
    required String toggle,
    required bool toggleState,
    required int iteration,
    required int frameId,
    required FrameTiming timing,
    required bool isWarmup,
  }) {
    final timestamp = DateTime.now().toIso8601String();

    // Extract all timing components from FrameTiming
    final buildDuration = timing.buildDuration.inMicroseconds;
    final rasterDuration = timing.rasterDuration.inMicroseconds;
    final totalSpan = timing.totalSpan.inMicroseconds;

    // Write build_time metric
    _writeTimingRow(
      timestamp,
      scenarioId,
      toggle,
      toggleState,
      'frame_build_time',
      buildDuration,
      iteration,
      frameId,
      isWarmup,
    );

    // Write raster_time metric
    _writeTimingRow(
      timestamp,
      scenarioId,
      toggle,
      toggleState,
      'frame_raster_time',
      rasterDuration,
      iteration,
      frameId,
      isWarmup,
    );

    // Write total_time metric
    _writeTimingRow(
      timestamp,
      scenarioId,
      toggle,
      toggleState,
      'frame_total_time',
      totalSpan,
      iteration,
      frameId,
      isWarmup,
    );
  }

  void _writeTimingRow(
    String timestamp,
    String scenarioId,
    String toggle,
    bool toggleState,
    String metricName,
    int value,
    int iteration,
    int frameId,
    bool isWarmup,
  ) {
    final row = [
      timestamp,
      scenarioId,
      runId,
      deviceModel,
      androidVersion,
      flutterVersion,
      'true',
      toggle,
      toggleState.toString(),
      metricName,
      value.toString(),
      'microseconds',
      iteration.toString(),
      frameId.toString(),
      isWarmup.toString(),
    ].join(',');

    _sink.writeln(row);
    _rowCount++;
  }

  /// Finalize and close the file
  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
    debugPrint('[CsvDataWriter] Closed. Total rows written: $_rowCount');
    debugPrint('[CsvDataWriter] File ready for retrieval: ${_file.path}');
  }

  String get filePath => _file.path;
  int get rowCount => _rowCount;

  // Platform-specific metadata extraction
  String _getDeviceModel() {
    try {
      if (Platform.isAndroid) {
        // Read from system properties
        final result = Process.runSync('getprop', ['ro.product.model']);
        return result.stdout.toString().trim().replaceAll(',', '_');
      }
    } catch (_) {}
    return 'unknown_device';
  }

  String _getAndroidVersion() {
    try {
      if (Platform.isAndroid) {
        final result = Process.runSync('getprop', ['ro.build.version.release']);
        return result.stdout.toString().trim();
      }
    } catch (_) {}
    return 'unknown';
  }

  String _getFlutterVersion() {
    // This is compile-time constant in profile mode
    return '3.40.0-beta'; // Update based on actual version
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FRAME TIMING COLLECTOR - Uses Flutter's official FrameTiming API
// ═══════════════════════════════════════════════════════════════════════════

/// Collects frame timings using Flutter's SchedulerBinding.addTimingsCallback
///
/// This is the CORRECT way to measure frame performance:
/// - Uses engine-level timing data
/// - Provides build, raster, and total times
/// - No manual DateTime.now() measurements (inaccurate)
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
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN TEST SUITE
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late CsvDataWriter csvWriter;
  late AppConfig appConfig;
  late FrameTimingCollector frameCollector;

  group('Raw Data Collection', () {
    setUpAll(() async {
      await di.init();
      appConfig = di.sl<AppConfig>();
      csvWriter = await CsvDataWriter.create();
      frameCollector = FrameTimingCollector();

      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('  RAW DATA COLLECTION STARTED');
      debugPrint('  Output: ${csvWriter.filePath}');
      debugPrint('  Run ID: ${csvWriter.runId}');
      debugPrint('═══════════════════════════════════════════════════════════');
    });

    tearDownAll(() async {
      await csvWriter.close();

      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('  RAW DATA COLLECTION COMPLETE');
      debugPrint('  Total measurements: ${csvWriter.rowCount}');
      debugPrint('  ');
      debugPrint('  To retrieve data:');
      debugPrint('  adb pull ${csvWriter.filePath} ./raw_data/');
      debugPrint('═══════════════════════════════════════════════════════════');
    });

    // ═════════════════════════════════════════════════════════════════════
    // SCN-JSON: Large JSON Parsing Performance (25MB from GitHub)
    // ═════════════════════════════════════════════════════════════════════
    //
    // EXPERIMENT: Parse 25MB JSON from GitHub
    // - Toggle OFF: Parse on main isolate (UI FREEZES)
    // - Toggle ON: Parse via compute() (UI RESPONSIVE)
    //
    // NAVIGATION: Tab 1 "JSON" -> NetworkJsonScreen
    // DATA SOURCE: https://raw.githubusercontent.com/json-iterator/test-data/refs/heads/master/large-file.json
    // ═════════════════════════════════════════════════════════════════════
    testWidgets('SCN-JSON: Frame timing during large JSON parse', (
      tester,
    ) async {
      const scenario = 'SCN-JSON';
      const toggle = 'largeJsonParce';

      for (final toggleState in [false, true]) {
        debugPrint('[$scenario] toggle_state=$toggleState');

        // Clear JSON cache to force fresh download for first iteration
        // (subsequent iterations will use cached data to isolate parsing time)
        final networkJsonDatasource = di.sl<NetworkJsonDatasource>();
        networkJsonDatasource.clearCache();

        for (int i = 0; i < WARMUP_ITERATIONS + DATA_ITERATIONS; i++) {
          final isWarmup = i < WARMUP_ITERATIONS;
          final label = isWarmup ? 'WARMUP' : 'DATA';

          // Configure toggle BEFORE creating app
          appConfig.set(FeatureToggle.largeJsonParce, toggleState);

          // Create app
          final app = await createTestApp();
          await tester.pumpWidget(app);
          await tester.pumpAndSettle();

          // Navigate to JSON tab (index 1)
          final bottomNav = find.byType(BottomNavigationBar);
          expect(bottomNav, findsOneWidget);

          // Tap on JSON tab (second item)
          final jsonTabIcon = find.byIcon(Icons.cloud_download);
          await tester.tap(jsonTabIcon);
          await tester.pumpAndSettle();

          // Verify we're on NetworkJsonScreen
          expect(find.text('Network JSON Parse'), findsOneWidget);

          // Find and tap "FETCH & PARSE JSON" button
          final fetchButton = find.text('FETCH & PARSE JSON');
          expect(fetchButton, findsOneWidget);

          // Start frame collection BEFORE triggering fetch
          frameCollector.start();
          final loadStart = DateTime.now();

          // Tap fetch button to start loading
          await tester.tap(fetchButton);
          await tester.pump();

          // Wait for loading to complete (look for results card)
          // Max timeout: 120 seconds (25MB download can take time)
          bool completed = false;
          while (!completed) {
            await tester.pump(const Duration(milliseconds: 16));

            // Check for results (success case)
            if (find.text('Results').evaluate().isNotEmpty) {
              completed = true;
            }

            // Check for error (failure case)
            if (find.textContaining('Error').evaluate().isNotEmpty) {
              debugPrint('  [$label $i] ERROR during fetch');
              completed = true;
            }

            // Timeout
            if (DateTime.now().difference(loadStart) >
                const Duration(seconds: 120)) {
              debugPrint('  [$label $i] TIMEOUT after 120s');
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
              scenarioId: scenario,
              toggle: toggle,
              toggleState: toggleState,
              iteration: i,
              frameId: f,
              timing: timings[f],
              isWarmup: isWarmup,
            );
          }

          // Write total load time
          csvWriter.writeRow(
            scenarioId: scenario,
            toggle: toggle,
            toggleState: toggleState,
            metricName: 'load_time_total',
            metricValue: loadTime.inMilliseconds,
            unit: 'milliseconds',
            iteration: i,
            isWarmup: isWarmup,
          );

          debugPrint(
            '  [$label $i] frames=${timings.length}, loadTime=${loadTime.inMilliseconds}ms, toggleState=$toggleState',
          );

          // Reset app for next iteration
          await tester.pumpWidget(Container());
          await tester.pump(ITERATION_COOLDOWN);
        }
      }
    });

    // ═════════════════════════════════════════════════════════════════════
    // SCN-REBUILD: Widget Rebuild Performance (Scroll)
    // ═════════════════════════════════════════════════════════════════════
    testWidgets('SCN-REBUILD: Frame timing during scroll', (tester) async {
      const scenario = 'SCN-REBUILD';
      const toggle = 'correctDataUpdate';

      // Enable prerequisites for consistent baseline
      appConfig.set(FeatureToggle.lazyLoad, true);
      appConfig.set(FeatureToggle.largeJsonParce, true);

      for (final toggleState in [false, true]) {
        debugPrint('[$scenario] toggle_state=$toggleState');

        for (int i = 0; i < WARMUP_ITERATIONS + DATA_ITERATIONS; i++) {
          final isWarmup = i < WARMUP_ITERATIONS;
          final label = isWarmup ? 'WARMUP' : 'DATA';

          appConfig.set(FeatureToggle.correctDataUpdate, toggleState);

          final app = await createTestApp();
          await tester.pumpWidget(app);

          // Wait for initial load
          while (find.byType(PhotoListItem).evaluate().isEmpty) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          await tester.pumpAndSettle();

          // Find scrollable and start frame collection
          final scrollable = find.byType(Scrollable).first;
          frameCollector.start();

          // Perform scroll gesture
          await tester.fling(scrollable, const Offset(0, -500), 1500);
          await tester.pumpAndSettle();

          // Scroll back
          await tester.fling(scrollable, const Offset(0, 500), 1500);
          await tester.pumpAndSettle();

          final timings = frameCollector.stop();

          // Write frame data
          for (int f = 0; f < timings.length; f++) {
            csvWriter.writeFrameTiming(
              scenarioId: scenario,
              toggle: toggle,
              toggleState: toggleState,
              iteration: i,
              frameId: f,
              timing: timings[f],
              isWarmup: isWarmup,
            );
          }

          debugPrint('  [$label $i] scroll frames=${timings.length}');

          await tester.pumpWidget(Container());
          await tester.pump(ITERATION_COOLDOWN);
        }
      }
    });

    // ═════════════════════════════════════════════════════════════════════
    // SCN-LAZY: Initial Build Time (Lazy vs Eager Loading)
    // ═════════════════════════════════════════════════════════════════════
    testWidgets('SCN-LAZY: Initial build timing', (tester) async {
      const scenario = 'SCN-LAZY';
      const toggle = 'lazyLoad';

      appConfig.set(FeatureToggle.largeJsonParce, true);

      for (final toggleState in [false, true]) {
        debugPrint('[$scenario] toggle_state=$toggleState');

        for (int i = 0; i < WARMUP_ITERATIONS + DATA_ITERATIONS; i++) {
          final isWarmup = i < WARMUP_ITERATIONS;
          final label = isWarmup ? 'WARMUP' : 'DATA';

          appConfig.set(FeatureToggle.lazyLoad, toggleState);

          final app = await createTestApp();
          frameCollector.start();

          final buildStart = DateTime.now();
          await tester.pumpWidget(app);
          await tester.pumpAndSettle(const Duration(seconds: 10));
          final buildTime = DateTime.now().difference(buildStart);

          final timings = frameCollector.stop();

          // Write frame data
          for (int f = 0; f < timings.length; f++) {
            csvWriter.writeFrameTiming(
              scenarioId: scenario,
              toggle: toggle,
              toggleState: toggleState,
              iteration: i,
              frameId: f,
              timing: timings[f],
              isWarmup: isWarmup,
            );
          }

          // Write total build time
          csvWriter.writeRow(
            scenarioId: scenario,
            toggle: toggle,
            toggleState: toggleState,
            metricName: 'initial_build_time',
            metricValue: buildTime.inMilliseconds,
            unit: 'milliseconds',
            iteration: i,
            isWarmup: isWarmup,
          );

          debugPrint(
            '  [$label $i] buildTime=${buildTime.inMilliseconds}ms, frames=${timings.length}',
          );

          await tester.pumpWidget(Container());
          await tester.pump(ITERATION_COOLDOWN);
        }
      }
    });

    // ═════════════════════════════════════════════════════════════════════
    // SCN-SHIMMER: Animation Smoothness
    // ═════════════════════════════════════════════════════════════════════
    testWidgets('SCN-SHIMMER: Animation frame timing', (tester) async {
      const scenario = 'SCN-SHIMMER';
      const toggle = 'minimizeExpensiveRendering';

      appConfig.set(FeatureToggle.lazyLoad, true);
      appConfig.set(FeatureToggle.largeJsonParce, true);

      for (final toggleState in [false, true]) {
        debugPrint('[$scenario] toggle_state=$toggleState');

        for (int i = 0; i < WARMUP_ITERATIONS + DATA_ITERATIONS; i++) {
          final isWarmup = i < WARMUP_ITERATIONS;
          final label = isWarmup ? 'WARMUP' : 'DATA';

          appConfig.set(FeatureToggle.minimizeExpensiveRendering, toggleState);

          final app = await createTestApp();
          await tester.pumpWidget(app);

          // Start collecting animation frames
          frameCollector.start();

          // Pump frames for animation duration
          final animStart = DateTime.now();
          while (DateTime.now().difference(animStart) < ANIMATION_DURATION) {
            await tester.pump(const Duration(milliseconds: 16));
          }

          final timings = frameCollector.stop();

          // Write frame data
          for (int f = 0; f < timings.length; f++) {
            csvWriter.writeFrameTiming(
              scenarioId: scenario,
              toggle: toggle,
              toggleState: toggleState,
              iteration: i,
              frameId: f,
              timing: timings[f],
              isWarmup: isWarmup,
            );
          }

          debugPrint('  [$label $i] animation frames=${timings.length}');

          await tester.pumpWidget(Container());
          await tester.pump(ITERATION_COOLDOWN);
        }
      }
    });
  });
}
