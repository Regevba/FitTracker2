# HADF: Hardware-Aware Dispatch Framework

> **Type:** Theoretical Research / Framework Extension
> **Date:** 2026-04-16
> **Status:** Design Complete (all 9 sections approved)
> **Builds on:** SoC-on-Software Research (v5.0), Dispatch Intelligence (v5.2), Framework Measurement (v6.0)
> **Target:** v6.x or v7.0 framework upgrade (if validated)

---

## 1. Problem Statement

The PM framework (v5.0-v6.0) optimizes dispatch based on **task complexity** (what work needs doing) but is blind to **hardware capability** (what the execution environment can do). Every dispatch decision assumes a generic cloud endpoint and ignores the device entirely.

This leaves performance on the table:

- **On-device compute is free** but unused. Modern chips (A17 Pro: 35 TOPS, Tensor G4: 30+ TOPS) can handle embeddings, classification, and lightweight inference locally.
- **Cloud hardware varies** but is treated as uniform. An H100-class GPU serves requests differently than a TPU v5, but the framework dispatches identically to both.
- **Conditions change mid-session** (thermal throttling, cloud load spikes, network degradation) but dispatch strategy is static.

HADF makes the framework **hardware-aware** at both ends of the pipeline (device + cloud) and adapts dispatch strategy in real-time.

## 2. Design Principles

1. **Extension, not replacement.** HADF adds a `hardware_context` field to `dispatch-intelligence.json`. The existing v5.2 dispatch engine (complexity scoring, model routing, tool budgets) remains the decision-maker. HADF provides better inputs.

2. **Graceful degradation.** Every layer has a fallback. Unknown device? Architecture-level default. Uncertain cloud? Static provider lookup. No affinity data? Cold start with Layer 1 baselines. Worst case: framework behaves identically to today.

3. **Confidence-gated.** HADF never overrides dispatch below a confidence threshold. The gate starts high (effectively disabled) and lowers as data validates the system.

4. **Zero extra cost.** No additional API calls. No cloud telemetry uploads. All fingerprinting data derived from timestamps the app already has. All learning data stays on-device.

5. **Measured from day one.** v6.0's instrumentation protocols measure HADF's effectiveness automatically. Phase timing, cache metrics, and token budgets all capture HADF-specific data.

## 3. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                    HADF Pipeline                                  │
│                                                                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐        │
│  │  Device       │    │  Cloud        │    │  Composite   │        │
│  │  Detection    │───>│  Fingerprint  │───>│  Optimizer   │        │
│  │  Engine       │    │  Engine       │    │  (L/C/Q)     │        │
│  │  (Layer 0)    │    │  (Layer 2)    │    │              │        │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘        │
│         │                   │                    │                 │
│         v                   v                    v                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐        │
│  │  Static       │    │  Dynamic      │    │  Evolutionary │       │
│  │  Profiles     │    │  Adaptation   │    │  Learning     │       │
│  │  (Layer 1)    │    │  (Layer 3)    │    │  (Layer 4)    │       │
│  └──────────────┘    └──────────────┘    └──────────────┘        │
│         │                   │                    │                 │
│         └───────────────────┼────────────────────┘                │
│                             v                                     │
│                   ┌──────────────────┐                            │
│                   │  hardware_context │                            │
│                   │  (JSON output)    │                            │
│                   └────────┬─────────┘                            │
│                            │                                      │
└────────────────────────────┼──────────────────────────────────────┘
                             v
                   ┌──────────────────┐
                   │  v5.2/v6.0       │
                   │  Dispatch Engine  │  (existing — reads hardware_context)
                   └──────────────────┘
