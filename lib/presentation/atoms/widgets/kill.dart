import 'package:flutter/material.dart';
import 'package:perform_test/core/config/feature_toggle.dart';
import 'package:perform_test/service/app_config/app_config_provider.dart';
import 'package:perform_test/data/datasource/calculate.dart';
import 'package:perform_test/service/metrics_handlers/exec_time.dart';

class KillWidget extends StatefulWidget {
  const KillWidget({super.key});

  @override
  State<KillWidget> createState() => _KillWidgetState();
}

class _KillWidgetState extends State<KillWidget> {
  final int fibonacciNum = 45;
  int? result;
  bool calculating = false;

  @override
  Widget build(BuildContext context) {
    final appConfig = AppConfigProvider.of(context);
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () async {
              setState(() {
                calculating = true;
              });
              await ExecTime().measureUIFreezTime(() async {
                result = appConfig.get(FeatureToggle.optimFibonacci)
                    ? await Calculate().optimCalculateFibonacci(fibonacciNum)
                    : syncFibo(fibonacciNum);
              });
              setState(() {
                calculating = false;
              });
              await WidgetsBinding.instance.endOfFrame;
            },
            child: const Text(
              'KILL UI THREAD ☠️',
              style: TextStyle(fontSize: 40),
            ),
          ),
          Text(
            calculating
                ? "Calculating fibo($fibonacciNum)..."
                : (result != null ? "Result: $result" : "  "),
            style: const TextStyle(fontSize: 40),
          ),
        ],
      ),
    );
  }
}

int syncFibo(int fibonacciNum) {
  int result = 0;
  ExecTime().measureExecutionTime(() async {
    result = await Calculate().calculateFibonacci(fibonacciNum);
  });
  return result;
}
