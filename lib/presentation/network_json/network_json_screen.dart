import 'package:flutter/material.dart';
import 'package:perform_test/core/config/feature_toggle.dart';
import 'package:perform_test/data/datasource/network_json_datasource.dart';
import 'package:perform_test/di/injection_container.dart' as di;
import 'package:perform_test/service/app_config/app_config.dart';

/// Screen for testing large network JSON parsing performance.
///
/// EXPERIMENT: largeJsonParce toggle (network variant)
///
/// This screen demonstrates the difference between:
/// - Sync parsing on main isolate (UI freezes during parse)
/// - Async parsing via compute() (UI remains responsive)
///
/// The JSON file (~25MB) contains ~11000 GitHub events.
class NetworkJsonScreen extends StatefulWidget {
  const NetworkJsonScreen({super.key});

  @override
  State<NetworkJsonScreen> createState() => _NetworkJsonScreenState();
}

class _NetworkJsonScreenState extends State<NetworkJsonScreen>
    with SingleTickerProviderStateMixin {
  late final NetworkJsonDatasource _datasource;
  late final AppConfig _appConfig;
  late final AnimationController _spinnerController;

  NetworkJsonResult? _result;
  String? _error;
  bool _isLoading = false;

  // For UI responsiveness indicator
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _datasource = di.sl<NetworkJsonDatasource>();
    _appConfig = di.sl<AppConfig>();

    // Animation controller for spinner (tests UI responsiveness)
    _spinnerController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(() {
            if (_isLoading) {
              setState(() => _frameCount++);
            }
          });
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    super.dispose();
  }

  bool get _useIsolate => _appConfig.get(FeatureToggle.largeJsonParce);

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _result = null;
      _error = null;
      _frameCount = 0;
    });

    // Start spinner animation
    _spinnerController.repeat();

    try {
      final result = await _datasource.fetchLargeJson();

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    } finally {
      _spinnerController.stop();
    }
  }

  void _clearCache() {
    _datasource.clearCache();
    setState(() {
      _result = null;
      _error = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
  }

  void _toggleMode() {
    _appConfig.set(FeatureToggle.largeJsonParce, !_useIsolate);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network JSON Parse'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear cache',
            onPressed: _clearCache,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Experiment info card
            _buildInfoCard(),
            const SizedBox(height: 16),

            // Toggle switch
            _buildToggleCard(),
            const SizedBox(height: 16),

            // Action button
            _buildActionButton(),
            const SizedBox(height: 16),

            // Loading indicator with frame counter
            if (_isLoading) _buildLoadingIndicator(),

            // Results
            if (_result != null) _buildResultsCard(),

            // Error
            if (_error != null) _buildErrorCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'SCN-NETWORK-JSON',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'HYPOTHESIS:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Parsing large JSON (~25MB) on main isolate blocks UI significantly. '
              'Using compute() keeps UI responsive during parsing.',
            ),
            const SizedBox(height: 12),
            const Text(
              'DATA SOURCE:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              _datasource.jsonUrl,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _datasource.hasCachedData
                      ? Icons.cached
                      : Icons.cloud_download,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  _datasource.hasCachedData
                      ? 'Data cached (instant load)'
                      : 'Will download from network',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard() {
    return Card(
      color: _useIsolate ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _useIsolate ? 'OPTIMIZED' : 'BASELINE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _useIsolate
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                    Text(
                      _useIsolate
                          ? 'Parse via compute() (UI responsive)'
                          : 'Parse on main isolate (UI blocks)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                Switch(
                  value: _useIsolate,
                  onChanged: (_) => _toggleMode(),
                  activeThumbColor: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _fetchData,
      icon: Icon(_isLoading ? Icons.hourglass_empty : Icons.play_arrow),
      label: Text(_isLoading ? 'Loading...' : 'FETCH & PARSE JSON'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Spinner (should rotate smoothly if UI is responsive)
            RotationTransition(
              turns: _spinnerController,
              child: const Icon(
                Icons.refresh,
                size: 48,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'UI Responsiveness Test',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Frame updates: $_frameCount',
              style: const TextStyle(
                fontSize: 24,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _useIsolate
                  ? 'Counter should increment smoothly'
                  : 'Counter may freeze during parse',
              style: TextStyle(
                fontSize: 12,
                color: _useIsolate ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    final result = _result!;
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Results',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            _buildMetricRow(
              'Mode',
              result.usedIsolate ? 'Isolate (async)' : 'Main thread (sync)',
            ),
            _buildMetricRow(
              'JSON Size',
              '${result.toMetrics()['jsonSizeMB']} MB',
            ),
            _buildMetricRow('Events Parsed', '${result.eventCount}'),
            const Divider(),
            _buildMetricRow(
              'Download Time',
              '${result.downloadTimeMs} ms',
              highlight: false,
            ),
            _buildMetricRow(
              'Parse Time',
              '${result.parseTimeMs} ms',
              highlight: true,
            ),
            _buildMetricRow('Total Time', '${result.totalTimeMs} ms'),
            const Divider(),
            _buildMetricRow('UI Frames', '$_frameCount updates'),
            const SizedBox(height: 8),
            // Sample data
            ExpansionTile(
              title: const Text('Sample Event'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'ID: ${result.events.first.id}\n'
                    'Type: ${result.events.first.type}\n'
                    'Created: ${result.events.first.createdAt}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? Colors.deepPurple : null,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
