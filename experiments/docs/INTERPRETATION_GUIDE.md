# Results Interpretation Guide

This guide helps you correctly interpret experiment results and avoid common analytical errors.

## 1. Reading Results Files

### 1.1 JSON Result Structure

```json
{
  "metadata": {
    "scenario": { "id": "SCN-FIB", "name": "..." },
    "condition": "baseline",           // or "optimized"
    "timestamp": "2026-01-12T...",
    "deviceModel": "SM-A125F",
    "androidVersion": "12",
    "flutterVersion": "3.10.0",
    "commitHash": "abc123..."
  },
  "metrics": {
    "frameTimings": {
      "summary": {
        "frameCount": 300,
        "avgFps": 58.5,
        "jankPercent": 8.3,
        "buildStats": { "median": 2.1, "p95": 4.5, ... },
        "rasterStats": { "median": 6.2, "p95": 12.1, ... },
        "totalStats": { "median": 14.2, "p95": 18.5, ... }
      }
    },
    "customMetrics": {
      "computation_time_ms": {
        "values": [2012, 2045, 1998, ...],
        "stats": { "median": 2015, "p95": 2050, ... }
      }
    }
  }
}
```

### 1.2 Key Fields to Check First

1. **metadata.condition** - Baseline or optimized?
2. **frameTimings.summary.frameCount** - Enough samples?
3. **frameTimings.summary.jankPercent** - Overall quality
4. **customMetrics.\*.stats.median** - Primary metric values

## 2. Comparison Analysis

### 2.1 Baseline vs Optimized Comparison

```
Step 1: Verify both conditions have same sample size
Step 2: Compare MEDIAN values (not mean)
Step 3: Calculate effect size
Step 4: Check if control metrics unchanged
```

### 2.2 Effect Size Calculation

```
ABSOLUTE EFFECT = optimized_median - baseline_median
PERCENT CHANGE = (baseline - optimized) / baseline × 100%

Example (frame time):
  Baseline median: 18.5ms
  Optimized median: 12.2ms
  Absolute effect: -6.3ms (improvement)
  Percent change: 34% faster
```

### 2.3 Statistical Significance

For performance experiments, practical significance often matters more than statistical significance:

| Percent Change | Interpretation            |
| -------------- | ------------------------- |
| <5%            | Negligible (within noise) |
| 5-20%          | Small but real effect     |
| 20-50%         | Meaningful improvement    |
| >50%           | Large improvement         |

## 3. Common Interpretation Errors

### 3.1 ❌ Error: Comparing Means Instead of Medians

**Problem:** Performance data is typically right-skewed (some frames take much longer). Mean is pulled up by outliers.

**Correct Approach:**

```
✅ Use median (p50) for typical performance
✅ Use p95/p99 for worst-case analysis
❌ Don't use mean for frame times
```

### 3.2 ❌ Error: Ignoring Sample Size

**Problem:** Small sample sizes make statistics unreliable.

**Correct Approach:**

```
✅ Check frameCount or sample count
✅ Minimum 30 samples per condition
✅ For p99, need 100+ samples
```

### 3.3 ❌ Error: FPS Ceiling Effect

**Problem:** If both conditions achieve 60 FPS, you can't see the difference.

**Example:**

```
Baseline: 60.0 FPS
Optimized: 60.0 FPS
WRONG CONCLUSION: "No improvement"

Baseline frame time p95: 15.2ms
Optimized frame time p95: 8.1ms
CORRECT CONCLUSION: "47% headroom improvement"
```

**Correct Approach:**

```
✅ Look at frame time percentiles, not just FPS
✅ Look at jank percentage
✅ Test on slower device to see ceiling effect
```

### 3.4 ❌ Error: Confounding Metrics

**Problem:** Measuring a metric that doesn't reflect the tested variable.

**Examples:**

```
SCN-JSON: Measuring "total load time"
  ❌ Confounds async I/O (same in both) with sync parsing
  ✅ Measure animation FPS DURING parsing only

SCN-IMG: Measuring FPS
  ❌ FPS not affected by bitmap size in memory
  ✅ Measure decoded bytes, memory savings

SCN-FIB: Measuring computation time
  ❌ Should be SAME in both conditions (control metric)
  ✅ Measure UI responsiveness during computation
```

### 3.5 ❌ Error: Ignoring Control Metrics

**Problem:** If a control metric changed, the experiment may be invalid.

**Example:**

```
SCN-FIB Control: Computation time should be same
  Baseline: 2015ms
  Optimized: 2018ms ✅ (within tolerance)

  If optimized was 500ms: ❌ Something wrong with setup
```

## 4. Scenario-Specific Interpretation

### 4.1 SCN-FIB (Fibonacci)

**Primary Question:** Does UI stay responsive during computation?

