/// Experiment Result Exporter
///
/// Handles export of experiment results to JSON and CSV formats with
/// full metadata for reproducibility.
library;

import 'dart:convert';
import 'dart:io';

import '../scenarios/base_scenario.dart';
import 'unified_metrics_collector.dart';

/// Exports experiment results with full metadata.
class ResultExporter {
  final String outputDirectory;

  ResultExporter({required this.outputDirectory});

  /// Export a single experiment result.
  Future<String> exportResult({
    required ExperimentScenario scenario,
    required bool isOptimized,
    required UnifiedMetricsCollector collector,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final environment = await _collectEnvironment();
    final timestamp = DateTime.now();

    final result = {
      'metadata': {
        'scenario': scenario.toMetadata(),
        'condition': isOptimized ? 'optimized' : 'baseline',
        'timestamp': timestamp.toIso8601String(),
        'timestampUnix': timestamp.millisecondsSinceEpoch,
        ...environment,
        if (additionalMetadata != null) ...additionalMetadata,
      },
      'metrics': collector.exportToJson(),
    };

    // Generate filename
    final filename = _generateFilename(scenario.id, isOptimized, timestamp);

    // Save JSON
    final jsonPath = '$outputDirectory/$filename.json';
    await _writeJson(jsonPath, result);

    // Also save CSV for easy spreadsheet import
    final csvPath = '$outputDirectory/$filename.csv';
    await _writeCsv(csvPath, result);

    return jsonPath;
  }

  /// Export comparison between baseline and optimized.
  Future<String> exportComparison({
    required ExperimentScenario scenario,
    required Map<String, dynamic> baselineResult,
    required Map<String, dynamic> optimizedResult,
  }) async {
    final timestamp = DateTime.now();

    final comparison = {
      'metadata': {
        'scenario': scenario.toMetadata(),
        'timestamp': timestamp.toIso8601String(),
        'type': 'comparison',
      },
      'baseline': baselineResult,
      'optimized': optimizedResult,
      'analysis': _computeComparison(baselineResult, optimizedResult),
    };

    final filename = '${scenario.id}_comparison_${_formatTimestamp(timestamp)}';
    final path = '$outputDirectory/$filename.json';

    await _writeJson(path, comparison);
    return path;
  }

  /// Export batch results (all experiments).
  Future<String> exportBatch({
    required List<Map<String, dynamic>> results,
    required String batchId,
  }) async {
    final timestamp = DateTime.now();
    final environment = await _collectEnvironment();

    final batch = {
      'batchId': batchId,
      'timestamp': timestamp.toIso8601String(),
      'environment': environment,
      'resultCount': results.length,
      'results': results,
    };

    final filename = 'batch_${batchId}_${_formatTimestamp(timestamp)}';
    final path = '$outputDirectory/$filename.json';

    await _writeJson(path, batch);
    return path;
  }

  // ===========================================================================
  // ENVIRONMENT COLLECTION
  // ===========================================================================

  Future<Map<String, dynamic>> _collectEnvironment() async {
    final env = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'dartVersion': Platform.version,
      'locale': Platform.localeName,
      'numberOfProcessors': Platform.numberOfProcessors,
    };

    // Flutter version
    try {
      final flutterResult = await Process.run('flutter', [
        '--version',
        '--machine',
      ]);
      if (flutterResult.exitCode == 0) {
        env['flutter'] = jsonDecode(flutterResult.stdout as String);
      }
    } catch (_) {
      env['flutter'] = 'unavailable';
    }

    // Git commit hash
    try {
      final gitResult = await Process.run('git', ['rev-parse', 'HEAD']);
      if (gitResult.exitCode == 0) {
        env['commitHash'] = (gitResult.stdout as String).trim();
      }
    } catch (_) {
      env['commitHash'] = 'unavailable';
    }

    // Git branch
    try {
      final branchResult = await Process.run('git', [
        'rev-parse',
        '--abbrev-ref',
        'HEAD',
      ]);
      if (branchResult.exitCode == 0) {
        env['gitBranch'] = (branchResult.stdout as String).trim();
      }
    } catch (_) {
      env['gitBranch'] = 'unavailable';
    }

    // Device info (Android via ADB)
    try {
      final deviceResult = await Process.run('adb', [
        'shell',
        'getprop',
        'ro.product.model',
      ]);
      if (deviceResult.exitCode == 0) {
        env['deviceModel'] = (deviceResult.stdout as String).trim();
      }

      final androidResult = await Process.run('adb', [
        'shell',
        'getprop',
        'ro.build.version.release',
      ]);
      if (androidResult.exitCode == 0) {
        env['androidVersion'] = (androidResult.stdout as String).trim();
      }
    } catch (_) {
      env['device'] = 'unavailable (no ADB)';
    }

    return env;
  }

