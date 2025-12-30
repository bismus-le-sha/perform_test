import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' as services;
import 'package:logging/logging.dart';
import 'package:perform_test/data/model/photo.dart';
import 'package:perform_test/service/app_config/app_config.dart';
import 'package:perform_test/service/metrics_handlers/experiment_metrics.dart';

import '../../core/config/feature_toggle.dart';

/// Data source for fetching photos with instrumented JSON parsing.
///
/// EXPERIMENT: largeJsonParse toggle
///
/// HYPOTHESIS: Parsing large JSON on the main isolate blocks the UI thread,
/// while using compute() offloads parsing to a background isolate.
///
/// TOGGLE STATES:
/// - false: Parse JSON synchronously on main isolate (UI blocking)
/// - true: Parse JSON via compute() in background isolate (non-blocking)
///
/// METRICS:
/// - File I/O time (asset loading) - should be SAME for both states
/// - JSON parsing time - should be SAME for both states
/// - UI blocking time - should be HIGH for sync, LOW for async
/// - Frame drops during parsing - should be HIGH for sync, NONE for async
///
/// CONTROLLED VARIABLES:
/// - Same JSON file (feed.json)
/// - Same parsing logic (_parseResponse)
/// - Measurements separated for I/O vs parsing phases
class PhotoRemoteDataSource {
  final Logger _logger;
  final AppConfig _appConfig;

  /// Metrics for JSON parsing experiment
  final ExperimentMetrics _parsingMetrics;

  /// Cached asset data for warm-up / repeated tests
  String? _cachedJsonData;

  PhotoRemoteDataSource({required Logger logger, required AppConfig appConfig})
    : _appConfig = appConfig,
      _logger = logger,
      _parsingMetrics = ExperimentMetrics(
        experimentName: 'JSON_PARSING',
        warmUpIterations: 2,
        logger: logger,
      );

  /// Load JSON from assets with separate I/O measurement.
  ///
  /// Returns: (jsonString, loadTimeUs)
  Future<(String, int)> _loadJsonAsset() async {
    // If cached from previous run, return immediately (for benchmark mode)
    if (_cachedJsonData != null) {
      _logger.fine('Using cached JSON data');
      return (_cachedJsonData!, 0);
    }

    developer.Timeline.startSync('JSON_ASSET_LOAD');
    final sw = Stopwatch()..start();

    final data = await services.rootBundle.loadString("assets/data/feed.json");

    sw.stop();
    developer.Timeline.finishSync();

    final loadTimeUs = sw.elapsedMicroseconds;
    _logger.info(
      'Asset I/O time: ${loadTimeUs}μs (${(loadTimeUs / 1000).toStringAsFixed(2)}ms)',
    );

    // Cache for subsequent measurements to isolate parsing
    _cachedJsonData = data;

    return (data, loadTimeUs);
  }

  /// Simulated network delay (NOT part of measurement)
  Future<void> _simulateNetworkDelay() async {
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  /// Parse JSON string to Photo list (top-level function for compute())
  static List<Photo> _parseResponse(String json) {
    return photoApiResponseFromJson(json).results;
  }

  /// Fetch photos with instrumented measurements.
  ///
  /// Separates I/O time from parsing time for clean experimental comparison.
  Future<List<Photo>> fetchPhotos() async {
    _logger.info('=== FETCH PHOTOS START ===');
    _logger.info(
      'Toggle largeJsonParse: ${_appConfig.get(FeatureToggle.largeJsonParce)}',
    );

    // Phase 1: Simulate network (not measured - same for both toggle states)
    await _simulateNetworkDelay();

    // Phase 2: Load asset (measured separately)
    final (jsonData, ioTimeUs) = await _loadJsonAsset();
    _logger.info('JSON size: ${jsonData.length} characters');

    // Phase 3: Parse JSON (the experimental variable)
    final useIsolate = _appConfig.get(FeatureToggle.largeJsonParce);

    List<Photo> photos;
    if (useIsolate) {
      // ASYNC PATH: Parse in background isolate
      final (result, _) = await _parsingMetrics.measureAsyncOperation(
        () => compute(_parseResponse, jsonData),
        label: 'JSON_PARSE_ISOLATE',
      );
      photos = result;
    } else {
      // SYNC PATH: Parse on main isolate (blocks UI)
      final (result, _) = await _parsingMetrics.measureSyncOperation(
        () => _parseResponse(jsonData),
        label: 'JSON_PARSE_MAIN',
      );
      photos = result;
    }

    _logger.info('Parsed ${photos.length} photos');
    _logger.info('=== FETCH PHOTOS END ===');

    return photos;
  }

  /// Get parsing metrics for analysis
  ExperimentStats getParsingStats() => _parsingMetrics.getStats();

  /// Print summary of parsing measurements
  void printParsingMetrics() => _parsingMetrics.printSummary();

  /// Reset metrics and cache for fresh measurement
  void resetMetrics() {
    _parsingMetrics.reset();
    _cachedJsonData = null;
  }
}