```

**Data flow per session:**

1. Session starts → Layer 0 detects device chip (deterministic, instant)
2. Layer 1 loads matching static profile (lookup, instant)
3. Layer 4 checks Chip Affinity Map for warm-start data
4. First cloud call → Layer 2 begins fingerprinting (probabilistic, improves over calls)
5. After N calls → Layer 3 activates dynamic adaptation (continuous)
6. Session ends → Layer 4 writes telemetry to Chip Affinity Map (cross-session learning)

## 4. Layer 0: Device Detection Engine

Fully deterministic. Every platform exposes chip identity through OS APIs.

### Detection per platform

| Platform | API | Returns | Example |
|---|---|---|---|
| iOS/iPadOS | `utsname.machine` via `sysctluname` | Device model → chip mapping | `iPhone16,1` → A17 Pro |
| macOS | `sysctlbyname("machdep.cpu.brand_string")` | Direct chip ID | `Apple M3 Max` |
| Android (API 31+) | `Build.SOC_MANUFACTURER` + `Build.SOC_MODEL` | Direct SoC identity | `Google` + `Tensor G4` |
| Android (legacy) | `Build.HARDWARE` + `/proc/cpuinfo` | Chipset name, core config | `taro` → Snapdragon 8 Gen 1 |
| Web/WASM | `navigator.hardwareConcurrency` + `navigator.deviceMemory` | Core count + RAM (coarse) | 8 cores, 8GB |

### Output: Device Capability Manifest

```json
{
  "chip_id": "apple_a17_pro",
  "vendor": "apple",
  "arch": "arm64",
  "family": "a_series",
  "generation": 17,
  "cores": {
    "performance": 2,
    "efficiency": 4,
    "gpu": 6
  },
  "npu": {
    "present": true,
    "tops": 35,
    "supported_formats": ["coreml", "float16", "int8"]
  },
  "memory": {
    "total_gb": 8,
    "bandwidth_gbps": 51.2,
    "unified": true
  },
  "thermal_class": "mobile",
  "detection_confidence": 1.0
}
```

### Design decisions

- **Local lookup table** (`chip-profiles.json`, ~50 chips). Updated with app releases. No network call.
- **Runs once** at session start. Hardware doesn't change mid-session. Cached for session lifetime.
- **Unknown chips** degrade to architecture-level defaults (`arm64_mobile_unknown`, `arm64_desktop_unknown`). Unknown chip ID logged for next profile update.
- **Web/WASM** is the weakest signal. Browser APIs intentionally obscure hardware (fingerprinting protection). Enough for tier classification (low/mid/high), not specific chips.

## 5. Layer 1: Static Chip Profiles

Pre-built optimization profiles per chip family. The framework's starting knowledge before it observes anything at runtime.

### Profile schema

```json
{
  "profile_id": "apple_a17_pro",
  "family": "a_series",
  "vendor": "apple",
  "tier": "high",
  "compute_budget": {
    "on_device_ml_capable": true,
    "npu_tops": 35,
    "max_model_size_mb": 4000,
    "preferred_precision": "float16",
    "concurrent_ml_tasks": 2
  },
  "dispatch_hints": {
    "prefer_on_device": ["text_classification", "embedding", "lightweight_inference"],
    "prefer_cloud": ["complex_reasoning", "long_context", "multi_step_planning"],
    "hybrid_capable": true
  },
  "thermal_profile": {
    "sustained_workload_seconds": 30,
    "throttle_risk": "moderate",
    "battery_sensitivity": "high"
  },
  "memory_constraints": {
    "available_for_ml_mb": 3000,
    "unified_memory": true,
    "swap_penalty": "none"
  },
  "composite_baseline": {
    "latency_score": 0.82,
    "cost_score": 0.90,
    "quality_score": 0.65,
    "overall": 0.79
  }
}
```

### Coverage (~50 profiles, 95%+ of active devices)

| Tier | Apple | Google | Qualcomm | Samsung | MediaTek |
|---|---|---|---|---|---|
| Flagship | A17 Pro, A18 Pro, M3/M4 | Tensor G4 | Snapdragon 8 Gen 3 | Exynos 2400 | Dimensity 9300 |
| Mid | A16, A17, M1/M2 | Tensor G3 | Snapdragon 7 Gen 3 | Exynos 1480 | Dimensity 8300 |
| Low | A15 and below | Tensor G2 | Snapdragon 6 Gen 1 | Exynos 1380 | Dimensity 7050 |
| Desktop/Server | M3 Ultra, M4 Max | -- | Snapdragon X Elite | -- | -- |

### Design decisions

- **Dispatch-oriented, not spec sheets.** Only data that affects dispatch decisions. "NPU 35 TOPS" matters. "GPU clock 2.15GHz" doesn't.
- **`composite_baseline` is the key output.** Three scores (0-1) relative to cloud: latency (how fast on-device), cost (how much offload), quality (how close to cloud).
- **Ships with app binary.** No network dependency. `profile_version` field tracks staleness.
- **Unknown chips** get tier-estimated profiles. Layer 0 detects `arm64 + 8 cores + 6GB` → `arm64_mid_tier_estimated`.
- **Desktop profiles unlock different strategies.** M4 Max with 128GB can run models locally that phones never could.

## 6. Layer 2: Cloud Inference Fingerprinting

The novel contribution of this framework. No one formally does this today.

### The problem

When you call `api.anthropic.com/v1/messages`, you get a response but not a hardware manifest. The inference provider abstracts the hardware away. But the response carries signals about what hardware served it.

### Measurable signals per API call

| Signal | What it reveals | Measurement |
|---|---|---|
| Time-to-first-token (TTFT) | Prefill speed → chip architecture class | `timestamp_first_token - timestamp_request_sent` |
| Tokens per second (TPS) | Decode throughput → memory bandwidth + compute | `output_tokens / (end_time - first_token_time)` |
| TTFT variance | Load balancer behavior → fleet homogeneity | Standard deviation over N calls |
| TPS consistency | Thermal/power throttling → chip class | Coefficient of variation within session |
| Latency floor | Network RTT vs. compute → geography + hardware | Minimum observed TTFT over N calls |
| Batch sensitivity | Throughput vs. input length → memory architecture | Compare TPS at 500 vs 5000 input tokens |
| Concurrent degradation | TPS under load → parallelism model | Measure during known high-traffic windows |

### Three-stage algorithm

**Stage 1: Collect (calls 1-5)**

Raw signal recording. Every API call automatically records TTFT, TPS, input/output counts, timestamp. Zero overhead.

```json
{
  "call_id": "uuid",
  "timestamp": "2026-04-16T10:23:01Z",
  "provider": "anthropic",
  "model": "claude-sonnet-4-6",
  "input_tokens": 2400,
  "output_tokens": 850,
  "ttft_ms": 340,
  "tps": 78.2,
  "total_latency_ms": 11220,
  "region_hint": "us-east-1"
}
```

**Stage 2: Classify (calls 5-15)**

Statistical classifier using **Mahalanobis distance** against known Hardware Signature Table:

```
Hardware Signature Table (from public benchmarks):

