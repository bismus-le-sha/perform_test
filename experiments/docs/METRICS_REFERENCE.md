# Metrics Reference

## Quick Reference Table

| Metric           | Unit       | Source      | Good Value | Bad Value |
| ---------------- | ---------- | ----------- | ---------- | --------- |
| FPS              | frames/sec | FrameTiming | 60         | <55       |
| Frame time (p50) | ms         | FrameTiming | <10        | >16.67    |
| Frame time (p95) | ms         | FrameTiming | <14        | >20       |
| Jank %           | percent    | FrameTiming | <5%        | >15%      |
| Build time       | ms         | FrameTiming | <4         | >8        |
| Raster time      | ms         | FrameTiming | <12        | >14       |
| UI freeze        | ms         | Timer       | 0          | >200      |
| Dart heap        | MB         | VM Service  | varies     | OOM       |
| Image memory     | MB         | Calculated  | minimized  | unbounded |

## Detailed Metric Definitions

---

### FPS (Frames Per Second)

**Definition:** Number of frames rendered per second.

**Calculation:**

```
FPS = 1000 / avgFrameTimeMs
```

**Source:** Derived from FrameTiming

**Target Values:**

- 60 FPS for 60Hz displays (16.67ms/frame)
- 90 FPS for 90Hz displays (11.11ms/frame)
- 120 FPS for 120Hz displays (8.33ms/frame)

**Limitations:**

- Capped by display refresh rate
- Doesn't show variance (60 FPS could be smooth or janky)
- Single dropped frame doesn't lower average much

**When to Use:** Quick overview metric; supplement with percentiles

---

### Frame Time

**Definition:** Time to render a single frame, from vsync signal to completion.

**Components:**

```
Total Frame Time = Build Time + Layout Time + Paint Time + Raster Time + vsync Wait
                 ≈ Build Time + Raster Time (simplified)
```

**Source:** `SchedulerBinding.addTimingsCallback` → `FrameTiming`

**Target Values:**
| Percentile | Target | Concern | Critical |
|------------|--------|---------|----------|
| p50 | <10ms | >12ms | >16ms |
| p75 | <12ms | >14ms | >18ms |
| p95 | <14ms | >18ms | >25ms |
| p99 | <16ms | >25ms | >50ms |

**Interpretation:**

- p50 (median) = typical user experience
- p95 = 1 in 20 frames; represents occasional hitches
- p99 = 1 in 100 frames; captures worst common case

---

### Build Time

**Definition:** Time spent in the **build phase** (widget tree construction).

**What's Included:**

- `Widget.build()` execution
- `State.setState()` processing
- Element tree reconciliation

**What's Excluded:**

- Layout (`RenderObject.performLayout`)
- Paint (`RenderObject.paint`)
- Raster (GPU operations)

**Source:** `FrameTiming.buildDuration`

**Target:** <4ms (leaves headroom for other phases)

**Optimization Targets:**

- Reduce unnecessary rebuilds (SCN-REBUILD)
- Use `const` constructors
- Avoid expensive computations in build()

---

### Raster Time

**Definition:** Time spent **rasterizing** (converting scene to pixels on GPU).

**What's Included:**

- Layer tree compositing
- GPU shader execution
- Texture upload
- ShaderMask computation (SCN-SHIMMER)

**What's Excluded:**

- Widget build
- Layout
- Network I/O

**Source:** `FrameTiming.rasterDuration`

**Target:** <12ms

**Optimization Targets:**

- Reduce ShaderMask count (SCN-SHIMMER)
- Use image caching (SCN-IMG)
- Avoid expensive effects (blur, shadows)

---

### Jank Percentage

**Definition:** Proportion of frames exceeding the frame deadline.

**Calculation:**

```dart
jankPercent = (framesWithTotalTime > frameDeadline) / totalFrames * 100
```

**Frame Deadline:**

- 60Hz: 16.67ms
- 90Hz: 11.11ms
- 120Hz: 8.33ms

**Target:** <5% for smooth experience

**Severity Scale:**
| Jank % | User Experience |
|--------|-----------------|
| 0-5% | Smooth |
| 5-10% | Occasional hitches |
| 10-20% | Noticeably janky |
| >20% | Poor |

