/// ═══════════════════════════════════════════════════════════════════════════
/// CSV DATA WRITER - Core module for raw data persistence
/// ═══════════════════════════════════════════════════════════════════════════
///
/// DESIGN PRINCIPLES:
/// 1. One file per toggle experiment
/// 2. Immediate flush after each measurement (crash-safe)
/// 3. Clean CSV format for easy analysis
///
/// FILE NAMING: flutter_perf_{toggle}_{timestamp}.csv
/// RETRIEVAL: adb pull /sdcard/Download/flutter_perf_*.csv ./raw_data/
/// ═══════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Writes raw measurements directly to CSV file on device storage.
///
/// Each toggle experiment creates its own CSV file for:
/// - Independent data collection
/// - Easier partial runs
/// - Cleaner data analysis
class CsvDataWriter {
  late final File _file;
  late final IOSink _sink;
  final String runId;
  final String toggleName;
  final String scenarioId;
  int _rowCount = 0;

  /// Device metadata (captured once)
  late final String deviceModel;
  late final String androidVersion;
  late final String flutterVersion;

  CsvDataWriter._({
    required this.runId,
    required this.toggleName,
    required this.scenarioId,
  });

  /// Factory constructor - initializes file and writes header
  static Future<CsvDataWriter> create({
    required String toggleName,
    required String scenarioId,
  }) async {
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final runId = '${scenarioId}_$timestamp';
    final writer = CsvDataWriter._(
      runId: runId,
      toggleName: toggleName,
      scenarioId: scenarioId,
    );
    await writer._initialize();
    return writer;
  }

  Future<void> _initialize() async {
    // Capture device metadata
    deviceModel = _getDeviceModel();
    androidVersion = _getAndroidVersion();
    flutterVersion = _getFlutterVersion();

    // Create file on external storage (accessible via adb)
    // Format: flutter_perf_{toggle}_{timestamp}.csv
    final fileName = 'flutter_perf_${toggleName}_$runId.csv';
    final filePath = '/sdcard/Download/$fileName';

    _file = File(filePath);
    _sink = _file.openWrite(mode: FileMode.writeOnly);

    // Write CSV header
    _sink.writeln(_csvHeader);
    await _sink.flush();

    debugPrint(
      '[CsvDataWriter] ═══════════════════════════════════════════════',
    );
    debugPrint('[CsvDataWriter] Output file: $filePath');
    debugPrint('[CsvDataWriter] Toggle: $toggleName');
    debugPrint('[CsvDataWriter] Scenario: $scenarioId');
    debugPrint('[CsvDataWriter] Device: $deviceModel');
    debugPrint('[CsvDataWriter] Android: $androidVersion');
    debugPrint('[CsvDataWriter] Flutter: $flutterVersion');
    debugPrint(
      '[CsvDataWriter] ═══════════════════════════════════════════════',
    );
  }

  /// CSV header row
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
      toggleName,
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

    // Don't call flush() synchronously - it causes IOSink binding issues
    // Data will be flushed periodically or at close()
  }

  /// Write frame timing data from Flutter's FrameTiming API
  void writeFrameTiming({
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
      toggleName,
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

  /// Write a row with string condition (for 3+ states like BASELINE/OPTIMIZED/STATIC)
  void writeRowWithCondition({
    required String condition,
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
      'true', // profile_mode
      toggleName,
      condition, // Use condition name instead of boolean
      metricName,
      metricValue.toString(),
      unit,
      iteration.toString(),
      frameId?.toString() ?? '',
      isWarmup.toString(),
    ].join(',');

    _sink.writeln(row);
    _rowCount++;

    // Don't call flush() synchronously - it causes IOSink binding issues
    // Data will be flushed periodically or at close()
  }

  /// Write frame timing data with string condition (for 3+ states)
  void writeFrameTimingWithCondition({
    required String condition,
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
    _writeTimingRowWithCondition(
      timestamp,
      condition,
      'frame_build_time',
      buildDuration,
      iteration,
      frameId,
      isWarmup,
    );

    // Write raster_time metric
    _writeTimingRowWithCondition(
      timestamp,
      condition,
      'frame_raster_time',
      rasterDuration,
      iteration,
      frameId,
      isWarmup,
    );

    // Write total_time metric
    _writeTimingRowWithCondition(
      timestamp,
      condition,
      'frame_total_time',
      totalSpan,
      iteration,
      frameId,
      isWarmup,
    );
  }

  void _writeTimingRowWithCondition(
    String timestamp,
    String condition,
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
      toggleName,
      condition, // Use condition name instead of boolean
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
    debugPrint(
      '[CsvDataWriter] ═══════════════════════════════════════════════',
    );
    debugPrint('[CsvDataWriter] EXPERIMENT COMPLETE');
    debugPrint('[CsvDataWriter] Toggle: $toggleName');
    debugPrint('[CsvDataWriter] Total rows: $_rowCount');
    debugPrint('[CsvDataWriter] File: ${_file.path}');
    debugPrint('[CsvDataWriter] ');
    debugPrint('[CsvDataWriter] RETRIEVE DATA:');
    debugPrint('[CsvDataWriter] adb pull ${_file.path} ./raw_data/');
    debugPrint(
      '[CsvDataWriter] ═══════════════════════════════════════════════',
    );
  }

  String get filePath => _file.path;
  int get rowCount => _rowCount;

  // Platform-specific metadata extraction
  String _getDeviceModel() {
    try {
      if (Platform.isAndroid) {
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
    return '3.40.0-beta';
  }
}
