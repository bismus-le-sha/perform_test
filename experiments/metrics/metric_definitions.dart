/// Metric Definitions Reference
///
/// This file provides formal definitions for all metrics used in experiments,
/// including their sources, units, precision, and interpretation guidelines.
library;

/// ============================================================================
/// FRAME TIMING METRICS
/// ============================================================================
///
/// Source: SchedulerBinding.addTimingsCallback (FrameTiming)
/// Available in: Profile and Release modes
/// NOT available in: Debug mode (timing is distorted)
///
/// ### Build Duration (UI Thread)
/// - **Definition**: Time spent constructing the widget tree and running
///   build() methods.
/// - **Unit**: milliseconds
/// - **Target**: < 4ms (to leave room for other UI work)
/// - **Measurement**: FrameTiming.buildDuration
/// - **What it includes**:
///   - Widget.build() execution
///   - Element tree updates
///   - State management overhead
/// - **What it excludes**:
///   - Layout (RenderObject.performLayout)
///   - Paint (RenderObject.paint)
///   - Compositing
///
/// ### Raster Duration (Raster Thread)
/// - **Definition**: Time spent rasterizing the frame on the GPU.
/// - **Unit**: milliseconds
/// - **Target**: < 12ms
/// - **Measurement**: FrameTiming.rasterDuration
/// - **What it includes**:
///   - Layer tree compositing
///   - GPU shader execution
///   - Texture upload
/// - **What it excludes**:
///   - Build phase
///   - Layout phase
///
/// ### Total Frame Time
/// - **Definition**: End-to-end time from vsync to frame completion.
/// - **Unit**: milliseconds
/// - **Target**: < 16.67ms (60 FPS) or < 8.33ms (120 FPS)
/// - **Measurement**: FrameTiming.totalSpan
/// - **Note**: Includes potential vsync wait time
///
/// ### Jank Detection
/// - **Definition**: Frame that exceeds the deadline (16.67ms for 60Hz).
/// - **Calculation**: totalFrameTime > targetFrameDuration
/// - **Severity levels**:
///   - Minor jank: 1 frame dropped (16.67-33.33ms)
///   - Moderate jank: 2-3 frames dropped (33.33-66.67ms)
///   - Severe jank: 4+ frames dropped (>66.67ms)
///
/// ============================================================================
/// MEMORY METRICS
/// ============================================================================
///
/// ### Dart Heap Used
/// - **Source**: VM Service (Isolate.getMemoryUsage)
/// - **Unit**: bytes / megabytes
/// - **What it measures**: Dart object allocations
/// - **Note**: Does not include native memory or GPU textures
///
/// ### Image Cache Memory
/// - **Source**: PaintingBinding.instance.imageCache
/// - **Unit**: bytes
/// - **What it measures**: Decoded image bitmaps in RAM
/// - **Limitations**: Does not show GPU texture memory
///
/// ### Native Heap (via ADB)
/// - **Source**: adb shell dumpsys meminfo <package>
/// - **Unit**: kilobytes
/// - **What it measures**: C/C++ allocations, Skia buffers
/// - **Limitations**: Requires USB debugging, host-side measurement
///
/// ============================================================================
/// UI RESPONSIVENESS METRICS
/// ============================================================================
///
/// ### FPS (Frames Per Second)
/// - **Calculation**: 1000 / averageFrameTimeMs
/// - **Unit**: frames per second
/// - **Target**: 60 FPS (16.67ms/frame) or device refresh rate
/// - **Limitations**:
///   - Capped by display refresh rate
///   - Doesn't capture frame time variance
///
/// ### Frame Time Percentiles
/// - **Definition**: Statistical distribution of frame times
/// - **Preferred over average**: Captures worst-case behavior
/// - **Key percentiles**:
///   - p50 (median): Typical frame time
///   - p95: 1 in 20 frames are worse than this
///   - p99: 1 in 100 frames are worse than this
///
/// ### UI Freeze Duration
/// - **Definition**: Period where no frames are rendered
/// - **Detection method**: Timer-based monitoring (50ms resolution)
/// - **Threshold**: Usually >200ms is noticeable
/// - **Limitations**: Timer resolution affects accuracy
///
/// ============================================================================
/// COMPUTATION METRICS
/// ============================================================================
///
/// ### Execution Time
/// - **Source**: Stopwatch (dart:core)
/// - **Unit**: microseconds / milliseconds
/// - **Precision**: ~1 microsecond on most platforms
/// - **Best practices**:
///   - Use elapsedMicroseconds for precision
///   - Wait for frame boundary before/after measurement
///   - Warm-up iterations to exclude JIT
///
/// ### Timeline Events
/// - **Source**: dart:developer Timeline API
/// - **Visualization**: Flutter DevTools Performance tab
/// - **Use for**: Identifying phases, correlating with frames
///
/// ============================================================================
/// METRIC VALIDITY TABLE
/// ============================================================================
///
/// | Experiment    | Valid Metrics              | Invalid/Misleading Metrics |
/// |---------------|----------------------------|----------------------------|
/// | SCN-FIB       | FPS during compute,        | Computation time (should   |
/// |               | dropped frames, freeze     | be same in both conditions)|
/// |---------------|----------------------------|----------------------------|
/// | SCN-JSON      | Animation FPS, jank count  | Network time, total load   |
/// |               | during parsing             | time (confounds I/O+parse) |
/// |---------------|----------------------------|----------------------------|
/// | SCN-REBUILD   | Build count, build time    | FPS (may not differ for    |
/// |               |                            | simple widgets)            |
/// |---------------|----------------------------|----------------------------|
/// | SCN-LAZY      | Initial build time, widget | FPS (ceiling effect on     |
/// |               | count, memory              | capable devices)           |
/// |---------------|----------------------------|----------------------------|
/// | SCN-IMG       | Decoded bytes, memory      | FPS, raster time (not      |
/// |               | savings %                  | affected after decode)     |
/// |---------------|----------------------------|----------------------------|
/// | SCN-SHIMMER   | setState() count, raster   | FPS (may hit 60 on both    |
/// |               | time                       | on capable devices)        |
/// |---------------|----------------------------|----------------------------|
///
/// ============================================================================
/// PRECISION AND UNCERTAINTY
/// ============================================================================
///
/// ### Stopwatch Precision
/// - Dart Stopwatch uses monotonic clock
/// - Precision: ~1μs on most platforms
/// - **Uncertainty source**: JIT compilation, GC pauses
///
/// ### Frame Timing Precision
/// - Hardware-backed vsync timestamps
/// - Precision: ~100μs
/// - **Uncertainty source**: Display refresh rate variance
///
/// ### Timer-Based Monitoring
/// - Dart Timer has ~1ms resolution on most platforms
/// - **Cannot detect** sub-millisecond events
/// - Suitable for: Long freezes (>100ms)
/// - Not suitable for: Frame-level analysis
///
/// ### ADB Metrics
/// - Updated per-frame by Android system
/// - **Latency**: Commands have network/USB overhead
/// - Best used for: Post-hoc analysis, not real-time
///
/// ============================================================================
/// AGGREGATION GUIDELINES
/// ============================================================================
///
/// ### When to use Median (p50)
/// - Skewed distributions (most performance data)
/// - Outlier-resistant summary
/// - Example: Frame times, execution times
///
/// ### When to use Mean
/// - Normally distributed data
/// - When total matters (e.g., cumulative build time)
///
/// ### When to use Percentiles (p95, p99)
/// - Worst-case analysis
/// - Tail latency (user-perceived jank)
/// - Always report alongside median
///
/// ### When to use Max
/// - Absolute worst case
/// - Debugging severe jank
/// - **Caution**: Single outliers may be GC or system
///
/// ### Sample Size Guidelines
/// - Minimum: 30 samples (Central Limit Theorem)
/// - Recommended: 100+ samples for percentiles
/// - For p99: Need 100+ samples to be meaningful