---

### UI Freeze Duration

**Definition:** Period where the UI thread is blocked and no frames render.

**Detection Method:** Timer-based monitoring (50ms granularity)

**Source:** `UiFreezeMonitor`

**Target:** 0ms (no freezes)

**Severity Scale:**
| Duration | Severity | User Impact |
|----------|----------|-------------|
| 100-200ms | Minor | Slight hesitation |
| 200-500ms | Moderate | Noticeable pause |
| 500ms-2s | Severe | "App froze" |
| >2s | Critical | ANR risk |

**Limitations:**

- Timer resolution limits precision (~50ms)
- Cannot detect <50ms micro-freezes
- Timer callback itself uses main thread

---

### Widget Build Count

**Definition:** Number of times a widget's `build()` method is called.

**Source:** Custom logging in widget

**Use Cases:**

- SCN-REBUILD: Measuring unnecessary rebuilds
- General: Debugging rebuild storms

**Interpretation:**

- Compare baseline vs optimized
- Lower is better (for same functionality)
- Zero rebuilds for unchanged state is ideal

---

### Execution Time

**Definition:** Wall-clock time for a specific operation.

**Source:** `Stopwatch`

**Precision:** ~1μs

**Uncertainty:** ±1ms due to JIT/GC

**Best Practices:**

```dart
// Wait for frame boundary for consistent measurement
await SchedulerBinding.instance.endOfFrame;
final sw = Stopwatch()..start();
// ... operation ...
sw.stop();
final timeUs = sw.elapsedMicroseconds;
```

---

### Dart Heap Memory

**Definition:** Memory allocated for Dart objects.

**Source:** VM Service Protocol

**Components:**

- Used heap: Currently allocated objects
- Capacity: Total heap size
- External: Native objects held by Dart

**Limitations:**

- Does not include GPU memory
- Does not include native allocations
- Affected by GC timing

---

### Image Memory (Decoded Bytes)

**Definition:** Memory used by decoded image bitmaps.

**Calculation:**

```dart
decodedBytes = width * height * 4  // RGBA, 4 bytes per pixel
```

**Example:**

- 4000×3000 image = 48,000,000 bytes (48 MB)
- 1200×900 (optimized) = 4,320,000 bytes (4.3 MB)

**Source:** Calculated from image dimensions (ImageInfo)

**Note:** This is RAM usage. GPU texture memory is separate and not directly measurable in Dart.

---

## Aggregation Guidelines

### When to Use Each Statistic

| Statistic        | Use When                                     |
| ---------------- | -------------------------------------------- |
| **Mean**         | Data is normally distributed; total matters  |
| **Median (p50)** | Data is skewed; typical case matters         |
| **p95**          | Tail latency matters; user-perceived quality |
| **p99**          | Worst-case analysis; debugging severe jank   |
| **Max**          | Absolute worst case; GC/system interference  |
| **Min**          | Best achievable; theoretical limit           |
| **Std Dev**      | Consistency matters; variance analysis       |

### Sample Size Requirements

| Statistic | Minimum Samples | Recommended |
| --------- | --------------- | ----------- |
| Mean      | 10              | 30          |
| Median    | 10              | 30          |
| p75       | 20              | 50          |
| p95       | 30              | 100         |
| p99       | 100             | 300         |

---

## Metric Validity by Experiment

| Experiment  | Valid Primary Metrics               | Valid Secondary             | Invalid/Misleading                |
| ----------- | ----------------------------------- | --------------------------- | --------------------------------- |
| SCN-FIB     | FPS during compute, freeze duration | Jank %, dropped frames      | Computation time (should be same) |
| SCN-JSON    | Animation FPS, frame time p95       | Jank during parse           | Network time, total load time     |
| SCN-REBUILD | Build count, total build time       | FPS (if complex widget)     | Memory (not affected)             |
| SCN-LAZY    | Initial build time, widget count    | Memory, time-to-first-frame | FPS (ceiling effect)              |
| SCN-IMG     | Decoded bytes, memory savings %     | Compression ratio           | FPS, raster time                  |
| SCN-SHIMMER | setState count, raster time         | FPS (if low-end device)     | Build time (same)                 |
