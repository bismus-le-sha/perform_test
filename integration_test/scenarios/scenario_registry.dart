/// Scenario Registry
///
/// Central registry of all experiment scenarios.
library;

import 'scn_fibonacci.dart';
import 'scn_json_parsing.dart';
import 'scn_widget_rebuild.dart';
import 'scn_lazy_loading.dart';
import 'scn_image_memory.dart';
import 'scn_shimmer.dart';
import 'base_scenario.dart';

/// All available experiment scenarios.
final List<ExperimentScenario> allScenarios = [
  FibonacciScenario(),
  JsonParsingScenario(),
  WidgetRebuildScenario(),
  LazyLoadingScenario(),
  ImageMemoryScenario(),
  ShimmerScenario(),
];

/// Get scenario by ID.
ExperimentScenario? getScenarioById(String id) {
  return allScenarios.where((s) => s.id == id).firstOrNull;
}

/// Get scenario by toggle name.
ExperimentScenario? getScenarioByToggle(String toggleName) {
  return allScenarios.where((s) => s.toggleName == toggleName).firstOrNull;
}

/// Print all scenarios summary.
void printScenariosSummary() {
  print('=' * 60);
  print('AVAILABLE EXPERIMENT SCENARIOS');
  print('=' * 60);

  for (final scenario in allScenarios) {
    print('');
    print('${scenario.id}: ${scenario.name}');
    print('  Toggle: ${scenario.toggleName}');
    print('  Primary metrics:');
    for (final metric in scenario.dependentVariables.take(2)) {
      print('    - ${metric.name} (${metric.unit.name})');
    }
  }

  print('');
  print('=' * 60);
}
