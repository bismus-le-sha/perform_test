# Known Limitations

This document catalogs the limitations, constraints, and potential sources of error in the experimental framework.

## 1. Platform Limitations

### 1.1 Flutter Profile Mode

| Limitation                        | Impact                           | Workaround                                  |
| --------------------------------- | -------------------------------- | ------------------------------------------- |
| Not identical to Release          | Minor performance differences    | Document, compare with Release sporadically |
| Instrumentation overhead          | ~1-5% overhead                   | Consistent across conditions                |
| Timeline not available in Release | Cannot validate Release behavior | Use systrace for Release                    |

### 1.2 Android-Specific

| Limitation          | Impact                 | Workaround                   |
| ------------------- | ---------------------- | ---------------------------- |
| Thermal throttling  | Progressive slowdown   | Cooldown periods, short runs |
| Background services | CPU/memory competition | Airplane mode, kill apps     |
| Doze mode           | May pause app          | Keep screen on, plugged in   |
| ART compilation     | Initial runs slower    | Warm-up iterations           |

### 1.3 Device-Specific (Samsung Galaxy A12)

| Limitation    | Impact                          | Workaround                 |
| ------------- | ------------------------------- | -------------------------- |
| Mid-range GPU | May not show high-end behaviors | Document device class      |
| 60Hz display  | FPS capped at 60                | Measure frame time instead |
| 3GB RAM       | Memory pressure more visible    | Good for testing limits    |

## 2. Measurement Limitations

### 2.1 Frame Timing

```
LIMITATION: SchedulerBinding.addTimingsCallback
- May miss frames during severe UI blocking
- Callback itself adds ~0.01ms overhead
- vsyncOverhead can be affected by system load

IMPACT: Very severe freezes (>500ms) may show fewer dropped frames than actual

WORKAROUND: Supplement with UiFreezeMonitor for freeze detection
```

### 2.2 Stopwatch Precision

```
LIMITATION: dart:core Stopwatch
- ~1μs precision, but JIT/GC can add ms-level noise
- First invocation may include JIT compilation

IMPACT: Individual measurements may have ±1ms variance

WORKAROUND: Use warm-up iterations, statistical analysis
```

### 2.3 Timer Resolution

```
LIMITATION: dart:async Timer
- ~1ms minimum resolution on most platforms
- Cannot detect sub-millisecond events
- Timer itself runs on main isolate

IMPACT: UiFreezeMonitor cannot detect freezes <50ms accurately

WORKAROUND: Use for coarse freeze detection only; rely on FrameTiming for precise analysis
```

### 2.4 Memory Measurement

```
LIMITATION: VM Service Memory API
- Reports Dart heap only
- Does not include native allocations, GPU memory
- GC timing affects readings

IMPACT: Image memory (GPU textures) not directly measurable

WORKAROUND: Calculate from image dimensions (W×H×4); use ADB meminfo for total
```

## 3. Experimental Design Limitations

### 3.1 Toggle Interaction

```
LIMITATION: Some toggles may interact
- staticPlaceholder disables shimmer, affecting minimizeExpensiveRendering test
- lazyLoad affects scroll behavior, which affects correctDataUpdate test

IMPACT: Running multiple toggles simultaneously may confound results

WORKAROUND: Test toggles in isolation; document any interactions
```

### 3.2 Test Automation Overhead

```
LIMITATION: Integration test framework adds overhead
- WidgetTester.pump() is not instant
- Test isolation requires app restart
- Flutter driver has communication overhead

IMPACT: Measured times include test framework overhead

WORKAROUND: Measure relative differences (same overhead in both conditions)
```

### 3.3 Sample Size Constraints

```
LIMITATION: Practical limits on iteration count
- Each iteration takes time
- Device heats up over long runs
- Researcher patience

IMPACT: May not achieve statistical significance for small effects

WORKAROUND: Focus on large effect sizes; increase iterations for marginal results
```

## 4. Metric-Specific Limitations

### 4.1 SCN-FIB (Fibonacci)