  // ===========================================================================
  // FILE OPERATIONS
  // ===========================================================================

  Future<void> _writeJson(String path, Map<String, dynamic> data) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<void> _writeCsv(String path, Map<String, dynamic> data) async {
    final file = File(path);
    await file.parent.create(recursive: true);

    final buffer = StringBuffer();

    // Header row
    buffer.writeln('metric_name,value,unit,aggregation');

    // Extract metrics
    final metrics = data['metrics'] as Map<String, dynamic>?;
    if (metrics != null) {
      _flattenMetricsToCsv(metrics, buffer, '');
    }

    await file.writeAsString(buffer.toString());
  }

  void _flattenMetricsToCsv(
    Map<String, dynamic> metrics,
    StringBuffer buffer,
    String prefix,
  ) {
    for (final entry in metrics.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      final value = entry.value;

      if (value is Map<String, dynamic>) {
        _flattenMetricsToCsv(value, buffer, key);
      } else if (value is num) {
        buffer.writeln('$key,$value,,');
      } else if (value is List) {
        // Skip raw arrays, they're already in stats
      }
    }
  }

  String _generateFilename(
    String scenarioId,
    bool isOptimized,
    DateTime timestamp,
  ) {
    final condition = isOptimized ? 'opt' : 'base';
    return '${scenarioId}_${condition}_${_formatTimestamp(timestamp)}';
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}'
        '_${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}';
  }

  // ===========================================================================
  // COMPARISON ANALYSIS
  // ===========================================================================

  Map<String, dynamic> _computeComparison(
    Map<String, dynamic> baseline,
    Map<String, dynamic> optimized,
  ) {
    final analysis = <String, dynamic>{};

    // Extract frame timing comparisons
    final baselineFrames = baseline['metrics']?['frameTimings']?['summary'];
    final optimizedFrames = optimized['metrics']?['frameTimings']?['summary'];

    if (baselineFrames != null && optimizedFrames != null) {
      analysis['frameTimings'] = {
        'avgFpsDelta':
            (optimizedFrames['avgFps'] ?? 0) - (baselineFrames['avgFps'] ?? 0),
        'jankPercentDelta':
            (optimizedFrames['jankPercent'] ?? 0) -
            (baselineFrames['jankPercent'] ?? 0),
        'p95FrameTimeDelta':
            (optimizedFrames['totalStats']?['p95'] ?? 0) -
            (baselineFrames['totalStats']?['p95'] ?? 0),
      };
    }

    // Custom metrics comparison
    final baselineCustom =
        baseline['metrics']?['customMetrics'] as Map<String, dynamic>?;
    final optimizedCustom =
        optimized['metrics']?['customMetrics'] as Map<String, dynamic>?;

    if (baselineCustom != null && optimizedCustom != null) {
      final customComparison = <String, dynamic>{};

      for (final key in baselineCustom.keys) {
        if (optimizedCustom.containsKey(key)) {
          final baseMedian = baselineCustom[key]?['stats']?['median'] ?? 0;
          final optMedian = optimizedCustom[key]?['stats']?['median'] ?? 0;

          customComparison[key] = {
            'baselineMedian': baseMedian,
            'optimizedMedian': optMedian,
            'absoluteDelta': optMedian - baseMedian,
            'percentChange': baseMedian != 0
                ? ((optMedian - baseMedian) / baseMedian * 100)
                : 0,
          };
        }
      }

      analysis['customMetrics'] = customComparison;
    }

    return analysis;
  }
}

/// Result file naming convention.
///
/// Format: {SCENARIO_ID}_{CONDITION}_{YYYYMMDD}_{HHMMSS}.{ext}
///
/// Examples:
/// - SCN-FIB_base_20260112_143022.json
/// - SCN-FIB_opt_20260112_143522.json
/// - SCN-FIB_comparison_20260112_144022.json
/// - batch_full_20260112_150000.json
