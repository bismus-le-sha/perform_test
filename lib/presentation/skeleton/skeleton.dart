import 'package:flutter/material.dart';
import 'package:perform_test/core/config/feature_toggle.dart';
import 'package:perform_test/presentation/skeleton/placeholders.dart';
import 'package:perform_test/presentation/skeleton/shimmer.dart';
import 'package:perform_test/service/app_config/app_config_provider.dart';

const _shimmerGradient = LinearGradient(
  colors: [Color(0xFFEBEBF4), Color(0xFFF4F4F4), Color(0xFFEBEBF4)],
  stops: [0.1, 0.3, 0.4],
  begin: Alignment(-1.0, -0.3),
  end: Alignment(1.0, 0.3),
  tileMode: TileMode.clamp,
);

/// Skeleton placeholder shown during data loading.
///
/// EXPERIMENTS:
///
/// 1. minimizeExpensiveRendering toggle:
///    - false: BadPlaceHolderWay - 6 separate ShaderMask widgets
///    - true: OptimPlaceHolderWay - 1 ShaderMask wrapping all content
///
/// 2. staticPlaceholder toggle:
///    - false: Animated shimmer with ShaderMask (expensive)
///    - true: Static gray boxes (baseline for rendering cost isolation)
///
/// METRICS:
/// - FPS during placeholder display
/// - Raster thread time
/// - setState call count (animated only)
class SkeletonPlaceholder extends StatelessWidget {
  const SkeletonPlaceholder({super.key});

  final bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    final appConfig = AppConfigProvider.of(context);

    // Check if static placeholder mode is enabled
    // This completely disables animation for rendering cost isolation
    final useStaticPlaceholder = appConfig.get(FeatureToggle.staticPlaceholder);

    if (useStaticPlaceholder) {
      return Scaffold(body: StaticPlaceholder(isLoading: _isLoading));
    }

    // Animated shimmer mode
    return Scaffold(
      body: Shimmer(
        linearGradient: _shimmerGradient,
        child: appConfig.get(FeatureToggle.minimizeExpensiveRendering)
            ? OptimPlaceHolderWay(isLoading: _isLoading)
            : BadPlaceHolderWay(isLoading: _isLoading),
      ),
    );
  }
}

/// Static placeholder without animation.
///
/// EXPERIMENT: staticPlaceholder toggle
///
/// HYPOTHESIS: Animated shimmer with ShaderMask has significant rendering cost.
/// Static placeholders isolate the base layout cost from animation overhead.
///
/// METRICS TO COMPARE:
/// - FPS (should be 60 for static, potentially lower for animated)
/// - Raster thread utilization
/// - CPU usage
///
/// Use this as a BASELINE when analyzing shimmer animation cost.
class StaticPlaceholder extends StatelessWidget {
  const StaticPlaceholder({super.key, required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: isLoading ? const NeverScrollableScrollPhysics() : null,
      children: const [
        _StaticCardPlaceholder(),
        SizedBox(height: 8),
        _StaticCardPlaceholder(),
        SizedBox(height: 8),
        _StaticCardPlaceholder(),
      ],
    );
  }
}

/// Static card without ShaderMask or animation.
class _StaticCardPlaceholder extends StatelessWidget {
  const _StaticCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Profile header placeholder
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFEBEBF4),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 120, height: 16, color: const Color(0xFFEBEBF4)),
            ],
          ),
        ),
        // Photo placeholder
        AspectRatio(
          aspectRatio: 1.0,
          child: Container(color: const Color(0xFFEBEBF4)),
        ),
      ],
    );
  }
}

/// Bad placeholder: Multiple separate ShaderMask widgets.
///
/// EXPERIMENT: minimizeExpensiveRendering = false
///
/// Each CustomShaderMask:
/// - Listens to animation controller independently
/// - Calls setState() on every animation frame
/// - Creates its own ShaderMask with gradient computation
///
/// EXPECTED BEHAVIOR:
/// - 6 widgets × 60 FPS = 360 setState() calls per second
/// - Higher raster thread utilization
/// - Potentially lower FPS
class BadPlaceHolderWay extends StatelessWidget {
  const BadPlaceHolderWay({super.key, required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: isLoading ? const NeverScrollableScrollPhysics() : null,
      children: const [
        // Each CustomShaderMask triggers independent setState on animation tick
        // Using RepaintBoundary to isolate repaint cost measurement
        RepaintBoundary(
          child: CustomShaderMask(child: ProfileHeaderPlaceholder()),
        ),
        RepaintBoundary(child: CustomShaderMask(child: PhotoPlaceholder())),
        SizedBox(height: 8),
        RepaintBoundary(
          child: CustomShaderMask(child: ProfileHeaderPlaceholder()),
        ),
        RepaintBoundary(child: CustomShaderMask(child: PhotoPlaceholder())),
        SizedBox(height: 8),
        RepaintBoundary(
          child: CustomShaderMask(child: ProfileHeaderPlaceholder()),
        ),
        RepaintBoundary(child: CustomShaderMask(child: PhotoPlaceholder())),
      ],
    );
  }
}

/// Optimized placeholder: Single ShaderMask wrapping all content.
///
/// EXPERIMENT: minimizeExpensiveRendering = true
///
/// Single CustomShaderMask:
/// - One listener to animation controller
/// - One setState() call per animation frame
/// - One ShaderMask covering entire content
///
/// EXPECTED BEHAVIOR:
/// - 1 widget × 60 FPS = 60 setState() calls per second
/// - Lower raster thread utilization
/// - Stable 60 FPS
class OptimPlaceHolderWay extends StatelessWidget {
  const OptimPlaceHolderWay({super.key, required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: isLoading ? const NeverScrollableScrollPhysics() : null,
      children: const [
        // Single ShaderMask for all content - more efficient
        RepaintBoundary(
          child: CustomShaderMask(
            child: Column(
              children: [
                CardPlaceholder(),
                SizedBox(height: 8),
                CardPlaceholder(),
                SizedBox(height: 8),
                CardPlaceholder(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