Hardware Class     | TTFT/1K tokens | TPS (median) | TPS Variance | Batch Scaling
-------------------|----------------|--------------|--------------|---------------
NVIDIA H100 SXM   | 45-65ms        | 80-120       | < 0.08       | 0.92-0.98
NVIDIA A100        | 70-100ms       | 55-80        | < 0.10       | 0.88-0.95
Google TPU v5e     | 50-75ms        | 70-100       | < 0.12       | 0.95-0.99
Google TPU v4      | 60-90ms        | 50-75        | < 0.15       | 0.90-0.96
AWS Trainium 2     | 55-80ms        | 65-90        | < 0.10       | 0.91-0.97
AMD MI300X         | 50-70ms        | 75-105       | < 0.09       | 0.93-0.98
CPU fallback       | 200+ms         | 10-30        | > 0.20       | 0.60-0.80

Note: Illustrative ranges. Real values require empirical calibration.
```

Output: Cloud Hardware Estimate with confidence:

```json
{
  "estimated_class": "nvidia_h100_class",
  "confidence": 0.72,
  "runner_up": "google_tpu_v5e_class",
  "runner_up_confidence": 0.18,
  "signals_used": 8,
  "classification_method": "mahalanobis_nearest"
}
```

**Stage 3: Refine (calls 15+)**

- Confidence narrows over calls (0.72 → 0.88 after 30 calls)
- Detects hardware migration: sudden TPS/TTFT pattern shift → reclassify
- Analogous to TCP congestion detection

### Limitations

- Gets hardware **class**, not exact chip. "H100-class GPU" not "H100 SXM5 at 700W in rack 3."
- Can't distinguish custom silicon from similar-performing known chips. Classifies by behavior, not branding.
- Network noise inflates TTFT. Mitigated via latency floor (minimum observed) and TPS (post-connection, less affected).
- All data stays **on-device**. Zero privacy impact. Zero extra API calls.

## 7. Layer 3: Dynamic Adaptation Engine

Real-time mid-session dispatch adjustment. Static profiles are a starting point; reality drifts.

### Adaptation loop

```
Every N calls (or on significant signal change):

  Collect live signals (Layer 0 device state + Layer 2 cloud fingerprint)
       |
       v
  Compare to expected profile (Layer 1 baseline)
       |
       v
  Deviation detection
       |
       +--> deviation < threshold --> No change
       |
       +--> deviation >= threshold --> Adjust dispatch weights
                                          |
                                          v
                                      Updated composite score
                                      --> v5.2 dispatch engine
