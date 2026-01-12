# Experimental Methodology

## Overview

This document describes the scientific methodology for conducting performance experiments on Flutter applications. The methodology ensures reproducibility, statistical validity, and accurate interpretation of results.

## 1. Experimental Design Framework

### 1.1 Single Variable Isolation

Each experiment manipulates **exactly one** independent variable (feature toggle) while keeping all other factors constant.

```
INDEPENDENT VARIABLE: Feature toggle state (false = baseline, true = optimized)
DEPENDENT VARIABLES: Performance metrics (FPS, frame time, memory, etc.)
CONTROL VARIABLES: Device, Flutter version, data size, environmental conditions
```

### 1.2 Hypothesis Structure

Every experiment follows the classical hypothesis structure:

```
NULL HYPOTHESIS (H0): There is no significant difference between conditions
ALTERNATIVE HYPOTHESIS (H1): The optimization produces measurable improvement
```

### 1.3 Measurement Protocol

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        MEASUREMENT PROTOCOL                              │
├─────────────────────────────────────────────────────────────────────────┤
│  1. DEVICE PREPARATION                                                   │
│     ├── Enable airplane mode                                            │
│     ├── Close background apps                                           │
│     ├── Set brightness to 50%                                           │
│     ├── Wait for thermal stability (2 min)                              │
│     └── Verify ADB connection                                           │
│                                                                         │
│  2. WARM-UP PHASE (excluded from analysis)                              │
│     ├── Run N warm-up iterations (N = 3 default)                        │
│     ├── Allows JIT compilation to complete                              │
│     └── Stabilizes memory allocation patterns                           │
│                                                                         │
│  3. MEASUREMENT PHASE                                                    │
│     ├── Run M measurement iterations (M = 10 default)                   │
│     ├── Record all metrics per iteration                                │
│     ├── Pause between iterations (thermal)                              │
│     └── Store raw data                                                  │
│                                                                         │
│  4. ANALYSIS PHASE                                                       │
│     ├── Compute statistical summaries                                   │
│     ├── Calculate effect size                                           │
│     └── Verify control metrics unchanged                                │
└─────────────────────────────────────────────────────────────────────────┘
```

## 2. Statistical Analysis

### 2.1 Preferred Aggregations

| Metric Type                         | Preferred Aggregation | Reason                                   |
| ----------------------------------- | --------------------- | ---------------------------------------- |
| Latency (frame time, response time) | **Median (p50)**      | Robust to outliers, skewed distributions |
| Worst-case behavior                 | **p95, p99**          | Captures tail latency affecting UX       |
| Throughput (FPS)                    | **Mean**              | Total frames / time                      |
| Counts (builds, drops)              | **Sum** or **Mean**   | Depends on comparison type               |
| Memory                              | **Max**               | Peak usage matters for OOM               |

### 2.2 Sample Size Requirements

```
Minimum samples for valid statistics:
  - Mean/Median: 10+ samples
  - Percentiles (p95): 30+ samples
  - Percentiles (p99): 100+ samples

Recommended: 30 samples per condition (total 60 per experiment)
```

### 2.3 Effect Size Calculation

```
ABSOLUTE EFFECT SIZE = optimized_median - baseline_median
RELATIVE EFFECT SIZE = (baseline_median - optimized_median) / baseline_median × 100%

Example:
  Baseline frame time: 18ms
  Optimized frame time: 12ms
  Absolute effect: -6ms
  Relative effect: 33% improvement
```

## 3. Environmental Controls

### 3.1 Device State

| Factor               | Control Method                  | Why                                   |
| -------------------- | ------------------------------- | ------------------------------------- |
| Thermal throttling   | 2-minute cooldown, monitor temp | CPU/GPU frequency affects performance |
| Background processes | Airplane mode, kill apps        | Reduces CPU/memory competition        |
| Screen               | 50% brightness, screen on       | Consistent GPU load                   |
| Battery              | >50% or plugged in              | Low battery may trigger power saving  |

### 3.2 Flutter Environment

| Factor          | Control Method        | Why                                                        |
| --------------- | --------------------- | ---------------------------------------------------------- |
| Build mode      | **Profile mode only** | Debug mode distorts timing; Release strips instrumentation |
| Flutter version | Lock in pubspec.lock  | Engine changes affect metrics                              |
| Dart VM         | Same device           | Different VMs have different GC behavior                   |

### 3.3 Test Data

| Factor        | Control Method         | Why                                      |
| ------------- | ---------------------- | ---------------------------------------- |
| JSON size     | Fixed file (feed.json) | Parse time proportional to size          |
| Image sources | Same URLs              | Network variability eliminated           |
| List size     | Fixed 500 items        | Complexity affects lazy/eager difference |

## 4. Confounding Factors

### 4.1 Known Confounds and Mitigations

| Confound               | Impact                  | Mitigation                          |
| ---------------------- | ----------------------- | ----------------------------------- |
| **JIT Compilation**    | First runs are slower   | Warm-up iterations                  |
| **Garbage Collection** | Random pauses           | Monitor GC events, increase samples |
| **Thermal Throttling** | Progressive slowdown    | Cooldown periods, monitor temp      |
| **Isolate Spawn**      | First compute() is slow | Warm-up for isolate experiments     |
| **Image Cache**        | Second loads are faster | Clear cache before measurement      |

### 4.2 GC Impact Detection

```dart
// Monitor GC events during experiment
final gc = VM.Service.getGCStats();
if (gc.count > threshold) {
  markIterationAsPotentiallyAffected();
}
```

## 5. Metric Sources

### 5.1 Source Hierarchy (Reliability)

```
MOST RELIABLE
│
├── 1. SchedulerBinding.addTimingsCallback
│       - Hardware-backed vsync timestamps
│       - Per-frame build/raster breakdown
│       - Available in Profile mode
│
├── 2. dart:developer Timeline
│       - Microsecond precision
│       - Correlates with DevTools
│       - Custom event markers
│
├── 3. Stopwatch measurements
│       - Simple, reliable
│       - ~1μs precision
│       - Manual instrumentation required
│
├── 4. VM Service Protocol
│       - Memory, CPU, GC stats
│       - Requires service connection
│       - Rich but complex API
│
├── 5. ADB dumpsys
│       - gfxinfo, meminfo
│       - Native-level data
│       - Host-side measurement
│
LEAST RELIABLE
└── 6. Timer-based monitoring
        - ~1ms resolution
        - Cannot detect sub-ms events
        - Only for coarse freeze detection
