import 'package:flutter/material.dart';
import 'package:perform_test/core/config/feature_toggle.dart';
import 'package:perform_test/service/app_config/app_config_provider.dart';
import 'package:perform_test/data/datasource/calculate.dart';
import 'package:perform_test/service/metrics_handlers/exec_time.dart';

/// Виджет для демонстрации влияния тяжелых вычислений на UI thread.
/// Позволяет переключаться между синхронными (блокирующими UI) и
/// асинхронными (в isolate) вычислениями.
class KillWidget extends StatefulWidget {
  const KillWidget({super.key});

  @override
  State<KillWidget> createState() => _KillWidgetState();
}

class _KillWidgetState extends State<KillWidget> {
  final int fibonacciNum = 42;
  int? result;
  bool calculating = false;
  final ExecTime _execTime = ExecTime();

  /// Запускает синхронное вычисление на UI thread (блокирует интерфейс).
  /// Измеряет UI blocking time через Timeline и Stopwatch.
  Future<void> _runSyncExperiment() async {
    setState(() => calculating = true);

    // Ждем стабилизации перед экспериментом
    await WidgetsBinding.instance.endOfFrame;

    // Измеряем UI blocking time для синхронного вычисления
    result = await _execTime.measureUIBlockingTime(
      () => Calculate().calculateFibonacciSync(fibonacciNum),
      label: 'FIBONACCI_SYNC_UI_BLOCK',
    );

    setState(() => calculating = false);
  }

  /// Запускает асинхронное вычисление в isolate (не блокирует UI).
  /// Измеряет только computation time, не UI blocking time.
  Future<void> _runIsolateExperiment() async {
    setState(() => calculating = true);

    // Ждем стабилизации перед экспериментом
    await WidgetsBinding.instance.endOfFrame;

    // Измеряем только computation time (не блокирует UI)
    result = await _execTime.measureAsyncExecutionTime(
      () => Calculate().optimCalculateFibonacci(fibonacciNum),
    );

    setState(() => calculating = false);
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = AppConfigProvider.of(context);
    final useIsolate = appConfig.get(FeatureToggle.optimFibonacci);

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: useIsolate ? _runIsolateExperiment : _runSyncExperiment,
            child: Text(
              useIsolate ? 'Calculate in Isolate 🚀' : 'KILL UI THREAD ☠️',
              style: const TextStyle(fontSize: 40),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            calculating
                ? "Calculating fibo($fibonacciNum)..."
                : (result != null ? "Result: $result" : "  "),
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 16),
          Text(
            useIsolate
                ? "Mode: Isolate (non-blocking)"
                : "Mode: Sync (UI blocking)",
            style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
