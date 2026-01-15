/// Scenario Registry
///
/// Central registry of all experiment scenarios.
library;

import 'package:flutter/foundation.dart';

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
  debugPrint('=' * 60);
  debugPrint('AVAILABLE EXPERIMENT SCENARIOS');
  debugPrint('=' * 60);

  for (final scenario in allScenarios) {
    debugPrint('');
    debugPrint('${scenario.id}: ${scenario.name}');
    debugPrint('  Toggle: ${scenario.toggleName}');
    debugPrint('  Primary metrics:');
    for (final metric in scenario.dependentVariables.take(2)) {
      debugPrint('    - ${metric.name} (${metric.unit.name})');
    }
  }

  debugPrint('');
  debugPrint('=' * 60);
}
