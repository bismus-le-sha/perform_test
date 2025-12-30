# Performance Experiment Testbed - Hypothesis Documentation

This document defines the experimental hypotheses, metrics, and expected outcomes for each feature toggle in this Flutter performance benchmark harness.

## Experimental Design Principles

1. **Single Variable Isolation**: Each toggle tests ONE performance factor
2. **Clean Baselines**: The `false` state represents the unoptimized baseline
3. **Measurable Differences**: Metrics should show clear, reproducible differences
4. **No Confounding Effects**: Toggles should not interfere with each other

---

## Experiment 1: `optimFibonacci`

### Hypothesis

Heavy synchronous computation on the main isolate blocks the UI thread, causing dropped frames and visible freeze. Using `compute()` offloads work to a background isolate, keeping the UI responsive during computation.

### Toggle States

| State   | Behavior                                                      |
| ------- | ------------------------------------------------------------- |
| `false` | Recursive Fibonacci (n=42) runs synchronously on main isolate |
| `true`  | Fibonacci runs via `compute()` in background isolate          |

### Metrics to Measure

| Metric                 | Sync (false) | Async (true) | Why                                |
| ---------------------- | ------------ | ------------ | ---------------------------------- |
| Computation time       | ~2000ms      | ~2000ms      | Should be SAME (isolated variable) |
| UI freeze duration     | ~2000ms      | ~0ms         | KEY DIFFERENTIATOR                 |
| Frame drops            | HIGH         | ZERO         | Observable in DevTools             |
| FPS during computation | 0            | 60           | UI responsiveness                  |

### What Should NOT Change

- Computation result (both produce same Fibonacci number)
- Total elapsed time (async overhead is minimal)

### Measurement Method

- `ExperimentMetrics.measureSyncOperation()` for sync path
- `ExperimentMetrics.measureAsyncOperation()` for async path
- `UiFreezeMonitor` for freeze detection
- `FrameStatsCollector` for frame drops

---

## Experiment 2: `correctDataUpdate`

### Hypothesis

Calling `setState()` on every scroll event causes excessive widget rebuilds, even when the visual state doesn't change. Checking if state actually changed before calling `setState()` minimizes unnecessary rebuilds.

### Toggle States

| State   | Behavior                                                                         |
| ------- | -------------------------------------------------------------------------------- |
| `false` | `BadScrollToTopButton` - calls `setState()` on EVERY scroll event                |
| `true`  | `OptimScrollToTopButton` - calls `setState()` only when crossing 100px threshold |

### Metrics to Measure

| Metric                  | Bad (false)         | Optimized (true)               | Why                     |
| ----------------------- | ------------------- | ------------------------------ | ----------------------- |
| Build call count        | HIGH (every scroll) | LOW (threshold crossings only) | Logged via `debugPrint` |
| FPS during scroll       | Potentially lower   | Stable 60                      | Rebuild overhead        |
| Build time accumulation | Higher              | Lower                          | Measured in widget      |

### What Should NOT Change

- Visual appearance of scroll-to-top button
- Scroll behavior
- Button functionality

### Measurement Method

- Count "Bad Button build" / "Optim Button build" log messages
- `FrameStatsCollector` for FPS during scroll
- DevTools widget rebuild indicator

---

## Experiment 3: `lazyLoad`

### Hypothesis

Eagerly building all list items using `Column` is expensive for large lists (500 items). `ListView.separated` lazily builds only visible items plus a small buffer.

### Toggle States

| State   | Behavior                                                              |
| ------- | --------------------------------------------------------------------- |
| `false` | `SingleChildScrollView` + `Column` - ALL items built immediately      |
| `true`  | `ListView.separated` - items built on-demand as they scroll into view |

### Metrics to Measure

| Metric              | Eager (false)                | Lazy (true)          | Why                  |
| ------------------- | ---------------------------- | -------------------- | -------------------- |
| Initial build time  | HIGH (~500 widgets)          | LOW (~10 visible)    | KEY DIFFERENTIATOR   |
| Memory usage        | HIGH (all widgets in memory) | LOW (only visible)   | Widget tree size     |
| Time to first frame | Longer                       | Shorter              | User-perceived speed |
| Scroll jank         | None (pre-built)             | Possible (on-demand) | Trade-off            |

### What Should NOT Change

- Visual appearance of items
- Item content
- Separator spacing (both have 16px gaps)

### Measurement Method

- `Stopwatch` in `PhotoList.build()` (note: measures different things!)
- Memory profiler in DevTools
- `FrameStatsCollector` for scroll performance

### Important Note

The `build()` stopwatch measures DIFFERENT things:

- Eager: Full Column with all 500 children (slow)
- Lazy: Just `ListView.separated` widget creation (fast), itemBuilders run later

---

## Experiment 4: `optimImageSize`

### Hypothesis

Decoding full-resolution images into GPU memory is wasteful when displayed at smaller sizes. Using `cacheWidth`/`cacheHeight` tells Flutter to decode at the target display size, reducing GPU memory usage.

### Toggle States

| State   | Behavior                                                                 |
| ------- | ------------------------------------------------------------------------ |
| `false` | Decode at full resolution (e.g., 4000x3000)                              |
| `true`  | Decode at layout size × devicePixelRatio (e.g., 400x300 @ 3x = 1200x900) |

### Metrics to Measure

| Metric              | Unoptimized (false) | Optimized (true)       | Why                |
| ------------------- | ------------------- | ---------------------- | ------------------ |
| Decoded image bytes | ~48MB (4000×3000×4) | ~4.3MB (1200×900×4)    | KEY DIFFERENTIATOR |
| GPU memory usage    | HIGH                | LOW                    | DevTools GPU view  |
| Raster thread time  | Higher              | Lower                  | Less pixel data    |
| Visual quality      | Full                | Sufficient for display | Should look same   |