```

### Four signal categories

**1. Device Thermal State**

| Platform | API | Signal |
|---|---|---|
| iOS | `ProcessInfo.thermalState` | `.nominal` → `.serious` → `.critical` |
| Android | `PowerManager.THERMAL_STATUS_*` | `NONE` → `MODERATE` → `SEVERE` → `SHUTDOWN` |
| macOS | `IOKit` thermal sensors | Temperature + fan speed |

Escalation matrix:
- `nominal` → full on-device capability
- `fair` → reduce on-device concurrency 50%
- `serious` → lightweight tasks only (classification, not inference)
- `critical` → all compute to cloud

**2. Cloud Performance Drift**

- TPS drop >20% from baseline → cloud under load or migrated to slower hardware
- TTFT spike >2x from latency floor → region failover or degraded path
- TPS variance increase → fleet instability

**3. Network Conditions**

- RTT increase → cloud calls cost more → on-device relatively cheaper
- Packet loss → cloud reliability drops → prefer on-device for latency-sensitive tasks
- WiFi → cellular handoff → entire bandwidth/latency profile changes

**4. Battery State (mobile only)**

| Battery | Charging? | Adaptation |
|---|---|---|
| >50% | No | Full capability |
| 20-50% | No | Reduce on-device ML 50% |
| <20% | No | Prefer cloud |
| Any | Yes | Full capability (thermal limits still apply) |

### Dispatch weight formula

```
adjusted_score = baseline_score
  x device_modifier    [0.1 - 1.5]
  x cloud_modifier     [0.1 - 1.5]
  x network_modifier   [0.1 - 1.5]
  x battery_modifier   [0.1 - 1.5]
```

Feeds into dispatch as `hardware_context.realtime_score`.

### Frequency and anti-thrashing

- Device signals: event-driven via OS notification callbacks (~30s)
- Cloud signals: re-evaluated per API call (piggybacks on Layer 2)
- Network: derived from TTFT decomposition on cloud signal changes
- Weight recalculation: only when a modifier changes by >5%

### What Layer 3 does NOT do

- No prediction (that's Layer 4)
- No cross-session memory (that's Layer 4)
- No user-visible changes (invisible adaptation)

## 8. Layer 4: Evolutionary Learning

Cross-session learning. Builds a persistent model of what works best on each hardware combination.

### Chip Affinity Map

Local database (SQLite or JSON) on-device. Each entry pairs a device chip with an observed cloud hardware class and the optimal dispatch strategy for that pair.

```json
{
  "affinity_entries": [
    {
      "device_chip": "apple_a17_pro",
      "cloud_class": "nvidia_h100_class",
      "cloud_confidence": 0.85,
      "region_hint": "us-east-1",
      "samples": 847,
      "last_updated": "2026-04-16T14:30:00Z",
      "learned_weights": {
        "on_device_tasks": ["embedding", "classification", "tokenization"],
        "cloud_tasks": ["reasoning", "long_context", "code_generation"],
        "hybrid_threshold_tokens": 2000,
        "optimal_batch_size": 3,
        "preferred_concurrency": 2
      },
      "performance_history": {
        "avg_latency_ms": 1240,
        "avg_tps": 82.4,
        "p95_latency_ms": 2100,
        "cost_per_1k_tokens": 0.0032,
        "quality_score_avg": 0.88
      },
      "time_patterns": {
        "peak_hours_utc": [14, 15, 16, 17],
        "peak_tps_degradation": 0.78,
        "off_peak_tps_bonus": 1.12
      }
    }
  ]
}
```

### Session lifecycle

**Start:**
1. Layer 0 detects device → check Affinity Map for this chip
2. Entry exists → pre-load learned_weights (warm start, skip cold-start phase)
3. No entry → use Layer 1 static profile (cold start)

**During:**
4. Layer 2 classifies cloud → check for device+cloud pair
5. Pair exists → refine learned_weights with session data
6. No pair → create new entry seeded from Layer 1 baseline

**End:**
7. Update performance_history (rolling average, last 50 sessions)
8. Update time_patterns if new peak/off-peak data
9. Update learned_weights if Layer 3 found a better strategy
10. Increment samples counter

### Learning algorithm: Exponential Moving Average

```
new_weight = alpha x session_observation + (1 - alpha) x stored_weight