| Limitation                 | Impact                              | Mitigation                |
| -------------------------- | ----------------------------------- | ------------------------- |
| Isolate spawn overhead     | First compute() includes spawn time | Warm-up iterations        |
| No actual work result used | Optimizer might eliminate           | Use result (print/store)  |
| Fixed N=42                 | May not represent real workloads    | Document, test multiple N |

### 4.2 SCN-JSON (JSON Parsing)

| Limitation              | Impact                             | Mitigation                 |
| ----------------------- | ---------------------------------- | -------------------------- |
| compute() serialization | Adds overhead beyond parsing       | Measure and document       |
| Model complexity varies | Different models parse differently | Use same model             |
| File caching            | Second read may be from cache      | Clear cache or use network |

### 4.3 SCN-REBUILD (Widget Rebuild)

| Limitation             | Impact                  | Mitigation                        |
| ---------------------- | ----------------------- | --------------------------------- |
| Simple widget          | May not show FPS impact | Document; primary metric is count |
| Flutter optimizations  | May skip actual repaint | Measure build() call count        |
| Scroll velocity varies | Affects event count     | Use programmatic scroll           |

### 4.4 SCN-LAZY (Lazy Loading)

| Limitation                                  | Impact                             | Mitigation                 |
| ------------------------------------------- | ---------------------------------- | -------------------------- |
| Build() stopwatch measures different things | Eager/lazy not directly comparable | Document carefully         |
| ListView cacheExtent                        | Affects how many items pre-built   | Use default or document    |
| Network images                              | Async loading confounds            | Use local assets or cached |

### 4.5 SCN-IMG (Image Memory)

| Limitation                         | Impact                    | Mitigation                |
| ---------------------------------- | ------------------------- | ------------------------- |
| GPU memory not directly measurable | Cannot verify GPU savings | Calculate from dimensions |
| ImageCache affects measurements    | Second load from cache    | Clear cache before test   |
| DPR varies by device               | Results not portable      | Document DPR              |

### 4.6 SCN-SHIMMER (Shimmer Effect)

| Limitation               | Impact                            | Mitigation           |
| ------------------------ | --------------------------------- | -------------------- |
| FPS ceiling              | High-end devices hit 60 in both   | Measure raster time  |
| Simple shader            | More complex shaders differ more  | Document shader type |
| Thermal during animation | Continuous animation heats device | Limit duration       |

## 5. Environmental Limitations

### 5.1 Cannot Fully Control

```
- Android system services (may spike CPU)
- Memory pressure from system
- Exact thermal state
- ART garbage collection timing
- Display vsync jitter
```

### 5.2 Partially Controllable

```
- Background app CPU usage (airplane mode helps)
- Screen brightness (set to 50%)
- Battery optimization (disable for test app)
- Animation scales (leave at 1.0)
```

## 6. Interpretation Limitations

### 6.1 Generalizability

```
WARNING: Results from Samsung Galaxy A12 may not generalize to:
- High-end devices (may show no difference due to headroom)
- Low-end devices (may show larger differences)
- Different Android versions
- iOS devices

RECOMMENDATION: Test on device class representative of target users
```

### 6.2 Workload Representativeness

```
WARNING: Synthetic benchmarks may not reflect real app behavior:
- Fixed data sizes vs. variable real data
- Controlled timing vs. user interaction patterns
- Clean state vs. accumulated app state

RECOMMENDATION: Supplement with real-world testing
```

## 7. Documentation Gaps

### 7.1 What This Framework Does NOT Measure

1. **User-perceived performance** - Subjective, requires user studies
2. **Battery consumption** - Requires specialized tools (Battery Historian)
3. **Network performance** - Intentionally excluded via local assets
4. **Startup time** - Separate measurement methodology needed
5. **Animation smoothness** - Frame time is proxy, not direct measure

### 7.2 Future Improvements Needed

- [ ] Add VM Service integration for GC monitoring
- [ ] Add systrace support for native-level analysis
- [ ] Add automated thermal monitoring
- [ ] Add cross-device comparison framework
- [ ] Add battery measurement integration
