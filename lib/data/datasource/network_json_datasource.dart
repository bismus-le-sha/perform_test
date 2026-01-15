import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:perform_test/core/config/feature_toggle.dart';
import 'package:perform_test/service/app_config/app_config.dart';

/// Model for large JSON test data from json-iterator/test-data
///
/// Sample entry structure:
/// {
///   "id": 2489651045,
///   "type": "CreateEvent",
///   "actor": {...},
///   "repo": {...},
///   "payload": {...},
///   "public": true,
///   "created_at": "2015-01-01T15:00:00Z"
/// }
class GitHubEvent {
  final int id;
  final String type;
  final Map<String, dynamic> actor;
  final Map<String, dynamic> repo;
  final Map<String, dynamic> payload;
  final bool public;
  final String createdAt;

  GitHubEvent({
    required this.id,
    required this.type,
    required this.actor,
    required this.repo,
    required this.payload,
    required this.public,
    required this.createdAt,
  });

  factory GitHubEvent.fromJson(Map<String, dynamic> json) {
    return GitHubEvent(
      id: json['id'] as int,
      type: json['type'] as String,
      actor: json['actor'] as Map<String, dynamic>,
      repo: json['repo'] as Map<String, dynamic>,
      payload: json['payload'] as Map<String, dynamic>,
      public: json['public'] as bool,
      createdAt: json['created_at'] as String,
    );
  }
}

/// Result of network JSON fetch operation with detailed metrics
class NetworkJsonResult {
  final List<GitHubEvent> events;
  final int downloadTimeMs;
  final int parseTimeMs;
  final int totalTimeMs;
  final int jsonSizeBytes;
  final int eventCount;
  final bool usedIsolate;

  NetworkJsonResult({
    required this.events,
    required this.downloadTimeMs,
    required this.parseTimeMs,
    required this.totalTimeMs,
    required this.jsonSizeBytes,
    required this.eventCount,
    required this.usedIsolate,
  });

  Map<String, dynamic> toMetrics() => {
    'downloadTimeMs': downloadTimeMs,
    'parseTimeMs': parseTimeMs,
    'totalTimeMs': totalTimeMs,
    'jsonSizeBytes': jsonSizeBytes,
    'jsonSizeMB': (jsonSizeBytes / 1024 / 1024).toStringAsFixed(2),
    'eventCount': eventCount,
    'usedIsolate': usedIsolate,
  };
}

/// Data source for fetching and parsing large JSON from network.
///
/// EXPERIMENT: largeJsonParce toggle (network variant)
///
/// Uses GitHub Events data (~25MB JSON) to stress-test JSON parsing
/// performance on mobile devices.
///
/// DATA SOURCE:
/// https://raw.githubusercontent.com/json-iterator/test-data/master/large-file.json
class NetworkJsonDatasource {
  final Logger _logger;
  final AppConfig _appConfig;

  /// URL for large test JSON (~25MB, ~11000 GitHub events)
  static const String _jsonUrl =
      'https://raw.githubusercontent.com/json-iterator/test-data/refs/heads/master/large-file.json';

  /// Cached JSON string for repeated benchmarks
  String? _cachedJsonData;

  NetworkJsonDatasource({required Logger logger, required AppConfig appConfig})
    : _logger = logger,
      _appConfig = appConfig;