Learning rate (alpha) by experience:
  First 10 sessions:  alpha = 0.3   (learn fast)
  Sessions 10-50:     alpha = 0.1   (stabilize)
  Sessions 50+:       alpha = 0.05  (slow drift tracking)
```

### Time-of-day patterns

Cloud performance varies predictably by time. Peak hours (14:00-18:00 UTC for US providers) show lower TPS. The framework learns this and **preemptively** shifts dispatch during learned peak hours before Layer 3 detects degradation. First predictive capability.

### Cold start vs. warm start

| Scenario | Behavior | Time to optimal |
|---|---|---|
| Brand new device | Layer 1 only | ~15 API calls |
| Known device, new cloud class | Seed from nearest known class | ~8 calls |
| Known device + known cloud | Full affinity loaded | Immediate (0 calls) |
| Device upgrade (same vendor) | Nearest-family seed (A16 → A17) | ~5 calls |

### Data hygiene

- **Expiration:** 90 days without access → archived (not deleted)
- **Anomaly rejection:** >3 standard deviations from history → excluded from EMA
- **Storage cap:** 200 entries (~50 chips x 4 cloud classes) = ~100KB
- **Privacy:** All on-device. Never synced, never uploaded.

### What Layer 4 uniquely enables

1. Zero cold-start for returning users
2. Provider migration detection (cloud class goes stale → reclassify)
3. Time-aware optimization (no other layer knows "Tuesdays at 3pm are slow")
4. Device upgrade continuity (cloud-side knowledge carries forward)

## 9. Composite Optimization Score

All four layers converge into a single output for the dispatch engine.

### Formula

```
CompositeScore = w_L x LatencyScore + w_C x CostScore + w_Q x QualityScore

Where w_L + w_C + w_Q = 1.0
```

### Context-dependent weights

| Context | w_L (Latency) | w_C (Cost) | w_Q (Quality) | Rationale |
|---|---|---|---|---|
| User-facing interaction | 0.50 | 0.15 | 0.35 | User is waiting |
| Background task | 0.15 | 0.50 | 0.35 | No one waiting, minimize cost |
| Critical reasoning | 0.10 | 0.10 | 0.80 | Accuracy trumps everything |
| High-frequency polling | 0.35 | 0.45 | 0.20 | Many small calls |

### Sub-score computation

**Latency Score:**
- Device latency: Layer 1 baseline x Layer 3 device_modifier
- Cloud latency: Layer 2 expected TPS/TTFT x Layer 3 cloud_modifier x network_modifier
- Layer 4 override: if affinity exists (>50 samples, confidence >0.8), use learned latency + time pattern

**Cost Score:**
- on_device_ratio x 1.0 + cloud_ratio x cloud_cost_factor
- Layer 4 override: learned optimal on_device_ratio

**Quality Score:**
- On-device tasks: device quality baseline
- Cloud tasks: 1.0 (cloud is reference)
- Hybrid zone: interpolated by Layer 2 confidence

### Output: hardware_context JSON

```json
{
  "hardware_context": {
    "device": {
      "chip_id": "apple_a17_pro",
      "tier": "high",
      "realtime_modifier": 0.92,
      "thermal_state": "fair"
    },
    "cloud": {
      "estimated_class": "nvidia_h100_class",
      "confidence": 0.85,
      "realtime_tps": 78.4,
      "drift_status": "stable"
    },
    "composite": {
      "score": 0.81,
      "latency_component": 0.84,
      "cost_component": 0.76,
      "quality_component": 0.88,
      "weight_preset": "user_facing",
      "strategy": "hybrid",
      "on_device_tasks": ["embedding", "classification"],
      "cloud_tasks": ["reasoning", "code_generation"],
      "affinity_source": "learned",
      "affinity_samples": 847
    },
    "meta": {
      "hadf_version": "1.0",
      "layers_active": [0, 1, 2, 3, 4],
      "layer2_calls_observed": 23,
      "layer4_warm_start": true
    }
  }
}
```

### Confidence gate

```
score > 0.7  --> trust HADF strategy fully
score 0.4-0.7 --> blend HADF with default (weighted average)
score < 0.4  --> ignore HADF, use default v5.2/v6.0 routing
```

### Edge case: all layers degraded

Unknown device + uncertain cloud + no affinity = strategy `cloud_preferred` = identical to current behavior without HADF. **Zero regression.**

## 10. v6.0 Integration Design

HADF plugs into the existing framework at three points.

### Integration Point 1: Dispatch Intelligence Config

`dispatch-intelligence.json` gains a `hardware_context` section:

```
dispatch-intelligence.json:
  model_routing          (v5.2 — existing)
  probe                  (v5.2 — existing)
  validation             (v5.2 — existing)
  mirror_pattern         (v5.2 — existing)
  hardware_context       (HADF — new)