```

### 5.2 Metric Precision Table

| Metric             | Source      | Precision | Uncertainty        |
| ------------------ | ----------- | --------- | ------------------ |
| Frame build time   | FrameTiming | ~100μs    | ±0.5ms (variance)  |
| Frame raster time  | FrameTiming | ~100μs    | ±0.5ms (variance)  |
| Execution time     | Stopwatch   | ~1μs      | ±1ms (JIT/GC)      |
| Memory (Dart heap) | VM Service  | bytes     | ±100KB (GC timing) |
| Memory (native)    | ADB meminfo | KB        | ±500KB (sampling)  |
| UI freeze          | Timer       | ~50ms     | ±50ms (resolution) |

## 6. Result Interpretation

### 6.1 Decision Matrix

| Observed                                               | Interpretation           | Action                                       |
| ------------------------------------------------------ | ------------------------ | -------------------------------------------- |
| Optimization improves primary metric by >minEffectSize | **Valid improvement**    | Accept optimization                          |
| Optimization improves but <minEffectSize               | **Marginal improvement** | Consider complexity trade-off                |
| No significant difference                              | **Null result**          | Optimization not effective for this scenario |
| Optimization degrades metrics                          | **Regression**           | Investigate; may indicate bug                |
| Control metrics changed                                | **Invalid experiment**   | Confounding variable; redo                   |

### 6.2 Common Pitfalls

```
❌ PITFALL: Measuring FPS when device can hit 60 FPS in both conditions
   → FPS ceiling masks improvement
   → USE: Frame time percentiles instead

❌ PITFALL: Reporting "total load time" for JSON parsing
   → Confounds async I/O with sync parsing
   → USE: Separate I/O time and parse time metrics

❌ PITFALL: Using mean for frame times
   → Outliers skew results
   → USE: Median and percentiles

❌ PITFALL: Single iteration measurements
   → Cannot account for variance
   → USE: Multiple iterations with statistics

❌ PITFALL: Testing in Debug mode
   → Timing is severely distorted
   → USE: Profile mode only
```

### 6.3 Reporting Template

```markdown
## Experiment: [SCN-ID] [Name]

### Hypothesis

[Clear statement of what we're testing]

### Conditions

- Baseline: toggle=false ([description])
- Optimized: toggle=true ([description])

### Results

| Metric    | Baseline (p50) | Optimized (p50) | Delta   | % Change |
| --------- | -------------- | --------------- | ------- | -------- |
| [metric1] | [value]        | [value]         | [value] | [%]      |
| [metric2] | [value]        | [value]         | [value] | [%]      |

### Statistical Summary

- Sample size: N=30 per condition
- Confidence: 95% CI for median
- Effect size: [value]

### Conclusion

[Accept/Reject hypothesis with evidence]

### Limitations

[Any caveats or conditions where this may not apply]
```

## 7. Reproducibility Checklist

Before publishing results, verify:

- [ ] Device model and Android version documented
- [ ] Flutter version (output of `flutter --version`)
- [ ] Git commit hash of test code
- [ ] Build mode confirmed as Profile
- [ ] Warm-up iterations specified
- [ ] Sample size specified
- [ ] Statistical method described
- [ ] Raw data preserved
- [ ] Environmental conditions noted
- [ ] Known limitations documented

## 8. References

1. Flutter Performance Best Practices: https://docs.flutter.dev/perf
2. Flutter DevTools: https://docs.flutter.dev/tools/devtools
3. Dart VM Service Protocol: https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/service.md
4. Android Performance: https://developer.android.com/topic/performance