  /// Download JSON from network with progress tracking
  Future<(String, int)> _downloadJson() async {
    // Return cached if available (for benchmark mode)
    if (_cachedJsonData != null) {
      _logger.fine('Using cached network JSON data');
      return (_cachedJsonData!, 0);
    }

    developer.Timeline.startSync('NETWORK_JSON_DOWNLOAD');
    final sw = Stopwatch()..start();

    try {
      _logger.info('Starting download from: $_jsonUrl');

      final response = await http.get(Uri.parse(_jsonUrl));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: Failed to download JSON');
      }

      sw.stop();
      developer.Timeline.finishSync();

      final downloadTimeMs = sw.elapsedMilliseconds;
      final data = response.body;

      _logger.info(
        'Download complete: ${data.length} bytes in ${downloadTimeMs}ms',
      );
      _logger.info(
        'Download speed: ${(data.length / 1024 / downloadTimeMs * 1000).toStringAsFixed(1)} KB/s',
      );

      // Cache for subsequent benchmarks
      _cachedJsonData = data;

      return (data, downloadTimeMs);
    } catch (e) {
      sw.stop();
      developer.Timeline.finishSync();
      _logger.severe('Download failed: $e');
      rethrow;
    }
  }

  /// Parse JSON string to GitHubEvent list (top-level function for compute())
  static List<GitHubEvent> _parseJsonToEvents(String jsonString) {
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
    return jsonList
        .map((item) => GitHubEvent.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetch and parse large JSON with instrumented measurements.
  ///
  /// Uses largeJsonParce toggle:
  /// - false: Parse on main isolate (BLOCKS UI)
  /// - true: Parse via compute() (UI RESPONSIVE)
  Future<NetworkJsonResult> fetchLargeJson() async {
    final totalStopwatch = Stopwatch()..start();
    final useIsolate = _appConfig.get(FeatureToggle.largeJsonParce);

    _logger.info('=== NETWORK JSON FETCH START ===');
    _logger.info('Toggle largeJsonParce: $useIsolate');

    // Phase 1: Download (same for both toggle states)
    final (jsonData, downloadTimeMs) = await _downloadJson();
    final jsonSizeBytes = jsonData.length;

    _logger.info(
      'JSON size: ${(jsonSizeBytes / 1024 / 1024).toStringAsFixed(2)} MB',
    );

    // Phase 2: Parse JSON (the experimental variable)
    List<GitHubEvent> events;
    int parseTimeMs;

    if (useIsolate) {
      // ASYNC PATH: Parse in background isolate
      _logger.info('Parsing in background isolate...');

      developer.Timeline.startSync('NETWORK_JSON_PARSE_ISOLATE');
      final parseSw = Stopwatch()..start();

      events = await compute(_parseJsonToEvents, jsonData);

      parseSw.stop();
      developer.Timeline.finishSync();
      parseTimeMs = parseSw.elapsedMilliseconds;

      _logger.info('Isolate parse time: ${parseTimeMs}ms');
    } else {
      // SYNC PATH: Parse on main isolate (blocks UI)
      _logger.info('Parsing on main isolate (will block UI)...');

      developer.Timeline.startSync('NETWORK_JSON_PARSE_MAIN');
      final parseSw = Stopwatch()..start();

      events = _parseJsonToEvents(jsonData);

      parseSw.stop();
      developer.Timeline.finishSync();
      parseTimeMs = parseSw.elapsedMilliseconds;

      _logger.info('Main thread parse time: ${parseTimeMs}ms');
    }

    totalStopwatch.stop();
    final totalTimeMs = totalStopwatch.elapsedMilliseconds;

    _logger.info('Parsed ${events.length} events');
    _logger.info(
      'Total time: ${totalTimeMs}ms (download: ${downloadTimeMs}ms, parse: ${parseTimeMs}ms)',
    );
    _logger.info('=== NETWORK JSON FETCH END ===');

    return NetworkJsonResult(
      events: events,
      downloadTimeMs: downloadTimeMs,
      parseTimeMs: parseTimeMs,
      totalTimeMs: totalTimeMs,
      jsonSizeBytes: jsonSizeBytes,
      eventCount: events.length,
      usedIsolate: useIsolate,
    );
  }

  /// Clear cached data to force fresh download
  void clearCache() {
    _cachedJsonData = null;
    _logger.info('Network JSON cache cleared');
  }

  /// Check if data is cached
  bool get hasCachedData => _cachedJsonData != null;

  /// Get JSON URL for display
  String get jsonUrl => _jsonUrl;
}