```

The dispatch engine's 3-stage pipeline (probe → score → route) is enhanced at stage 2:

- **Stage 1 (Probe):** Unchanged. Assesses task complexity.
- **Stage 2 (Score):** HADF-enhanced. Reads `hardware_context.composite.strategy` to determine hybrid/cloud/device routing. Confidence gate applied here.
- **Stage 3 (Route):** Unchanged. Applies model + tool budget.

### Integration Point 2: v6.0 Measurement Protocols

| v6.0 Protocol | HADF Measurement | File |
|---|---|---|
| Phase timing | Dispatch overhead (<50ms target) | `state.json.timing` |
| Cache hit tracking | Affinity Map hit rate | `.claude/features/{name}/hadf-metrics.json` |
| Token budget | HADF context cost | `token-budget.json` (new layer) |
| CU v2 | Effective CU reduction from hardware-aware dispatch | `cache-metrics.json` baselines |

### Integration Point 3: Shared Data Layer

New files:

| File | Purpose | Size | Access |
|---|---|---|---|
| `.claude/shared/chip-profiles.json` | Static profiles (Layer 1) | ~25KB | Read-only at runtime |
| `.claude/shared/chip-affinity-map.json` | Learned data (Layer 4) | ~100KB max | Read at start, write at end |

Extended files:

| File | New section | Purpose |
|---|---|---|
| `dispatch-intelligence.json` | `hardware_context` | HADF output for dispatch |
| `cache-metrics.json` | `hadf_affinity` | Aggregate affinity statistics |
| `token-budget.json` | `hadf` layer | Token overhead tracking |

### Per-feature telemetry: hadf-metrics.json

```json
{
  "feature": "smart-reminders",
  "hadf_version": "1.0",
  "sessions": 12,
  "device": {
    "chip_id": "apple_a17_pro",
    "detection_method": "utsname",
    "confidence": 1.0
  },
  "cloud": {
    "classified_as": "nvidia_h100_class",
    "confidence_progression": [0.0, 0.42, 0.65, 0.78, 0.85],
    "reclassifications": 0
  },
  "adaptation_events": [
    {
      "session": 3,
      "trigger": "thermal_escalation",
      "from": "hybrid",
      "to": "cloud_preferred",
      "duration_minutes": 4.2
    }
  ],
  "affinity": {
    "warm_starts": 9,
    "cold_starts": 3,
    "hit_rate": 0.75
  },
  "impact": {
    "avg_dispatch_overhead_ms": 12,
    "latency_improvement_pct": null,
    "cost_savings_pct": null
  }
}
```

### Change impact summary

| Component | Change | Risk |
|---|---|---|
| `dispatch-intelligence.json` | New section | None (additive) |
| `cache-metrics.json` | New section | None (additive) |
| `token-budget.json` | New layer entry | None (reporting) |
| Dispatch engine (SKILL.md) | Stage 2 reads hardware_context | Low (confidence gate) |
| `chip-profiles.json` | New file | None (config) |
| `chip-affinity-map.json` | New file | Low (local, capped) |
| `hadf-metrics.json` | New file | None (measurement) |

## 11. Validation Plan

Five phases, each validating a layer independently, then the system end-to-end.

### Phase 1: Device Detection (Layer 0 + Layer 1)

| Test | Method | Pass |
|---|---|---|
| Chip ID accuracy | 10+ physical devices | 100% correct |
| Unknown chip | Spoofed model string | Falls back to arch default |
| Profile accuracy | Core ML benchmark on 5 devices | Within 20% of stated TOPS |
| Profile staleness | Remove chip-profiles.json | Degrades, no crash |
| Cross-platform | iOS sim, Android emu, macOS | Correct API per platform |

**Timeline:** Immediate. No cloud dependency.

### Phase 2: Cloud Fingerprinting (Layer 2)

**Experiment:** 50 identical API calls x 5 times of day x 3 days = 750 data points. Measure TTFT, TPS, total latency.

| Outcome | Meaning | Action |
|---|---|---|
| Clear stable clusters | Hardware classes detectable | Calibrate classifier |
| Clusters shift by time | Load balancer moves traffic | Layer 2 + Layer 3 validated |
| Fuzzy clusters | Hardware too similar or noise dominates | Reduce to coarse classification |
| No clusters | Network dominates latency | Layer 2 invalidated; fall back to static |

**Cost:** ~$5 in API calls.

### Phase 3: Dynamic Adaptation (Layer 3)

Within-session A/B: calls 1-10 (HADF off), 11-20 (HADF on), 21-30 (HADF on + simulated thermal stress).

| Signal | Validated if | Failed if |
|---|---|---|
| Thermal adaptation | Shift within 30s | No shift or >2min |
| Cloud drift | Modifier adjusts after 3+ degraded calls | No adjustment or false positive |
| Battery | Workload reduces at 20% | No change |
| Anti-thrashing | Max 1 change per 30s under stable conditions | Rapid oscillation |

### Phase 4: Evolutionary Learning (Layer 4)

**Longitudinal:** Week 1 (5 features, cold start) vs. Week 2 (5 features, warm start).

- Warm-start should reach optimal dispatch 3x faster
- EMA stabilizes after 10 sessions
- Anomaly rejection correctly excludes bad sessions

### Phase 5: End-to-End (Confidence Gate Ramp)

| Stage | Gate | Features | Purpose |
|---|---|---|---|
| A | 0.99 (disabled) | 3 features | Baseline |
| B | 0.70 (high confidence) | 3 features | Partial activation |
| C | 0.40 (full) | 3 features | Full activation |

**Success metrics:**

| Metric | Baseline (A) | Target (C) | Kill |
|---|---|---|---|
| Dispatch overhead | 0ms | <50ms | >200ms |
| Latency improvement | 0% | >10% reduction | Increase >5% |
| Token budget | 79K | <80K (+1K) | >85K |
| Warm-start hit rate | N/A | >60% at 10 sessions | <30% at 20 sessions |
| Cloud confidence | N/A | >0.70 avg at 15 calls | <0.50 at 30 calls |
| Zero regression | Pass | Pass | Any feature fails |

**Total validation:** ~4-5 weeks, ~$5-10 API cost.

## 12. Open Questions

1. **Can cloud fingerprinting actually work?** Phase 2 validation is the gate. If clusters don't emerge, Layer 2 falls back to static provider lookup — still useful but less novel.

2. **How does multi-provider routing interact?** If the app calls both Anthropic and OpenAI, each gets its own fingerprint. The Affinity Map stores per-provider entries.

3. **On-device model availability.** Layer 1 assumes certain models can run locally. Apple's Core ML model catalog and Android's ML Kit evolve — profiles need to track which on-device models are available per OS version, not just per chip.

4. **Privacy regulation.** Device fingerprinting (even self-directed, on-device) may intersect with App Store guidelines. Layer 0's detection uses public APIs, but bundling chip capability data could be flagged during review. Needs legal review before shipping.

5. **Chip Affinity Map portability.** If a user restores from backup to a new device, the Affinity Map's device-side entries are stale. The map should detect device_chip mismatch and invalidate device-specific entries while preserving cloud-side knowledge.

---

> **Next steps:** If this research is validated (especially Phase 2 — cloud fingerprinting), HADF becomes a candidate for the v6.x or v7.0 framework upgrade. The confidence gate allows incremental rollout with zero regression risk.