### What Should NOT Change

- Image URL (both use `photo.urls.regular`)
- Visual appearance (imperceptible at display size)
- Layout dimensions
- FPS (unless memory pressure causes issues)

### Measurement Method

- `ImageMemoryTracker` for decoded bytes
- DevTools Memory view for GPU usage
- `FrameStatsCollector` for raster time

### Critical Implementation Note

This experiment tests CLIENT-SIDE decoding, NOT server-side resizing. Both states download the SAME image; the difference is in how Flutter decodes it for display.

---

## Experiment 5: `minimizeExpensiveRendering`

### Hypothesis

Multiple `ShaderMask` widgets each trigger independent GPU shader computations and `setState()` calls on every animation frame. Consolidating into a single `ShaderMask` reduces GPU work and state updates.

### Toggle States

| State   | Behavior                                                          |
| ------- | ----------------------------------------------------------------- |
| `false` | `BadPlaceHolderWay` - 6 separate `CustomShaderMask` widgets       |
| `true`  | `OptimPlaceHolderWay` - 1 `CustomShaderMask` wrapping all content |

### Metrics to Measure

| Metric               | Bad (false)     | Optimized (true) | Why                 |
| -------------------- | --------------- | ---------------- | ------------------- |
| setState() calls/sec | 360 (6 × 60fps) | 60 (1 × 60fps)   | Animation callbacks |
| Raster thread time   | Higher          | Lower            | Shader computations |
| FPS                  | Potentially <60 | Stable 60        | GPU bottleneck      |

### What Should NOT Change

- Visual appearance of shimmer effect
- Animation timing
- Placeholder layout

### Measurement Method

- Count "setState" or rebuild logs
- `FrameStatsCollector` for raster time
- DevTools performance overlay

---

## Experiment 6: `largeJsonParce`

### Hypothesis

Parsing large JSON (~3.5MB, 500 records) on the main isolate blocks UI rendering. Using `compute()` moves parsing to a background isolate, keeping the UI responsive during data loading.

### Toggle States

| State   | Behavior                                                      |
| ------- | ------------------------------------------------------------- |
| `false` | `_parseResponse()` runs synchronously on main isolate         |
| `true`  | `_parseResponse()` runs via `compute()` in background isolate |

### Metrics to Measure

| Metric                    | Sync (false) | Async (true) | Why                                   |
| ------------------------- | ------------ | ------------ | ------------------------------------- |
| Parse time                | ~Xms         | ~Xms         | Should be SAME (isolated measurement) |
| UI freeze during parse    | YES          | NO           | KEY DIFFERENTIATOR                    |
| Frame drops               | HIGH         | ZERO         | Observable                            |
| Shimmer animation stutter | YES          | NO           | Visual indicator                      |

### What Should NOT Change

- Parsed data (same Photo objects)
- File I/O time (measured separately)
- Total load time (similar)

### Measurement Method

- `ExperimentMetrics` with separate I/O and parse phases
- `UiFreezeMonitor` for blocking detection
- `FrameStatsCollector` for frame drops
- Visual observation of shimmer animation

### Implementation Note

File I/O (`rootBundle.loadString`) is measured SEPARATELY from JSON parsing to isolate the parsing cost.

---

## Experiment 7: `staticPlaceholder`

### Hypothesis

Animated shimmer with `ShaderMask` and continuous repaint is more expensive than static placeholders. This toggle isolates the animation cost from layout cost.

### Toggle States

| State   | Behavior                                              |
| ------- | ----------------------------------------------------- |
| `false` | Animated shimmer with `ShaderMask` gradient animation |
| `true`  | Static gray boxes, no animation                       |

### Metrics to Measure

| Metric             | Animated (false)  | Static (true) | Why                 |
| ------------------ | ----------------- | ------------- | ------------------- |
| FPS                | 60 (if optimized) | 60            | Baseline comparison |
| Raster thread time | Higher            | Lower         | No shader work      |
| CPU usage          | Higher            | Lower         | No animation tick   |
| Battery drain      | Higher            | Lower         | Power consumption   |

### What Should NOT Change

- Layout structure
- Placeholder dimensions
- Screen coverage

### Measurement Method

- `FrameStatsCollector` for raster time
- System CPU monitor
- DevTools performance view

### Use Case

This is a BASELINE experiment to isolate the cost of shimmer animation from the cost of placeholder layout.

---

## Running Experiments

### Manual Testing

1. Set toggle to `false` (baseline)
2. Run app and collect metrics for 30+ seconds
3. Set toggle to `true` (optimized)
4. Repeat measurement
5. Compare results

### Automated Benchmarking

```bash
# Profile mode is REQUIRED for accurate measurements
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/benchmark_suite.dart \
  --profile
```

### Statistical Rigor

- Run each configuration 5-10 times
- Report median (p50) as primary metric
- Include p95/p99 for outlier analysis
- Skip warm-up iterations (first 3 runs / 30 frames)

---

## Invalid Comparisons to Avoid

| Bad Comparison               | Why Invalid                                         |
| ---------------------------- | --------------------------------------------------- |
| FPS for `optimFibonacci`     | Sync path has 0 FPS during computation; meaningless |
| Build time for `lazyLoad`    | Measures different things in each mode              |
| Image bytes without same URL | Server-side vs client-side optimization conflated   |
| Multiple toggles enabled     | Confounding effects                                 |

---

## Conclusion

Each experiment is designed to test ONE hypothesis with MEASURABLE outcomes. The baseline (`false`) should always show worse performance than the optimized (`true`) state. Results should be reproducible and defensible in an academic/engineering review.
