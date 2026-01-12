# Performance Experiments Framework

## Overview

This directory contains the fully automated, reproducible experimental testbed for evaluating Flutter performance optimization techniques.

## Architecture

```
experiments/
├── scenarios/           # Formal experiment definitions
│   ├── base_scenario.dart
│   ├── scn_fibonacci.dart
│   ├── scn_json_parsing.dart
│   ├── scn_widget_rebuild.dart
│   ├── scn_lazy_loading.dart
│   ├── scn_image_memory.dart
│   └── scn_shimmer.dart
│
├── metrics/             # Metric collection infrastructure
│   ├── metric_collector.dart
│   ├── vm_service_client.dart
│   ├── adb_metrics.dart
│   └── metric_definitions.dart
│
├── scripts/             # Automation scripts
│   ├── run_experiment.dart
│   ├── run_all_experiments.ps1
│   └── device_preparation.ps1
│
├── results/             # Experiment outputs (gitignored except templates)
│   └── .gitkeep
│
└── docs/                # Methodology documentation
    ├── METHODOLOGY.md
    ├── METRICS_REFERENCE.md
    ├── LIMITATIONS.md
    └── INTERPRETATION_GUIDE.md
```

## Quick Start

```bash
# 1. Prepare device
./experiments/scripts/device_preparation.ps1

# 2. Run single experiment
dart run experiments/scripts/run_experiment.dart --scenario=fibonacci --iterations=10

# 3. Run all experiments (batch)
./experiments/scripts/run_all_experiments.ps1
```

## Experimental Design Principles

1. **Single Variable Isolation** - Each experiment tests ONE performance factor
2. **Reproducibility** - Same inputs → Same outputs across runs
3. **Warm-up** - JIT compilation effects excluded via warm-up iterations
4. **Statistical Rigor** - Percentile-based analysis (p50, p95, p99)
5. **Environmental Control** - Device state, thermal, background processes documented

## Device Under Test

| Property     | Value                           |
| ------------ | ------------------------------- |
| Device       | Samsung Galaxy A12 SM-A125F/DSN |
| Android      | 12                              |
| Flutter Mode | Profile                         |
| Connection   | USB (ADB)                       |

## Known Limitations

See [docs/LIMITATIONS.md](docs/LIMITATIONS.md) for complete list.
