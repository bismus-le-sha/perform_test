/// Feature toggles for controlled performance experiments.
///
/// Each toggle isolates ONE performance variable for A/B comparison.
/// All toggles default to false (unoptimized/baseline state).
///
/// EXPERIMENTAL DESIGN PRINCIPLES:
/// 1. Each toggle tests ONE hypothesis
/// 2. Baseline (false) should be measurably worse
/// 3. Optimized (true) should show clear improvement
/// 4. No toggle should have confounding side effects
enum FeatureToggle {
  /// EXPERIMENT: UI thread blocking via synchronous computation
  ///
  /// HYPOTHESIS: Heavy synchronous computation blocks the UI thread,
  /// causing dropped frames and visible freeze. Using compute() offloads
  /// work to a background isolate, keeping UI responsive.
  ///
  /// METRICS:
  /// - Execution time (should be same for both)
  /// - UI freeze duration (high for sync, zero for async)
  /// - Frame drops during computation
  ///
  /// false: Sync recursive Fibonacci on main isolate (BLOCKS UI)
  /// true: Fibonacci via compute() in background isolate (UI RESPONSIVE)
  optimFibonacci,

  /// EXPERIMENT: Widget rebuild efficiency
  ///
  /// HYPOTHESIS: Calling setState() on every scroll event causes excessive
  /// widget rebuilds. Checking if state actually changed before setState()
  /// reduces unnecessary rebuilds.
  ///
  /// METRICS:
  /// - Widget build() call count (via debugPrint)
  /// - Build time accumulation
  /// - FPS during scrolling
  ///
  /// false: BadScrollToTopButton - setState on EVERY scroll event
  /// true: OptimScrollToTopButton - setState only when threshold crossed
  correctDataUpdate,

  /// EXPERIMENT: Lazy vs eager list rendering
  ///
  /// HYPOTHESIS: Eagerly building all list items (Column) is expensive
  /// for large lists. ListView.builder lazily builds only visible items.
  ///
  /// METRICS:
  /// - Initial build time (high for eager, low for lazy)
  /// - Memory usage (high for eager, low for lazy)
  /// - Scroll performance (potentially worse for lazy due to on-demand building)
  ///
  /// false: SingleChildScrollView + Column (ALL items built immediately)
  /// true: ListView.separated (items built on-demand)
  lazyLoad,

  /// EXPERIMENT: Image rasterization memory optimization
  ///
  /// HYPOTHESIS: Decoding full-resolution images into GPU memory is wasteful
  /// when displayed at smaller sizes. Using cacheWidth/cacheHeight tells
  /// Flutter to decode at the target display size.
  ///
  /// METRICS:
  /// - Decoded image bytes (via ImageInfo.sizeBytes)
  /// - GPU memory usage (DevTools)
  /// - Raster thread time
  ///
  /// NOTE: This tests CLIENT-SIDE decoding, not server-side resizing.
  /// Both states load the SAME image URL.
  ///
  /// false: Decode at full resolution (wastes GPU memory)
  /// true: Decode at layout size × devicePixelRatio (optimized)
  optimImageSize,

  /// EXPERIMENT: ShaderMask consolidation for shimmer effect
  ///
  /// HYPOTHESIS: Multiple ShaderMask widgets each trigger independent
  /// GPU shader computations. Consolidating into a single ShaderMask
  /// reduces GPU work and setState calls.
  ///
  /// METRICS:
  /// - setState() call count (6x vs 1x per animation frame)
  /// - Raster thread time
  /// - FPS during shimmer animation
  ///
  /// false: BadPlaceHolderWay - 6 separate ShaderMask widgets
  /// true: OptimPlaceHolderWay - 1 ShaderMask wrapping all content
  minimizeExpensiveRendering,

  /// EXPERIMENT: JSON parsing on main isolate vs background isolate
  ///
  /// HYPOTHESIS: Parsing large JSON on the main isolate blocks UI rendering.
  /// Using compute() moves parsing to a background isolate.
  ///
  /// METRICS:
  /// - Parse time (should be SAME for both - isolated measurement)
  /// - UI freeze duration (high for sync, zero for async)
  /// - Frame drops during parsing
  ///
  /// NOTE: File I/O is measured separately from parsing.
  ///
  /// false: Parse on main isolate (BLOCKS UI)
  /// true: Parse via compute() (UI RESPONSIVE)
  largeJsonParce, // Note: historical typo preserved for config compatibility
  /// EXPERIMENT: Static vs animated placeholder
  ///
  /// HYPOTHESIS: Animated shimmer with continuous repaint is more expensive
  /// than static placeholders. This toggle isolates animation cost.
  ///
  /// METRICS:
  /// - FPS (should be 60 for static, potentially lower for animated)
  /// - Raster thread utilization
  /// - Battery/CPU usage
  ///
  /// false: Animated shimmer with ShaderMask
  /// true: Static gray placeholder (no animation)
  staticPlaceholder,
}
