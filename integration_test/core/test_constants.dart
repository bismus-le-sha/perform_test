/// ═══════════════════════════════════════════════════════════════════════════
/// TEST CONFIGURATION CONSTANTS
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Shared configuration for all toggle experiments.
/// Modify these values to adjust experiment parameters.
/// ═══════════════════════════════════════════════════════════════════════════

/// Number of data iterations per toggle state (excluding warmup)
const int kDataIterations = 10;

/// Number of warmup iterations (marked in data, analyzed separately)
const int kWarmupIterations = 2;

/// Cooldown between iterations to stabilize device state
const Duration kIterationCooldown = Duration(seconds: 2);

/// Scroll duration for scroll-based scenarios
const Duration kScrollDuration = Duration(milliseconds: 1500);

/// Animation observation duration
const Duration kAnimationDuration = Duration(seconds: 2);

/// Maximum timeout for network operations (25MB JSON download)
const Duration kNetworkTimeout = Duration(seconds: 120);

/// Frame pump interval (60 FPS target)
const Duration kFrameInterval = Duration(milliseconds: 16);

/// PumpAndSettle timeout for heavy operations
const Duration kHeavyOperationTimeout = Duration(seconds: 30);