**Key Metrics:**
| Metric | Baseline Expected | Optimized Expected |
|--------|-------------------|-------------------|
| FPS during compute | ~0 (blocked) | ~60 (responsive) |
| UI freeze duration | ~2000ms | ~0ms |
| Computation time | ~2000ms | ~2000ms (SAME) |

**Success Criteria:**

- Optimized FPS > 30 during computation
- Computation time within 10% (control)

### 4.2 SCN-JSON (JSON Parsing)

**Primary Question:** Does animation stay smooth during parsing?

**Key Metrics:**
| Metric | Baseline Expected | Optimized Expected |
|--------|-------------------|-------------------|
| Animation FPS during parse | <30 (stutter) | ~60 (smooth) |
| Jank frames during parse | HIGH | LOW |
| Parse time | ~Xms | ~Xms (similar) |

**Success Criteria:**

- Optimized maintains >45 FPS during parsing
- Parse time within 20% (may include serialization overhead)

### 4.3 SCN-REBUILD (Widget Rebuild)

**Primary Question:** Does checking state reduce rebuilds?

**Key Metrics:**
| Metric | Baseline Expected | Optimized Expected |
|--------|-------------------|-------------------|
| Build count | HIGH (every scroll) | LOW (~2) |
| Total build time | Higher | Lower |
| FPS | May be same | May be same |

**Success Criteria:**

- Build count reduced by >80%
- FPS may not change for simple widgets (expected)

### 4.4 SCN-LAZY (Lazy Loading)

**Primary Question:** Is initial render faster with lazy loading?

**Key Metrics:**
| Metric | Baseline Expected | Optimized Expected |
|--------|-------------------|-------------------|
| Initial build time | HIGH (~500 widgets) | LOW (~15 widgets) |
| Time to first frame | Longer | Shorter |
| Scroll FPS | Same or better | Same or slight jank |

**Success Criteria:**

- Initial build time reduced by >80%
- Scroll FPS within 5% (trade-off is acceptable)

### 4.5 SCN-IMG (Image Memory)

**Primary Question:** Does sized decoding reduce memory?

**Key Metrics:**
| Metric | Baseline Expected | Optimized Expected |
|--------|-------------------|-------------------|
| Decoded bytes | W×H×4 (full) | (W×DPR)×(H×DPR)×4 |
| Memory savings | 0% | 50-95% |
| Visual quality | Full | Same (at display size) |

**Success Criteria:**

- Memory savings > 50%
- Compression ratio > 2x

### 4.6 SCN-SHIMMER (Shimmer Effect)

**Primary Question:** Does consolidating ShaderMasks improve efficiency?

**Key Metrics:**
| Metric | Baseline Expected | Optimized Expected |
|--------|-------------------|-------------------|
| setState calls/sec | 360 (6×60) | 60 (1×60) |
| Raster time | Higher | Lower |
| FPS | May be same | May be same |

**Success Criteria:**

- setState calls reduced by ~83% (6x → 1x)
- Raster time p95 < 12ms

## 5. Reporting Results

### 5.1 Summary Table Template

```markdown
| Scenario    | Primary Metric     | Baseline | Optimized | Change | Valid? |
| ----------- | ------------------ | -------- | --------- | ------ | ------ |
| SCN-FIB     | FPS during compute | 0        | 58        | +58    | ✅     |
| SCN-JSON    | Animation FPS      | 24       | 57        | +137%  | ✅     |
| SCN-REBUILD | Build count        | 847      | 4         | -99%   | ✅     |
| SCN-LAZY    | Initial build (ms) | 450      | 35        | -92%   | ✅     |
| SCN-IMG     | Decoded bytes (MB) | 48       | 4.3       | -91%   | ✅     |
| SCN-SHIMMER | setState/sec       | 360      | 60        | -83%   | ✅     |
```

### 5.2 Validity Checklist

Before concluding, verify:

- [ ] Sample size adequate (≥30 per condition)
- [ ] Control metrics unchanged
- [ ] Environmental conditions similar
- [ ] No obvious outliers skewing results
- [ ] Effect size exceeds minimum threshold
- [ ] Results reproducible across runs

### 5.3 Conclusion Template

```markdown
## Conclusion: [ACCEPT/REJECT] Hypothesis

**Evidence:**

- Primary metric improved by X% (p50: baseline → optimized)
- Effect size exceeds minimum threshold of Y%
- Control metrics remained stable (within Z%)

**Confidence:** [HIGH/MEDIUM/LOW]

- HIGH: Large effect, many samples, consistent
- MEDIUM: Moderate effect or some variance
- LOW: Small effect near noise floor

**Caveats:**

- [Any limitations or conditions]
- [Device-specific considerations]
- [Generalizability notes]
```
